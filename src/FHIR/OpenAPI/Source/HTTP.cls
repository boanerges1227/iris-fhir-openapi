Class FHIR.OpenAPI.Source.HTTP Extends %RegisteredObject
{
/// Fetch the only allowed metadata resource; do not follow redirects or send patient queries.
ClassMethod Fetch(source, report, ByRef context) As %DynamicObject
{
    Set cap="",base=source.%Get("baseUrl")
    While $Extract(base,*)="/" { Set base=$Extract(base,1,*-1) }
    If '##class(FHIR.OpenAPI.Options).URL(base) Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_URL_INVALID","error","Source URL must be free of credentials, query strings, and fragments.") Quit cap
    Set entry=##class(FHIR.OpenAPI.Config).Source(base)
    If entry="" Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_NOT_ALLOWED","error","Administrator has not registered this source.") Quit cap
    Set scheme=$Piece(base,"://",1),location=$Piece(base,"://",2),authority=$Piece(location,"/",1),path=$Extract(location,$Length(authority)+1,*)_"/metadata"
    Set host=$Piece(authority,":",1),port=$Select(scheme="https":443,1:80)
    If $Extract(authority)="[" {
        Set host=$Piece($Extract(authority,2,*),"]",1)
        If authority["]:" Set port=+$Piece(authority,"]:",2)
    } Else { If authority[":" Set port=+$Piece(authority,":",2) }
    If (scheme="http"),'$List(entry,3) Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_NOT_ALLOWED","error","HTTP development exception is not enabled.") Quit cap
    // Connect to the fixed registered IP; no DNS resolution at request time. The logical host is used only for Host/SNI/identity.
    If scheme="https",'$SYSTEM.Security.Check("%Admin_Secure","USE") Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_TLS_PRIVILEGES_REQUIRED","error","Reading IRIS TLS policy requires existing %Admin_Secure privilege; the module does not auto-elevate.") Quit cap
    If scheme="https",'##class(FHIR.OpenAPI.Config).TLSAllowed($List(entry,2)) Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_TLS_CONFIG_UNSAFE","error","SSL config must enable client mode and trusted chain verification; the caller needs existing security admin privilege to read policy.") Quit cap
    Set req=##class(FHIR.OpenAPI.Source.Request).%New(),req.Server=host,req.Port=port,req.Https=(scheme="https"),req.ConnectAddress=$List(entry,1),req.IdentityHost=host
    Set req.OpenTimeout=5,req.Timeout=##class(FHIR.OpenAPI.Deadline).Remaining(15),req.WriteTimeout=5,req.FollowRedirect=0,req.AcceptGzip=0,req.SSLCheckServerIdentity=1,req.SSLConfiguration=$List(entry,2)
    Set bounded=##class(FHIR.OpenAPI.Source.BoundedStream).%New(),req.ResponseStream=bounded
    Do req.SetHeader("Accept","application/fhir+json"),req.SetHeader("Connection","close")
    Set auth=source.%Get("auth"),mode=$Select($IsObject(auth):auth.%Get("kind","anonymous"),1:"anonymous")
    If mode="bearer" Do req.SetHeader("Authorization","Bearer "_auth.%Get("token"))
    If mode="basic" Do req.SetHeader("Authorization","Basic "_$SYSTEM.Encryption.Base64Encode(auth.%Get("username")_":"_auth.%Get("password")))
    Try {
        Set sc=req.Get(path)
        If $SYSTEM.Status.IsError(sc) {
            Set code=$Select(bounded.LimitExceeded:"SOURCE_TOO_LARGE",$ZConvert($SYSTEM.Status.GetErrorText(sc),"L")["timed out":"SOURCE_TIMEOUT",$SYSTEM.Status.GetErrorText(sc)["SOURCE_TIMEOUT":"SOURCE_TIMEOUT",$SYSTEM.Status.GetErrorText(sc)["GENERATION_TIMEOUT":"SOURCE_TIMEOUT",1:"SOURCE_FETCH_FAILED")
            Do ##class(FHIR.OpenAPI.Report).Add(report,code,"error","Unable to read source metadata; check network, TLS, or timeout.")
        } Else {
            Set response=req.HttpResponse,status=response.StatusCode
            If status'=200 {
                Do ##class(FHIR.OpenAPI.Report).Add(report,$Select((status=401)!(status=403):"SOURCE_AUTH_FAILED",status=301!(status=302)!(status=307)!(status=308):"SOURCE_REDIRECT_BLOCKED",1:"SOURCE_HTTP_FAILED"),"error","Source service did not return 200; redirects are not followed.")
            } Else {
                If response.GetHeader("Content-Encoding")'="" {
                    Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_ENCODING_UNSUPPORTED","error","Initial release does not accept compressed responses.")
                } ElseIf response.Data.Size>10485760 {
                    Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_TOO_LARGE","error","Metadata exceeds the 10 MiB limit.")
                } Else {
                    Set cap=##class(%DynamicObject).%FromJSON(response.Data),context.visibility=$Select(mode="anonymous":"anonymous-source",1:"authenticated-source")
                }
            }
        }
    } Catch ex { Do ##class(FHIR.OpenAPI.Report).Add(report,$Select(bounded.LimitExceeded:"SOURCE_TOO_LARGE",ex.Name="GENERATION_TIMEOUT":"SOURCE_TIMEOUT",1:"SOURCE_RESPONSE_INVALID"),"error","Source response could not be parsed or exceeded the size limit.") }
    Set req=""
    Quit cap
}
}
