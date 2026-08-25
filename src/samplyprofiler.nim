## Low-overhead custom interval markers for the Samply profiler.
##
## Build the program with `-d:samply` to enable marker output. Without that
## define, `marker` expands to its body and `initSamplyProfiler` is disabled.
## On Linux, Samply discovers marker files from mmap events, so this module
## keeps the marker file mapped for the lifetime of the profiler. The marker
## file is created in the working directory, or in the system temp directory
## when the working directory cannot support a writable shared mapping (for
## example a Windows drive accessed from WSL).
## Non-Linux builds keep the same no-op API and do not create marker files.
##
## The marker format is one completed interval per line:
##
##   <monotonic_start_ns> <monotonic_end_ns> <name>
##
## Use `PerThread` for parallel code. Use `PerProcess` when one thread owns the
## profiler and one marker file is sufficient.

when defined(linux):
  import std/os

when defined(linux):
  type
    CTimespec {.importc: "struct timespec", header: "<time.h>".} = object
      `tv_sec`: int64
      `tv_nsec`: int64

  proc cClockGettime(clockId: cint, ts: ptr CTimespec): cint {.
    importc: "clock_gettime", header: "<time.h>".}
  proc cGetPid(): cint {.importc: "getpid", header: "<unistd.h>".}
  proc cSyscall(number: clong): clong {.importc: "syscall", header: "<unistd.h>".}

  proc cOpen(path: cstring, flags: cint, mode: cuint): cint {.
    importc: "open", header: "<fcntl.h>".}
  proc cClose(fd: cint): cint {.importc: "close", header: "<unistd.h>".}
  proc cFtruncate(fd: cint, length: int64): cint {.
    importc: "ftruncate", header: "<unistd.h>".}
  proc cMmap(address: pointer, length: csize_t, protection: cint,
             flags: cint, fd: cint, offset: int64): pointer {.
    importc: "mmap", header: "<sys/mman.h>".}
  proc cMunmap(address: pointer, length: csize_t): cint {.
    importc: "munmap", header: "<sys/mman.h>".}
  proc cMremap(oldAddress: pointer, oldSize: csize_t, newSize: csize_t,
               flags: cint): pointer {.
    importc: "mremap", header: "<sys/mman.h>".}
  proc cMsync(address: pointer, length: csize_t, flags: cint): cint {.
    importc: "msync", header: "<sys/mman.h>".}

  const
    clockMonotonic = 1.cint
    openFlags = (2 or 64 or 512).cint # O_RDWR | O_CREAT | O_TRUNC
    mapProtection = (1 or 2).cint # PROT_READ | PROT_WRITE
    mapShared = 1.cint # MAP_SHARED
    mapFailed = cast[pointer](-1)
    remapMayMove = 1.cint # MREMAP_MAYMOVE
    syncAsync = 1.cint # MS_ASYNC

  when defined(amd64):
    const getTidSyscall = 186.clong
  elif defined(arm64):
    const getTidSyscall = 178.clong
  elif defined(i386) or defined(arm):
    const getTidSyscall = 224.clong
  else:
    const getTidSyscall = 186.clong

type
  SamplyProfilerMode* = enum ## Selects the marker file ownership model.
    PerThread
    PerProcess

  SamplyProfiler* = object ## Owns one Samply marker file and its memory mapping.
    ##
    ## A profiler is move-only. Call `close` when the profiling scope ends; the
    ## destructor also closes an unclosed profiler.
    enabled*: bool
    path*: string
    when defined(linux):
      fd: cint
      mapping: pointer
      capacity: int
      length: int
      hasFile: bool

## Closes the profiler and releases its marker file resources.
proc close*(p: var SamplyProfiler) {.raises: [].}

proc `=destroy`(p: var SamplyProfiler) =
  close(p)
  `=destroy`(p.path)

proc `=wasMoved`(p: var SamplyProfiler) =
  p.enabled = false
  p.path = ""
  when defined(linux):
    p.fd = -1
    p.mapping = nil
    p.capacity = 0
    p.length = 0
    p.hasFile = false

