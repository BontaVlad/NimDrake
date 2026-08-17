## CI gate: every exported symbol in the public modules must carry a `##` doc
## comment, and every module needs a module-level doc block before its
## imports.
##
## This is a pragmatic line-based scanner tuned to NimDrake's style, not a
## full Nim parser. It flags:
##
## - a missing module doc block (no `##`/`##[` comment before the first import),
## - exported top-level routines (`proc`, `func`, `iterator`, `template`,
##   `converter`, `macro`) with no doc comment,
## - exported top-level `type`/`const`/`var` entries with no doc comment.
##
## A routine is documented when the doc comment appears either immediately
## above the declaration at column 0, or as the first statement of its body
## (`proc foo(...) =\n  ## doc`), which is this project's convention.
## Trivial one-expression routines (`proc len = x.len`) are exempt: they are
## self-evident accessors. Object fields and enum values are exempt by design.
##
## Run: `nim r --hints:off tools/checkdocs.nim`

import std/[os, strutils, sequtils]

const
  ROUTINE_KW = ["proc", "func", "iterator", "template", "converter", "macro"]
  srcDir = "src"
  skipFiles = [
    "generated.nim",   # Futhark output
    "arc.nim",         # `arcResource` helper
    "valgrind.nim",    # dev-only tooling
  ]

type
  Problem = object
    file: string
    line: int
    symbol: string

var problems: seq[Problem]

proc sigEndOf(lines: seq[string], start: int): int =
  ## Index of the last line of a routine signature starting at `start`.
  ## A signature ends on the line that opens the body: `=` or a closing `}`
  ## (for `{.borrow.}` / `{.error.}` bodies).
  var i = start
  while i < lines.len:
    let s = lines[i].strip
    if s.endsWith("=") or s.endsWith("}"):
      return i
    inc i
  return start

proc trivialRoutine(lines: seq[string], start, sigEnd: int): bool =
  ## True for a single-line signature ending in `=` whose body is exactly one
  ## expression line (a trivial accessor).
  if sigEnd != start: return false
  let s = lines[start].strip
  if not s.endsWith("="): return false
  var i = start + 1
  var nonBlank = 0
  while i < lines.len:
    let t = lines[i].strip
    if t.len == 0:
      inc i
      continue
    let indent = lines[i].len - lines[i].strip(leading = true).len
    if indent == 0: break
    inc nonBlank
    if nonBlank > 1: return false
    inc i
  true

proc scanFile(path: string) =
  let lines = readFile(path).splitLines
  var
    inDocBlock = false        # inside ##[ ]##
    blockKind = ""            # "type"/"const"/"var"/"let" block being scanned
    blockIndent = -1
    lastDocLine = -1          # 1-based line of last col-0 `##` comment
    inExample = false
    exampleIndent = -1
    haveModuleDoc = false
    seenImport = false

  for lineNo0, raw in pairs(lines):
    let lineNo = lineNo0 + 1           # 1-based for reporting
    let st = raw.strip
    let indent = raw.len - raw.strip(leading = true).len

    if st.len == 0: continue

    # Skip directive bodies (`runnableExamples:`) — their code can look like
    # declarations but must not be gated.
    if st == "runnableExamples:" and indent == 0:
      inExample = true
      exampleIndent = indent
      continue
    if inExample:
      if indent <= exampleIndent and not st.startsWith("#"):
        inExample = false
      else:
        continue

    if st.startsWith("##[") and indent == 0:
      inDocBlock = true
      if not seenImport: haveModuleDoc = true
      continue
    if inDocBlock:
      if st.endsWith("]##") or st.startsWith("##]"):
        inDocBlock = false
      continue

    # A top-level doc comment (column 0) — module docs, or docs above a decl.
    if raw.startsWith("##") and indent == 0:
      if not seenImport: haveModuleDoc = true
      lastDocLine = lineNo
      continue

    # Regular comments (any indentation), pragmas, blank separators.
    if st.startsWith("#") or raw.startsWith("{"): continue

    if not seenImport and (st.startsWith("import") or
                           st.startsWith("include") or
                           st.startsWith("export")):
      seenImport = true
      continue

    if seenImport:
      # Exported top-level routine declaration.
      if indent == 0:
        var isRoutine = false
        for kw in ROUTINE_KW:
          if st.startsWith(kw) and st.len > kw.len and st[kw.len] in {' ', '\t'}:
            isRoutine = true
            break
        if isRoutine:
          blockKind = ""
          blockIndent = -1
          if '*' in st:
            let sigEnd = sigEndOf(lines, lineNo0)
            if not trivialRoutine(lines, lineNo0, sigEnd):
              let bodyIdx = sigEnd + 1
              let bodyLine = if bodyIdx < lines.len: lines[bodyIdx] else: ""
              let documented =
                (lineNo - lastDocLine == 1) or
                (lineNo - lastDocLine == 2 and
                 lines[lineNo - 2].startsWith("##")) or
                bodyLine.strip.startsWith("##")
              if not documented:
                problems.add(Problem(file: path, line: lineNo, symbol: st))
          continue

        # Type/const/var/let block header.
        if st == "type" or st == "const" or st == "var" or st == "let":
          blockKind = st
          blockIndent = -1
      elif blockKind.len > 0 and indent > 0:
        # Entry line of a type/const/var block: `Name* = ...` or `Name*: type`.
        if blockIndent == -1:
          blockIndent = indent
        if indent == blockIndent:
          let docPos = raw.find("##")
          let decl = if docPos >= 0: raw[0 ..< docPos].strip else: raw
          if '*' in decl:
            let documented =
              docPos >= 0 or
              (lineNo - lastDocLine == 1) or
              (lineNo - lastDocLine == 2 and
               lines[lineNo - 2].startsWith("##"))
            if not documented:
              problems.add(Problem(file: path, line: lineNo, symbol: st))

  if not haveModuleDoc and not skipFiles.anyIt(path.endsWith(it)):
    problems.add(Problem(file: path, line: 1,
      symbol: "missing module-level doc comment before imports"))

when isMainModule:
  for f in walkFiles(srcDir / "*.nim"):
    if skipFiles.anyIt(f.endsWith(it)): continue
    scanFile(f)
  for f in walkFiles(srcDir / "compatibility" / "*.nim"):
    scanFile(f)

  if problems.len == 0:
    echo "checkdocs: OK — all exported symbols documented"
    quit(0)
  echo "checkdocs: FAIL — documented-symbol gaps:"
  for p in problems:
    echo p.file & ":" & $p.line & ": " & p.symbol
  quit(1)