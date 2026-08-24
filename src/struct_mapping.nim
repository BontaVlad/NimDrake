## Mapping between Nim objects and DuckDB rows and STRUCT values.
##
## Column names are matched case-insensitively. Extra columns are ignored,
## missing optional fields become `none`, and missing required fields raise
## `ValueError`. When *no* field name matches any column and the result has
## exactly one STRUCT column, that column is decoded as the object itself
## (e.g. `SELECT data FROM t` into the struct's own type). Decoded values
## own their storage.
##
## Decoding is planned once per chunk: `rowPlan` resolves every field of the
## target object against the chunk schema, binds all column and STRUCT-child
## views up front, translates ENUM dictionaries into Nim ordinals, and binds
## LIST views. The per-row pass then performs no FFI calls. Materialize with
## `toSeq` / `toSeqInto`, or iterate lazily with `rows`. DDL generation and
## named-type creation live in the `ddl` module.

import std/[options, strutils, times]

import ./qresult
import ./types

template unwrapped[T](_: typedesc[Option[T]]): typedesc[T] = T
  ## The value type inside an `Option[T]`.

proc findField(names: openArray[string], wanted, context: string): int =
  ## Exact-match lookup with a case-insensitive fallback; raises `ValueError`
  ## when several columns match equally well.
  result = -1
  for index, name in names:
    if name == wanted:
      if result >= 0:
        raise newException(ValueError,
          "ambiguous field '" & wanted & "' in " & context)
      result = index
  if result >= 0:
    return

  for index, name in names:
    if cmpIgnoreCase(name, wanted) == 0:
      if result >= 0:
        raise newException(ValueError,
          "ambiguous case-insensitive field '" & wanted & "' in " &
          context)
      result = index

proc requireKind(view: ColumnView, expected: DuckType, valueType: string) =
  if view.kind != expected:
    raise newException(ValueError,
      "cannot decode " & $view.kind & " as " & valueType)

# ---------------------------------------------------------------------------
# Chunk decode plan
#
# A `DecodePlan` lays out one plan node per decodable field node of the
# target type, depth-first in field order. `slotsFor`, `collect`, and
# `decodeAt` walk the identical structure, so slot numbers computed during
# planning line up with the ones consumed while decoding a row.
# ---------------------------------------------------------------------------

func slotsFor[T](_: typedesc[T]): int =
  ## Number of plan nodes (bound views) that decoding a value of type `T`
  ## occupies: one per scalar/list/struct node, plus the nodes of every
  ## contained field.
  when T is Option:
    1 + slotsFor(unwrapped(T))
  elif T is seq:
    1
  elif T is tuple:
    var value: T
    result = 1
    for _, field in fieldPairs(value):
      result += slotsFor(typeof(field))
  elif T is object:
    const kind = toDuckType(T)
    when kind == DuckType.Invalid:
      var value: T
      result = 1
      for _, field in fieldPairs(value):
        result += slotsFor(typeof(field))
    else:
      1
  else:
    1

type
  ListViewBox[kt: static DuckType] = ref object of RootObj
    ## Type-erased holder for a chunk-bound `ListView`, stored in
    ## `DecodePlan.lists` and cast back by `decodeAt` for `seq` fields.
    view: ListView[kt]

  DecodePlan = object
    ## All per-chunk state needed to decode rows without further FFI calls.
    ##
    ## `slots` holds one bound `ColumnView` per node. `enumBySlot` maps an
    ## ENUM node's slot to a dictionary-index -> Nim-ordinal table. `lists`
    ## holds chunk-bound `ListView`s for `seq` nodes. `missing` records the
    ## slots of optional nodes whose source column/field is absent.
    slots: seq[ColumnView]
    enumBySlot: seq[seq[int32]]
    lists: seq[RootRef]
    missing: seq[int]
    hasMissing: bool
    rootStruct: bool ## True when the whole object is decoded from a single
                     ## STRUCT column (slot 0 is the root node).

proc storeValidated[T](view: ColumnView, plan: var DecodePlan,
                       slot: int): int =
  ## Validates `view` against the canonical DuckDB kind of `T`, stores it,
  ## and returns the next slot. Compile-time error for unmapped types.
  const kind = toDuckType(T)
  when kind == DuckType.Invalid:
    {.error: "unsupported struct mapping field type " & $T.}
  view.requireKind(kind, $T)
  plan.slots[slot] = view
  slot + 1

