## Compile-time SQL query DSL for NimDrake.
##
## A trimmed fork of ormin's `query:` macro (MIT, https://github.com/jh54/ormin).
## The compile-time AST walker + SQL string builder is preserved nearly
## verbatim; the schema-validation machinery (compile-time `tableNames`/
## `attributes` consts, `importModel`, `Function` registry, `importSql`) and
## the runtime hook layer (`DbValue[T]`, `fromQueryHook`, `toQueryHook`,
## `bindResult`, `bindToJson`, the `PStmt` cursor, `orminLastError`) are gone.
##
## Identifiers are emitted verbatim with auto-aliases (`t1`, `t2`, …). Typos
## surface as runtime `OperationError` from DuckDB. Bind parameters are not
## type-checked at compile time — NimDrake's existing `bindVal` template
## overloads (in `nimdrake/query`) resolve the right `duckdb_bind_*` call via
## Nim's overload resolution. The same `bindVal` surface covers `Option[T]`
## (binds NULL on `none`), `JsonNode`, `DecimalType`, and `Uuid`.
##
## Public surface
## ==============
## - `query(con): …`           → `QResult[Materialized]`
##     Always returns a materialized result. For `select`/`insert…returning`
##     use `res.chunks`; for `insert`/`update`/`delete` use `res.rowsChanged`.
## - `transaction`, `transient` — re-exported from `nimdrake/transaction`.
##   For "swallow unique-violation" patterns, use a plain `try`/`except`
##   around a `query` call.
##
## Clause support
## ===============
## select / distinct / insert / update / delete / replace /
## where / innerjoin / leftjoin / rightjoin / fulljoin / crossjoin … on /
## groupby / having / orderby / limit / offset /
## returning / onconflict(cols) / doupdate(col = expr, …) / donothing() /
## with cteName(…) / union / intersect / except /
## `?expr` bind place-holder / `!!"raw sql"` splice / `as` alias /
## `[not] in` / `[not] between … and …` / like / ilike /
## and / or / not / ==/!=/</<=/>/>= / asc / desc / arithmetic / `&` (||).
##
## Complex-query notes
## ===================
## - The `select` table is alias `t1`; each `join` table is `t2`, `t3`, ….
##   Columns of later tables must be qualified (`t2.n_name`) in the select,
##   where, and orderby clauses; a bare identifier is emitted against `t1`.
##   For grouped queries keep join projections empty (`join orders() on …`)
##   and put aggregates in the select, qualified by the owning alias.
## - Window calls wrap the aggregate: `over(sum(x), partitionby(y) orderby(z))`.
## - CTE bodies and set-op branches may chain clauses inline
##   (`with cte(select x where …)`, `union(select … where …, …)`).
## - Correlated subqueries reference the outer row via its alias (`t1.`).
## - SQL's `*` is spelled `_` (e.g. `count(_)`); `except` is a Nim keyword,
##   so the set op is spelled `` `except`(…) ``.
##
## Dropped (compared to ormin)
## ===========================
## - Compile-time column-name validation against a static schema.
## - Auto-join via foreign-key walking (write the `on` clause explicitly).
## - `query(T)` typed-object projection and `produce json` (use
##   `res.chunks` + `bindAs` directly, or `Table.initTable` from
##   `nimdrake/table` for cross-chunk access).
## - `createProc` / `createIter` (write the Nim proc yourself).
## - `importSql` (NimDrake's `registerScalar`/`registerAggregate`/
##   `registerTableFunction` cover user-defined functions).
## - `protocol` (server/client JSON RPC).
## - `tryQuery` (use a plain `try`/`except OperationError` instead).

import std/[macros, strutils]
import nimdrake

export transaction, transient

# ---------------------------------------------------------------------------
# Compile-time query builder
# ---------------------------------------------------------------------------

type
  Env = seq[string]            ## active table aliases, e.g. `@["t1"]`
  Params = seq[NimNode]        ## Nim expressions to bind in placeholder order
  QueryKind = enum
    qkNone, qkSelect, qkJoin, qkInsert, qkReplace,
    qkUpdate, qkDelete, qkInsertReturning
  QueryBuilder = ref object
    head, fromm, join, values, where: string
    groupby, having, orderby, limit, offset: string
    returning, onConflict, onConflictWhere: string
    env: Env
    ctes: seq[tuple[name, sql: string]]
    cteBase: int
    kind: QueryKind
    colAliases: seq[string]
    params: Params
    coln, qmark, aliasGen: int
    onConflictTargetSet, onConflictActionSet: bool
    onConflictIsDoUpdate, onConflictWhereSet: bool
    singleReturningCol: bool

const
  equals = "="
  nequals = "<>"

