## Catalog introspection without raw SQL.
##
## Two tiers:
##
## **TableDescription** — column-level introspection for a named table.
## Obtain from any `Connection`:
##
## .. code-block:: nim
##
##    let td = newTableDescription(con, "my_table")
##    assert td.columnCount > 0
##    for i in 0 ..< td.columnCount:
##      echo td.columnName(i), " → ", toDuckType(td.columnType(i))
##
## **Catalog / CatalogEntry** — entry lookup by type and name.
## Obtainable from a `BindInfo` inside a table-function bind callback
## (guaranteed active transaction):
##
## .. code-block:: nim
##
##    proc myBind(info: BindInfo) =
##      let cat = newCatalog(info, "memory")
##      let entry = cat.getEntry(CatalogEntryType.Table, "main", "t")
##      echo entry.isSome, " ", entry.entryType
##
## The DuckDB C API for catalogs is transaction-scoped; the standalone
## `Connection`-based catalog constructor is intentionally absent because
## `duckdb_client_context_get_catalog` returns `nil` outside an active
## transaction. For bulk listing of schemas/tables, use
## `conn.execute("SELECT … FROM information_schema.tables …")`.
import std/options
import /[ffi, exceptions, arc, types, database, table_functions]

type
  CatalogEntryType* {.pure, size: sizeof(cuint).} = enum ## The catalog entry
    ## kinds DuckDB can store; used with `getEntry` to filter lookups.
    Invalid            = DUCKDB_CATALOG_ENTRY_TYPE_INVALID
    Table              = DUCKDB_CATALOG_ENTRY_TYPE_TABLE
    Schema             = DUCKDB_CATALOG_ENTRY_TYPE_SCHEMA
    View               = DUCKDB_CATALOG_ENTRY_TYPE_VIEW
    Index              = DUCKDB_CATALOG_ENTRY_TYPE_INDEX
    PreparedStatement  = DUCKDB_CATALOG_ENTRY_TYPE_PREPARED_STATEMENT
    Sequence           = DUCKDB_CATALOG_ENTRY_TYPE_SEQUENCE
    Collation          = DUCKDB_CATALOG_ENTRY_TYPE_COLLATION
    Type               = DUCKDB_CATALOG_ENTRY_TYPE_TYPE
    Database           = DUCKDB_CATALOG_ENTRY_TYPE_DATABASE

arcResource(duckdbTableDescriptionDestroy):
  type
    TableDescription* = object ## Owns a DuckDB table-description handle with
                              ## column metadata; freed on destruction.
      handle: duckdbTableDescription

arcResource(duckdbDestroyCatalogEntry):
  type
    CatalogEntry* = object ## Owns a catalog entry handle; valid only for the
                           ## duration of the opening transaction.
      handle: duckdbCatalogEntry

type
  Catalog* = object ## An open catalog, valid while a transaction is active;
                    ## ownership is moved out on destruction.
    handle: duckdbCatalog
    context: duckdbClientContext

proc `=destroy`(c: var Catalog) =
  if c.handle != nil:
    duckdbDestroyCatalog(c.handle.addr)
    c.handle = nil
  # context is borrowed from DuckDB (valid for duration of current
  # transaction); do NOT destroy it.

proc `=wasMoved`(c: var Catalog) =
  c.handle = nil
  c.context = nil

proc `=copy`(dest: var Catalog; source: Catalog) {.error.}
proc `=dup`(c: Catalog): Catalog {.error.}

# ---------------------------------------------------------------------------
# newTableDescription
# ---------------------------------------------------------------------------

proc newTableDescription*(
    con: Connection; table: string;
    schema = ""; catalog = ""): TableDescription =
  ## Inspect the columns of `table` in the given (or DuckDB default)
  ## `schema` and `catalog`.  Empty strings resolve to DuckDB's defaults
  ## (nullptr passed to the C API).
  let schemaC = if schema.len == 0: cstring(nil) else: schema.cstring
  let catalogC = if catalog.len == 0: cstring(nil) else: catalog.cstring
  var h: duckdbTableDescription
  let st = duckdb_table_description_create_ext(
    con.rawHandle, catalogC, schemaC, table.cstring, h.addr)
  if st != enum_duckdb_state.DuckDBSuccess:
    let msg =
      if h != nil: $duckdb_table_description_error(h)
      else: ""
    if h != nil:
      duckdb_table_description_destroy(h.addr)
    raise newException(OperationError,
      "Failed to create table description for '" & table & "'" &
      (if msg.len > 0: ": " & msg else: ""))
  result.handle = h