proc collect[T](view: ColumnView, plan: var DecodePlan, slot: int,
                context: string): int
  ## Resolves node `slot` (and recursively its children) for target type `T`
  ## against `view`, storing bound views and enum tables into `plan`.
  ## Returns the next unconsumed slot. Raises `ValueError` for kind
  ## mismatches and missing non-optional fields.

proc collectTupleChildren[T: tuple](structView: ColumnView,
                                    plan: var DecodePlan, slot: int): int =
  ## Plans the positional children of a STRUCT node decoded into tuple `T`.
  let bound = structView.bindAs(DuckType.Struct)
  var expected = 0
  var probe: T
  for _, _ in fieldPairs(probe):
    inc expected
  if bound.structChildCount != expected:
    raise newException(ValueError,
      "tuple arity mismatch: expected " & $expected & ", got " &
      $bound.structChildCount)
  result = slot + 1
  var index = 0
  for _, field in fieldPairs(probe):
    result = collect[typeof(field)](
      bound.structChild(index), plan, result, "tuple " & $T)
    inc index

proc collectObjectChildren[T: object](structView: ColumnView,
                                      plan: var DecodePlan, slot: int,
                                      context: string): int =
  ## Plans the children of a STRUCT node decoded into object `T`; children
  ## are matched to STRUCT members by (case-insensitive) field name.
  if structView.ltype.childNames == nil:
    raise newException(ValueError, "STRUCT field names are unavailable")
  let names = structView.ltype.childNames[]
  result = slot + 1
  let bound = structView.bindAs(DuckType.Struct)
  var probe: T
  for name, field in fieldPairs(probe):
    let index = findField(names, name, context)
    if index >= 0:
      result = collect[typeof(field)](
        bound.structChild(index), plan, result, context)
    elif field is Option:
      plan.hasMissing = true
      plan.missing.add(result)
      inc result, slotsFor(typeof(field))
    else:
      raise newException(ValueError,
        "missing non-optional STRUCT field '" & name & "'")

proc collect[T](view: ColumnView, plan: var DecodePlan, slot: int,
                context: string): int =
  when T is Option:
    plan.slots[slot] = view
    collect[unwrapped(T)](view, plan, slot + 1, context)
  elif T is seq[byte]:
    storeValidated[T](view, plan, slot)
  elif T is seq:
    view.requireKind(DuckType.List, $T)
    plan.slots[slot] = view
    type Element = typeof(default(T)[0])
    plan.lists[slot] = ListViewBox[colDuckTypeOf(Element)](
      view: view.bindAs(seq[Element]))
    slot + 1
  elif T is enum:
    view.requireKind(DuckType.Enum, $T)
    if view.ltype.enumLabels == nil:
      raise newException(ValueError, "ENUM labels are unavailable for " & $T)
    let labels = view.ltype.enumLabels[]
    var table = newSeq[int32](labels.len)
    for index, label in labels:
      block found:
        for value in low(T)..high(T):
          if $value == label:
            table[index] = ord(value).int32
            break found
        raise newException(ValueError,
          "DuckDB ENUM label '" & label & "' is not present in " & $T)
    plan.slots[slot] = view
    plan.enumBySlot[slot] = table
    slot + 1
  elif T is DateTime:
    case view.kind
    of DuckType.Timestamp, DuckType.Date, DuckType.TimestampS,
        DuckType.TimestampMs, DuckType.TimestampNs:
      plan.slots[slot] = view
      slot + 1
    else:
      raise newException(ValueError,
        "cannot decode " & $view.kind & " as DateTime")
  elif T is tuple:
    view.requireKind(DuckType.Struct, $T)
    plan.slots[slot] = view
    collectTupleChildren[T](view, plan, slot)
  elif T is object:
    const kind = toDuckType(T)
    when kind == DuckType.Invalid:
      view.requireKind(DuckType.Struct, $T)
      plan.slots[slot] = view
      collectObjectChildren[T](view, plan, slot, "STRUCT " & $T)
    else:
      storeValidated[T](view, plan, slot)
  else:
    storeValidated[T](view, plan, slot)

proc newPlan(total: int): DecodePlan =
  result.slots = newSeq[ColumnView](total)
  result.enumBySlot = newSeq[seq[int32]](total)
  result.lists = newSeq[RootRef](total)

