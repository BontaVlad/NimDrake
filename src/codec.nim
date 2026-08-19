## Timestamp, interval, integer, and decimal conversions between Nim values
## and the raw DuckDB FFI types from `ffi`.
##
## The naming convention is the whole story:
##
## - `toX` converts a **Nim** value → the raw **DuckDB** type that the FFI
##   functions in `ffi` accept (`Time` → `duckdb_time`, `Timestamp` →
##   `duckdb_timestamp`, `Uuid` → `duckdb_hugeint`, ...).
## - `fromX` converts the raw **DuckDB** type → a **Nim** value.
## - The `fromDuck*` / `toDuck*` family are the precision-specific
##   timestamp/time codecs: `fromDuckTimestampS/Ms/Ns` decode COUNT-based
##   timestamps at seconds/milliseconds/nanoseconds precision, and the `Tz`
##   variants carry an explicit UTC offset (a `ZonedTime`).
##
## Every conversion is component-wise and allocation-free where possible;
## high-level decimal conversion remains available, while raw decimal display
## uses the appendable formatter below.
##
## .. note:: These procs are the low level the `qresult` views build on. You
##   normally touch them only when writing your own encoders/decoders for
##   exotic columns.
##

import std/[times, math]
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
  ## Reinterprets a signed 128-bit `Int128` as the DuckDB `duckdb_hugeint`.
  duckdb_hugeint(lower: val.lo, upper: val.hi)

proc fromHugeInt*(val: duckdb_hugeint): Int128 {.inline.} =
  ## Reinterprets a DuckDB `duckdb_hugeint` as a signed `Int128`.
  Int128(hi: val.upper, lo: val.lower)

# ---------------------------------------------------------------------------
# UInt128 ↔ duckdb_uhugeint
# ---------------------------------------------------------------------------

proc toUHugeInt*(val: UInt128): duckdb_uhugeint {.inline.} =
  ## Reinterprets an unsigned `UInt128` as the DuckDB `duckdb_uhugeint`.
  duckdb_uhugeint(lower: val.lo, upper: val.hi)

proc fromUHugeInt*(val: duckdb_uhugeint): UInt128 {.inline.} =
  ## Reinterprets a DuckDB `duckdb_uhugeint` as an unsigned `UInt128`.
  UInt128(hi: val.upper, lo: val.lower)

# ---------------------------------------------------------------------------
# Timestamp ↔ duckdb_timestamp
# ---------------------------------------------------------------------------

proc fromTimestamp*(val: int64): Timestamp {.inline.} =
  ## Decodes `val` microseconds since the Unix epoch into a `Timestamp`.
  let (seconds, microseconds) = divMod(val, 1_000_000)
  let dt = fromUnix(seconds).inZone(utc()) + initDuration(microseconds = microseconds)
  Timestamp(dt)

proc fromTimestamp*(val: duckdb_timestamp): Timestamp {.inline.} =
  ## Decodes a DuckDB `duckdb_timestamp` (microseconds since epoch) into a `Timestamp`.
  fromTimestamp(val.micros)

proc toTimestamp*(val: Timestamp): duckdb_timestamp {.inline.} =
  ## Encodes a `Timestamp` as `duckdb_timestamp` microseconds since the epoch.
  let t = val.toTime
  duckdb_timestamp(micros: t.toUnix * 1_000_000 + (t.nanosecond div 1_000))

# ---------------------------------------------------------------------------
# DateTime / Date ↔ duckdb_date
# ---------------------------------------------------------------------------

proc toDatetime*(val: DateTime): duckdb_date {.inline.} =
  ## Encodes a `DateTime` as a DuckDB `duckdb_date` (whole days since epoch).
  let
    timeInfo = val.inZone(utc())
    days = floorDiv(timeInfo.toTime.toUnix, 86_400)
  duckdb_date(days: days.int32)

proc fromDatetime*(val: int32): DateTime {.inline.} =
  ## Decodes `val` days since the Unix epoch into a `DateTime` at midnight UTC.
  let seconds = convert(Days, Seconds, val)
  fromUnix(seconds).inZone(utc())

proc fromDatetime*(val: duckdb_date): DateTime {.inline.} =
  ## Decodes a DuckDB `duckdb_date` into a `DateTime` at midnight UTC.
  fromDatetime(val.days)

# ---------------------------------------------------------------------------
# Time ↔ duckdb_time
# ---------------------------------------------------------------------------

proc toTime*(val: Time): duckdb_time {.inline.} =
  ## Encodes a `Time` as DuckDB `duckdb_time` micros since midnight.
  let micros = convert(Seconds, Microseconds, val.toUnix)
  duckdb_time(micros: micros)

