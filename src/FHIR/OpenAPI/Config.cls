Class FHIR.OpenAPI.Config Extends %RegisteredObject
{
/// Administrator registers the exact base URL and fixed connection IP; requests cannot modify the source allow-list.
ClassMethod RegisterSource(baseUrl As %String, address As %String, sslConfiguration As %String = "", allowHTTP As %Boolean = 0) As %Status
{
    If '$SYSTEM.Security.Check("%Admin_Secure","USE") Quit $SYSTEM.Status.Error(5001,"Registering a source requires %Admin_Secure privilege.")
    If '##class(FHIR.OpenAPI.Access).Allowed() Quit $SYSTEM.Status.Error(5001,"Missing module privilege.")
    While $Extract(baseUrl,*)="/" { Set baseUrl=$Extract(baseUrl,1,*-1) }
    If '##class(FHIR.OpenAPI.Options).URL(baseUrl) Quit $SYSTEM.Status.Error(5001,"Source URL is invalid.")
    If '$SYSTEM.INetInfo.AddrType(address) Quit $SYSTEM.Status.Error(5001,"A fixed IP address must be registered.")
    If ($Extract(baseUrl,1,7)="http://"),'allowHTTP Quit $SYSTEM.Status.Error(5001,"HTTP may only be registered in explicit dev mode.")
    If ($Extract(baseUrl,1,8)="https://"),(sslConfiguration="") Quit $SYSTEM.Status.Error(5001,"HTTPS sources must specify an SSL configuration.")
    If ($Extract(baseUrl,1,8)="https://"),'..TLSAllowed(sslConfiguration) Quit $SYSTEM.Status.Error(5001,"SSL configuration must enable client mode and require a trusted certificate chain.")
    Set ^FHIR.OpenAPI.Config($Namespace,"sources",baseUrl)=$ListBuild(address,sslConfiguration,allowHTTP)
    Quit 1
}
/// Return registered sources for the current namespace read-only; source credentials are never returned.
ClassMethod Source(baseUrl As %String)
{
    Quit $Get(^FHIR.OpenAPI.Config($Namespace,"sources",baseUrl))
}
/// Check TLS security policy on both registration and fetch; a downgraded config must not continue to send credentials.
ClassMethod TLSAllowed(name As %String) As %Boolean
{
    Set old=$Namespace,ok=0
    Try {
        Set $Namespace="%SYS"
        // Only query public policy columns; never call SSLConfigs.Get which would return cleartext private-key passphrases.
        Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT Enabled,Type,VerifyPeer FROM Security.SSLConfigs WHERE Name=?",name)
        If rs.%SQLCODE=0,rs.%Next() Set ok=(rs.Enabled=1)&(rs.Type=0)&(rs.VerifyPeer=2)
    } Catch ex { Set ok=0 }
    Set $Namespace=old
    Quit ok
}
}
