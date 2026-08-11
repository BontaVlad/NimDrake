import std/[os, osproc, strutils, strformat]

const CookbookDir = "docs/cookbook"

proc getProjectFlags(): string =
  let srcPath = getCurrentDir() / "src"
  let includePath = getCurrentDir() / "src" / "include"
  result = fmt"--path:{srcPath.quoteShell} --passL:-L{includePath.quoteShell} --passL:-lduckdb --passL:-Wl,-rpath,{includePath.quoteShell}"

proc runSnippet(code: string, flags: string): string =
  let tmpFile = getTempDir() / "cookbook_verify.nim"
  writeFile(tmpFile, code)
  let cmd = fmt"nim r --hints:off --warnings:off {flags} {tmpFile.quoteShell}"
  let (output, exitCode) = execCmdEx(cmd)
  result = if exitCode == 0: output.strip()
           else: "ERROR: " & output.strip()

proc findNimTestBlocks(content: string): seq[(int, int, string, string)] =
  ## Find all ```nim test blocks and their corresponding output blocks.
  result = @[]
  var pos = 0
  let marker = "```nim test\n"

  while true:
    let codeStart = content.find(marker, pos)
    if codeStart < 0: break

    let codeEnd = content.find("\n```", codeStart + marker.len)
    if codeEnd < 0: break

    let codeBlock = content[codeStart .. codeEnd + 3]

    let outputStart = content.find("\n\n```\n", codeEnd)
    if outputStart < 0: break

    let outputEnd = content.find("```", outputStart + 6)
    if outputEnd < 0: break

    let oldOutput = content[outputStart + 6 ..< outputEnd]

    result.add((codeStart, outputEnd + 3, codeBlock, oldOutput))
    pos = outputEnd + 3

proc processFile(path: string, flags: string): bool =
  echo "Verifying: ", path
  let content = readFile(path)

  let blocks = findNimTestBlocks(content)
  if blocks.len == 0:
    echo "  (no runnable snippets)"
    return true

  var allPassed = true
  for idx, (_, _, codeBlock, expectedOutput) in blocks:
    let code = codeBlock.replace("```nim test\n", "").replace("\n```", "")
    let actualOutput = runSnippet(code, flags)

    if actualOutput.startsWith("ERROR:"):
      echo fmt"  [{idx + 1}/{blocks.len}] FAIL - {actualOutput}"
      allPassed = false
    elif actualOutput != expectedOutput.strip():
      echo fmt"  [{idx + 1}/{blocks.len}] MISMATCH"
      echo fmt"    Expected: {expectedOutput.strip()}"
      echo fmt"    Actual:   {actualOutput}"
      allPassed = false
    else:
      echo fmt"  [{idx + 1}/{blocks.len}] OK"

  result = allPassed

proc processDir(dir: string, flags: string): bool =
  var allPassed = true
  for path in walkDirRec(dir):
    if path.endsWith(".md"):
      if not processFile(path, flags):
        allPassed = false
  result = allPassed

if isMainModule:
  let args      = commandLineParams()
  let targetDir = if args.len >= 1: args[0] else: CookbookDir

  if not dirExists(targetDir):
    quit("Directory not found: " & targetDir, 1)

  echo "NimDrake cookbook verifier"
  echo "========================"
  let flags = getProjectFlags()
  let passed = processDir(targetDir, flags)
  echo ""
  if passed:
    echo "All snippets verified!"
  else:
    echo "Some snippets failed!"
    quit(1)
