when defined(features.nimdrake.tensor):
  import arraymancer/tensor
  import std/[strformat]
  import /[ffi, database, types, qresult, table_scan]

  type
    TensorSource*[T] = ref object
      tensor: Tensor[T]
      colNames: seq[string]

  template tensorDT(T: typedesc): DuckType =
    when T is bool: DuckType.Boolean
    elif T is int8: DuckType.TinyInt
    elif T is int16: DuckType.SmallInt
    elif T is int32: DuckType.Integer
    elif T is int64 or T is int: DuckType.BigInt
    elif T is uint8 or T is byte: DuckType.UTinyInt
    elif T is uint16: DuckType.USmallInt
    elif T is uint32: DuckType.UInteger
    elif T is uint64: DuckType.UBigInt
    elif T is float32: DuckType.Float
    elif T is float64: DuckType.Double
    else: {.error: "Tensor element type not supported: " & $T.}

  proc columns*[T](s: TensorSource[T]): seq[Column] =
    let ncols = s.tensor.shape[1]
    result = newSeq[Column](ncols)
    let lt = newLogicalType(tensorDT(T))
    for j in 0 ..< ncols:
      let name =
        if j < s.colNames.len: s.colNames[j]
        else: fmt"col_{j}"
      result[j] = Column(idx: j, name: name, kind: tensorDT(T), ltype: lt)

  proc cardinality*[T](s: TensorSource[T]): Cardinality =
    knownCardinality(s.tensor.shape[0], true)

  proc writeTensorColumn[T](
      dstChunk: duckdb_data_chunk, colIdx: int,
      t: Tensor[T], startRow, n: int
  ) =
    if t.strides[0] == 1:
      let dstVec = duckdb_data_chunk_get_vector(dstChunk, colIdx.idx_t)
      let dstData = duckdb_vector_get_data(dstVec)
      let base = t.offset + colIdx * t.strides[1] + startRow
      copyMem(dstData, t.data[base].unsafeAddr, n * sizeof(T))
    else:
      var w = dstChunk.vector(colIdx, tensorDT(T))
      for i in 0 ..< n:
        let srcIdx = t.offset + (startRow + i) * t.strides[0] + colIdx * t.strides[1]
        w[i] = t.data[srcIdx]

  proc newFiller*[T](s: TensorSource[T]): FillFn =
    var row = 0
    let nrows = s.tensor.shape[0]
    let ncols = s.tensor.shape[1]
    result = proc(chunk: duckdb_data_chunk): int {.closure, gcsafe.} =
      if row >= nrows: return 0
      let n = min(VECTOR_SIZE.int, nrows - row)
      for ci in 0 ..< ncols:
        writeTensorColumn(chunk, ci, s.tensor, row, n)
      row += n
      return n

  proc registerTensor*[T](con: Connection, name: string, t: Tensor[T];
      colNames: seq[string] = @[]) =
    let ncols = t.shape[1]
    var names = colNames
    if names.len == 0:
      names = newSeq[string](ncols)
      for j in 0 ..< ncols:
        names[j] = fmt"col_{j}"
    let src = TensorSource[T](tensor: t, colNames: names)
    registerImpl(con, name, src)

else:
  template registerTensor*(con: untyped, name: string, tensor: untyped,
      colNames: untyped = @[]) =
    {.error: "registerTensor requires -d:features.nimdrake.tensor and arraymancer".}
