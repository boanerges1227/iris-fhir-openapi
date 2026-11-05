Class FHIR.OpenAPI.Source.File Extends %RegisteredObject
{
/// Only accept uploaded objects; do not read files based on server paths in the request.
ClassMethod Fetch(source, report, ByRef context) As %DynamicObject
{
    Set cap=source.%Get("capability")
    If '$IsObject(cap) Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Please upload a CapabilityStatement JSON object.","/source/capability") Quit ""
    If cap.%IsA("%DynamicArray") Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Top-level capability must not be an array.","/source/capability") Quit ""
    Set stream=##class(%Stream.TmpBinary).%New()
    Do cap.%ToJSON(stream)
    If stream.Size>10485760 Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_TOO_LARGE","error","Metadata exceeds the 10 MiB limit.") Quit ""
    Quit ##class(FHIR.OpenAPI.JSON).Copy(cap)
}
}
