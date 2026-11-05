Class FHIR.OpenAPI.Report Extends %RegisteredObject
{
/// Create a unified report; diagnostics never store source credentials or original patient data.
ClassMethod New() As %DynamicObject
{
    Quit {"diagnostics":[],"omittedOperations":[],"counts":{},"status":"ok","generatorVersion":"0.1.0"}
}
/// Add a stable diagnostic code and source pointer so callers do not rely on message text to branch.
ClassMethod Add(report As %DynamicObject, code As %String, severity As %String, message As %String, pointer As %String = "", resource As %String = "", interaction As %String = "")
{
    Set d={"code":(code),"severity":(severity),"message":(message),"sourcePointer":(pointer),"resourceType":(resource),"interaction":(interaction),"remediation":"Correct input or export configuration according to design and source endpoint declarations."}
    Do report.diagnostics.%Push(d)
    If severity="error" Set report.status="error"
    If (severity="warning"),(report.status="ok") Set report.status="warning"
}
/// Check whether the report contains blocking errors.
ClassMethod HasErrors(report As %DynamicObject) As %Boolean
{
    Quit report.status="error"
}
/// Check whether the report contains a specific diagnostic code, for entry points and tests to verify stable error codes.
ClassMethod HasCode(report As %DynamicObject, code As %String) As %Boolean
{
    Set found=0
    For i=0:1:report.diagnostics.%Size()-1 {
        If report.diagnostics.%Get(i).code=code Set found=1 Quit
    }
    Quit found
}
}
