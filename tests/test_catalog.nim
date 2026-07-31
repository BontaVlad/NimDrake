import std/options
import unittest2
import ../src/[ffi, database, query, qresult, types, exceptions, table_functions, catalog]

suite "TableDescription":

  test "basic column introspection":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE td_intro (a INT, b VARCHAR, c DOUBLE)")
    let td = newTableDescription(conn, "td_intro")
    check td.columnCount == 3
    check td.columnName(0) == "a"
    check td.columnName(1) == "b"
    check td.columnName(2) == "c"
    check toDuckType(td.columnType(0)) == DuckType.Integer
    check toDuckType(td.columnType(1)) == DuckType.Varchar
    check toDuckType(td.columnType(2)) == DuckType.Double

  test "default schema via empty string (nullptr)":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE td_default (x INT)")
    let td = newTableDescription(conn, "td_default")
    check td.columnCount == 1
    check td.columnName(0) == "x"

  test "explicit schema":
    let conn = newDatabase().connect()
    conn.execute("CREATE SCHEMA s")
    conn.execute("CREATE TABLE s.td_schema (y BIGINT)")
    let td = newTableDescription(conn, "td_schema", schema = "s")
    check td.columnCount == 1
    check td.columnName(0) == "y"
    check toDuckType(td.columnType(0)) == DuckType.BigInt

  test "nonexistent table raises OperationError":
    let conn = newDatabase().connect()
    expect(OperationError):
      discard newTableDescription(conn, "no_such_table_xyz")

  test "columnHasDefault":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE td_defaults (a INT DEFAULT 42, b INT)")
    let td = newTableDescription(conn, "td_defaults")
    check td.columnHasDefault(0) == true
    check td.columnHasDefault(1) == false

  test "move semantics — moved-from TableDescription is nil":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE td_move (x INT)")
    var td1 = newTableDescription(conn, "td_move")
    let td2 = move(td1)
    check(td1.rawHandle == nil)
    check td2.columnCount == 1
    check td2.columnName(0) == "x"


