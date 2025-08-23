import tables

import ./[api, gtypes]

type
  Field* = distinct ptr GArrowField
  Schema* = distinct ptr GArrowSchema
  Table* = distinct ptr GArrowTable

converter toArrowType*(s: Schema): ptr GArrowSchema =
  cast[ptr GArrowSchema](s)

proc `=destroy`(field: Field) =
  if not isNil(field.addr):
    gObjectUnref(cast[ptr GArrowField](field))

proc `=destroy`(s: Schema) =
  if not isNil(s.addr):
    gObjectUnref(cast[gpointer](s))

proc name*(field: Field): string =
  result = $garrow_field_get_name(cast[ptr GArrowField](field))

proc `$`*(field: Field): string =
  let gStr = garrow_field_to_string(cast[ptr GArrowField](field))
  result = $gStr
  gFree(gStr)

proc `==`*(a, b: Field): bool =
  garrow_field_equal(cast[ptr GArrowField](a), cast[ptr GArrowField](b)).bool

proc newField*[T](name: string): Field =
  let gType = newGType(T)
  result = Field(garrow_field_new(name.cstring, gType))

proc `$`*(schema: Schema): string =
  let gStr = garrow_schema_to_string(schema)
  result = $gStr
  gFree(gStr)

proc newSchema*(flds: openArray[Field]): Schema =
  let fList = newGList(flds)
  result = cast[Schema](garrow_schema_new(fList.list))

iterator fields*(schema: Schema): lent Field {.inline.} =
  for field in newGList[Field](garrow_schema_get_fields(schema)):
    yield field

iterator items*(schema: Schema): lent Field {.inline.} =
  for field in schema.fields:
    yield field

when isMainModule:
  let schemaFields = @[
    newField[bool]("sexy"),
    newField[int]("age")
  ]
  echo schemaFields
  let schema = newSchema(schemaFields)
