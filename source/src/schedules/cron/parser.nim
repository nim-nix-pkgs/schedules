from strformat import fmt
from strutils import split, parseInt, toLowerAscii
from sequtils import map
import ./expr

template attempt(a: untyped): untyped =
  result = a
  if result != nil: return result

let MONTHS = [
  "jan",
  "feb",
  "mar",
  "apr",
  "may",
  "jun",
  "jul",
  "aug",
  "sep",
  "oct",
  "nov",
  "dec",
]

let WEEKDAYS = [
  "mon",
  "tue",
  "wed",
  "thu",
  "fri",
  "sat",
  "sun",
]

proc parseMonth(s: string): int =
  let idx = MONTHS.find(s)
  return if idx == -1:
    idx
  else:
    idx + 1

proc parseWeekday(s: string): int =
  let idx = WEEKDAYS.find(s)
  result = if idx == -1:
    -1
  else:
    idx + 1

proc parseNonSeq(s: string): Expr =
  if s == "":
    raise newException(
      ValueError,
      fmt"{s}"
    )
  newAllExpr()

proc parseAll(s: string): Expr =
  if s == "*":
    newAllExpr()
  else:
    nil

proc parseAny(s: string): Expr =
  if s == "?":
    newAnyExpr()
  else:
    nil

proc parseLastDayOfMonth(s: string): Expr =
  if s == "l" or s == "last":
    newLastExpr()
  else:
    nil

proc parseLastDayOfWeek(s: string, op: proc(s: string): int): Expr =
  let tokens = s.split("l")
  if len(tokens) != 2 or tokens[1] != "":
    return nil
  try:
    let day = op(tokens[0])
    if day == -1:
      return nil
    return newLastNExpr(day)
  except ValueError:
    return nil

proc parseNearest(s: string, validRange: Slice[int]): Expr =
  let tokens = s.split("w")
  if len(tokens) != 2 or tokens[1] != "":
    return nil
  try:
    let nearest = parseInt(tokens[0])
    return newNearestExpr(nearest)
  except ValueError:
    return nil

proc parseIndex(s: string, validRange: Slice[int], op: proc (s: string): int): Expr =
  let tokens = s.split("#")
  if len(tokens) != 2:
    return nil
  try:
    let left = op(tokens[0])
    if left == -1:
      return nil
    let right = parseInt(tokens[1])
    if right < validRange.a or right > validRange.b:
      return nil
    return newIndexExpr(left, right)
  except ValueError:
    return nil

proc parseRange(s: string, validRange: Slice[int], op: proc (s: string): int): Expr =
  let tokens = s.split("-").map(op)

  for token in tokens:
    if token == -1:
      return nil

    if token < validRange.a or token > validRange.b:
      raise newException(ValueError, fmt"range not in {validRange}: {s}")

  if len(tokens) == 1:
    return newNumExpr(tokens[0])

  if len(tokens) == 2:
    return newRangeExpr(tokens[0], tokens[1])

  raise newException(ValueError, fmt"not m or m/n: {s}")


proc parseStep(s: string, validRange: Slice[int], op: proc (s: string): Expr): Expr =
  if s == "":
    raise newException(ValueError, fmt"empty in seq: {s}")

  let tokens = s.split("/")

  if len(tokens) > 2:
    raise newException(ValueError, fmt"not m/n: {s}")

  let stepExpr = op(tokens[0])
  if len(tokens) == 1:
    return stepExpr

  let step = parseInt(tokens[1])
  if step < validRange.a or step > validRange.b:
    raise newException(ValueError, fmt"step not in {validRange}: {s}")

  return newStepExpr(stepExpr, step)

proc parseSeq(s: string, op: proc (s: string): Expr): Expr =
  if s == "":
    raise newException(ValueError, fmt"{s}")

  let tokens = s.split(",").map(op)
  return if len(tokens) == 1:
    tokens[0]
  else:
    newSeqExpr(tokens)

let SECONDS_RANGE = 0 .. 59
proc parseSeconds*(s: string): Expr =
  parseSeq(toLowerAscii(s), proc (s: string): Expr =
    parseStep(s, SECONDS_RANGE, proc (s: string): Expr =
      attempt parseAll(s)
      attempt parseRange(s, SECONDS_RANGE, parseInt)
      raise newException(ValueError, fmt"invalid second: {s}")
    )
  )

let MINUTES_RANGE = 0 .. 59
proc parseMinutes*(s: string): Expr =
  parseSeq(toLowerAscii(s), proc (s: string): Expr =
    parseStep(s, MINUTES_RANGE, proc (s: string): Expr =
      attempt parseAll(s)
      attempt parseRange(s, MINUTES_RANGE, parseInt)
      raise newException(ValueError, fmt"invalid minute: {s}")
    )
  )

let HOURS_RANGE = 0 .. 23
proc parseHours*(s: string): Expr =
  parseSeq(toLowerAscii(s), proc (s: string): Expr =
    parseStep(s, HOURS_RANGE, proc (s: string): Expr =
      attempt parseAll(s)
      attempt parseRange(s, HOURS_RANGE, parseInt)
      raise newException(ValueError, fmt"invalid hour: {s}")
    )
  )

let DAYS_RANGE = 1 .. 31
proc parseDayOfMonths*(s: string): Expr =
  parseSeq(toLowerAscii(s), proc (s: string): Expr =
    parseStep(s, DAYS_RANGE, proc (s: string): Expr =
      attempt parseAll(s)
      attempt parseAny(s)
      attempt parseLastDayOfMonth(s)
      attempt parseNearest(s, DAYS_RANGE)
      attempt parseRange(s, DAYS_RANGE, parseInt)
      raise newException(ValueError, fmt"invalid day of month: {s}")
    )
  )

let MONTHS_RANGE = 1 .. 12
proc parseMonths*(s: string): Expr =
  parseSeq(toLowerAscii(s), proc (s: string): Expr =
    parseStep(s, MONTHS_RANGE, proc (s: string): Expr =
      attempt parseAll(s)
      attempt parseRange(s, MONTHS_RANGE, parseMonth)
      attempt parseRange(s, MONTHS_RANGE, parseInt)
      raise newException(ValueError, fmt" invalid month: {s}")
    )
  )

let WEEKS_RANGE = 1 .. 7
proc parseDayOfWeeks*(s: string): Expr =
  parseSeq(toLowerAscii(s), proc (s: string): Expr =
    parseStep(s, WEEKS_RANGE, proc (s: string): Expr =
      attempt parseAll(s)
      attempt parseAny(s)
      attempt parseLastDayOfWeek(s, parseWeekday)
      attempt parseLastDayOfWeek(s, parseInt)
      attempt parseIndex(s, WEEKS_RANGE, parseWeekday)
      attempt parseIndex(s, WEEKS_RANGE, parseInt)
      attempt parseRange(s, WEEKS_RANGE, parseWeekday)
      attempt parseRange(s, WEEKS_RANGE, parseInt)
      raise newException(ValueError, fmt"invalid day of week: {s}")
    )
  )

let YEARS_RANGE = 1970 .. 9999
proc parseYears*(s: string): Expr =
  parseSeq(toLowerAscii(s), proc (s: string): Expr =
    parseStep(s, 1 .. 100, proc (s: string): Expr =
      attempt parseAll(s)
      attempt parseRange(s, YEARS_RANGE, parseInt)
      raise newException(ValueError, fmt"invalid year: {s}")
    )
  )
