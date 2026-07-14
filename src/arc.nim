import std/macros

func findHandleType(recList: NimNode): NimNode =
  if recList.kind != nnkRecList:
    return nil
  for field in recList:
    if field.kind == nnkIdentDefs:
      let name =
        if field[0].kind == nnkPostfix:
          field[0][1]
        else:
          field[0]
      if name.strVal == "handle":
        return field[^2]

macro arcResource*(destroyProc: untyped, body: untyped): untyped =
  ## Statement macro: for each object type in `body`'s type section that
  ## declares a `handle` field, generate a move-only `=destroy` (calling
  ## `destroyProc` on the handle) and a `rawHandle*` accessor.
  ##
  ## No `=copy` or `=dup` are emitted, so Nim 2 treats each type as move-only.
  ## Use this for move-only wrapper types that own a single C handle.
  ##
  ## ``Database`` and ``Connection`` use `threading/smartptrs <https://github.com/nim-lang/threading>`_
  ## instead (thread-safe shared ownership via ``SharedPtr``).
  ##
  ## ### Example
  ## arcResource(duckdbDestroyConfig):
  ##   type
  ##     Config* = object
  ##       handle: duckdbConfig

  result = body

  for node in body:
    if node.kind == nnkTypeSection:
      for typeDef in node:
        if typeDef.kind != nnkTypeDef:
          continue
        let impl = typeDef[2]
        if impl.kind != nnkObjectTy or impl[1].kind != nnkEmpty:
          continue
        let nameNode = typeDef[0]
        let typeName =
          if nameNode.kind == nnkPostfix:
            nameNode[1]
          else:
            nameNode
        let handleType = findHandleType(impl[2])
        if handleType.isNil:
          continue

        let self = ident("self")
        let handleField = ident("handle")
        let addrOp = ident("addr")

        result.add quote do:
          proc `=destroy`*(`self`: `typeName`) =
            if `self`.`handleField` != nil:
              `destroyProc`(`self`.`handleField`.`addrOp`)

          proc rawHandle*(`self`: `typeName`): `handleType` {.inline.} =
            `self`.`handleField`