proc newQueryBuilder(): QueryBuilder {.compileTime.} =
  QueryBuilder(
    head: "", fromm: "", join: "", values: "", where: "",
    groupby: "", having: "", orderby: "", limit: "", offset: "",
    returning: "", onConflict: "", onConflictWhere: "",
    env: @[], ctes: @[], cteBase: 0, kind: qkNone, params: @[],
    colAliases: @[], coln: 0, qmark: 0, aliasGen: 1,
    onConflictTargetSet: false, onConflictActionSet: false,
    onConflictIsDoUpdate: false, onConflictWhereSet: false,
    singleReturningCol: false)

proc getAlias(q: QueryBuilder): string {.compileTime.} =
  result = "t" & $q.aliasGen
  inc q.aliasGen

proc placeholder(q: QueryBuilder): string {.compileTime.} =
  inc q.qmark
  result = "$" & $q.qmark

proc escIdent(dest: var string; src: string) {.inline.} =
  ## Emits an identifier verbatim (unquoted). DuckDB accepts unquoted
  ## identifiers; tokens that need quoting are caught by DuckDB at parse time.
  dest.add src

proc nodeName(n: NimNode): string {.compileTime.} =
  case n.kind
  of nnkIdent, nnkSym:
    result = n.strVal
  of nnkAccQuoted:
    result = if n.len == 1: nodeName(n[0]) else: ""
  else:
    result = ""

proc isQueryClause(name: string): bool {.compileTime.} =
  case name.toLowerAscii()
  of "with", "select", "distinct", "insert", "update", "replace", "delete",
      "where", "join", "innerjoin", "outerjoin", "leftjoin", "leftouterjoin",
      "rightjoin", "rightouterjoin", "fulljoin", "fullouterjoin", "crossjoin",
      "groupby", "orderby", "having", "limit", "offset", "returning",
      "onconflict", "donothing", "doupdate":
    result = true
  else:
    result = false

proc isSetOpName(name: string): bool {.compileTime.} =
  case name.toLowerAscii()
  of "union", "intersect", "except":
    result = true
  else:
    result = false

proc isSetOpCall(n: NimNode): bool {.compileTime.} =
  n.kind == nnkCall and isSetOpName(nodeName(n[0]))

proc isNullLiteral(n: NimNode): bool {.compileTime.} =
  case n.kind
  of nnkNilLit:
    result = true
  of nnkIdent, nnkSym:
    result = cmpIgnoreCase(n.strVal, "null") == 0
  else:
    result = false

proc peelTrailingCommand(n: NimNode): tuple[core, tail: NimNode] {.compileTime.} =
  if n.kind == nnkCommand and n.len == 2 and n[1].kind == nnkCommand and
      nodeName(n[1][0]) == "on":
    return (copyNimTree(n), newEmptyNode())
  if n.kind == nnkCommand and n.len == 2 and n[1].kind == nnkCommand and
      nodeName(n[1][0]).toLowerAscii() in ["like", "ilike"]:
    return (copyNimTree(n), newEmptyNode())
  if n.kind == nnkCommand and n.len == 2 and n[1].kind == nnkCommand and
      not isQueryClause(nodeName(n[0])) and not isSetOpName(nodeName(n[0])):
    return (copyNimTree(n[0]), copyNimTree(n[1]))
  if n.kind == nnkCommand and n.len == 2 and n[1].kind == nnkCall and
      not isQueryClause(nodeName(n[0])) and not isSetOpName(nodeName(n[0])) and
      isQueryClause(nodeName(n[1][0])):
    return (copyNimTree(n[0]), copyNimTree(n[1]))
  if (n.kind == nnkCommand and
      (isQueryClause(nodeName(n[0])) or isSetOpName(nodeName(n[0])))) or
      isSetOpCall(n):
    return (copyNimTree(n), newEmptyNode())
  if n.len > 0:
    let idx = n.len - 1
    let peeled = peelTrailingCommand(n[idx])
    if peeled.tail.kind != nnkEmpty:
      result.core = copyNimTree(n)
      result.core[idx] = peeled.core
      result.tail = peeled.tail
      return result
  result = (copyNimTree(n), newEmptyNode())

proc flattenQueryCommands(n: NimNode; parts: var seq[NimNode]) {.compileTime.} =
  case n.kind
  of nnkStmtList:
    for it in n:
      flattenQueryCommands(it, parts)
  of nnkCall:
    let name = nodeName(n[0])
    if isQueryClause(name):
      var cmd = newNimNode(nnkCommand)
      for it in n:
        cmd.add copyNimTree(it)
      parts.add cmd
    else:
      parts.add copyNimTree(n)
  of nnkCommand:
    var cmd = copyNimTree(n)
    if cmd.len >= 2:
      let idx = cmd.len - 1
      let peeled = peelTrailingCommand(cmd[idx])
      cmd[idx] = peeled.core
      parts.add cmd
      if peeled.tail.kind != nnkEmpty:
        flattenQueryCommands(peeled.tail, parts)
    else:
      parts.add cmd
  else:
    parts.add copyNimTree(n)