suite "Catalog in bind callbacks":

  type
    LookupResult = ref object
      found: bool
      entryType: CatalogEntryType
      entryName: string
    MainState = ref object
      done: bool

  var gResult: LookupResult

  proc destroyResult(p: pointer) {.cdecl.} =
    GC_unref(cast[LookupResult](p))

  proc destroyMainState(p: pointer) {.cdecl.} =
    `=destroy`(cast[MainState](p))

  proc initWriteBool(info: InitInfo) {.cdecl.} =
    let state = MainState(done: false)
    GC_ref(state)
    info.setInitData(cast[pointer](state), destroyMainState)

  proc mainWriteBool(info: FunctionInfo; output: duckdb_data_chunk) {.cdecl.} =
    let state = cast[MainState](info.getInitData())
    if state.done:
      duckdb_data_chunk_set_size(output, 0)
      return
    state.done = true
    let r = cast[LookupResult](info.getBindData())
    let vec = duckdb_data_chunk_get_vector(output, 0)
    let data = cast[ptr bool](duckdb_vector_get_data(vec))
    data[] = r.found
    duckdb_data_chunk_set_size(output, 1)

  proc bindLookupTable(info: BindInfo) {.cdecl.} =
    info.addResultColumn("found", DuckType.Boolean)
    let cat = newCatalog(info, "memory")
    let entry = cat.getEntry(CatalogEntryType.Table, "main", "probe_table")
    let r = LookupResult(found: entry.isSome)
    if entry.isSome:
      r.entryType = entry.get.entryType
      r.entryName = entry.get.name
    gResult = r
    GC_ref(r)
    info.setBindData(cast[pointer](r), destroyResult)

  proc bindLookupNonexistent(info: BindInfo) {.cdecl.} =
    info.addResultColumn("found", DuckType.Boolean)
    let cat = newCatalog(info, "memory")
    let entry = cat.getEntry(CatalogEntryType.Table, "main", "no_such_entry_xyz")
    let r = LookupResult(found: entry.isSome)
    gResult = r
    GC_ref(r)
    info.setBindData(cast[pointer](r), destroyResult)

  proc bindTypeName(info: BindInfo) {.cdecl.} =
    info.addResultColumn("found", DuckType.Boolean)
    let cat = newCatalog(info, "memory")
    let name = cat.typeName
    let r = LookupResult(found: name == "duckdb", entryName: name)
    gResult = r
    GC_ref(r)
    info.setBindData(cast[pointer](r), destroyResult)

  proc bindLookupView(info: BindInfo) {.cdecl.} =
    info.addResultColumn("found", DuckType.Boolean)
    let cat = newCatalog(info, "memory")
    let entry = cat.getEntry(CatalogEntryType.View, "main", "probe_view")
    let r = LookupResult(found: entry.isSome)
    if entry.isSome:
      r.entryType = entry.get.entryType
      r.entryName = entry.get.name
    gResult = r
    GC_ref(r)
    info.setBindData(cast[pointer](r), destroyResult)

  proc bindTableExists(info: BindInfo) {.cdecl.} =
    info.addResultColumn("found", DuckType.Boolean)
    let cat = newCatalog(info, "memory")
    let r = LookupResult(found: cat.tableExists("main", "probe_table"))
    gResult = r
    GC_ref(r)
    info.setBindData(cast[pointer](r), destroyResult)

  proc bindViewExists(info: BindInfo) {.cdecl.} =
    info.addResultColumn("found", DuckType.Boolean)
    let cat = newCatalog(info, "memory")
    let r = LookupResult(found: cat.viewExists("main", "probe_view"))
    gResult = r
    GC_ref(r)
    info.setBindData(cast[pointer](r), destroyResult)

  proc bindMoveCatalog(info: BindInfo) {.cdecl.} =
    info.addResultColumn("found", DuckType.Boolean)
    var cat = newCatalog(info, "memory")
    let cat2 = move(cat)
    let name = cat2.typeName
    let r = LookupResult(found: true, entryName: name)
    gResult = r
    GC_ref(r)
    info.setBindData(cast[pointer](r), destroyResult)

  test "existing table entry lookup":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE probe_table (x INT)")
    let tf = newTableFunction("cata_tbl", bindProc = bindLookupTable,
                              initProc = initWriteBool, mainProc = mainWriteBool)
    conn.register(tf)
    for _ in conn.execute("SELECT found FROM cata_tbl()"):
      discard
    check gResult.found
    check gResult.entryType == CatalogEntryType.Table
    check gResult.entryName == "probe_table"

  test "nonexistent entry returns none":
    let conn = newDatabase().connect()
    let tf = newTableFunction("cata_none", bindProc = bindLookupNonexistent,
                              initProc = initWriteBool, mainProc = mainWriteBool)
    conn.register(tf)
    for _ in conn.execute("SELECT found FROM cata_none()"):
      discard
    check gResult.found == false

  test "typeName returns 'duckdb'":
    let conn = newDatabase().connect()
    let tf = newTableFunction("cata_tn", bindProc = bindTypeName,
                              initProc = initWriteBool, mainProc = mainWriteBool)
    conn.register(tf)
    for _ in conn.execute("SELECT found FROM cata_tn()"):
      discard
    check gResult.found
    check gResult.entryName == "duckdb"

  test "view entry lookup":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE probe_view_base (x INT)")
    conn.execute("CREATE VIEW probe_view AS SELECT * FROM probe_view_base")
    let tf = newTableFunction("cata_vw", bindProc = bindLookupView,
                              initProc = initWriteBool, mainProc = mainWriteBool)
    conn.register(tf)
    for _ in conn.execute("SELECT found FROM cata_vw()"):
      discard
    check gResult.found
    check gResult.entryType == CatalogEntryType.View
    check gResult.entryName == "probe_view"

  test "tableExists returns true for existing table":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE probe_table (x INT)")
    let tf = newTableFunction("cata_tex", bindProc = bindTableExists,
                              initProc = initWriteBool, mainProc = mainWriteBool)
    conn.register(tf)
    for _ in conn.execute("SELECT found FROM cata_tex()"):
      discard
    check gResult.found

  test "viewExists returns true for existing view":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE probe_view_base2 (x INT)")
    conn.execute("CREATE VIEW probe_view AS SELECT * FROM probe_view_base2")
    let tf = newTableFunction("cata_viex", bindProc = bindViewExists,
                              initProc = initWriteBool, mainProc = mainWriteBool)
    conn.register(tf)
    for _ in conn.execute("SELECT found FROM cata_viex()"):
      discard
    check gResult.found

  test "move semantics — moved-to Catalog is usable after move":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE probe_table (x INT)")
    let tf = newTableFunction("cata_mv", bindProc = bindMoveCatalog,
                              initProc = initWriteBool, mainProc = mainWriteBool)
    conn.register(tf)
    for _ in conn.execute("SELECT found FROM cata_mv()"):
      discard
    check gResult.found
    check gResult.entryName == "duckdb"

suite "TableDescription — additional coverage":
  test "TableDescription with composite column types":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE td_composite (i INT, s STRUCT(a INT, b VARCHAR), l INTEGER[])")
    let td = newTableDescription(conn, "td_composite")
    check td.columnCount == 3
    check td.columnName(0) == "i"
    check td.columnName(1) == "s"
    check td.columnName(2) == "l"
    check toDuckType(td.columnType(0)) == DuckType.Integer
    check toDuckType(td.columnType(1)) == DuckType.Struct
    check toDuckType(td.columnType(2)) == DuckType.List

  test "TableDescription explicit schema (non-default)":
    let conn = newDatabase().connect()
    conn.execute("CREATE SCHEMA custom_schema")
    conn.execute("CREATE TABLE custom_schema.td_custom (x BIGINT, y VARCHAR)")
    let td = newTableDescription(conn, "td_custom", schema = "custom_schema")
    check td.columnCount == 2
    check td.columnName(0) == "x"
    check td.columnName(1) == "y"

  test "TableDescription with DEFAULT 42 — columnHasDefault returns true":
    let conn = newDatabase().connect()
    conn.execute("CREATE TABLE td_def (a INT DEFAULT 42, b INT, c VARCHAR DEFAULT 'x')")
    let td = newTableDescription(conn, "td_def")
    check td.columnHasDefault(0) == true
    check td.columnHasDefault(1) == false
    check td.columnHasDefault(2) == true
