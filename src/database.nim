# import std/[logging]

import /[api, config, exceptions]

type
  Database* = object of duckdbDatabase
  Connection* = distinct ptr duckdbConnection

converter toBase*(d: Database): duckdbDatabase =
  cast[duckdbDatabase](d)

converter toBase*(d: ptr Database): ptr duckdbDatabase =
  cast[ptr duckdbDatabase](d)

converter toBase*(c: Connection): duckdbConnection =
  cast[duckdbConnection](c)

converter toBase*(c: ptr Connection): ptr duckdbConnection =
  cast[ptr duckdbConnection](c)

# This might be a problem, closing the database but not the connection
proc `=destroy`(db: Database) =
  if not isNil(db.addr):
    duckdbClose(db.addr)

proc `=destroy`(con: Connection) =
  if not isNil(con.addr):
    duckdbDisconnect(con.addr)

proc connect*(path: string): Connection =
  let db = DataBase()
  check(duckdbOpen(path.cstring, db.addr), "Failed to open database")
  check(duckdbConnect(db, result.addr), "Failed to connect to database")

proc connect*(path: string, config: Config): Connection =
  let db = DataBase()
  var error: cstring
  let state: duckdbState = duckdbOpenExt(path.cstring, db.addr, config, error.addr)
  check(state, $error, `=destroy`(db))
  check(
    duckdbConnect(db, result.addr), "Failed to connect to database", `=destroy`(result)
  )

proc connect*(config: Config): Connection =
  connect(":memory:", config)

proc connect*(): Connection =
  connect(":memory:")
