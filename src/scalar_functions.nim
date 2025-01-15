import std/[macros, sequtils, tables, strformat, sugar, enumerate]
import fusion/[matching, astdsl]
import /[api, query_result, database, types, exceptions]

include datachunk

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

macro scalar*(body: typed): untyped =
  if body.kind != nnkTemplateDef:
    error("The {.scalar.} pragma can only be applied to proc definitions.")

  let typeToField = {
    DuckType.Invalid: ident"valueInvalid",
    DuckType.ANY: ident"valueInvalid",
    DuckType.VARINT: ident"valueInvalid",
    DuckType.SQLNULL: ident"valueInvalid",
    DuckType.Boolean: ident"valueBoolean",
    DuckType.TinyInt: ident"valueTinyint",
    DuckType.SmallInt: ident"valueSmallint",
    DuckType.Integer: ident"valueInteger",
    DuckType.BigInt: ident"valueBigint",
    DuckType.UTinyInt: ident"valueUTinyint",
    DuckType.USmallInt: ident"valueUSmallint",
    DuckType.UInteger: ident"valueUInteger",
    DuckType.UBigInt: ident"valueUBigint",
    DuckType.Float: ident"valueFloat",
    DuckType.Double: ident"valueDouble",
    DuckType.Timestamp: ident"valueTimestamp",
    DuckType.Date: ident"valueDate",
    DuckType.Time: ident"valueTime",
    DuckType.Interval: ident"valueInterval",
    DuckType.HugeInt: ident"valueHugeint",
    DuckType.Varchar: ident"valueVarchar",
    DuckType.Blob: ident"valueBlob",
    DuckType.Decimal: ident"valueDecimal",
    DuckType.TimestampS: ident"valueTimestampS",
    DuckType.TimestampMs: ident"valueTimestampMs",
    DuckType.TimestampNs: ident"valueTimestampNs",
    DuckType.Enum: ident"valueEnum",
    DuckType.List: ident"valueList",
    DuckType.Struct: ident"valueStruct",
    DuckType.Map: ident"valueMap",
    DuckType.UUID: ident"valueUUID",
    DuckType.Union: ident"valueUnion",
    DuckType.Bit: ident"valueBit",
    DuckType.TimeTz: ident"valueTimeTz",
  }.toTable

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
      columnsNode = ident("columns") # size of the select size
      output = ident("output") # obj where we dump the results

    # define the parameters required by the wrapper function
    let parameters = [
      newEmptyNode(),
      newIdentDefs(ident("info"), ident("duckdb_function_info")), # Function context
      newIdentDefs(rawChunk, ident("duckdb_data_chunk")),
        # The result chunk that will contain the passed parameters
      newIdentDefs(output, ident("duckdb_vector")), # Obj where to dump the results
    ]

    let wrapperBody = buildAst(stmtList):
      var arguments = initTable[string, DuckType]()
      StmtList:
        VarSection:
          IdentDefs:
            ident "columns"
            empty()
            Call:
              BracketExpr:
                ident "newSeq"
                ident "Column"

      for param in params[1 ..^ 1]:
        let duckTp = newDuckType(param[^2])
        for idx, p in param[0 ..< ^2]:
          newCall(
            bindSym "add",
            columnsNode,
            newCall(bindSym "newColumn", newLit idx, newLit p.strVal, newLit duckTp),
          )
          arguments[genSym(nskLet, p.strVal).strVal] = duckTp

      newLetStmt(
        size,
        newDotExpr(
          newCall(bindSym "duckdb_data_chunk_get_size", rawChunk), ident("int")
        ),
      )
      newLetStmt(
        chunk,
        newCall(bindSym"newDataChunk", ident("rawChunk"), columnsNode, newLit false),
      )

      for idx, p, tp in enumerate(arguments.pairs):
        let container = nnkBracketExpr.newTree(chunk, newLit idx)
        newLetStmt(ident p, newDotExpr(container, typeToField[tp]))

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
    duckdb_register_scalar_function(con, fun.handle),
    fmt"Failed to register function '{fun.name}'",
  )