proc queryh(n: NimNode; q: QueryBuilder) {.compileTime.}
proc queryAsString(q: QueryBuilder, n: NimNode): string {.compileTime.}
proc applyQueryNode(n: NimNode; q: QueryBuilder) {.compileTime.}
proc renderInlineQuery(n: NimNode; params: var Params;
                       qb: QueryBuilder): string {.compileTime.}
proc cond(n: NimNode; q: var string; params: var Params; qb: QueryBuilder) {.compileTime.}

proc renderWindowClause(n: NimNode; q: var string; params: var Params;
                        qb: QueryBuilder) {.compileTime.} =
  let op = nodeName(n[0]).toLowerAscii()
  case op
  of "partitionby":
    q.add "partition by "
    for i in 1..<n.len:
      cond(n[i], q, params, qb)
      if i < n.len - 1: q.add ", "
  of "orderby":
    q.add "order by "
    for i in 1..<n.len:
      cond(n[i], q, params, qb)
      if i < n.len - 1: q.add ", "
  else:
    macros.error "unsupported window clause: " & op, n

proc cond(n: NimNode; q: var string; params: var Params; qb: QueryBuilder) {.compileTime.} =
  ## Renders a condition expression to SQL text appended onto `q`.
  ## No type information is tracked — we just emit text. Column identifiers
  ## are prefixed with the current env's last alias unless they appear in
  ## `colAliases`; DotExprs are emitted verbatim.
  case n.kind
  of nnkIdent:
    let name = $n
    if name == "_":
      q.add "*"
    elif cmpIgnoreCase(name, "null") == 0:
      q.add "NULL"
    else:
      block checkAliases:
        for a in qb.colAliases:
          if cmpIgnoreCase(a, name) == 0:
            escIdent(q, name)
            return
      # Prefix with the active table alias only for select/join (where
      # aliases appear in `from t1`/`join t2`). For update/delete the
      # UPDATEd table is un-aliased in SQL, so bare `name` is the right
      # reference. For insert, values don't reference column names by id.
      if qb.kind in {qkSelect, qkJoin} and qb.env.len > 0:
        q.add qb.env[^1]
        q.add '.'
      escIdent(q, name)
  of nnkDotExpr:
    escIdent(q, $n[0])
    q.add '.'
    escIdent(q, $n[1])
  of nnkPar, nnkStmtListExpr:
    if n.len == 1:
      q.add "("
      cond(n[0], q, params, qb)
      q.add ")"
    else:
      macros.error "tuple construction not supported here", n
  of nnkCurly:
    q.add "("
    cond(n[0], q, params, qb)
    for i in 1..<n.len:
      q.add ", "
      cond(n[i], q, params, qb)
    q.add ")"
  of nnkNilLit:
    q.add "NULL"
  of nnkDistinctTy:
    q.add "distinct "
    cond(n[0], q, params, qb)
  of nnkStrLit, nnkRStrLit, nnkTripleStrLit:
    q.add("'" & n.strVal.replace("'", "''") & "'")
  of nnkIntLit..nnkInt64Lit:
    q.add $n.intVal
  of nnkFloatLit:
    q.add $n.floatVal
  of nnkInfix:
    let op = $n[0]
    case op
    of "and", "or":
      cond(n[1], q, params, qb)
      q.add ' '
      q.add op
      q.add ' '
      cond(n[2], q, params, qb)
    of "<=", "<", ">=", ">", "==", "!=", "=~":
      if isNullLiteral(n[1]) or isNullLiteral(n[2]):
        if op != "==" and op != "!=":
          macros.error "NULL comparisons only support == and !=", n
        if isNullLiteral(n[1]) and isNullLiteral(n[2]):
          macros.error "NULL cannot be compared against NULL", n
        let target = if isNullLiteral(n[1]): n[2] else: n[1]
        cond(target, q, params, qb)
        if op == "==": q.add " is NULL" else: q.add " is not NULL"
      else:
        let env = qb.env
        if env.len == 2:
          qb.env = @[env[0]]
        cond(n[1], q, params, qb)
        q.add ' '
        if op == "==": q.add equals
        elif op == "!=": q.add nequals
        elif op == "=~": q.add "like"
        else: q.add op
        q.add ' '
        if env.len == 2:
          qb.env = @[env[1]]
        cond(n[2], q, params, qb)
        qb.env = env
    of "in", "notin":
      cond(n[1], q, params, qb)
      if n[2].kind == nnkInfix and $n[2][0] == "..":
        if op == "in": q.add " between " else: q.add " not between "
        let r = n[2]
        cond(r[1], q, params, qb)
        q.add " and "
        cond(r[2], q, params, qb)
      else:
        if op == "in": q.add " in " else: q.add " not in "
        cond(n[2], q, params, qb)
    of "as":
      cond(n[1], q, params, qb)
      q.add " as "
      expectKind n[2], nnkIdent
      let alias = $n[2]
      escIdent(q, alias)
      qb.colAliases.add(alias)
    of "&":
      cond(n[1], q, params, qb)
      q.add " || "
      cond(n[2], q, params, qb)
    else:
      cond(n[1], q, params, qb)
      q.add ' '
      q.add op
      q.add ' '
      cond(n[2], q, params, qb)
  of nnkPrefix:
    let op = $n[0]
    case op
    of "?":
      q.add placeholder(qb)
      params.add(n[1])
    of "%":
      # Same as `?` — bind the expression verbatim. The historical
      # JSON-specific bind path is gone; JsonNode params bind through
      # NimDrake's `bindVal(JsonNode)` overload, which stringifies via `$`.
      q.add placeholder(qb)
      params.add(n[1])
    of "not":
      q.add "not "
      cond(n[1], q, params, qb)
    of "!!":
      let arg = n[1]
      if arg.kind in {nnkStrLit..nnkTripleStrLit}: q.add arg.strVal
      else: q.add repr(n[1])
    else:
      q.add ' '
      q.add op
      q.add ' '
      cond(n[1], q, params, qb)
  of nnkCall:
    let op = nodeName(n[0])
    if isSetOpCall(n):
      q.add renderInlineQuery(n, params, qb)
      return
    if op == "over":
      if n.len < 2:
        macros.error "over requires at least one expression", n
      cond(n[1], q, params, qb)
      q.add " over ("
      for i in 2..<n.len:
        if i > 2: q.add " "
        if n[i].kind notin nnkCallKinds:
          macros.error "window clauses must be calls like partitionby(...) or orderby(...)", n[i]
        renderWindowClause(n[i], q, params, qb)
      q.add ")"
      return
    if op == "exists":
      expectLen n, 2
      q.add "exists ("
      q.add renderInlineQuery(n[1], params, qb)
      q.add ")"
      return
    if op == "asc" or op == "desc":
      expectLen n, 2
      cond(n[1], q, params, qb)
      q.add ' '
      q.add op
      return
    # Generic SQL function call — emit `name(arg1, arg2, ...)`
    # verbatim. Unknown names surface as DuckDB errors at runtime.
    escIdent(q, op)
    q.add "("
    for i in 1..<n.len:
      cond(n[i], q, params, qb)
      if i < n.len - 1: q.add ", "
    q.add ")"
  of nnkIfStmt, nnkIfExpr:
    q.add "\Lcase "
    for x in n:
      case x.kind
      of nnkElifBranch, nnkElifExpr:
        q.add "\L  when "
        cond(x[0], q, params, qb)
        q.add " then"
      of nnkElse, nnkElseExpr:
        q.add "\L  else"
      else:
        macros.error "illformed if expression", n
      q.add "\L    "
      cond(x[^1], q, params, qb)
    q.add "\Lend"
  of nnkCommand:
    let head = nodeName(n[0])
    if head == "select" or head == "distinct":
      q.add renderInlineQuery(n, params, qb)
    elif n.len == 2 and n[1].kind == nnkCommand and n[1].len == 2:
      let op = nodeName(n[1][0]).toLowerAscii()
      if op in ["like", "ilike"]:
        let env = qb.env
        if env.len == 2: qb.env = @[env[0]]
        cond(n[0], q, params, qb)
        q.add " "
        q.add (if op == "ilike": "ilike" else: "like")
        q.add " "
        if env.len == 2: qb.env = @[env[1]]
        cond(n[1][1], q, params, qb)
        qb.env = env
      else:
        macros.error "construct not supported in condition: " & treeRepr n, n
    else:
      macros.error "construct not supported in condition: " & treeRepr n, n
  else:
    macros.error "construct not supported in condition: " & treeRepr n, n

