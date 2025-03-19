
import unittest2
import ../../src/[api, database, query, query_result, vector, aggregate_functions, types]

# suite "Aggregate functions":
#   test "Low level aggregate api functions":

#     type
#       RepeatedStringAggState = ref object of AggregateState
#         data: cstring
#         size: idx_t

#     # proc size(info: FunctionInfo): int =
#     #   return sizeof(RepeatedStringAggState)

#     proc init(state: RepeatedStringAggState) =
#       state.data = nil
#       state.size = 0

#     proc update(info: FunctionInfo, states: seq[RepeatedStringAggState]): string =
#       # let rowCount = duckdbDataChunkGetSize(input)
#       echo states.repr
#       # echo rowCount


#     proc combine(info: FunctionInfo, source: RepeatedStringAggState, target: RepeatedStringAggState, count: int) =
#       target.data = source.data
#       echo source.repr
#       echo target.repr

#     proc finalize(info: FunctionInfo, source: RepeatedStringAggState, output: duckdb_vector, count: int, offset: int) =
#      echo source.repr

#     let
#       conn = newDatabase().connect()
#       aggFunc = newAggregateFunction(
#         "myAggFunc",
#         init,
#         update,
#         combine,
#         finalize
#       )
#     conn.register(aggFunc)
#     let outcome = conn.execute("SELECT myAggFunc('foo');").fetchAll()
#     # echo aggFunc.repr
#     # conn.register(aggFunc)
