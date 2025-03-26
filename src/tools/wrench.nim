import std/macros
import fusion/matching

# The DuckType enum and Vector type definitions would be here as in your example
macro generateTypeToField*(registryName: static[string], vectorType: typed): untyped =
  ## Creates a getFieldName function that returns the field identifier
  ## in the Vector type corresponding to a given DuckType

  result = newStmtList()

  # Get the vector object definition
  let typeImpl = getImpl(vectorType)

  # Recursively search for the case statement in the type definition
  proc findCaseStmt(node: NimNode): NimNode =
    if node.kind == nnkRecCase:
      return node
    for i in 0 ..< node.len:
      let child = node[i]
      if child.kind == nnkRecCase:
        return child
      if child.len > 0:
        let found = findCaseStmt(child)
        if found != nil:
          return found
    return nil

  # Extract the object type from the type definition
  var objTy: NimNode = nil

  if typeImpl.kind == nnkTypeDef:
    let typeDef = typeImpl[2]
    if typeDef.kind == nnkRefTy and typeDef[0].kind == nnkObjectTy:
      objTy = typeDef[0]
    elif typeDef.kind == nnkObjectTy:
      objTy = typeDef

  if objTy == nil:
    error("Expected a ref object or object type", vectorType)

  # Find the recList containing the case statement
  var recList: NimNode = nil
  for i in 0 ..< objTy.len:
    if objTy[i].kind == nnkRecList:
      recList = objTy[i]
      break

  if recList == nil:
    error("Could not find record list in object definition", vectorType)

  # Find the case statement in the record list
  let caseStmt = findCaseStmt(recList)
  if caseStmt == nil:
    error("Could not find case statement in object definition", vectorType)

  var tableExpr = nnkTableConstr.newTree()
  # Process each branch of the case statement
  for i in 1 ..< caseStmt.len:
    caseStmt[i].assertMatch:
      OfBranch:
        pref DotExpr[_, (strVal: @types)]
        RecList[any IdentDefs[any Postfix[_, (strVal: @fieldName)]]] |
          IdentDefs[any Postfix[_, (strVal: @fieldName)]]

    # if duckType.strVal in
    # echo types.repr, " -> ", fieldName.repr

    for key in types:
      let keyExpr = nnkDotExpr.newTree(newIdentNode("DuckType"), newIdentNode(key))

      # let valueExpr = nnkIdent.newTree(valueIdent)

      # Create the key-value pair
      tableExpr.add(nnkExprColonExpr.newTree(keyExpr, newLit(fieldName[0])))

  result = nnkLetSection.newTree(
    nnkIdentDefs.newTree(
      newIdentNode(registryName),
      newEmptyNode(),
      nnkDotExpr.newTree(tableExpr, newIdentNode("toTable")),
    )
  )

macro getField*(obj: object, fieldName: static string): untyped =
  nnkDotExpr.newTree(obj, ident(fieldName))
