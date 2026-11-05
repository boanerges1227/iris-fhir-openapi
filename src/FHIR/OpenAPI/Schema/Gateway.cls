Class FHIR.OpenAPI.Schema.Gateway Extends %RegisteredObject
{
/// Resource schema only preserves the resource type and allows unknown fields; it does not impersonate full FHIR validation.
ClassMethod Resource(type As %String) As %DynamicObject
{
    Set schema={"type":"object","required":["resourceType"],"properties":{"resourceType":{"type":"string"}},"additionalProperties":true,"x-fhir-schema-level":"gateway"}
    If type'="" Set schema.properties.resourceType.enum=[(type)]
    Quit schema
}
/// Internal file references are constructed by a unified method to avoid path spelling drift.
ClassMethod Ref(name As %String) As %DynamicObject
{
    Quit {"$ref":("#/components/schemas/"_name)}
}
/// Create shared minimal schemas; Bundle retains recursive entry/resource references.
ClassMethod Build() As %DynamicObject
{
    Set schemas={}
    For name="Resource","OperationOutcome","CapabilityStatement","Parameters","Bundle" Do schemas.%Set(name,..Resource($Select(name="Resource":"",1:name)))
    Set bundle=schemas.Bundle
    Set bundle.properties.type={"type":"string"}
    Set bundle.properties.entry={"type":"array","items":{"type":"object","properties":{"resource":(..Ref("Resource"))},"additionalProperties":true}}
    Set patch={"type":"array","items":{"type":"object","required":["op","path"],"properties":{"op":{"type":"string","enum":["add","remove","replace","move","copy","test"]},"path":{"type":"string"},"from":{"type":"string"},"value":{}},"additionalProperties":true}}
    Set schemas.JSONPatch=patch
    For name="SearchBundle","HistoryBundle" {
        Set b=##class(FHIR.OpenAPI.JSON).Copy(bundle),b.properties.type.enum=[($Select(name="SearchBundle":"searchset",1:"history"))]
        Do b.required.%Push("type"),schemas.%Set(name,b)
    }
    Quit schemas
}
}