proc fromTime*(val: int64): Time {.inline.} =
  ## Decodes `val` microseconds since midnight into a `Time`.
  let seconds = val div 1_000_000
  let micros = val mod 1_000_000
  initTime(seconds, micros.int * 1_000)

proc fromTime*(val: duckdb_time): Time {.inline.} =
  ## Decodes a DuckDB `duckdb_time` into a `Time`.
  fromTime(val.micros)

# ---------------------------------------------------------------------------
# TimeInterval ↔ duckdb_interval
# ---------------------------------------------------------------------------

proc toInterval*(val: TimeInterval): duckdb_interval {.inline.} =
  ## Encodes a `TimeInterval` as DuckDB's `duckdb_interval`
  ## (months/days/micros normalized like DuckDB's `INTERVAL`).
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
  ## Decodes a DuckDB `duckdb_interval` into a `TimeInterval`, re-splitting
  ## months into years+months.
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
  ## Decodes a COUNT-based DuckDB `DATE` (days since epoch) into a `DateTime`.
  fromUnix(0).inZone(utc()) + initDuration(days = days.int)

proc fromDuckTime*(micros: int64): Time {.inline.} =
  ## Decodes a COUNT-based DuckDB `TIME` (micros since midnight) into a `Time`.
  let seconds = micros div 1_000_000
  initTime(seconds, (micros mod 1_000_000).int * 1_000)

proc fromDuckTimestampS*(raw: int64): DateTime {.inline.} =
  ## Decodes a COUNT-based DuckDB `TIMESTAMP_S` (seconds since epoch).
  fromUnix(raw).inZone(utc())

proc fromDuckTimestampMs*(raw: int64): DateTime {.inline.} =
  ## Decodes a COUNT-based DuckDB `TIMESTAMP_MS` (milliseconds since epoch).
  let (s, ms) = divmod(raw, 1000)
  fromUnix(s).inZone(utc()) + initDuration(milliseconds = ms)

proc fromDuckTimestampNs*(raw: int64): DateTime {.inline.} =
  ## Decodes a COUNT-based DuckDB `TIMESTAMP_NS` (nanoseconds since epoch).
  let
    (s, ns) = divMod(raw, 1_000_000_000)
    us = ns div 1000
    nsRem = ns mod 1000
  fromUnix(s).inZone(utc()) + initDuration(microseconds = us, nanoseconds = nsRem)

proc fromDuckTimeTz*(raw: int64): ZonedTime {.inline.} =
  ## Decodes a DuckDB `TIME WITH TIME ZONE` into a `ZonedTime`, applying the
  ## embedded offset to recover the wall-clock time.
  let tmz = duckdb_from_time_tz(cast[duckdb_time_tz](raw))
  let seconds = tmz.time.hour.int * 3600 + tmz.time.min.int * 60 + tmz.time.sec
  let nanoseconds = tmz.time.micros * 1000
  ZonedTime(time: initTime(seconds, nanoseconds), utcOffset: tmz.offset, isDst: false)

proc fromDuckTimestampTz*(raw: int64): ZonedTime {.inline.} =
  ## Decodes a DuckDB `TIMESTAMP WITH TIME ZONE`: microseconds since epoch in
  ## UTC. The zone offset is not part of the stored value; `utcOffset` is
  ## always 0 on read.
  let (s, us) = divMod(raw, 1_000_000)
  ZonedTime(time: initTime(s, us * 1_000), utcOffset: 0, isDst: false)

proc fromDuckUuid*(raw: duckdb_hugeint): Uuid {.inline.} =
  ## Decodes a DuckDB `UUID` (stored as a big-endian 128-bit int). DuckDB
  ## flips bit 63 of the upper half so `ORDER BY uuid` matches
  ## `ORDER BY uuid::varchar`; this undoes that flip.
  var bytes: array[16, uint8]
  let hi = cast[uint64](raw.upper) xor 0x8000_0000_0000_0000'u64
  let lo = raw.lower
  for b in 0 .. 7:
    bytes[b] = uint8((hi shr ((7 - b) * 8)) and 0xFF)
    bytes[8 + b] = uint8((lo shr ((7 - b) * 8)) and 0xFF)
  initUuid(bytes)

proc fromDuckEnum*(data: pointer, i: int, kt: DuckType): uint {.inline.} =
  ## Reads the `i`-th enum value from a raw column buffer `data`; the storage
  ## width follows the backing integer type of `kt`. Raises `ValueError` for
  ## non-enum kinds.
  case kt
  of DuckType.UTinyInt:
    cast[ptr UncheckedArray[uint8]](data)[i].uint
  of DuckType.USmallInt:
    cast[ptr UncheckedArray[uint16]](data)[i].uint
  of DuckType.UInteger:
    cast[ptr UncheckedArray[uint32]](data)[i].uint
  else:
    raise newException(ValueError, "enum kind not supported: " & $kt)

