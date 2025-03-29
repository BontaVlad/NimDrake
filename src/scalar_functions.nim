import std/[macros, sequtils, tables, strformat, enumerate]
import fusion/[matching, astdsl]
import /[api, database, types, datachunk, exceptions]
import tools/wrench

type
  ScalarFunctionBase* = object of RootObj
    name*: string  # TODO: might not need name
    handle*: duckdbScalarFunction

  ScalarFunction* = ref object of ScalarFunctionBase
  ScalarValidityMask* = ref object of RootObj
    outputValid*: bool = false
    isValid*: Table[string, bool]

proc `=destroy`(s: ScalarFunctionBase) =
  if not isNil(s.addr) and not isNil(s.handle.addr):
    duckdb_destroy_scalar_function(s.handle.addr)

proc newScalarFunction*(name: string): ScalarFunction =
  result = ScalarFunction(name: name, handle: duckdb_create_scalar_function())

proc findScalarValidityMaskParam(formalParams: NimNode): int =
  ## Searches for a parameter of type ScalarValidityMask in the formal parameters
  ## extracted from a proc signature. Returns the index where it's found, or -1 if not found.

  for i in 0 ..< formalParams.len:
    let param = formalParams[i]

    # Handle different ways the parameter might appear
    if param.kind == nnkIdent:
      # Simple parameter without type annotation
      continue
    elif param.kind == nnkIdentDefs:
      # Parameter(s) with type annotation like "mask: ScalarValidityMask"
      if param[1].strVal == "ScalarValidityMask":
        return i
      # Handle potential nested type like "mask: seq[ScalarValidityMask]" if needed
    elif param.kind == nnkSym:
      # Symbol reference - might need to examine its type
      discard
    elif param.kind == nnkEmpty:
      # Empty parameter
      discard
    else:
      # Try to check more complex type expressions
      var typeNode = param

      # Walk the tree to find the type node if it's nested
      if param.len > 0 and param[param.len - 1].kind == nnkIdent:
        typeNode = param[param.len - 1]

      if typeNode.kind == nnkIdent and typeNode.strVal == "ScalarValidityMask":
        return i
  return -1


