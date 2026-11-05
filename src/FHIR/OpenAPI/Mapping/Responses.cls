Class FHIR.OpenAPI.Mapping.Responses Extends %RegisteredObject
{
/// Success responses are modeled by interaction; Prefer only affects the body, it does not alter R4 status codes.
ClassMethod Build(code As %String, resource As %String, flags, conditional As %Boolean = 0) As %DynamicObject
{
    Set out={},schema=resource
    If code["search" Set schema="SearchBundle"
    If code["history" Set schema="HistoryBundle"
    If (code="batch")!(code="transaction") Set schema="BundleResponse"
    If code="metadata" Set schema="CapabilityStatement"
    If code="delete" Set schema="OperationOutcome"
    Set success="200"
    If code="create" Set success="201"
    Do out.%Set(success,..Response("Success: write operations may omit the body per Prefer.",schema,((code="create")!(code="update")!(code="patch"))))
    If code="create",flags.%Get("conditionalCreate") Do out.%Set("200",..Response("Conditional create matched an existing resource.",resource,1))
    If code="update",(conditional!flags.%Get("updateCreate")) Do out.%Set("201",..Response("Resource created.",resource,1))
    If code="delete" {
        Do out.%Set("202",{"description":"Server accepted the delete request but does not guarantee the final result."})
        Do out.%Set("204",{"description":"Deleted successfully, no body."})
    }
    If code="read",flags.%Get("conditionalRead", "not-supported")'="not-supported" Do out.%Set("304",{"description":"Conditional read: content unchanged, no body."})
    For status="400","404","405","406","409","412","415","422","5XX" Do out.%Set(status,..Response("FHIR server or gateway error; body may be empty.","OperationOutcome"))
    If code="read" Do out.%Set("410",..Response("Resource has been deleted.","OperationOutcome"))
    Quit out
}
/// Shared response references point only within the file, ensuring gateways can import offline.
ClassMethod Response(description, schema As %String, alternative As %Boolean = 0) As %DynamicObject
{
    Set shape=##class(FHIR.OpenAPI.Schema.Gateway).Ref(schema)
    If alternative,schema'="OperationOutcome" Set shape={"oneOf":[(shape),(##class(FHIR.OpenAPI.Schema.Gateway).Ref("OperationOutcome"))]}
    Quit {"description":(description),"content":{"application/fhir+json":{"schema":(shape)}}}
}
}
