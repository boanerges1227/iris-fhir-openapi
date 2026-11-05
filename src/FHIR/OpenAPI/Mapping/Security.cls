Class FHIR.OpenAPI.Mapping.Security Extends %RegisteredObject
{
/// Export authentication is explicitly configured by the user; it does not inherit the actual credentials used when collecting metadata.
ClassMethod Apply(spec, config, report)
{
    Set mode=config.mode
    If mode="unspecified" Do ##class(FHIR.OpenAPI.Report).Add(report,"SECURITY_UNSPECIFIED","warning","Public API authentication method not determined.","/security") Quit
    If mode="none" Set spec.security=[] Quit
    Set scheme={}
    If mode="bearer" Set scheme={"type":"http","scheme":"bearer"}
    If mode="basic" Set scheme={"type":"http","scheme":"basic"}
    If mode="apiKey" Set scheme={"type":"apiKey","name":(config.name),"in":(config.in)}
    If mode="oauth2" Set scheme={"type":"oauth2","flows":(config.flows)}
    Set spec.components.securitySchemes={"FHIRAuth":(scheme)}
    Set scopes=config.%Get("requiredScopes",[])
    Set spec.security=[{"FHIRAuth":(scopes)}]
}
}