proc appendDuckDecimal*(dest: var string, raw: Int128, scale: int8)
proc formatDuckDecimal*(raw: Int128, scale: int8): string

proc fromDuckDecimal*(scale, width: int8, data: pointer, i: int): DecimalType {.inline.} =
  ## Decodes the `i`-th `DECIMAL(scale, width)` value from a raw column
  ## buffer `data`. The storage width selects the in-buffer integer size:
  ## ≤4 int16, ≤9 int32, ≤18 int64, else a duckdb hugeint.
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
  newDecimal(formatDuckDecimal(val, scale))

proc appendDuckDecimal*(dest: var string, raw: Int128, scale: int8) =
  ## Appends an unscaled DuckDB DECIMAL value without constructing DecimalType.
  ## The sign is applied to the complete magnitude, which preserves values
  ## between -1 and 0 that a whole/fraction split can otherwise misrender.
  doAssert scale >= 0, "decimal scale must not be negative"
  var factor = i128(1)
  for _ in 0 ..< scale:
    factor = factor * i128(10)
  let negative = raw < zero(Int128)
  let magnitude = if negative: -raw else: raw
  let whole = magnitude div factor
  let fractional = magnitude mod factor
  if negative:
    dest.add '-'
  dest.add $whole
  if scale > 0:
    dest.add '.'
    var divisor = factor div i128(10)
    var remainder = fractional
    for _ in 0 ..< scale:
      let digit = remainder div divisor
      dest.add char(ord('0') + int(digit.lo))
      remainder = remainder mod divisor
      divisor = divisor div i128(10)

proc formatDuckDecimal*(raw: Int128, scale: int8): string =
  ## Formats an unscaled DuckDB DECIMAL value without constructing DecimalType.
  result = newStringOfCap(32)
  appendDuckDecimal(result, raw, scale)

# ---------------------------------------------------------------------------
# Inverse encoders — write path for Vector[kt][] =
# ---------------------------------------------------------------------------

proc toDuckTimestampS*(val: DateTime): int64 {.inline.} =
  ## Encodes `val` as a COUNT-based DuckDB `TIMESTAMP_S` (seconds since epoch).
  let t = val.inZone(utc()).toTime
  t.toUnix

proc toDuckTimestampMs*(val: DateTime): int64 {.inline.} =
  ## Encodes `val` as a COUNT-based DuckDB `TIMESTAMP_MS` (milliseconds since epoch).
  let t = val.inZone(utc()).toTime
  t.toUnix * 1000 + (t.nanosecond div 1_000_000)

proc toDuckTimestampNs*(val: DateTime): int64 {.inline.} =
  ## Encodes `val` as a COUNT-based DuckDB `TIMESTAMP_NS` (nanoseconds since epoch).
  let t = val.inZone(utc()).toTime
  t.toUnix * 1_000_000_000 + t.nanosecond

proc toDuckTimeTz*(val: ZonedTime): int64 {.inline.} =
  ## Encodes a `ZonedTime` as a DuckDB `TIME WITH TIME ZONE`, packing the
  ## micros and offset into DuckDB's bit layout.
  let micros = val.time.toUnix * 1_000_000 + (val.time.nanosecond div 1_000)
  let packed = duckdb_create_time_tz(cast[int64](micros), int32(val.utcOffset))
  cast[int64](packed.bits)

proc toDuckTimestampTz*(val: ZonedTime): int64 {.inline.} =
  ## Encodes `val` as a COUNT-based DuckDB `TIMESTAMP WITH TIME ZONE`: the
  ## instant `val.time` as UTC microseconds since epoch. `utcOffset` is
  ## display metadata and is not applied; convert a wall-clock time to an
  ## instant first if needed.
  val.time.toUnix * 1_000_000 + (val.time.nanosecond div 1_000)

proc toDuckUuid*(val: Uuid): duckdb_hugeint {.inline.} =
  ## Encodes a `Uuid` as the DuckDB `UUID` int (big-endian with bit 63 of the
  ## upper half flipped so DuckDB's order matches `uuid::varchar`).
  var hi: uint64 = 0
  var lo: uint64 = 0
  for b in 0 .. 7:
    hi = hi or (uint64(val.bytes[b]) shl ((7 - b) * 8))
    lo = lo or (uint64(val.bytes[8 + b]) shl ((7 - b) * 8))
  duckdb_hugeint(
    upper: cast[int64](hi xor 0x8000_0000_0000_0000'u64),
    lower: lo,
  )

proc toDuckDecimal*(val: DecimalType, width: int8, scale: int8): Int128 {.inline.} =
  ## Encodes a `DecimalType` as the unscaled `Int128` DuckDB stores for a
  ## `DECIMAL(width, scale)`. Non-finite values (`NaN`, `Inf`) encode as 0.
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
