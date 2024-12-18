import std/[unittest, sequtils, sugar]
import ../../src/[api, database, query, query_result, vector, table_functions, types]

suite "table_functions":
  test "Iterator with one parameter":
    let con = connect()

    iterator countToN(count: int): int {.producer, closure.} =
      for i in 0 ..< count:
        yield i

    con.register(countToN)

    let outcome = con.execute("SELECT * FROM countToN(3)").fetchall()
    check outcome[0].valueInteger == @[0'i32, 1'i32, 2'i32]

  test "Iterator with multiple parameters and default value":
    let con = connect()

    # providing a default will do nothing
    iterator countToN(count, step: int, val: int = 3): int {.producer, closure.} =
      for i in countUp(0, count, step):
        yield val

    con.register(countToN)

    let outcome = con.execute("SELECT * FROM countToN(9, 3, -1)").fetchall()
    check outcome[0].valueInteger == @[-1'i32, -1'i32, -1'i32, -1'i32]

  test "Iterator with multiple parameters, string output":
    let con = connect()

    iterator progress(count: int, sigil: string): string {.producer, closure.} =
      var output = ""
      var progress = 0
      for _ in 0 ..< count:
        for _ in 0 .. progress:
          output &= sigil
        yield output

    con.register(progress)

    let outcome = con.execute("SELECT * FROM progress(5, '#')").fetchall()

    check outcome[0].valueVarChar == @["#", "##", "###", "####", "#####"]

  test "Infinite iterator":
    let con = connect()

    iterator floatCounter(): float {.producer, closure.} =
      var counter = 0.0
      while true:
        yield counter
        counter += 1.0

    con.register(floatCounter)

    let outcome = con.execute("SELECT * FROM floatCounter() LIMIT 5;").fetchall()
    check outcome[0].valueDouble == @[0.0, 1.0, 2.0, 3.0, 4.0]
