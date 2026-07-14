## Single-source-of-truth DuckDB ↔ Nim scalar conversion helpers.
##
## Every `to*` / `from*` proc is defined here so the two previous parallel
## decoder stacks (``value.nim`` and ``exp_result.nim``) can be consolidated.

import std/[times, math, strutils]
import nint128
export nint128
import uuid4
export uuid4
import /[ffi, types]
import /compatibility/decimal_compat
export decimal_compat

# ---------------------------------------------------------------------------
# Int128 ↔ duckdb_hugeint
# ---------------------------------------------------------------------------

proc toHugeInt*(val: Int128): duckdb_hugeint {.inline.} =
  duckdb_hugeint(lower: val.lo, upper: val.hi)

proc fromHugeInt*(val: duckdb_hugeint): Int128 {.inline.} =
  Int128(hi: val.upper, lo: val.lower)

# ---------------------------------------------------------------------------
# UInt128 ↔ duckdb_uhugeint
# ---------------------------------------------------------------------------

proc toUHugeInt*(val: UInt128): duckdb_uhugeint {.inline.} =
  duckdb_uhugeint(lower: val.lo, upper: val.hi)

proc fromUHugeInt*(val: duckdb_uhugeint): UInt128 {.inline.} =
  UInt128(hi: val.upper, lo: val.lower)

# ---------------------------------------------------------------------------
# Timestamp ↔ duckdb_timestamp
# ---------------------------------------------------------------------------

proc fromTimestamp*(val: int64): Timestamp {.inline.} =
  let (seconds, microseconds) = divMod(val, 1_000_000)
  let dt = fromUnix(seconds).inZone(utc()) + initDuration(microseconds = microseconds)
  Timestamp(dt)

proc fromTimestamp*(val: duckdb_timestamp): Timestamp {.inline.} =
  fromTimestamp(val.micros)

proc toTimestamp*(val: Timestamp): duckdb_timestamp {.inline.} =
  let ms = convert(Seconds, Microseconds, val.toTime.toUnix)
  duckdb_timestamp(micros: ms)

# ---------------------------------------------------------------------------
# DateTime / Date ↔ duckdb_date
# ---------------------------------------------------------------------------

proc toDatetime*(val: DateTime): duckdb_date {.inline.} =
  let
    timeInfo = val.inZone(utc())
    unixSeconds = timeInfo.toTime.toUnix
    days = convert(Seconds, Days, unixSeconds)
  duckdb_date(days: days.int32)

proc fromDatetime*(val: int32): DateTime {.inline.} =
  let seconds = convert(Days, Seconds, val)
  fromUnix(seconds).inZone(utc())

proc fromDatetime*(val: duckdb_date): DateTime {.inline.} =
  fromDatetime(val.days)

# ---------------------------------------------------------------------------
# Time ↔ duckdb_time
# ---------------------------------------------------------------------------

proc toTime*(val: Time): duckdb_time {.inline.} =
  let micros = convert(Seconds, Microseconds, val.toUnix)
  duckdb_time(micros: micros)

proc fromTime*(val: int64): Time {.inline.} =
  let seconds = val div 1_000_000
  let micros = val mod 1_000_000
  initTime(seconds, micros.int * 1_000)

proc fromTime*(val: duckdb_time): Time {.inline.} =
  fromTime(val.micros)

# ---------------------------------------------------------------------------
# TimeInterval ↔ duckdb_interval
# ---------------------------------------------------------------------------

proc toInterval*(val: TimeInterval): duckdb_interval {.inline.} =
  let micros =
    convert(Hours, Microseconds, val.hours) +
    convert(Minutes, Microseconds, val.minutes) +
    convert(Seconds, Microseconds, val.seconds) + val.microseconds
  duckdb_interval(
    months: val.months.int32 + int32(val.years * 12),
    days: val.days.int32,
    micros: micros,
  )

proc fromInterval*(val: duckdb_interval): TimeInterval {.inline.} =
  let
    years = val.months div 12
    months = val.months mod 12
    hours = val.micros div 3_600_000_000
    mins = (val.micros mod 3_600_000_000) div 60_000_000
    secs = (val.micros mod 60_000_000) div 1_000_000
    micros = val.micros mod 1_000_000
  initTimeInterval(
    years = years,
    months = months,
    days = val.days,
    hours = hours,
    minutes = mins,
    seconds = secs,
    microseconds = micros,
  )

# ---------------------------------------------------------------------------
# DuckType-specific decoders (from exp_result.nim — the correct versions)
# ---------------------------------------------------------------------------

proc fromDuckDate*(days: int32): DateTime {.inline.} =
  fromUnix(0).inZone(utc()) + initDuration(days = days.int)

proc fromDuckTime*(micros: int64): Time {.inline.} =
  let seconds = micros div 1_000_000
  initTime(seconds, (micros mod 1_000_000).int * 1_000)

proc fromDuckTimestampS*(raw: int64): DateTime {.inline.} =
  fromUnix(raw).inZone(utc())

proc fromDuckTimestampMs*(raw: int64): DateTime {.inline.} =
  let (s, ms) = divmod(raw, 1000)
  fromUnix(s).inZone(utc()) + initDuration(milliseconds = ms)

proc fromDuckTimestampNs*(raw: int64): DateTime {.inline.} =
  let
    (s, ns) = divMod(raw, 1_000_000_000)
    us = ns div 1000
    nsRem = ns mod 1000
  fromUnix(s).inZone(utc()) + initDuration(microseconds = us, nanoseconds = nsRem)

