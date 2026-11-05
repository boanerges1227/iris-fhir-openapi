Class FHIR.OpenAPI.CLI Extends %RegisteredObject
{
/// Receive a configuration stream and return an output stream; the caller decides whether to write to a server file.
ClassMethod Generate(input As %Stream.Object, ByRef specification As %Stream.Object, ByRef report As %Stream.Object) As %Status
{
    Set specification="",report=""
    Try {
        Set request=##class(%DynamicObject).%FromJSON(input)
        Set sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
        Set report=##class(FHIR.OpenAPI.JSON).Canonical(result.report),specification=""
        If result.httpStatus=200 {
            Set specification=##class(FHIR.OpenAPI.JSON).Canonical(result.openapi),sc=1
        } Else { Set sc=$SYSTEM.Status.Error(5001,"FHIR OpenAPI generation failed; please check the report.") }
    } Catch ex {
        Set current=##class(FHIR.OpenAPI.Report).New()
        Do ##class(FHIR.OpenAPI.Report).Add(current,"CONFIG_INVALID","error","Failed to read configuration; a valid JSON configuration stream is required.")
        Set report=##class(FHIR.OpenAPI.JSON).Canonical(current),sc=$SYSTEM.Status.Error(5001,"Failed to read configuration; a valid JSON configuration stream is required.")
    }
    Quit sc
}
}
