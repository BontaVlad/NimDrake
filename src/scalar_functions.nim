import std/[macros, sequtils, tables, strformat, enumerate]
import fusion/[matching, astdsl]
import /[api, database, types, datachunk, exceptions]

type
  ScalarFunctionBase* = object of RootObj
    name*: string
    handle*: duckdb_scalar_function

  ScalarFunction* = ref object of ScalarFunctionBase

proc `=destroy`(s: ScalarFunctionBase) =
  if not isNil(s.addr) and not isNil(s.handle.addr):
    duckdb_destroy_scalar_function(s.handle.addr)

proc newScalarFunction*(name: string): ScalarFunction =
  result = ScalarFunction(name: name, handle: duckdb_create_scalar_function())

# The DuckType enum and Vector type definitions would be here as in your example
macro generateTypeToField(registryName: static[string], vectorType: typed): untyped =
  ## Creates a getFieldName function that returns the field identifier
  ## in the Vector type corresponding to a given DuckType

  result = newStmtList()

  # Get the vector object definition
  let typeImpl = getImpl(vectorType)

  # Recursively search for the case statement in the type definition
  proc findCaseStmt(node: NimNode): NimNode =
    if node.kind == nnkRecCase:
      return node
    for i in 0 ..< node.len:
      let child = node[i]
      if child.kind == nnkRecCase:
        return child
      if child.len > 0:
        let found = findCaseStmt(child)
        if found != nil:
          return found
    return nil

  # Extract the object type from the type definition
  var objTy: NimNode = nil

  if typeImpl.kind == nnkTypeDef:
    let typeDef = typeImpl[2]
    if typeDef.kind == nnkRefTy and typeDef[0].kind == nnkObjectTy:
      objTy = typeDef[0]
    elif typeDef.kind == nnkObjectTy:
      objTy = typeDef

  if objTy == nil:
    error("Expected a ref object or object type", vectorType)

  # Find the recList containing the case statement
  var recList: NimNode = nil
  for i in 0 ..< objTy.len:
    if objTy[i].kind == nnkRecList:
      recList = objTy[i]
      break

  if recList == nil:
    error("Could not find record list in object definition", vectorType)

  # Find the case statement in the record list
  let caseStmt = findCaseStmt(recList)
  if caseStmt == nil:
    error("Could not find case statement in object definition", vectorType)

  var tableExpr = nnkTableConstr.newTree()
  # Process each branch of the case statement
  for i in 1 ..< caseStmt.len:
    caseStmt[i].assertMatch:
      OfBranch:
        pref DotExpr[_, (strVal: @types)]
        RecList[any IdentDefs[any Postfix[_, (strVal: @fieldName)]]] |
          IdentDefs[any Postfix[_, (strVal: @fieldName)]]

    # if duckType.strVal in
    # echo types.repr, " -> ", fieldName.repr

    for key in types:
      let keyExpr = nnkDotExpr.newTree(newIdentNode("DuckType"), newIdentNode(key))

      # let valueExpr = nnkIdent.newTree(valueIdent)

      # Create the key-value pair
      tableExpr.add(nnkExprColonExpr.newTree(keyExpr, newLit(fieldName[0])))

  result = nnkLetSection.newTree(
    nnkIdentDefs.newTree(
      newIdentNode(registryName),
      newEmptyNode(),
      nnkDotExpr.newTree(tableExpr, newIdentNode("toTable")),
    )
  )

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
  let
    params = formalParams.toSeq
    scalarFunc = ident(name) # the name of the actual function we want to pass to duckdb
    callbackNode = ident(name & "callBack")
    callback = newProc(name = callbackNode, params = params, body = implementation)
    # the actual proc we want to call on the rows
    wrapperName = ident("scalarWrapper" & name) # proc that will be called by duckdb

  # The function that will be called by duckdb
  # wrapper(info: duckdb_function_info, chunk: duckdb_data_chunk, output: duckdb_vector)
  #    let size = get size from chunk
  #
  #    for every parameter in the callback function generate a corresponding
  #    get_vector and cast from chunk
  #
  #    output = cast the return obj to the req return tp
  #
  let wrapper = buildAst(stmtList):
    let
      size = ident("size") # size of the select size
      chunk = ident("chunk") # size of the select size
      rawChunk = ident("rawChunk")
      typesNode = ident("types") # size of the select size
      output = ident("output") # obj where we dump the results
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

      let ridx = ident "ridx"
      ForStmt:
        ridx
        Infix:
          ident "..<"
          newLit 0
          size
        StmtList:
          Command:
            bindSym "setValidity"
            outputValidityMask
            ridx
            newLit false

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
          Command:
            bindSym "setValidity"
            outputValidityMask
            iNode
            newLit true

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