proc fromDuckTimeTz*(raw: int64): ZonedTime {.inline.} =
  let tmz = duckdb_from_time_tz(cast[duckdb_time_tz](raw))
  let seconds = tmz.time.hour.int * 3600 + tmz.time.min.int * 60 + tmz.time.sec
  let nanoseconds = tmz.time.micros * 1000
  ZonedTime(time: initTime(seconds, nanoseconds), utcOffset: tmz.offset, isDst: false)

proc fromDuckTimestampTz*(raw: int64): ZonedTime {.inline.} =
  let microsInDay = floorMod(raw, 86_400_000_000'i64)
  let (s, us) = divMod(microsInDay, 1_000_000)
  ZonedTime(time: initTime(s, us * 1_000), utcOffset: 0, isDst: false)

proc fromDuckUuid*(raw: duckdb_hugeint): Uuid {.inline.} =
  var bytes: array[16, uint8]
  let hi = cast[uint64](raw.upper)
  let lo = raw.lower
  for b in 0 .. 7:
    bytes[b] = uint8((hi shr ((7 - b) * 8)) and 0xFF)
    bytes[8 + b] = uint8((lo shr ((7 - b) * 8)) and 0xFF)
  initUuid(bytes)

proc fromDuckEnum*(data: pointer, i: int, kt: DuckType): uint {.inline.} =
  case kt
  of DuckType.UTinyInt:
    cast[ptr UncheckedArray[uint8]](data)[i].uint
  of DuckType.USmallInt:
    cast[ptr UncheckedArray[uint16]](data)[i].uint
  of DuckType.UInteger:
    cast[ptr UncheckedArray[uint32]](data)[i].uint
  else:
    raise newException(ValueError, "enum kind not supported: " & $kt)

proc fromDuckDecimal*(scale, width: int8, data: pointer, i: int): DecimalType {.inline.} =
  var val: Int128
  if width <= 4:
    val = i128(cast[ptr UncheckedArray[int16]](data)[i])
  elif width <= 9:
    val = i128(cast[ptr UncheckedArray[int32]](data)[i])
  elif width <= 18:
    val = i128(cast[ptr UncheckedArray[int64]](data)[i])
  else:
    let raw = cast[ptr UncheckedArray[duckdb_hugeint]](data)[i]
    val = fromHugeInt(raw)
  var fracScale = i128(1)
  for _ in 0 ..< scale:
    fracScale = fracScale * i128(10)
  let
    whole = val div fracScale
    fractional = val mod fracScale
    absFrac = cast[UInt128](if fractional < zero(Int128): -fractional else: fractional)
    fracStr = $absFrac
    paddedFrac = repeat('0', scale - fracStr.len) & fracStr
  newDecimal($whole & "." & paddedFrac)

# ---------------------------------------------------------------------------
# Inverse encoders — write path for Vector[kt][] =
# ---------------------------------------------------------------------------

proc toDuckTimestampS*(val: DateTime): int64 {.inline.} =
  let t = val.inZone(utc()).toTime
  t.toUnix

proc toDuckTimestampMs*(val: DateTime): int64 {.inline.} =
  let t = val.inZone(utc()).toTime
  t.toUnix * 1000 + (t.nanosecond div 1_000_000)

proc toDuckTimestampNs*(val: DateTime): int64 {.inline.} =
  let t = val.inZone(utc()).toTime
  t.toUnix * 1_000_000_000 + t.nanosecond

proc toDuckTimeTz*(val: ZonedTime): int64 {.inline.} =
  let micros = val.time.toUnix * 1_000_000 + (val.time.nanosecond div 1_000)
  let packed = duckdb_create_time_tz(cast[int64](micros), int32(val.utcOffset))
  cast[int64](packed.bits)

proc toDuckTimestampTz*(val: ZonedTime): int64 {.inline.} =
  val.time.toUnix * 1_000_000 + (val.time.nanosecond div 1_000)

proc toDuckUuid*(val: Uuid): duckdb_hugeint {.inline.} =
  var hi: uint64 = 0
  var lo: uint64 = 0
  for b in 0 .. 7:
    hi = hi or (uint64(val.bytes[b]) shl ((7 - b) * 8))
    lo = lo or (uint64(val.bytes[8 + b]) shl ((7 - b) * 8))
  duckdb_hugeint(upper: cast[int64](hi), lower: lo)

proc toDuckDecimal*(val: DecimalType, width: int8, scale: int8): Int128 {.inline.} =
  let s = $val
  if s == "" or s == "NaN" or s == "Inf" or s == "-Inf":
    return zero(Int128)
  var unscaled = ""
  var seenDot = false
  var fracDst = 0
  var neg = false
  for i in 0 ..< s.len:
    case s[i]
    of '-':
      if i == 0: neg = true
      else: discard
    of '.':
      seenDot = true
    of '0' .. '9':
      unscaled.add s[i]
      if seenDot:
        inc fracDst
    else: discard
  while fracDst < scale:
    unscaled.add '0'
    inc fracDst
  if unscaled.len == 0:
    return zero(Int128)
  var r = zero(Int128)
  for c in unscaled:
    r = r * i128(10) + i128(ord(c) - ord('0'))
  if neg:
    r = -r
  result = r