proc rowPlan*[T: object](chunk: DataChunk): DecodePlan =
  ## Resolves every field of object `T` against `chunk.meta` and binds all
  ## needed views once for the whole chunk. Raises `ValueError` if a
  ## non-optional field has no matching column.
  ##
  ## If no field name matches any column and the chunk has exactly one
  ## STRUCT column, the whole object is decoded from that column instead.
  var names = newSeq[string](chunk.meta.columns.len)
  for index, column in chunk.meta.columns:
    names[index] = column.name

  block chooseStrategy:
    var probe: T
    for name, _ in fieldPairs(probe):
      if findField(names, name, "query result") >= 0:
        break chooseStrategy
    if chunk.meta.columns.len == 1 and
        chunk.meta.columns[0].kind == DuckType.Struct:
      result = newPlan(slotsFor(T))
      result.rootStruct = true
      discard collect[T](chunk.vector(0), result, 0, "query result")
      return

  var probe: T
  var total = 0
  for _, field in fieldPairs(probe):
    inc total, slotsFor(typeof(field))
  result = newPlan(total)

  var slot = 0
  for name, field in fieldPairs(probe):
    let index = findField(names, name, "query result")
    if index >= 0:
      slot = collect[typeof(field)](
        chunk.vector(index), result, slot, "query result")
    elif field is Option:
      result.hasMissing = true
      result.missing.add(slot)
      inc slot, slotsFor(typeof(field))
    else:
      raise newException(ValueError,
        "missing non-optional column '" & name & "' for " & $T)
  doAssert slot == total

# ---------------------------------------------------------------------------
# Row decoding
# ---------------------------------------------------------------------------

proc decodeScalar[T](destination: var T, view: ColumnView, row: int) =
  const kind = toDuckType(T)
  when kind == DuckType.Invalid:
    {.error: "unsupported struct mapping field type " & $T.}
  else:
    let values = view.bindAs(kind)
    when T is int:
      destination = int(values[row])
    elif T is uint:
      destination = uint(values[row])
    else:
      destination = values[row]

proc requireCell[T](plan: DecodePlan, slot, row: int): ColumnView =
  ## The bound view for node `slot`; raises `ValueError` when the cell is
  ## NULL (never called for `Option` nodes, which accept NULL).
  result = plan.slots[slot]
  if not result.valid(row):
    raise newException(ValueError,
      "NULL in non-optional field of type " & $T)

proc decodeAt[T](destination: var T, plan: DecodePlan, slot: int,
                 row: int): int
  ## Decodes the node at `slot` for `row` into `destination` and returns the
  ## next slot. Mirrors `collect` exactly.

proc decodeAt[T](destination: var T, plan: DecodePlan, slot: int,
                 row: int): int =
  when T is Option:
    type Value = unwrapped(T)
    let absent = plan.hasMissing and slot in plan.missing
    if absent or not plan.slots[slot].valid(row):
      destination = none(Value)
      result = slot + 1 + slotsFor(Value)
    else:
      var value: Value
      result = decodeAt[Value](value, plan, slot + 1, row)
      destination = some(value)
  elif T is seq[byte]:
    decodeScalar(destination, requireCell[T](plan, slot, row), row)
    result = slot + 1
  elif T is seq:
    type Element = typeof(default(T)[0])
    discard requireCell[T](plan, slot, row)
    destination = cast[ListViewBox[colDuckTypeOf(Element)]](
      plan.lists[slot]).view[row]
    result = slot + 1
  elif T is enum:
    let view = requireCell[T](plan, slot, row)
    let raw = view.bindAs(DuckType.Enum)[row].int
    let table = plan.enumBySlot[slot]
    if raw < 0 or raw >= table.len:
      raise newException(ValueError, "ENUM index is outside its schema")
    destination = T(table[raw])
    result = slot + 1
  elif T is DateTime:
    let view = requireCell[T](plan, slot, row)
    case view.kind
    of DuckType.Timestamp:
      destination = DateTime(view.bindAs(DuckType.Timestamp)[row])
    of DuckType.Date:
      destination = view.bindAs(DuckType.Date)[row]
    of DuckType.TimestampS:
      destination = view.bindAs(DuckType.TimestampS)[row]
    of DuckType.TimestampMs:
      destination = view.bindAs(DuckType.TimestampMs)[row]
    of DuckType.TimestampNs:
      destination = view.bindAs(DuckType.TimestampNs)[row]
    else:
      raise newException(ValueError,
        "cannot decode " & $view.kind & " as DateTime")
    result = slot + 1
  elif T is tuple:
    discard requireCell[T](plan, slot, row).bindAs(DuckType.Struct)
    result = slot + 1
    for _, field in fieldPairs(destination):
      result = decodeAt[typeof(field)](field, plan, result, row)
  elif T is object:
    const kind = toDuckType(T)
    when kind == DuckType.Invalid:
      discard requireCell[T](plan, slot, row).bindAs(DuckType.Struct)
      result = slot + 1
      for _, field in fieldPairs(destination):
        result = decodeAt[typeof(field)](field, plan, result, row)
    else:
      decodeScalar(destination, requireCell[T](plan, slot, row), row)
      result = slot + 1
  else:
    decodeScalar(destination, requireCell[T](plan, slot, row), row)
    result = slot + 1

