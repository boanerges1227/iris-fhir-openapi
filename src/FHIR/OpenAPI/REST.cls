Class FHIR.OpenAPI.REST Extends %CSP.REST
{
Parameter UseSession = 1;
Parameter HandleCorsRequest = 0;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/" Method="GET" Call="Index"/>
  <Route Url="/app.js" Method="GET" Call="Script"/>
  <Route Url="/style.css" Method="GET" Call="Style"/>
  <Route Url="/api/v1/health" Method="GET" Call="Health"/>
  <Route Url="/api/v1/inspect" Method="POST" Call="Inspect"/>
  <Route Url="/api/v1/generate" Method="POST" Call="Generate"/>
</Routes>
}
/// Return capability status visible only to the current admin, plus a session CSRF token.
ClassMethod Health() As %Status
{
    If '##class(FHIR.OpenAPI.Access).Allowed() Quit ..JSON({"error":"FORBIDDEN"},403)
    If $Length($Get(%session.Data("FHIRAPI","csrf")))'=44 Set %session.Data("FHIRAPI","csrf")=$SYSTEM.Encryption.Base64Encode($SYSTEM.Encryption.GenCryptRand(32,1))
    Quit ..JSON({"version":"0.1.0","namespace":($Namespace),"localAvailable":(##class(FHIR.OpenAPI.Source.Local).Available()),"httpAvailable":true,"fileAvailable":true,"csrfToken":(%session.Data("FHIRAPI","csrf"))},200)
}
/// Preview and generation entry points share all validation and CSRF protection.
ClassMethod Inspect() As %Status
{
    Quit ..Process(0)
}
/// REST generation must carry the preview hash to prevent the page from skipping snapshot confirmation.
ClassMethod Generate() As %Status
{
    Quit ..Process(1)
}
/// Limit byte count and stream-parse JSON; never place the entire request in a single ObjectScript string.
ClassMethod Process(generate As %Boolean) As %Status
{
    If '##class(FHIR.OpenAPI.Access).Allowed() Quit ..JSON({"error":"FORBIDDEN"},403)
    If $Get(%request.CgiEnvs("HTTP_X_CSRF_TOKEN"))'=$Get(%session.Data("FHIRAPI","csrf"))!($Get(%session.Data("FHIRAPI","csrf"))="") Quit ..JSON({"error":"CSRF_REQUIRED"},403)
    Set origin=$Get(%request.CgiEnvs("HTTP_ORIGIN")),host=$Get(%request.CgiEnvs("HTTP_HOST"))
    If origin'="",$Piece(origin,"://",2)'=host Quit ..JSON({"error":"ORIGIN_REJECTED"},403)
    If %request.Content.Size>12582912 Quit ..JSON({"error":"REQUEST_TOO_LARGE"},413)
    Set invalid=0
    Try {
        Set request=##class(%DynamicObject).%FromJSON(%request.Content)
    } Catch ex { Set invalid=1 }
    If invalid Quit ..JSON({"error":"JSON_INVALID"},400)
    If request.%IsA("%DynamicArray") Quit ..JSON({"error":"JSON_OBJECT_REQUIRED"},400)
    If generate,'request.%IsDefined("expectedSourceHash") Quit ..JSON({"error":"EXPECTED_HASH_REQUIRED"},400)
    If generate {
        Set sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
    } Else { Set sc=##class(FHIR.OpenAPI.Service).Inspect(request,.result) }
    Quit ..JSON(result,result.httpStatus)
}
/// Output canonical JSON as UTF-8, ensuring reproducible download ordering.
ClassMethod JSON(value, status As %Integer) As %Status
{
    Set %response.Status=status,%response.ContentType="application/json",%response.CharSet="utf-8"
    Do %response.SetHeader("Cache-Control","no-store"),%response.SetHeader("X-Content-Type-Options","nosniff")
    Set stream=##class(FHIR.OpenAPI.JSON).Canonical(value)
    While 'stream.AtEnd { Write stream.Read(32768) }
    Quit 1
}
/// Admin page only reads static content imported at install time; the URL must not specify a file path.
ClassMethod Asset(name As %String, type As %String) As %Status
{
    If '##class(FHIR.OpenAPI.Access).Allowed() Quit ..JSON({"error":"FORBIDDEN"},403)
    Set %response.ContentType=type,%response.CharSet="utf-8"
    Do %response.SetHeader("Content-Security-Policy","default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"),%response.SetHeader("Cache-Control","no-store"),%response.SetHeader("X-Content-Type-Options","nosniff")
    Write $Get(^FHIR.OpenAPI.Config($Namespace,"assets",name))
    Quit 1
}
/// Page index.
ClassMethod Index() As %Status
{
    Quit ..Asset("index.html","text/html")
}
/// Bundled JavaScript.
ClassMethod Script() As %Status
{
    Quit ..Asset("app.js","text/javascript")
}
/// Bundled stylesheet.
ClassMethod Style() As %Status
{
    Quit ..Asset("style.css","text/css")
}
}
