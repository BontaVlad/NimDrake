import /[database]

template transient*(con: Connection, statements: untyped) =
  con.execute("BEGIN TRANSACTION;")
  try:
    statements
  finally:
    con.execute("ROLLBACK TRANSACTION;")

template transaction*(con: Connection, statements: untyped) =
  con.execute("BEGIN TRANSACTION;")
  try:
    statements
    con.execute("COMMIT TRANSACTION;")
  except Exception:
    con.execute("ROLLBACK TRANSACTION;")
    raise