proc lookupCte(ctes: openArray[tuple[name, sql: string]]; name: string): int {.compileTime.} =
  result = -1
  for i, cte in ctes:
    if cmpIgnoreCase(cte.name, name) == 0:
      return i

proc sourceAlias(q: QueryBuilder; src: string): string {.compileTime.} =
  if q.kind == qkJoin and q.env.len > 0:
    result = q.env[^1]
  else:
    result = q.getAlias()

proc tableSel(n: NimNode; q: QueryBuilder) {.compileTime.} =
  if n.kind == nnkCall and q.kind != qkDelete:
    let call = n
    let tab = $call[0]
    let alias = sourceAlias(q, tab)
    if q.kind == qkSelect:
      escIdent(q.fromm, tab)
      q.fromm.add " as " & alias
    elif q.kind != qkJoin:
      escIdent(q.head, tab)
    if q.kind == qkUpdate: q.head.add " set "
    elif q.kind notin {qkSelect, qkJoin}: q.head.add "("

    if q.env.len == 0 or q.env[^1] != alias:
      q.env.add(alias)
    for i in 1..<call.len:
      let col = call[i]
      if col.kind == nnkExprEqExpr and
          q.kind in {qkInsert, qkInsertReturning, qkUpdate, qkReplace}:
        let colname = $col[0]
        if q.coln > 0: q.head.add ", "
        escIdent(q.head, colname)
        inc q.coln
        if q.kind == qkUpdate:
          q.head.add " = "
          cond(col[1], q.head, q.params, q)
        else:
          if q.values.len > 0: q.values.add ", "
          cond(col[1], q.values, q.params, q)
      elif col.kind == nnkPrefix and (let op = $col[0]; op == "?" or op == "%"):
        let colname = $col[1]
        if q.coln > 0: q.head.add ", "
        escIdent(q.head, colname)
        inc q.coln
        q.head.add " = "
        q.head.add placeholder(q)
        q.params.add(col[1])
      elif q.kind in {qkSelect, qkJoin}:
        if q.coln > 0: q.head.add ", "
        inc q.coln
        cond(col, q.head, q.params, q)
      else:
        macros.error "unknown selector: " & repr(n), n
    if q.kind notin {qkUpdate, qkSelect, qkJoin}: q.head.add ")"
  elif n.kind in {nnkIdent, nnkAccQuoted, nnkSym} and q.kind == qkDelete:
    let tab = $n
    let alias = q.getAlias()
    escIdent(q.head, tab)
    q.env.add(alias)
  elif n.kind in {nnkIdent, nnkAccQuoted, nnkSym} and q.kind in {qkSelect, qkJoin}:
    # `select thread` (no parens) → `select * from thread as t1`.
    let tab = $n
    let alias = q.getAlias()
    if q.head.len > 0 and q.head[^1] == ' ': discard
    if q.coln > 0: q.head.add ", "
    inc q.coln
    q.head.add alias
    q.head.add ".*"
    if q.kind == qkSelect:
      escIdent(q.fromm, tab)
      q.fromm.add " as " & alias
    q.env.add(alias)
  elif n.kind == nnkRStrLit:
    q.head.add n.strVal
  else:
    macros.error "unknown selector: " & repr(n), n

