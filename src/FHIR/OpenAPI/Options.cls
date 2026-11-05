Class FHIR.OpenAPI.Options Extends %RegisteredObject
{
/// Check for unknown fields to prevent silently using defaults after mistyping auth or filter field names.
ClassMethod Keys(value, allowed As %String, report, pointer As %String = "")
{
    If '$IsObject(value) Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","Configuration must be a JSON object.",pointer) Quit
    If value.%IsA("%DynamicArray") Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","Array is not allowed here.",pointer) Quit
    Set iter=value.%GetIterator()
    While iter.%GetNext(.key,.item) {
        If '..Member(allowed,key) Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_UNKNOWN_FIELD","error","Unknown configuration field: "_key,pointer_"/"_key)
    }
}
/// Normalize configuration to the generator's single contract without altering the original input.
ClassMethod Validate(raw As %DynamicObject, report) As %DynamicObject
{
    If '$IsObject(raw) Set raw={}
    Set options=##class(FHIR.OpenAPI.JSON).Copy(raw)
    Do ..Keys(options,"|source|expectedSourceHash|publicBaseUrl|info|resources|interactions|searchMethods|includeMetadata|includeConditionalInteractions|security|schemaMode|failurePolicy|",report)
    Set url=options.%Get("publicBaseUrl")
    If options.%GetTypeOf("publicBaseUrl")'="string" Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","Public base URL must be a string.","/publicBaseUrl")
    If '..URL(url) Do ##class(FHIR.OpenAPI.Report).Add(report,"PUBLIC_URL_INVALID","error","Public base URL must be an HTTP(S) address without credentials, query strings, or fragments.","/publicBaseUrl")
    While $Extract(url,*)="/" { Set url=$Extract(url,1,*-1) }
    Set options.publicBaseUrl=url
    Set info=options.%Get("info")
    If '$IsObject(info) Set info={}
    Do ..Keys(info,"|title|version|description|",report,"/info")
    For field="title","version","description" {
        If info.%IsDefined(field),info.%GetTypeOf(field)'="string" Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","API info field must be a string.","/info/"_field)
    }
    If (info.%Get("title")="")!(info.%Get("version")="") Do ##class(FHIR.OpenAPI.Report).Add(report,"INFO_REQUIRED","error","Title and API version are required.","/info")
    Set options.info=info
    For field="resources","interactions","security" {
        If 'options.%IsDefined(field) Do options.%Set(field,{})
        If '$IsObject(options.%Get(field)) Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","Configuration value must be an object.","/"_field) Do options.%Set(field,{})
    }
    Do ..Keys(options.resources,"|include|exclude|",report,"/resources")
    Do ..Keys(options.interactions,"|include|",report,"/interactions")
    Do ..Keys(options.security,"|mode|name|in|flows|requiredScopes|",report,"/security")
    For field="mode","name","in" {
        If options.security.%IsDefined(field),options.security.%GetTypeOf(field)'="string" Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","Security field must be a string.","/security/"_field)
    }
    If options.security.%IsDefined("requiredScopes") Do ..StringArray(options.security.requiredScopes,report,"/security/requiredScopes")
    For flag="includeMetadata","includeConditionalInteractions" {
        If options.%IsDefined(flag),(options.%GetTypeOf(flag)'="boolean") Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","Toggle flag must be a JSON boolean.","/"_flag)
    }
    For field="schemaMode","failurePolicy" {
        If 'options.%IsDefined(field) Do options.%Set(field,$Select(field="schemaMode":"gateway",1:"report"))
    }
    If options.schemaMode'="gateway" Do ##class(FHIR.OpenAPI.Report).Add(report,"SCHEMA_MODE_UNSUPPORTED","error","Initial release only supports the gateway simplified schema structure.","/schemaMode")
    If '..Member("|report|strict|",options.failurePolicy) Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","failurePolicy must be report or strict.","/failurePolicy")
    If 'options.%IsDefined("searchMethods") Set options.searchMethods=["GET","POST"]
    Do ..StringArray(options.searchMethods,report,"/searchMethods","|GET|POST|")
    If 'options.%IsDefined("includeMetadata") Set options.includeMetadata=0
    If 'options.%IsDefined("includeConditionalInteractions") Set options.includeConditionalInteractions=0
    For field="include","exclude" {
        If options.resources.%IsDefined(field) Do ..StringArray(options.resources.%Get(field),report,"/resources/"_field,##class(FHIR.OpenAPI.Capability.Parser).ResourceNames())
    }
    If options.interactions.%IsDefined("include") Do ..StringArray(options.interactions.include,report,"/interactions/include","|read|vread|update|patch|delete|history-instance|history-type|create|search-type|history-system|search-system|batch|transaction|")
    If 'options.security.%IsDefined("mode") Set options.security.mode="unspecified"
    Set mode=options.security.mode
    If '..Member("|unspecified|none|bearer|oauth2|apiKey|basic|",mode) Do ##class(FHIR.OpenAPI.Report).Add(report,"SECURITY_INVALID","error","Unknown security mode.","/security/mode")
    If mode="apiKey" {
        If (options.security.%Get("name")="")!('..Member("|header|query|cookie|",options.security.%Get("in"))) Do ##class(FHIR.OpenAPI.Report).Add(report,"SECURITY_INVALID","error","apiKey requires a name and a valid location.","/security")
    }
    If mode="oauth2" Do ..OAuth(options.security.%Get("flows"),report)
    Quit options
}
/// Strictly validate array values and enums; reject strings pretending to be lists.
ClassMethod StringArray(value, report, pointer, allowed As %String = "")
{
    If '$IsObject(value) Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","String array required.",pointer) Quit
    If 'value.%IsA("%DynamicArray") Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","Array required.",pointer) Quit
    For i=0:1:value.%Size()-1 {
        Set item=value.%Get(i)
        If (value.%GetTypeOf(i)'="string")!((allowed'="")&('..Member(allowed,item))) Do ##class(FHIR.OpenAPI.Report).Add(report,"CONFIG_INVALID","error","Invalid list item.",pointer_"/"_i)
    }
}
/// Validate the basic structure of the public URL; source connections have separate allow-list and address resolution checks.
ClassMethod URL(value As %String) As %Boolean
{
    Set matcher=##class(%Regex.Matcher).%New("^https?://(\[[0-9a-fA-F:]+\]|[A-Za-z0-9][A-Za-z0-9.-]*)(:[0-9]{1,5})?(/[^?#@\s]*)?$",value)
    Quit matcher.Locate()
}
/// Check URLs and scopes required for OAuth flows; does not automatically contact the authorization server.
ClassMethod OAuth(flows, report)
{
    Do ..Keys(flows,"|implicit|password|clientCredentials|authorizationCode|",report,"/security/flows")
    If '$IsObject(flows) Quit
    If 'flows.%Size() Do ##class(FHIR.OpenAPI.Report).Add(report,"SECURITY_INVALID","error","OAuth requires at least one flow.","/security/flows")
    Set iter=flows.%GetIterator()
    While iter.%GetNext(.kind,.flow) {
        Set allowed=$Select(kind="implicit":"|authorizationUrl|refreshUrl|scopes|",kind="authorizationCode":"|authorizationUrl|tokenUrl|refreshUrl|scopes|",1:"|tokenUrl|refreshUrl|scopes|")
        Do ..Keys(flow,allowed,report,"/security/flows/"_kind)
        If '$IsObject(flow) Continue
        For field="authorizationUrl","tokenUrl" {
            Set required=$Select(field="authorizationUrl":((kind="implicit")!(kind="authorizationCode")),1:(kind'="implicit"))
            If required,((flow.%GetTypeOf(field)'="string")!('..URL(flow.%Get(field)))) Do ##class(FHIR.OpenAPI.Report).Add(report,"SECURITY_INVALID","error","OAuth flow is missing a valid URL.","/security/flows/"_kind_"/"_field)
        }
        Set scopes=flow.%Get("scopes")
        If '$IsObject(scopes) {
            Do ##class(FHIR.OpenAPI.Report).Add(report,"SECURITY_INVALID","error","OAuth scopes must be an object.","/security/flows/"_kind)
        } Else {
            If scopes.%IsA("%DynamicArray") Do ##class(FHIR.OpenAPI.Report).Add(report,"SECURITY_INVALID","error","OAuth scopes cannot be an array.","/security/flows/"_kind)
            Set si=scopes.%GetIterator()
            While si.%GetNext(.scope,.description) {
                If scopes.%GetTypeOf(scope)'="string" Do ##class(FHIR.OpenAPI.Report).Add(report,"SECURITY_INVALID","error","Scope description must be a string.","/security/flows/"_kind)
            }
        }
        If flow.%IsDefined("refreshUrl"),((flow.%GetTypeOf("refreshUrl")'="string")!('..URL(flow.refreshUrl))) Do ##class(FHIR.OpenAPI.Report).Add(report,"SECURITY_INVALID","error","refreshUrl must be a valid URL.","/security/flows/"_kind)
    }
}
/// Check whether a value is in the list; an omitted list means the item is absent.
ClassMethod Contains(array, value As %String) As %Boolean
{
    Set found=0
    If $IsObject(array) {
        For i=0:1:array.%Size()-1 { If array.%Get(i)=value Set found=1 Quit }
    }
    Quit found
}
/// Exact member match; reject inputs containing the set delimiter to avoid cross-member substring hits.
ClassMethod Member(allowed As %String, value) As %Boolean
{
    If $IsObject(value) Quit 0
    If (value="")!(value["|") Quit 0
    Quit allowed[("|"_value_"|")
}
}