# ---------------------------------------------------------------------------
# TableDescription accessors
# ---------------------------------------------------------------------------

proc columnCount*(td: TableDescription): int {.inline.} =
  ## Number of columns in the described table.
  duckdb_table_description_get_column_count(td.handle).int

proc columnName*(td: TableDescription; i: int): string {.inline.} =
  ## NOTE: the C string returned must be freed with ``duckdb_free``.
  let cs = duckdb_table_description_get_column_name(td.handle, i.idx_t)
  result = $cs
  duckdb_free(cast[pointer](cs))

proc columnType*(td: TableDescription; i: int): LogicalType {.inline.} =
  ## Freshly-owned ``LogicalType`` ref for column `i` (destroyed by GC).
  newLogicalType(duckdb_table_description_get_column_type(td.handle, i.idx_t))

proc columnHasDefault*(td: TableDescription; i: int): bool {.inline.} =
  ## Whether column `i` has a DEFAULT expression.
  var b: bool
  check(duckdb_column_has_default(td.handle, i.idx_t, b.addr),
    "duckdb_column_has_default failed for column " & $i)
  b

# ---------------------------------------------------------------------------
# newCatalog — from a table-function bind callback
# ---------------------------------------------------------------------------

proc newCatalog*(info: BindInfo; name: string): Catalog =
  ## Open the named catalog inside a table-function bind callback.
  ## Valid only during an active transaction (which always holds inside
  ## bind/init callbacks).  ``name`` is required — for in-memory databases
  ## the default catalog is ``"memory"``.
  var ctx: duckdbClientContext
  duckdb_table_function_get_client_context(info.handle, ctx.addr)
  result.handle = duckdb_client_context_get_catalog(ctx, name.cstring)
  if result.handle == nil:
    raise newException(OperationError,
      "Catalog '" & name & "' not found (or no active transaction)")
  result.context = ctx

# ---------------------------------------------------------------------------
# Catalog accessors + entry lookup
# ---------------------------------------------------------------------------

proc typeName*(c: Catalog): string {.inline.} =
  ## The catalog *type* name — e.g. ``"duckdb"`` for a DuckDB database.
  ## (Not the catalog's user-visible name — the DuckDB C API only exposes
  ## type name here.)
  $duckdb_catalog_get_type_name(c.handle)

proc getEntry*(c: Catalog; entryType: CatalogEntryType;
               schema, name: string): Option[CatalogEntry] =
  ## Look up a catalog entry by type and name.  Returns ``some`` when
  ## the entry exists, ``none`` otherwise.
  ##
  ## .. note:: Both ``schema`` and ``name`` are required — the C API
  ##    documents no nulltpr default.  The returned entry handle is
  ##    valid only for the duration of the current transaction; do not
  ##    cache it across queries.
  let h = duckdb_catalog_get_entry(c.handle, c.context,
    cast[duckdb_catalog_entry_type](entryType),
    schema.cstring, name.cstring)
  if h == nil:
    result = none CatalogEntry
  else:
    result = some CatalogEntry(handle: h)

proc tableExists*(c: Catalog; schema, name: string): bool {.inline.} =
  ## Whether `table` (in schema, catalog) exists as a table.
  c.getEntry(CatalogEntryType.Table, schema, name).isSome

proc viewExists*(c: Catalog; schema, name: string): bool {.inline.} =
  ## Whether `name` (in schema, catalog) exists as a view.
  c.getEntry(CatalogEntryType.View, schema, name).isSome

# ---------------------------------------------------------------------------
# CatalogEntry accessors
# ---------------------------------------------------------------------------

proc entryType*(e: CatalogEntry): CatalogEntryType {.inline.} =
  ## The entry's kind (`table`, `view`, ...); see `CatalogEntryType`.
  cast[CatalogEntryType](duckdb_catalog_entry_get_type(e.handle))

proc name*(e: CatalogEntry): string {.inline.} =
  ## The entry's name. The underlying C string is owned by the entry;
  ## this proc copies it.
  $duckdb_catalog_entry_get_name(e.handle)