proc joinKeyword(kind: string): string {.compileTime.} =
  case kind.toLowerAscii()
  of "join", "innerjoin":
    "inner join "
  of "outerjoin":
    "outer join "
  of "leftjoin", "leftouterjoin":
    "left outer join "
  of "rightjoin", "rightouterjoin":
    "right outer join "
  of "fulljoin", "fullouterjoin":
    "full outer join "
  of "crossjoin":
    "cross join "
  else:
    ""

proc queryh(n: NimNode; q: QueryBuilder) {.compileTime.} =
  var n = n
  if n.kind == nnkCall:
    let c = newNimNode(nnkCommand)
    for i in 0..<n.len:
      c.add n[i]
    n = c
  expectKind n, nnkCommand
  let kind = nodeName(n[0]).toLowerAscii()
  case kind
  of "with":
    expectLen n, 2
    expectKind n[1], nnkCall
    if n[1].len != 2:
      macros.error "with expects syntax like with cteName(select ...)", n[1]
    let cteName = nodeName(n[1][0])
    if cteName.len == 0:
      macros.error "with requires a CTE name", n[1][0]
    if lookupCte(q.ctes, cteName) >= 0:
      macros.error "duplicate CTE name: " & cteName, n[1][0]
    var subq = newQueryBuilder()
    subq.qmark = q.qmark
    subq.aliasGen = q.aliasGen
    subq.ctes = q.ctes
    subq.cteBase = q.ctes.len
    applyQueryNode(n[1][1], subq)
    if subq.kind notin {qkSelect, qkJoin}:
      macros.error "CTEs require a select-style query", n[1][1]
    q.qmark = subq.qmark
    q.aliasGen = subq.aliasGen
    for p in subq.params:
      q.params.add p
    q.ctes.add((name: cteName, sql: queryAsString(subq, n[1][1])))
  of "select":
    q.kind = qkSelect
    q.head = "select "
    expectLen n, 2
    if n[1].kind == nnkCommand and nodeName(n[1][0]) == "distinct":
      expectLen n[1], 2
      q.head = "select distinct "
      tableSel(n[1][1], q)
    else:
      tableSel(n[1], q)
  of "distinct":
    q.kind = qkSelect
    q.head = "select distinct "
    expectLen n, 2
    tableSel(n[1], q)
  of "insert":
    q.kind = qkInsert
    q.head = "insert into "
    expectLen n, 2
    tableSel(n[1], q)
  of "update":
    q.kind = qkUpdate
    q.head = "update "
    expectLen n, 2
    tableSel(n[1], q)
  of "replace":
    q.kind = qkReplace
    q.head = "replace into "
    expectLen n, 2
    tableSel(n[1], q)
  of "delete":
    q.kind = qkDelete
    q.head = "delete from "
    expectLen n, 2
    tableSel(n[1], q)
  of "where":
    expectLen n, 2
    if q.kind in {qkInsert, qkInsertReturning}:
      if not q.onConflictTargetSet or not q.onConflictActionSet or not q.onConflictIsDoUpdate:
        macros.error "'where' for insert is only supported after 'onconflict(...)' and 'doupdate(...)'", n
      if q.onConflictWhereSet:
        macros.error "conflict update 'where' can only be specified once", n
      var conflictWhere = ""
      let oldKind = q.kind
      let oldEnv = q.env
      if q.env.len > 0:
        let lastAlias = q.env[^1]
        q.kind = qkSelect
        q.env = @[lastAlias]
      cond(n[1], conflictWhere, q.params, q)
      q.kind = oldKind
      q.env = oldEnv
      q.onConflictWhere = " where " & conflictWhere
      q.onConflictWhereSet = true
    else:
      cond(n[1], q.where, q.params, q)
  of "join", "innerjoin", "outerjoin", "leftjoin", "leftouterjoin",
      "rightjoin", "rightouterjoin", "fulljoin", "fullouterjoin", "crossjoin":
    q.join.add "\L" & joinKeyword(kind)
    expectLen n, 2
    let joinClause = n[1]
    if kind == "crossjoin" and joinClause.kind == nnkCommand and joinClause.len == 2 and
        joinClause[1].kind == nnkCommand and joinClause[1].len == 2 and
        nodeName(joinClause[1][0]) == "on":
      macros.error "crossjoin does not support an on clause", n
    if joinClause.kind == nnkCommand and joinClause.len == 2 and
        joinClause[1].kind == nnkCommand and joinClause[1].len == 2 and
        nodeName(joinClause[1][0]) == "on" and
        joinClause[0].kind == nnkCall:
      let tab = $joinClause[0][0]
      let alias = q.getAlias()
      escIdent(q.join, tab)
      q.join.add " as " & alias
      var oldEnv = q.env
      q.env = @[alias]
      q.kind = qkJoin
      tableSel(joinClause[0], q)
      swap q.env, oldEnv
      let onn = joinClause[1][1]
      q.join.add " on "
      oldEnv = q.env
      q.env.add(alias)
      cond(onn, q.join, q.params, q)
      swap q.env, oldEnv
    elif joinClause.kind == nnkCall:
      let tab = $joinClause[0]
      let alias = q.getAlias()
      escIdent(q.join, tab)
      q.join.add " as " & alias
      var oldEnv = q.env
      q.env = @[alias]
      q.kind = qkJoin
      if kind == "crossjoin":
        tableSel(n[1], q)
      else:
        # auto-join removed (no schema); require an explicit `on` clause.
        macros.error "join requires `join person(cols) on ...`; " &
          "automatic FK-based joins need a static schema which this DSL does not keep", n
      swap q.env, oldEnv
    else:
      macros.error "unknown query component " & repr(n), n
  of "groupby":
    for i in 1..<n.len:
      cond(n[i], q.groupby, q.params, q)
      if i != n.len - 1: q.groupby &= ", "
  of "orderby":
    for i in 1..<n.len:
      cond(n[i], q.orderby, q.params, q)
      if i != n.len - 1: q.orderby &= ", "
  of "having":
    expectLen n, 2
    cond(n[1], q.having, q.params, q)
  of "limit":
    expectLen n, 2
    if n[1].kind == nnkIntLit and n[1].intVal == 1:
      q.singleReturningCol = true
    cond(n[1], q.limit, q.params, q)
  of "offset":
    expectLen n, 2
    cond(n[1], q.offset, q.params, q)
  of "onconflict":
    if q.kind notin {qkInsert, qkInsertReturning}:
      macros.error "'onconflict' only possible within 'insert'", n
    if q.onConflictTargetSet:
      macros.error "'onconflict' can only be specified once", n
    if n.len < 2:
      macros.error "'onconflict' expects one or more columns", n
    q.onConflict = "\Lon conflict ("
    for i in 1..<n.len:
      let colname = nodeName(n[i])
      if colname.len == 0:
        macros.error "'onconflict' columns must be identifiers", n[i]
      if i > 1: q.onConflict.add ", "
      escIdent(q.onConflict, colname)
    q.onConflict.add ")"
    q.onConflictTargetSet = true
  of "donothing":
    if q.kind notin {qkInsert, qkInsertReturning}:
      macros.error "'donothing' only possible within 'insert'", n
    if not q.onConflictTargetSet:
      macros.error "'donothing' requires a preceding 'onconflict' clause", n
    if q.onConflictActionSet:
      macros.error "conflict action already set; choose only one of 'donothing' or 'doupdate'", n
    expectLen n, 1
    q.onConflict.add " do nothing"
    q.onConflictActionSet = true
    q.onConflictIsDoUpdate = false
  of "doupdate":
    if q.kind notin {qkInsert, qkInsertReturning}:
      macros.error "'doupdate' only possible within 'insert'", n
    if not q.onConflictTargetSet:
      macros.error "'doupdate' requires a preceding 'onconflict' clause", n
    if q.onConflictActionSet:
      macros.error "conflict action already set; choose only one of 'donothing' or 'doupdate'", n
    if n.len < 2:
      macros.error "'doupdate' expects assignments like doupdate(col = value)", n
    q.onConflict.add " do update set "
    for i in 1..<n.len:
      let assignment = n[i]
      if assignment.kind != nnkExprEqExpr:
        macros.error "'doupdate' expects assignments like doupdate(col = value)", assignment
      let colname = nodeName(assignment[0])
      if colname.len == 0:
        macros.error "'doupdate' assignments must target a column identifier", assignment[0]
      if i > 1: q.onConflict.add ", "
      escIdent(q.onConflict, colname)
      q.onConflict.add " = "
      cond(assignment[1], q.onConflict, q.params, q)
    q.onConflictActionSet = true
    q.onConflictIsDoUpdate = true
  of "returning":
    if q.kind != qkInsert:
      macros.error "'returning' only possible within 'insert'"
    q.kind = qkInsertReturning
    expectLen n, 2
    q.returning = " returning "
    cond(n[1], q.returning, q.params, q)
    q.singleReturningCol = true
  else:
    macros.error "unknown query component " & repr(n), n