proc `=copy`(dest: var SamplyProfiler, source: SamplyProfiler) {.error.}
proc `=dup`(p: SamplyProfiler): SamplyProfiler {.error.}

when defined(linux):
  proc monotonicNs(): uint64 {.inline.} =
    var ts: CTimespec
    if cClockGettime(clockMonotonic, addr ts) != 0:
      return 0
    uint64(ts.tv_sec) * 1_000_000_000'u64 + uint64(ts.tv_nsec)

  proc processId*(): int =
    int(cGetPid())

  proc threadId*(): int =
    int(cSyscall(getTidSyscall))

  proc appendUint(buffer: ptr UncheckedArray[byte], position: var int,
                  value: uint64) {.inline.} =
    var digits: array[20, byte]
    var count = 0
    var current = value
    while current > 0:
      digits[count] = byte(current mod 10'u64)
      current = current div 10'u64
      inc count
    if count == 0:
      buffer[position] = byte(ord('0'))
      inc position
    else:
      while count > 0:
        dec count
        buffer[position] = byte(ord('0')) + digits[count]
        inc position

  proc uintLength(value: uint64): int {.inline.} =
    result = 1
    var current = value
    while current >= 10'u64:
      current = current div 10'u64
      inc result

  proc appendName(buffer: ptr UncheckedArray[byte], position: var int,
                  name: string) {.inline.} =
    for ch in name:
      # A newline would create a second marker record. Keep the line format
      # valid while preserving the useful text around the control character.
      if ch == '\n' or ch == '\r':
        buffer[position] = byte(ord(' '))
      else:
        buffer[position] = byte(ord(ch))
      inc position

  proc grow(p: var SamplyProfiler, required: int): bool =
    if required <= p.capacity - p.length:
      return true

    var newCapacity = p.capacity
    while newCapacity - p.length < required:
      if newCapacity > high(int) div 2:
        return false
      newCapacity *= 2

    if cFtruncate(p.fd, int64(newCapacity)) != 0:
      return false
    let newMapping = cMremap(
      p.mapping,
      csize_t(p.capacity),
      csize_t(newCapacity),
      remapMayMove,
    )
    if newMapping == mapFailed:
      return false
    p.mapping = newMapping
    p.capacity = newCapacity
    true

  proc markerFileName(mode: SamplyProfilerMode): string =
    result = "marker-" & $processId()
    if mode == PerThread:
      result.add('-' & $threadId())
    result.add(".txt")

  proc initFile(p: var SamplyProfiler, mode: SamplyProfilerMode,
                initialCapacity: int, dir: string): bool =
    ## Opens `dir / marker-<pid>[-<tid>].txt` and maps it writable and shared.
    ## On failure the descriptor is released; the partial file, if any, is
    ## removed by the caller via `discardFile`.
    p.path = dir / markerFileName(mode)
    p.fd = cOpen(p.path.cstring, openFlags, 0o644'u32)
    if p.fd < 0:
      return false
    p.hasFile = true
    if cFtruncate(p.fd, int64(initialCapacity)) != 0:
      return false
    p.mapping = cMmap(
      nil,
      csize_t(initialCapacity),
      mapProtection,
      mapShared,
      p.fd,
      0,
    )
    if p.mapping == mapFailed:
      p.mapping = nil
      return false
    p.capacity = initialCapacity
    p.length = 0
    true

  proc discardFile(p: var SamplyProfiler) =
    ## Releases the descriptor and removes the partial marker file.
    p.mapping = nil
    if p.hasFile:
      discard cClose(p.fd)
      p.fd = -1
      p.hasFile = false
    if p.path.len > 0:
      removeFile(p.path)
      p.path = ""

proc initSamplyProfiler*(mode = PerThread,
                        initialCapacity = 64 * 1024): SamplyProfiler =
  ## Creates a Samply marker writer.
  ##
  ## The profiler is enabled only when compiled with `-d:samply` on Linux.
  ## The marker file is created in the working directory. If that directory
  ## cannot support a writable shared mapping - for example a Windows drive
  ## accessed from WSL - the system temp directory is used instead. File and
  ## mapping failures disable profiling without interrupting the workload
  ## being profiled. `initialCapacity` grows automatically as needed.
  result.enabled = false
  when defined(linux):
    result.fd = -1
    when defined(samply):
      if initialCapacity <= 0:
        return
      if initFile(result, mode, initialCapacity, getCurrentDir()):
        result.enabled = true
      else:
        discardFile(result)
        if initFile(result, mode, initialCapacity, getTempDir()):
          result.enabled = true
        else:
          discardFile(result)

proc close*(p: var SamplyProfiler) {.raises: [].} =
  ## Flushes and closes the marker file. Safe to call more than once.
  when defined(linux):
    if p.mapping != nil and p.mapping != mapFailed:
      if p.length > 0:
        discard cMsync(p.mapping, csize_t(p.length), syncAsync)
      discard cMunmap(p.mapping, csize_t(p.capacity))
      p.mapping = nil
    elif p.mapping == mapFailed:
      p.mapping = nil
    if p.hasFile:
      discard cFtruncate(p.fd, int64(p.length))
      discard cClose(p.fd)
      p.fd = -1
      p.hasFile = false
    p.capacity = 0
    p.length = 0
  p.enabled = false

proc flush*(p: var SamplyProfiler) {.raises: [].} =
  ## Requests that completed marker bytes become visible to readers.
  ## Samply normally reads the file after process exit, so this is optional.
  when defined(linux):
    if p.enabled and p.mapping != nil and p.length > 0:
      discard cMsync(p.mapping, csize_t(p.length), syncAsync)

proc begin*(p: SamplyProfiler, name: string): uint64 {.inline.} =
  ## Starts an interval. `name` is accepted for symmetry with `finish`.
  when defined(linux):
    if p.enabled and name.len > 0:
      return monotonicNs()
  0

proc finish*(p: var SamplyProfiler, start: uint64, name: string) {.inline.} =
  ## Completes an interval and appends one Samply marker line.
  when defined(linux):
    if not p.enabled or p.mapping == nil or start == 0 or name.len == 0:
      return
    let stop = monotonicNs()
    let required = uintLength(start) + 1 + uintLength(stop) +
                   1 + name.len + 1
    if not grow(p, required):
      p.enabled = false
      return
    let buffer = cast[ptr UncheckedArray[byte]](p.mapping)
    var position = p.length
    appendUint(buffer, position, start)
    buffer[position] = byte(ord(' '))
    inc position
    appendUint(buffer, position, stop)
    buffer[position] = byte(ord(' '))
    inc position
    appendName(buffer, position, name)
    buffer[position] = byte(ord('\n'))
    inc position
    p.length = position

template marker*(p: var SamplyProfiler, name: string, body: untyped) =
  ## Marks a lexical scope. Nested scopes and exceptions are supported.
  when defined(samply):
    if p.enabled:
      let markerStart = p.begin(name)
      try:
        body
      finally:
        p.finish(markerStart, name)
    else:
      body
  else:
    body

var threadProfiler {.threadvar.}: SamplyProfiler
var threadProfilerInit {.threadvar.}: bool

proc initThreadProfiler*(mode = PerThread,
                         initialCapacity = 64 * 1024) =
  ## Initializes the profiler used by `marker "name": ...` in this thread.
  ## Called automatically on first use of the `marker "name"` template, so
  ## markers attach to whichever thread actually runs the marked scope.
  close(threadProfiler)
  threadProfiler = initSamplyProfiler(mode, initialCapacity)
  threadProfilerInit = true

proc closeThreadProfiler*() =
  ## Closes the current thread's profiler.
  close(threadProfiler)
  threadProfilerInit = false

proc flushThreadProfiler*() =
  ## Flushes the current thread's marker mapping.
  flush(threadProfiler)

template marker*(name: string, body: untyped) =
  ## Marks a scope with the current thread's profiler. The profiler is
  ## initialized on first use in each thread, so the marker file attaches to
  ## the thread that runs this scope.
  when defined(samply):
    if not threadProfilerInit:
      initThreadProfiler()
    marker(threadProfiler, name):
      body
  else:
    body
