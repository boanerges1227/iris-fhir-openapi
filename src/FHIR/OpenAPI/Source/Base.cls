Class FHIR.OpenAPI.Source.Base Extends %RegisteredObject
{
/// Strictly validate data source fields; different sources do not share file paths or authentication fields.
ClassMethod Validate(source, report) As %Boolean
{
    If '$IsObject(source) Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_INVALID","error","Data source is required.","/source") Quit 0
    Set kind=source.%Get("kind"),fields="|kind|"
    If kind="file" Set fields="|kind|capability|"
    If kind="local" Set fields="|kind|endpoint|"
    If kind="http" Set fields="|kind|baseUrl|auth|"
    If fields="|kind|" Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_INVALID","error","Unknown data source type.","/source/kind") Quit 0
    Do ##class(FHIR.OpenAPI.Options).Keys(source,fields,report,"/source")
    For field="endpoint","baseUrl" {
        If source.%IsDefined(field),source.%GetTypeOf(field)'="string" Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_INVALID","error","Address must be a string.","/source/"_field)
    }
    If kind="http",source.%IsDefined("auth") {
        Set auth=source.auth
        Do ##class(FHIR.OpenAPI.Options).Keys(auth,"|kind|username|password|token|",report,"/source/auth")
        If $IsObject(auth) {
            Set mode=auth.%Get("kind","anonymous")
            For field="kind","username","password","token" {
                If auth.%IsDefined(field),auth.%GetTypeOf(field)'="string" Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_AUTH_INVALID","error","Authentication field must be a string.","/source/auth/"_field)
            }
            If mode="bearer" {
                Set token=auth.%Get("token")
                If (token="")!(token[$Char(10))!(token[$Char(13)) Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_AUTH_INVALID","error","Bearer token must not be empty or contain line breaks.","/source/auth/token")
            }
            If '##class(FHIR.OpenAPI.Options).Member("|anonymous|basic|bearer|",mode) Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_AUTH_INVALID","error","Source authentication supports only anonymous/basic/bearer.","/source/auth")
        }
    }
    Quit '##class(FHIR.OpenAPI.Report).HasErrors(report)
}
/// Only dispatch supported fixed adapter names; arbitrary class method selection is not permitted.
ClassMethod Fetch(source, report, ByRef context) As %DynamicObject
{
    Set context={"kind":(source.kind),"namespace":($Namespace),"visibility":"uploaded-snapshot"}
    Set cap=""
    If source.kind="file" Set cap=##class(FHIR.OpenAPI.Source.File).Fetch(source,report,.context)
    If source.kind="local" Set cap=$ClassMethod("FHIR.OpenAPI.Source.Local","Fetch",source,report,.context)
    If source.kind="http" Set cap=$ClassMethod("FHIR.OpenAPI.Source.HTTP","Fetch",source,report,.context)
    Quit cap
}
}