proc queryAsString(q: QueryBuilder, n: NimNode): string {.compileTime.} =
  if q.onConflictTargetSet and not q.onConflictActionSet:
    macros.error "'onconflict' requires either 'donothing' or 'doupdate'", n
  if q.onConflictWhereSet and not q.onConflictIsDoUpdate:
    macros.error "conflict update 'where' requires 'doupdate(...)'", n
  if q.cteBase < q.ctes.len:
    result.add "with "
    for i in q.cteBase..<q.ctes.len:
      if i > q.cteBase:
        result.add ",\L"
      escIdent(result, q.ctes[i].name)
      result.add " as (\L"
      result.add q.ctes[i].sql
      result.add "\L)"
    result.add "\L"
  result.add q.head
  if q.fromm.len > 0:
    result.add "\Lfrom "
    result.add q.fromm
  if q.join.len > 0:
    result.add q.join
  if q.values.len > 0:
    result.add "\Lvalues ("
    result.add q.values
    result.add ")"
  if q.onConflict.len > 0:
    result.add q.onConflict
  if q.onConflictWhere.len > 0:
    result.add q.onConflictWhere
  if q.where.len > 0:
    if q.kind in {qkSelect, qkJoin, qkUpdate, qkDelete}:
      result.add "\Lwhere "
      result.add q.where
    else:
      macros.error "'where' is not supported for this query kind", n
  if q.groupby.len > 0:
    result.add "\Lgroup by "
    result.add q.groupby
  if q.having.len > 0:
    result.add "\Lhaving "
    result.add q.having
  if q.orderby.len > 0:
    result.add "\Lorder by "
    result.add q.orderby
  if q.limit.len > 0:
    result.add "\Llimit "
    result.add q.limit
  if q.offset.len > 0:
    result.add "\Loffset "
    result.add q.offset
  if q.returning.len > 0:
    result.add q.returning
  when defined(debugDslSql):
    macros.hint("Dsl SQL:\n" & result, n)

