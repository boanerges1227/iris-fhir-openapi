Class FHIR.OpenAPI.Mapping.Search Extends %RegisteredObject
{
/// All FHIR search values remain strings to prevent prefixes, tokens, and quantities from being incorrectly rejected by the gateway.
ClassMethod Parameters(params) As %DynamicArray
{
    Set out=[],iter=params.%GetIterator()
    While iter.%GetNext(.name,.raw) { Set keys("x"_name)=name }
    Set key=""
    For { Set key=$Order(keys(key)) Quit:key=""
        Set name=keys(key),raw=params.%Get(name)
        Do ##class(FHIR.OpenAPI.Deadline).Check()
        Set p={"name":(name),"in":"query","required":false,"schema":{"type":"string"},"description":(raw.%Get("documentation")),"x-fhir-search-type":(raw.%Get("type"))}
        If raw.%IsDefined("definition") Do p.%Set("x-fhir-definition",raw.definition)
        Do out.%Push(p)
    }
    Quit out
}
/// POST search uses a form object; it does not incorrectly output a JSON resource request body.
ClassMethod Body(params) As %DynamicObject
{
    Set properties={},iter=params.%GetIterator()
    While iter.%GetNext(.name,.raw) {
        Do ##class(FHIR.OpenAPI.Deadline).Check()
        Set p={"type":"string","description":(raw.%Get("documentation")),"x-fhir-search-type":(raw.%Get("type"))}
        If raw.%IsDefined("definition") Do p.%Set("x-fhir-definition",raw.definition)
        Do properties.%Set(name,p)
    }
    Quit {"required":false,"content":{"application/x-www-form-urlencoded":{"schema":{"type":"object","properties":(properties),"additionalProperties":true}}}}
}
}
