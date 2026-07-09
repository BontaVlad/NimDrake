import std/[macros, strformat]
import /[ffi, database, types, qresult, exceptions]

type
  ScalarFunctionBase* = object of RootObj
    name*: string
    handle*: duckdb_scalar_function

  ScalarFunction* = ref object of ScalarFunctionBase

proc `=destroy`(s: ScalarFunctionBase) =
  if s.handle != nil:
    duckdb_destroy_scalar_function(s.handle.addr)

proc `=wasMoved`(s: var ScalarFunctionBase) =
  s.handle = nil
  s.name = ""

proc `=copy`(dest: var ScalarFunctionBase, source: ScalarFunctionBase) {.error.}
proc `=dup`(s: ScalarFunctionBase): ScalarFunctionBase {.error.}

proc newScalarFunction*(name: string): ScalarFunction =
  result = ScalarFunction(name: name, handle: duckdb_create_scalar_function())

macro scalar*(body: typed): untyped =
  ## UDF scalar macro — currently stubbed. Will be revived in a future pass.
  if body.kind != nnkTemplateDef:
    error("The {.scalar.} pragma can only be applied to template definitions.")
  result = quote do:
    raise newException(
      OperationError,
      "UDF scalar macros need updating for the new qresult/Vector[kt] API.",
    )

proc register*(con: Connection, fun: ScalarFunction) =
  check(
    duckdb_register_scalar_function(con.rawHandle, fun.handle),
    fmt"Failed to register function '{fun.name}'",
  )