proc buildSetOpQueryParts(op: string; branches: openArray[NimNode];
                          q: QueryBuilder; lineInfo: NimNode) {.compileTime.} =
  if q.kind != qkNone or q.head.len > 0 or q.params.len > 0:
    macros.error "set operations must form the whole query", lineInfo
  if branches.len < 2:
    macros.error "set operations require at least two queries", lineInfo
  q.kind = qkSelect
  q.singleReturningCol = false
  for i, branchNode in branches:
    var branch = newQueryBuilder()
    branch.qmark = q.qmark
    branch.aliasGen = q.aliasGen
    branch.ctes = q.ctes
    branch.cteBase = q.ctes.len
    applyQueryNode(branchNode, branch)
    if branch.kind notin {qkSelect, qkJoin}:
      macros.error "set operations only support select-style queries", branchNode
    if i > 0:
      q.head.add "\L" & op & "\L"
    if isSetOpCall(branchNode):
      q.head.add "("
      q.head.add queryAsString(branch, branchNode)
      q.head.add ")"
    else:
      q.head.add queryAsString(branch, branchNode)
    q.qmark = branch.qmark
    q.aliasGen = branch.aliasGen
    for p in branch.params:
      q.params.add p

proc buildSetOpQuery(n: NimNode; q: QueryBuilder) {.compileTime.} =
  var branches: seq[NimNode] = @[]
  for i in 1..<n.len:
    branches.add n[i]
  buildSetOpQueryParts(nodeName(n[0]).toLowerAscii(), branches, q, n)

