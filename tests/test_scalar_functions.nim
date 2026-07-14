import unittest2
import ../src/[database, query, scalar_functions, types, qresult, exceptions]

# ── T1 ──────────────────────────────────────────────────────────────────────
proc intAdd(a, b: int64): int64 = a + b

test "T1: int64 add via UDF":
  let duck = newDatabase().connect()
  duck.registerScalar(intAdd)
  let r = duck.execute("SELECT intAdd(3::BIGINT, 4::BIGINT)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    check v[0] == 7'i64

# ── T2: supported types ─────────────────────────────────────────────────────
proc boolFromInt(x: int32): bool = x != 0
proc tinyRoundtrip(x: int8): int8 = x
proc smallRoundtrip(x: int16): int16 = x
proc intRoundtrip(x: int32): int32 = x
proc bigRoundtrip(x: int64): int64 = x
proc doubleRoundtrip(x: float64): float64 = x
proc upperGreeting(s: string): string = "HELLO, " & s & "!"

test "T2a: bool return (from int32 input)":
  let duck = newDatabase().connect()
  duck.registerScalar(boolFromInt)
  let r = duck.execute("SELECT boolFromInt(1::INTEGER), boolFromInt(0::INTEGER)")
  for chunk in r:
    let v0 = chunk.vector(0).bindAs DuckType.Boolean
    let v1 = chunk.vector(1).bindAs DuckType.Boolean
    check v0[0] == true
    check v1[0] == false

test "T2b: int8 (TINYINT) round-trip":
  let duck = newDatabase().connect()
  duck.registerScalar(tinyRoundtrip)
  let r = duck.execute("SELECT tinyRoundtrip(42::TINYINT)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.TinyInt
    check v[0] == 42'i8

test "T2c: int16 (SMALLINT) round-trip":
  let duck = newDatabase().connect()
  duck.registerScalar(smallRoundtrip)
  let r = duck.execute("SELECT smallRoundtrip(1000::SMALLINT)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.SmallInt
    check v[0] == 1000'i16

test "T2d: int32 (INTEGER) round-trip":
  let duck = newDatabase().connect()
  duck.registerScalar(intRoundtrip)
  let r = duck.execute("SELECT intRoundtrip(99999::INTEGER)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.Integer
    check v[0] == 99999'i32

test "T2e: int64 (BIGINT) round-trip":
  let duck = newDatabase().connect()
  duck.registerScalar(bigRoundtrip)
  let r = duck.execute("SELECT bigRoundtrip(9999999999::BIGINT)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    check v[0] == 9999999999'i64

test "T2f: float64 (DOUBLE) round-trip":
  let duck = newDatabase().connect()
  duck.registerScalar(doubleRoundtrip)
  let r = duck.execute("SELECT doubleRoundtrip(3.14159::DOUBLE)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.Double
    check v[0] == 3.14159

test "T2g: varchar (string) passthrough":
  let duck = newDatabase().connect()
  duck.registerScalar(upperGreeting)
  let r = duck.execute("SELECT upperGreeting('world'::VARCHAR)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.Varchar
    check v[0] == "HELLO, world!"

# ── T3: NULL propagation ────────────────────────────────────────────────────
proc identityBig(x: int64): int64 = x

test "T3: NULL input → NULL output":
  let duck = newDatabase().connect()
  duck.registerScalar(identityBig)
  let r = duck.execute("SELECT identityBig(NULL::BIGINT)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    check not v.valid(0)

# ── T4: exception handling ──────────────────────────────────────────────────
proc alwaysCrash(x: int32): int32 =
  raise newException(ValueError, "boom!")

test "T4: exception in UDF body produces error result":
  let duck = newDatabase().connect()
  duck.registerScalar(alwaysCrash)
  expect(OperationError):
    discard duck.execute("SELECT alwaysCrash(1)")

# ── T10: zero-param scalar ──────────────────────────────────────────────────
proc theAnswer(): int64 = 42

test "T10: zero-param constant function":
  let duck = newDatabase().connect()
  duck.registerScalar(theAnswer)
  let r = duck.execute("SELECT theAnswer()")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    check v[0] == 42'i64

# ── T11: three params ───────────────────────────────────────────────────────
proc sumThree(a, b, c: int64): int64 = a + b + c

test "T11: three-param scalar":
  let duck = newDatabase().connect()
  duck.registerScalar(sumThree)
  let r = duck.execute("SELECT sumThree(1::BIGINT, 2::BIGINT, 3::BIGINT)")
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.BigInt
    check v[0] == 6'i64

# ── T12: UDF in WHERE clause ────────────────────────────────────────────────
proc isPositive(x: int64): bool = x > 0

test "T12: UDF in WHERE clause":
  let duck = newDatabase().connect()
  duck.registerScalar(isPositive)
  let r = duck.execute(
    "SELECT i FROM (VALUES (-1), (0), (1), (2)) AS t(i) WHERE isPositive(i)")
  var collected: seq[int32]
  for chunk in r:
    let v = chunk.vector(0).bindAs DuckType.Integer
    for i in 0 ..< v.len:
      collected.add v[i]
  check collected == @[1'i32, 2]

# ── Compile-time rejection tests ────────────────────────────────────────────

proc voidRet(): void = discard

test "T5: void return rejected":
  let duck = newDatabase().connect()
  check not compiles(duck.registerScalar(voidRet))

proc genericDummy[T](x: T): int64 = 0

test "T6: generic proc rejected":
  let duck = newDatabase().connect()
  check not compiles(duck.registerScalar(genericDummy))

proc defaultParam(x: int64 = 0): int64 = x

test "T7: default param value rejected":
  let duck = newDatabase().connect()
  check not compiles(duck.registerScalar(defaultParam))

test "T8: non-proc symbol rejected":
  let duck = newDatabase().connect()
  # use a type as the second argument instead of a proc
  check not compiles(duck.registerScalar(int64))
