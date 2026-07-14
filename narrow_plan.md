# Narrow Implementation Plan

To be implemented in `/mnt/c/Users/Vlad/Sandbox/narrow/src/narrow/` by another agent.

All raw FFI procs referenced below are defined in `core/generated.nim` inside the narrow repo.

---

## 1. `IpcStreamWriter.writeRecordBatch` — add single-batch write

**Why**: `IpcStreamWriter` currently only has `writeTable` (batch-eager). `IpcFileWriter` has
`writeRecordBatch` (`io/ipc.nim:274`) but `IpcStreamWriter` does not. For streaming
DuckDB→Arrow IPC output, you need to push one `RecordBatch` at a time to a stream writer.

**Where**: `/mnt/c/Users/Vlad/Sandbox/narrow/src/narrow/io/ipc.nim`

**What to add** (after the existing `writeTable` proc, ~line 268):

```nim
proc writeRecordBatch*(writer: IpcStreamWriter, batch: RecordBatch) =
  let err: ptr GError = nil
  if garrow_record_batch_writer_write_record_batch(
       cast[ptr GArrowRecordBatchWriter](writer.handle),
       batch.handle, addr err) == 0:
    if err != nil:
      let msg = $err[].message
      g_error_free(err)
      raise newException(IOError, msg)
    raise newException(IOError, "failed to write record batch to stream writer")
```

**Raw FFI used**: `garrow_record_batch_writer_write_record_batch` (`core/generated.nim:29746`)  
Signature: `proc garrow_record_batch_writer_write_record_batch*(writer: ptr GArrowRecordBatchWriter; record_batch: ptr GArrowRecordBatch; error: ptr ptr GError): gboolean {.cdecl, importc: "garrow_record_batch_writer_write_record_batch".}`

**Priority**: High — required for streaming Arrow IPC output.

---

## 2. In-memory `BufferOutputStream` — add type + constructor

**Why**: narrow has NO in-memory output stream. `OutputStream` is file-backed only
(via `FileSystem.openOutputStream`, `filesystem.nim:822`). To build an `IpcStreamWriter`
that writes Arrow IPC bytes to a memory buffer (for socket transfer, DuckDB buffer feed,
or in-process handoff), you need a `BufferOutputStream`.

**Where**: Create a new file: `/mnt/c/Users/Vlad/Sandbox/narrow/src/narrow/io/buffer.nim`

**What to add**:

```nim
import pkg/gintro/[glib, gobject, gio]
import ../core/ffi

type
  BufferOutputStream* = object
    handle*: ptr GArrowBufferOutputStream

proc newBufferOutputStream*(): BufferOutputStream =
  result.handle = garrow_buffer_output_stream_new()

proc `=destroy`(s: BufferOutputStream) =
  if s.handle != nil:
    g_object_unref(cast[pointer](s.handle))

proc `=wasMoved`(s: var BufferOutputStream) =
  s.handle = nil

proc toOutputStream*(s: BufferOutputStream): ptr GArrowOutputStream =
  ## Cast to base `OutputStream` for passing to writer constructors.
  cast[ptr GArrowOutputStream](s.handle)
```

Also add the corresponding `ResizableBuffer` if useful:

```nim
type
  ResizableBuffer* = object
    handle*: ptr GArrowResizableBuffer

proc newResizableBuffer*(initialSize: int64): ResizableBuffer =
  result.handle = garrow_resizable_buffer_new(initialSize, nil)

proc `=destroy`(b: ResizableBuffer) =
  if b.handle != nil:
    g_object_unref(cast[pointer](b.handle))
```

Then export `BufferOutputStream` and `ResizableBuffer` from the `narrow` module and/or `io` submodule.

**Raw FFI used**:
- `garrow_buffer_output_stream_new` (`core/generated.nim:27824`) — `proc garrow_buffer_output_stream_new*(): ptr GArrowBufferOutputStream {.cdecl, importc.}`
- `garrow_resizable_buffer_new` (`core/generated.nim:24255`) — `proc garrow_resizable_buffer_new*(initial_size: gint64; error: ptr ptr GError): ptr GArrowResizableBuffer {.cdecl, importc.}`

**Priority**: High — required for in-memory Arrow IPC serialization.

---

## 3. Missing C Data Interface exports in `interop/cdata.nim`

**Where**: `/mnt/c/Users/Vlad/Sandbox/narrow/src/narrow/interop/cdata.nim`

**What to add**: The module currently exports only `exportSchema`, `exportRecordBatch`,
`importRecordBatchReader`, `exportRecordBatchReader`. These symmetric procs are missing:

### 3a. `exportArray`

```nim
proc exportArray*(arr: Array): pointer =
  ## Returns a pointer to an `ArrowArray` C struct (owned by caller).
  ## The caller must call `.release` when done.
  let err: ptr GError = nil
  result = garrow_array_export(cast[ptr GArrowArray](arr.handle), nil)
```

**Raw FFI**: `garrow_array_export` (`core/generated.nim:24357`)

### 3b. `importDataType` / `exportDataType`

```nim
proc importDataType*(cAbiType: pointer): DataType =
  let err: ptr GError = nil
  result = DataType(handle: garrow_data_type_import(cAbiType, addr err))

proc exportDataType*(dtype: DataType): pointer =
  result = garrow_data_type_export(dtype.handle, nil)
```

**Raw FFI**:
- `garrow_data_type_import` (`core/generated.nim:23717`)
- `garrow_data_type_export` (`core/generated.nim:23721`)

### 3c. `importField` / `exportField`

```nim
proc importField*(cAbiField: pointer): Field =
  let err: ptr GError = nil
  result = Field(handle: garrow_field_import(cAbiField, addr err))

proc exportField*(field: Field): pointer =
  result = garrow_field_export(field.handle, nil)
```

**Raw FFI**:
- `garrow_field_import` (`core/generated.nim:25034`)
- `garrow_field_export` (`core/generated.nim:25046`)

**Priority**: Medium — nice for symmetric round-tripping but not needed for the DuckDB→Arrow streaming path.

---

## 4. Minor reader gaps (low priority)

These raw procs in `core/generated.nim` have no high-level wrapper:

| Raw proc | Generated line | What it does |
|----------|---------------|-------------|
| `garrow_table_batch_reader_set_max_chunk_size` | 28241 | Set max chunk size on a table→reader |
| `garrow_record_batch_reader_get_sources` | 28229 | Get input sources from reader |
| `garrow_record_batch_reader_new` | 28197 | Build reader from `GList` of batches |
| `garrow_record_batch_reader_get_next_record_batch` | 28209 | Deprecated alias of `read_next_record_batch` |

None of these are needed for the DuckDB streaming use case. Defer.

---

## Summary — implementation order for the other agent

1. Add `writeRecordBatch` overload for `IpcStreamWriter` in `io/ipc.nim` (5-minute fix, one proc).
2. Create `io/buffer.nim` with `BufferOutputStream` type + constructor (10-minute fix, new file).
3. Fill missing C Data Interface exports in `interop/cdata.nim` (15 minutes, 6 procs).
4. Skip the minor reader gaps until needed.