proc isSetOpToken(n: NimNode): bool {.compileTime.} =
  n.kind in {nnkIdent, nnkSym, nnkAccQuoted} and isSetOpName(nodeName(n))

proc applyQueryNode(n: NimNode; q: QueryBuilder) {.compileTime.} =
  if isSetOpCall(n):
    buildSetOpQuery(n, q)
    return
  var flattened: seq[NimNode]
  flattenQueryCommands(n, flattened)
  var hasInfixSetOp = false
  for part in flattened:
    if isSetOpToken(part):
      hasInfixSetOp = true
      break
  if hasInfixSetOp:
    var op = ""
    var branches: seq[NimNode] = @[]
    var currentBranch = newStmtList()
    proc flushBranch(lineInfo: NimNode) {.compileTime.} =
      if currentBranch.len == 0:
        macros.error "expected query before set operation", lineInfo
      branches.add currentBranch
      currentBranch = newStmtList()
    for part in flattened:
      if isSetOpToken(part):
        let currentOp = nodeName(part).toLowerAscii()
        if op.len == 0:
          op = currentOp
        elif op != currentOp:
          macros.error "mixed infix set operations are not supported; use nesting for precedence", part
        flushBranch(part)
      else:
        if part.kind in {nnkCommand, nnkCall} or isSetOpCall(part):
          currentBranch.add part
        else:
          macros.error "illformed query", part
    if op.len == 0:
      macros.error "expected set operation between queries", n
    if currentBranch.len == 0:
      macros.error "set operation requires a query after " & op, n
    branches.add currentBranch
    buildSetOpQueryParts(op, branches, q, n)
    return
  for part in flattened:
    if isSetOpCall(part):
      buildSetOpQuery(part, q)
    elif part.kind in {nnkCommand, nnkCall}:
      queryh(part, q)
    else:
      macros.error "illformed query", part

proc renderInlineQuery(n: NimNode; params: var Params; qb: QueryBuilder): string {.compileTime.} =
  var subq = newQueryBuilder()
  subq.qmark = qb.qmark
  subq.aliasGen = qb.aliasGen
  subq.ctes = qb.ctes
  subq.cteBase = qb.ctes.len
  applyQueryNode(n, subq)
  if subq.kind notin {qkSelect, qkJoin}:
    macros.error "subqueries require a select-style query", n
  qb.qmark = subq.qmark
  qb.aliasGen = subq.aliasGen
  for p in subq.params:
    params.add p
  result = queryAsString(subq, n)

# ---------------------------------------------------------------------------
# Macros
# ---------------------------------------------------------------------------

macro query*(con: typed; body: untyped): untyped =
  ## Compile-time SQL DSL.
  ##
  ## `query(con): select thread(id) where id == ?userId`
  ## expands at compile time to:
  ##
  ## .. code-block:: nim
  ##   block:
  ##     let stmt = con.newStatement("select t1.id from thread as t1 where t1.id = $1")
  ##     stmt.bindVal(1, userId)
  ##     con.executeMaterialized(stmt)
  ##
  ## Returns `QResult[Materialized]`. For SELECT/INSERT…RETURNING use
  ## `res.chunks`; for INSERT/UPDATE/DELETE use `res.rowsChanged`.
  ##
  ## For "swallow unique-violation" patterns, wrap a `query` call in a
  ## plain `try`/`except OperationError`.
  var q = newQueryBuilder()
  applyQueryNode(body, q)
  let sql = queryAsString(q, body)
  expectKind con, {nnkIdent, nnkSym, nnkDotExpr, nnkCall, nnkBracketExpr,
                   nnkHiddenStdConv, nnkHiddenCallConv, nnkCheckedFieldExpr,
                   nnkDerefExpr, nnkAddr, nnkPar}
  let stmtSym = genSym(nskLet, "stmt")
  result = newStmtList()
  result.add newLetStmt(stmtSym, newCall(bindSym"newStatement", con, newLit(sql)))
  if q.params.len > 0:
    for i, p in q.params:
      result.add newTree(nnkDiscardStmt, newCall(bindSym"bindVal",
        stmtSym, newLit(i + 1), p))
  result.add newCall(bindSym"executeMaterialized", con, stmtSym)