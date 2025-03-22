# import unittest2
# import ../../src/[api, database, query, query_result, vector, aggregate_functions, types]

# suite "Aggregate functions":

#   test "Weighted Sum":
#     type
#       SumState = ref object of AggregateState
#         sum: int
#         count: int

#     proc init(state: SumState) =
#       state.sum = 0
#       state.count = 0

#     proc update(states: seq[SumState], values: seq[int], weights: seq[int], mask: ValidityMaskRegistry) =
#       for i in 0 ..< len(values):
#         states[i].sum += values[i] * weights[i]
#         inc(states[i].count)

#     proc combine(source: seq[SumState], target: seq[SumState], count: int) =
#       for i in 0 ..< count:
#         target[i].sum += source[i].sum
#         target[i].count += source[i].count

#     proc finalize() =
#       discard

#     let
#       conn = newDatabase().connect()
#       wSum = newAggregateFunction(
#         "weightedSum",
#         init,
#         update,
#         combine,
#         finalize
#       )
#     conn.register(wSum)
#     let outcome = conn.execute("SELECT weightedSum(i, 2) FROM range(100) t(i)").fetchAll()
#     check outcome[0].valueInteger[0] == 9900

#   test "Covar aggregate function":
#     type
#       CovarState = ref object of AggregateState
#         count: uint64
#         meanx: float
#         meany: float
#         coMoment: float

#     proc init(state: CovarState) =
#       state.count = 0
#       state.meanx = 0.0
#       state.meany = 0.0
#       state.coMoment = 0.0

#     proc update(state: var CovarState, x: float, y: float) =
#       inc(state.count)
#       let
#         n = state.count
#         dx = x - state.meanx
#         meanx = state.meanx + dx / float(n)
#         dy = y - state.meany
#         meany = state.meany + dy / float(n)
#         co = state.co_moment + dx * (y - meany)

#       state.meanx = meanx
#       state.meany = meany
#       state.coMoment = co

#     proc combine(source: var CovarState, target: var CovarState) =
#       if target.count == 0:
#         target = source
#       else:
#         let
#           count = target.count + source.count
#           meanx = (float(source.count) * source.meanx + float(target.count) * target.meanx) / float(count)
#           meany = (float(source.count) * source.meany + float(target.count) * target.meany) / float(count)
#           deltax = target.meanx - source.meanx
#           deltay = target.meany - source.meany

#         target.coMoment = source.coMoment + target.coMoment + deltax * deltay * float(source.count) * float(target.count) / float(count)

#         target.meanx = meanx
#         target.meany = meany
#         target.count = count

#     proc finalize(state: var CovarState): float =
#       discard
#       if state.count == 0:
#         return 0.0
#       else:
#         return state.coMoment / float(state.count)

#     let
#       conn = newDatabase().connect()
#       covarFunc = newAggregateFunction(
#         "covar",
#         init,
#         update,
#         combine,
#         finalize
#       )
#     conn.register(covarFunc)
#     let outcome = conn.execute("SELECT covar(3,3);").fetchAll()
#     echo outcome
