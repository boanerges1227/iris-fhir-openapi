Class FHIR.OpenAPI.Source.Local Extends %RegisteredObject
{
/// Dynamically detect Health classes to prevent compilation failure of the core package on plain IRIS.
ClassMethod Available() As %Boolean
{
    Quit ##class(%Dictionary.CompiledClass).%ExistsId("HS.FHIRServer.API.InteractionsStrategy")
}
/// Only read configuration metadata of deployed endpoints in the current namespace; existing services are never modified.
ClassMethod Fetch(source, report, ByRef context) As %DynamicObject
{
    Set endpoint=source.%Get("endpoint"),cap=""
    Set regex=##class(%Regex.Matcher).%New("^/[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)*$",endpoint)
    If 'regex.Locate() Do ##class(FHIR.OpenAPI.Report).Add(report,"LOCAL_ENDPOINT_INVALID","error","Absolute endpoint path in the current namespace is required.","/source/endpoint") Quit cap
    If '..Available() Do ##class(FHIR.OpenAPI.Report).Add(report,"LOCAL_FHIR_UNAVAILABLE","error","FHIR Server is not enabled in the current namespace.") Quit cap
    Try {
        Set strategy=$ClassMethod("HS.FHIRServer.API.InteractionsStrategy","GetStrategyForEndpoint",endpoint)
        Set interactions=strategy.NewInteractionsInstance()
        Set cap=interactions.LoadMetadata(),context.visibility="configured-endpoint",context.endpoint=endpoint
        Set stream=##class(%Stream.TmpBinary).%New()
        Do cap.%ToJSON(stream)
        If stream.Size>10485760 Set cap="" Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_TOO_LARGE","error","Metadata exceeds the 10 MiB limit.")
    } Catch ex {
        Do ##class(FHIR.OpenAPI.Report).Add(report,"LOCAL_ENDPOINT_FAILED","error","Unable to read the local endpoint; check path, namespace, and permissions.")
    }
    Quit cap
}
}
