import /[database]

template transaction*(con: Connection, statements: untyped) =
  con.execute("BEGIN TRANSACTION;")
  try:
    statements
    con.execute("COMMIT TRANSACTION;")
  except Exception:
    con.execute("ROLLBACK TRANSACTION;")
