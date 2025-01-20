import std/[unittest, sequtils]
import ../../src/[api, database, query, query_result, vector, table_functions, types]

suite "Lower level table functions":
  test "iterator with one parameter":
    let conn = newDatabase().connect()

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

    proc mainFunction(info: FunctionInfo, chunk: duckdb_data_chunk) =
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
    conn.register(tf)
    let outcome = $conn.execute("SELECT * FROM my_function(5);").fetchall()
    assert outcome == "@[@[42, 84, 42, 84, 42]]"

suite "Higher level table functions":
  test "Iterator with one parameter":
    let conn = newDatabase().connect()

    iterator countToN(count: int): int {.producer, closure.} =
      for i in 0 ..< count:
        yield i

    conn.register(countToN)

    let outcome = conn.execute("SELECT * FROM countToN(3)").fetchall()
    check outcome[0].valueInteger == @[0'i32, 1'i32, 2'i32]

  test "Iterator with multiple parameters and default value":
    let conn = newDatabase().connect()

    # providing a default will have no affect for now
    iterator countToN(count, step: int, val: int = 3): int {.producer, closure.} =
      for i in countUp(0, count, step):
        yield val

    conn.register(countToN)

    let outcome = conn.execute("SELECT * FROM countToN(9, 3, -1)").fetchall()
    check outcome[0].valueInteger == @[-1'i32, -1'i32, -1'i32, -1'i32]

  test "Iterator with multiple parameters, string output":
    let conn = newDatabase().connect()

    iterator progress(count: int, sigil: string): string {.producer, closure.} =
      var output = ""
      for _ in 0 ..< count:
        output &= sigil
        yield output

    conn.register(progress)

    let outcome = conn.execute("SELECT * FROM progress(5, '#')").fetchall()

    check outcome[0].valueVarChar == @["#", "##", "###", "####", "#####"]

  test "Lazy iterator":
    let conn = newDatabase().connect()

    iterator floatCounter(): float {.producer, closure.} =
      var counter = 0.0
      while true:
        yield counter
        counter += 1.0

    conn.register(floatCounter)

    let outcome = conn.execute("SELECT * FROM floatCounter() LIMIT 5;").fetchall()
    check outcome[0].valueDouble == @[0.0, 1.0, 2.0, 3.0, 4.0]
