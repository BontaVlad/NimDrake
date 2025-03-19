template ignoreLeak*(body: untyped) =
  proc runWhileIgnoringLeaks() {.codegenDecl: "__attribute__((leak_sanitizer(ignore))) $# $#$#".} =
    body