proc decodeRow[T: object](plan: DecodePlan, row: int): T =
  if plan.rootStruct:
    discard decodeAt(result, plan, 0, row)
    return
  var slot = 0
  for _, field in fieldPairs(result):
    slot = decodeAt[typeof(field)](field, plan, slot, row)

# ---------------------------------------------------------------------------
# Public surface: toSeq / toSeqInto / rows
# ---------------------------------------------------------------------------

proc toSeqInto*[T: object](chunk: DataChunk, destination: var seq[T]) =
  ## Decodes every row of `chunk` into `destination`, replacing its contents.
  let plan = rowPlan[T](chunk)
  destination.setLen(chunk.len)
  for row in 0..<chunk.len:
    destination[row] = decodeRow[T](plan, row)

proc toSeqInto*[T: object](resultSet: QResult[Materialized],
                           destination: var seq[T]) =
  ## Decodes every row of a materialized result into `destination`,
  ## replacing its contents. The destination is sized once from the known
  ## row count.
  destination.setLen(resultSet.rlen)
  var next = 0
  for chunk in resultSet.chunks:
    let plan = rowPlan[T](chunk)
    for row in 0..<chunk.len:
      destination[next] = decodeRow[T](plan, row)
      inc next

proc toSeqInto*[T: object](resultSet: sink QResult[Streaming],
                           destination: var seq[T]) =
  ## Drains a streaming result into `destination`, replacing its contents;
  ## each chunk is planned and decoded as it arrives.
  for chunk in items(resultSet):
    let base = destination.len
    let plan = rowPlan[T](chunk)
    destination.setLen(base + chunk.len)
    for row in 0..<chunk.len:
      destination[base + row] = decodeRow[T](plan, row)

proc toSeq*[T: object](chunk: DataChunk, _: typedesc[T]): seq[T] =
  ## Decodes every row of `chunk` into a fresh `seq[T]`.
  chunk.toSeqInto(result)

proc toSeq*[T: object](resultSet: QResult[Materialized],
                       _: typedesc[T]): seq[T] =
  ## Decodes every row of a materialized result into a fresh `seq[T]`.
  resultSet.toSeqInto(result)

proc toSeq*[T: object](resultSet: sink QResult[Streaming],
                       _: typedesc[T]): seq[T] =
  ## Drains a streaming result into a fresh `seq[T]`.
  resultSet.toSeqInto(result)

iterator rows*[T: object](chunk: DataChunk, _: typedesc[T]): T =
  ## Yields each row of `chunk` decoded into `T` without building a sequence.
  let plan = rowPlan[T](chunk)
  for row in 0..<chunk.len:
    yield decodeRow[T](plan, row)

iterator rows*[T: object](resultSet: QResult[Materialized],
                          _: typedesc[T]): T =
  ## Yields each row of a materialized result decoded into `T`.
  for chunk in resultSet.chunks:
    let plan = rowPlan[T](chunk)
    for row in 0..<chunk.len:
      yield decodeRow[T](plan, row)

iterator rows*[T: object](resultSet: QResult[Streaming],
                          _: typedesc[T]): T =
  ## Yields each row of a streaming result decoded into `T`, planning one
  ## chunk at a time.
  for chunk in items(resultSet):
    let plan = rowPlan[T](chunk)
    for row in 0..<chunk.len:
      yield decodeRow[T](plan, row)