macro scalar*(body: typed): untyped =
  if body.kind != nnkTemplateDef:
    error("The {.scalar.} pragma can only be applied to template definitions.")

  generateTypeToField("typeToField", Vector)

  body.assertMatch:
    TemplateDef:
      Sym(strVal: @name) | Postfix[_, Sym(strVal: @name)] # callback proc name
      _ # Term rewriting template
      _ # Generic params
      @formalParams # parameters passed to the callback
      @pragmas # callback pragmas
      _ # Reserved
      @implementation # callback body
      all _

  var types = initTable[DuckType, NimNode]()


  var params = formalParams.toSeq
  let
    scalarFunc = ident(name) # the name of the actual function we want to pass to duckdb
    callbackNode = ident(name & "callBack")
    callback = newProc(name = callbackNode, params = params, body = implementation)
    # the actual proc we want to call on the rows
    wrapperName = ident("scalarWrapper" & name) # proc that will be called by duckdb

  let maskAt = findScalarValidityMaskParam(formalParams)
  let shouldAddMask = maskAt >= 0
  if shouldAddMask:
    echo maskAt
    let maskNode = params[maskAt]
    params.delete(maskAt)
    echo maskNode.treeRepr

  # The function that will be called by duckdb
  # wrapper(info: duckdb_function_info, chunk: duckdb_data_chunk, output: duckdb_vector)
  #    let size = get size from chunk
  #
  #    for every parameter in the callback function generate a corresponding
  #    get_vector and cast from chunk
  #
  #    output = cast the return obj to the req return tp
  let wrapper = buildAst(stmtList):
    let
      size = ident("size") # size of the select size
      chunk = ident("chunk") # size of the select size
      rawChunk = ident("rawChunk")
      typesNode = ident("types") # size of the select size
      output = ident("output") # obj where we dump the results
      # validityMaskName = ident("ScalarValidityMaskWrapper")
      outputValidityMask = ident("outputValidityMask") # obj where we dump the results

    # define the parameters required by the wrapper function
    let parameters = [
      newEmptyNode(),
      newIdentDefs(ident("info"), ident("duckdbFunctionInfo")), # Function context
      newIdentDefs(rawChunk, ident("duckdbDataChunk")),
        # The result chunk that will contain the passed parameters
      newIdentDefs(output, ident("duckdbVector")), # Obj where to dump the results
    ]

    let wrapperBody = buildAst(stmtList):

      # TypeSection:
      #   TypeDef:
      #     validityMaskName
      #     Empty()
      #     RefTy:
      #       ObjectTy:
      #         Empty()
      #         OfInherit:
      #           ident "ScalarValidityMask"
      #         RecList:
      #           # IdentDefs:
      #           #   ident "output"
      #           #   bindSym "bool"
      #           #   bindSym "true"
      #           for p in params[1 ..^ 1]:
      #             for v in p[0 ..< ^2]:
      #               IdentDefs:
      #                 ident v.strVal
      #                 bindSym "bool"
      #                 bindSym "true"
      #                 # Empty()

      var arguments = initTable[string, DuckType]()
      StmtList:
        VarSection:
          IdentDefs:
            typesNode
            empty()
            Call:
              BracketExpr:
                ident "newSeq"
                ident "DuckType"

      for param in params[1 ..^ 1]:
        let duckTp = newDuckType(param[^2])
        for idx, p in param[0 ..< ^2]:
          newCall(bindSym "add", typesNode, newLit duckTp)
          arguments[genSym(nskLet, p.strVal).strVal] = duckTp

      newCall(bindSym "duckdbVectorEnsureValidityWritable", output)
      newLetStmt(
        size,
        newDotExpr(newCall(bindSym "duckdbDataChunkGetSize", rawChunk), ident("int")),
      )
      newLetStmt(
        chunk,
        newCall(bindSym"newDataChunk", ident("rawChunk"), typesNode, newLit false),
      )
      newVarStmt(
        outputValidityMask, newCall(bindSym"newValidityMask", output, size, newLit true)
      )

      for idx, p, tp in enumerate(arguments.pairs):
        let container = nnkBracketExpr.newTree(chunk, newLit idx)
        newLetStmt(ident p, newDotExpr(container, ident typeToField[tp]))

      let iNode = ident "i"
      ForStmt:
        iNode
        Infix:
          ident "..<"
          newLit 0
          size
        StmtList:
          if shouldAddMask:
            VarSection:
              IdentDefs:
                ident "mask"
                Empty()
                # Command:
                #   ident "new"
                Call:
                  ident "ScalarValidityMask"
          Command:
            ident "[]="
            output
            iNode
            Command:
              callbackNode
              for p in arguments.keys:
                BracketExpr:
                  ident p
                  iNode
              if shouldAddMask:
                ident "mask"
          # Command:
          #   bindSym "setValidity"
          #   outputValidityMask
          #   iNode
          #   DotExpr:
          #     ident "mask"
          #     ident "outputValid"

    # the actual wrapper definition
    newProc(
      name = wrapperName,
      params = parameters,
      body = wrapperBody,
      pragmas = nnkPragma.newTree(ident("cdecl")),
    )

  # the function that will registered in the duckdb connection
  let createdScalarFunc = buildAst(stmtList):
    newLetStmt scalarFunc, newCall(bindSym"newScalarFunction", newLit scalarFunc.strVal)

    # convert the type to a logicalType and register it to the scalar function
    for param in params[1 ..^ 1]:
      # last on is the type
      let duckTp = newDuckType(param[^2])

      if not types.contains(duckTp):
        let dTp = genSym(nskLet, $duckTp)
        newLetStmt dTp, newCall(bindSym"newDuckType", ident(param[^2].strVal))
        let lgTp = genSym(nskLet, $duckTp)
        newLetStmt lgTp, newCall(bindSym"newLogicalType", dTp)
        types[duckTp] = lgTp

      for p in param[0 ..< ^2]:
        newCall(
          bindSym("duckdb_scalar_function_add_parameter"),
          newDotExpr(scalarFunc, ident"handle"),
          newDotExpr(types[duckTp], ident"handle"),
        )

    let returnDkTp = newDuckType(params[0])

    if not types.contains(returnDkTp):
      let dTp = genSym(nskLet, $returnDkTp)
      newLetStmt dTp, newCall(bindSym"newDuckType", ident(params[0].strVal))
      let lgTp = genSym(nskLet, $returnDkTp)
      newLetStmt lgTp, newCall(bindSym"newLogicalType", dTp)
      types[returnDkTp] = lgTp

    newCall(
      bindSym("duckdb_scalar_function_set_name"),
      newDotExpr(scalarFunc, ident"handle"),
      newDotExpr(newLit(scalarFunc.strVal), ident("cstring")),
    )

    newCall(
      bindSym("duckdb_scalar_function_set_return_type"),
      newDotExpr(scalarFunc, ident"handle"),
      newDotExpr(types[returnDkTp], ident"handle"),
    )

    newCall(
      bindSym("duckdb_scalar_function_set_function"),
      newDotExpr(scalarFunc, ident"handle"),
      wrapperName,
    )

  result = nnkStmtList.newTree()
  result.add quote do:
    `callback`

    `wrapper`

    `createdScalarFunc`

proc register*(con: Connection, fun: ScalarFunction) =
  check(
    duckdb_register_scalar_function(con.handle, fun.handle),
    fmt"Failed to register function '{fun.name}'",
  )
