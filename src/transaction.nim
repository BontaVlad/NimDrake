import /[database]

template transient*(con: Connection, statements: untyped) =
  ## Executes statements inside a transaction that is always rolled back.
  ## If BEGIN TRANSACTION fails, ROLLBACK is not attempted.
  con.execute("BEGIN TRANSACTION;")
  try:
    statements
  finally:
    con.execute("ROLLBACK TRANSACTION;")

template transaction*(con: Connection, statements: untyped) =
  ## Executes statements inside a transaction that is committed on success.
  ## If BEGIN TRANSACTION fails, the exception propagates without rollback.
  ## If statements or COMMIT fail, ROLLBACK is attempted before re-raising.
  con.execute("BEGIN TRANSACTION;")
  try:
    statements
    con.execute("COMMIT TRANSACTION;")
  except Exception:
    con.execute("ROLLBACK TRANSACTION;")
    raise
