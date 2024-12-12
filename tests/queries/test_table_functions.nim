import std/[unittest, sequtils, sugar]
import ../../src/[api, database, query, query_result, vector, table_functions, types]

suite "tests":
  test "Test create table function":
    let con = connect()
    type
      BindData = ref object
        count: int

      InitData = ref object
        pos: int

    proc destroyBind(p: pointer) {.cdecl.} =
      `=destroy`(cast[BindData](p))

    proc destroyInit(p: pointer) {.cdecl.} =
      `=destroy`(cast[InitData](p))

    proc bindFunction(info: BindInfo) =
      info.add_result_column("my_column", DuckType.INTEGER)
      let
        parameter = info.parameters.toSeq
        data = BindData(count: parameter[0].valueInteger)
      GC_ref(data)
      duckdb_bind_set_bind_data(info.handle, cast[ptr BindData](data), destroyBind)

    proc initFunction(info: InitInfo) =
      let data = InitData(pos: 0)
      GC_ref(data)
      duckdb_init_set_init_data(info.handle, cast[ptr InitData](data), destroyInit)

    proc mainFunction(info: FunctionInfo, chunk: DataChunk) =
      # var bindInfo = cast[BindData](duckdb_function_get_bind_data(info))
      var bindInfo = cast[BindData](duckdb_function_get_bind_data(info))
      var initInfo = cast[InitData](duckdb_function_get_init_data(info))

      let raw = duckdb_vector_get_data(duckdb_data_chunk_get_vector(chunk, 0.idx_t))
      var resultArray = cast[ptr UncheckedArray[int32]](raw)

      var count = 0
      while initInfo.pos < bindInfo.count and count < duckdb_vector_size().int:
        resultArray[count] = if initInfo.pos mod 2 == 0: 42 else: 84
        count += 1
        initInfo.pos += 1
      duckdb_data_chunk_set_size(chunk, count.idx_t)

    let tf = newTableFunction(
      name = "my_function",
      parameters = @[newLogicalType(DuckType.Integer)],
      bindFunc = bindFunction,
      initFunc = initFunction,
      initLocalFunc = proc(_: InitInfo) =
        discard,
      mainFunc = mainFunction,
      extraData = nil,
      projectionPushdown = true,
    )
    con.register(tf)
    let outcome = $con.execute("SELECT * FROM my_function(5);").fetchall()
    assert outcome == "@[@[42, 84, 42, 84, 42]]"
