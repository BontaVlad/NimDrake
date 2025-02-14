# stolen from here: https://github.com/zevv/actors/blob/94e98311506cd5ae6c714d0b33725e2b0aa11750/actors/valgrind.nim#L3

const usesValgrind {.booldefine.} = false

when usesValgrind:
  const
    helgrind = "<valgrind/helgrind.h>"
    callgrind = "<valgrind/callgrind.h>"

  proc valgrind_annotate_happens_before*(
    x: pointer
  ) {.header: helgrind, importc: "ANNOTATE_HAPPENS_BEFORE".}

  proc valgrind_annotate_happens_after*(
    x: pointer
  ) {.header: helgrind, importc: "ANNOTATE_HAPPENS_AFTER".}

  proc valgrind_annotate_happens_before_forget_all*(
    x: pointer
  ) {.header: helgrind, importc: "ANNOTATE_HAPPENS_BEFORE_FORGET_ALL".}

  proc callgrind_toggle_collect*(
    x: pointer
  ) {.header: callgrind, importc: "CALLGRIND_TOGGLE_COLLECT".}

  let enabled {.header: helgrind, importc: "RUNNING_ON_VALGRIND".}: bool

  proc running_on_valgrind*(): bool =
    {.cast(noSideEffect), cast(gcSafe).}:
      result = enabled

else:
  proc valgrind_annotate_happens_before*(x: pointer) =
    discard

  proc valgrind_annotate_happens_after*(x: pointer) =
    discard

  proc valgrind_annotate_happens_before_forget_all*(x: pointer) =
    discard

  proc callgrind_toggle_collect*(x: pointer) =
    discard

  template running_on_valgrind*(): bool =
    false
