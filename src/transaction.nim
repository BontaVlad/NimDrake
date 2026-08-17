## Transaction scopes built on the SQL `BEGIN`/`COMMIT`/`ROLLBACK` commands.
##
## Both templates take a block of `Connection` statements and wrap them in a
## transaction; the difference is only the outcome on failure — `transaction`
## commits on success, `transient` always rolls back.
## These are small conveniences, not ACID-guaranteeing magic: they inherit
## DuckDB's own transactional semantics for the statements inside.
import /[database]

template transient*(con: Connection, statements: untyped) =
  ## Runs `statements` inside a transaction that is **always** rolled back —
  ## a scratchpad for setup you never want persisted. If `BEGIN TRANSACTION`
  ## fails, `ROLLBACK` is not attempted.
  con.execute("BEGIN TRANSACTION;")
  try:
    statements
  finally:
    con.execute("ROLLBACK TRANSACTION;")

template transaction*(con: Connection, statements: untyped) =
  ## Runs `statements` inside a transaction that is **committed** once the
  ## block finishes. If `BEGIN TRANSACTION` fails, the exception propagates
  ## without a rollback; if the block or the `COMMIT` fails, `ROLLBACK` is
  ## attempted before the exception is re-raised.
  con.execute("BEGIN TRANSACTION;")
  try:
    statements
    con.execute("COMMIT TRANSACTION;")
  except Exception:
    con.execute("ROLLBACK TRANSACTION;")
    raise
