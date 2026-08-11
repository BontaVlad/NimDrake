import std/[os, osproc, strutils, strformat]

const DefaultCookbookDir = "docs/cookbook"

proc getProjectFlags(): string =
  let srcPath = getCurrentDir() / "src"
  let includePath = getCurrentDir() / "src" / "include"
  result = fmt"--path:{srcPath.quoteShell} --passL:-L{includePath.quoteShell} --passL:-lduckdb --passL:-Wl,-rpath,{includePath.quoteShell}"

proc runSnippet(code: string, flags: string): tuple[ok: bool, output: string] =
  let tmpFile = getTempDir() / "cookbook_snippet.nim"
  writeFile(tmpFile, code)
  let cmd = fmt"nim r --hints:off --warnings:off {flags} {tmpFile.quoteShell}"
  let (output, exitCode) = execCmdEx(cmd)
  result = (exitCode == 0, output.strip())

proc findNimTestBlocks(content: string): seq[(int, int, string)] =
  ## Find all ```nim test blocks and their corresponding output blocks.
  ## Returns (start, end, codeBlock) tuples for each block.
  result = @[]
  var pos = 0
  let marker = "```nim test\n"

  while true:
    let codeStart = content.find(marker, pos)
    if codeStart < 0: break

    let codeEnd = content.find("\n```", codeStart + marker.len)
    if codeEnd < 0: break

    let codeBlock = content[codeStart .. codeEnd + 3]  # include ```

    # Find the output block after the code block
    let outputStart = content.find("\n\n```\n", codeEnd)
    if outputStart < 0: break

    let outputEnd = content.find("```", outputStart + 6)
    if outputEnd < 0: break

    result.add((codeStart, outputEnd + 3, codeBlock))
    pos = outputEnd + 3

proc processFile(path: string, flags: string) =
  echo "Processing: ", path
  let content = readFile(path)

  let blocks = findNimTestBlocks(content)
  if blocks.len == 0:
    echo "  (no runnable snippets, skipping)"
    return

  var output = content
  var offset = 0

  for idx, (start, endPos, codeBlock) in blocks:
    echo fmt"  [{idx + 1}/{blocks.len}] running snippet..."
    let code = codeBlock.replace("```nim test\n", "").replace("\n```", "")
    let (ok, snippetOutput) = runSnippet(code, flags)

    if not ok:
      echo fmt"  [{idx + 1}/{blocks.len}] FAILED to compile/run:"
      echo snippetOutput
      quit(1)

    # Trailing newline after the closing ``` keeps a blank line before the
    # next markdown heading so nim md2html renders the section structure.
    let replacement = codeBlock & "\n\n```\n" & snippetOutput & "\n```\n"

    let adjustedStart = start + offset
    let adjustedEnd = endPos + offset

    output = output[0 ..< adjustedStart] & replacement & output[adjustedEnd .. ^1]
    offset += replacement.len - (endPos - start)

  writeFile(path, output)
  echo "  done"

proc processDir(dir: string, flags: string) =
  for path in walkDirRec(dir):
    if path.endsWith(".md"):
      processFile(path, flags)

if isMainModule:
  let args      = commandLineParams()
  let targetDir = if args.len >= 1: args[0] else: DefaultCookbookDir

  if not dirExists(targetDir) and not fileExists(targetDir):
    quit("Path not found: " & targetDir, 1)

  echo "NimDrake cookbook runner -- ", targetDir
  let flags = getProjectFlags()
  if fileExists(targetDir):
    processFile(targetDir, flags)
  else:
    processDir(targetDir, flags)
  echo "Done."