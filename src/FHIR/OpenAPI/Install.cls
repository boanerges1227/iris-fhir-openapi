Class FHIR.OpenAPI.Install Extends %RegisteredObject
{
/// Check ownership before IPM copies static files to prevent path conflicts overwriting customer files before Setup.
ClassMethod Preflight(namespace As %String, webPath As %String, assetRoot As %String) As %Status
{
    If '$SYSTEM.Security.Check("%Admin_Secure","USE") Quit $SYSTEM.Status.Error(5001,"Installation requires %Admin_Secure privilege.")
    If namespace'=$Namespace Quit $SYSTEM.Status.Error(5001,"Must be executed in the target namespace.")
    Set old=$Namespace,sc=1,owned=0,marker="IRIS FHIR OpenAPI|"_namespace
    If $Get(^FHIR.OpenAPI.Config($Namespace,"webPath"))'="",$Get(^FHIR.OpenAPI.Config($Namespace,"webPath"))'=webPath Quit $SYSTEM.Status.Error(5001,"Target namespace is already bound to another admin path.")
    Try {
        Set $Namespace="%SYS"
        If ##class(Security.Applications).Exists(webPath) {
            Set sc=##class(Security.Applications).Get(webPath,.p)
            If (p("NameSpace")'=namespace)!(p("Description")'=marker)!(p("DispatchClass")'="FHIR.OpenAPI.REST") Throw ##class(%Exception.General).%New("Web path is already occupied by another application.")
            Set owned=1
        }
        If ##class(Security.Applications).Exists(webPath_"_login") {
            Set sc=##class(Security.Applications).Get(webPath_"_login",.loginProps)
            If loginProps("Description")'=(marker_"|login") Throw ##class(%Exception.General).%New("Login path is already occupied by another application.")
        }
        If 'owned {
            For name="index.html","app.js","style.css","login/index.html","login/login.js","login/login.css" {
                If ##class(%File).Exists(assetRoot_"/"_name) Throw ##class(%Exception.General).%New("Static target file does not belong to this installation; overwrite rejected.")
            }
        }
    } Catch ex { Set sc=ex.AsStatus() }
    Set $Namespace=old
    Quit sc
}
/// Idempotently install a standalone admin application; only accepts module classes already in the target namespace and offline static files.
/// Security objects are created in %SYS, but never automatically grant roles to users or modify customer FHIR endpoints.
ClassMethod Setup(namespace As %String = "", webPath As %String = "", assetRoot As %String = "", managedAssets As %Boolean = 0) As %Status
{
    If namespace="" Set namespace=$Namespace
    Set namespace=$ZConvert(namespace,"U")
    If namespace'=$Namespace Quit $SYSTEM.Status.Error(5001,"Please switch to the installation target namespace first.")
    If '$SYSTEM.Security.Check("%Admin_Secure","USE") Quit $SYSTEM.Status.Error(5001,"Installation requires %Admin_Secure privilege.")
    If webPath="" Set webPath="/fhir-openapi-"_$ZConvert(namespace,"L")
    Set regex=##class(%Regex.Matcher).%New("^/[A-Za-z0-9_-]+$",webPath)
    If 'regex.Locate() Quit $SYSTEM.Status.Error(5001,"Admin path must be a standalone single-segment absolute path.")
    If assetRoot="" Quit $SYSTEM.Status.Error(5001,"Bundled static asset directory must be provided.")
    If $Get(^FHIR.OpenAPI.Config($Namespace,"webPath"))'="",$Get(^FHIR.OpenAPI.Config($Namespace,"webPath"))'=webPath Quit $SYSTEM.Status.Error(5001,"This namespace is already bound to another admin path; please uninstall the old entry first.")
    If managedAssets,assetRoot'=($SYSTEM.Util.InstallDirectory()_"csp/fhir-openapi-"_$ZConvert(namespace,"L")) Quit $SYSTEM.Status.Error(5001,"Managed static files must reside in the module's fixed directory.")
    Set marker="IRIS FHIR OpenAPI|"_namespace,resource=##class(FHIR.OpenAPI.Access).Resource(),role=resource_"_Admin",old=$Namespace,sc=1,newApp=0,newRole=0,newResource=0,newLoginApp=0
    // Validate all static assets first to avoid leaving partially installed security objects when files are missing.
    Try {
        For name="index.html","app.js","style.css" {
            Set file=##class(%Stream.FileCharacter).%New(),file.Filename=assetRoot_"/"_name,file.TranslateTable="UTF8"
            If file.Size>1048576 Throw ##class(%Exception.General).%New("Static file is too large.")
            Set assets(name)=file.Read(1048576)
            If assets(name)="" Throw ##class(%Exception.General).%New("Missing static assets.")
        }
        Set $Namespace="%SYS"
        Set appExists=##class(Security.Applications).Exists(webPath)
        If appExists {
            Set sc=##class(Security.Applications).Get(webPath,.props)
            If (props("NameSpace")'=namespace)!(props("DispatchClass")'="FHIR.OpenAPI.REST")!(props("Description")'=marker) Throw ##class(%Exception.General).%New("Web path is already occupied by another application.")
        }
        If ##class(Security.Resources).Exists(resource) {
            Set sc=##class(Security.Resources).Get(resource,.resourceProps)
            If resourceProps("Description")'=marker Throw ##class(%Exception.General).%New("Security resource name is occupied by another object.")
        } Else {
            Set sc=##class(Security.Resources).Create(resource,marker,"",0)
            If $SYSTEM.Status.IsError(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
            Set newResource=1
        }
        If ##class(Security.Roles).Exists(role) {
            Set sc=##class(Security.Roles).Get(role,.roleProps)
            If roleProps("Description")'=marker Throw ##class(%Exception.General).%New("Role name is occupied by another object.")
        } Else {
            Set sc=##class(Security.Roles).Create(role,marker,resource_":USE","")
            If $SYSTEM.Status.IsError(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
            Set newRole=1
        }
        Kill props
        Set props("NameSpace")=namespace,props("DispatchClass")="FHIR.OpenAPI.REST",props("Description")=marker,props("Enabled")=1,props("AutheEnabled")=32,props("Resource")="",props("UseCookies")=2,props("CookiePath")=webPath,props("MatchRoles")=""
        If appExists {
            Set sc=##class(Security.Applications).Modify(webPath,.props)
        } Else {
            Set sc=##class(Security.Applications).Create(webPath,.props)
            If $SYSTEM.Status.IsOK(sc) Set newApp=1
        }
        If $SYSTEM.Status.IsError(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
        // The standalone anonymous app only serves fixed login static files; it cannot run CSP/REST. The admin API still requires password authentication.
        Set loginPath=webPath_"_login"
        If ##class(Security.Applications).Exists(loginPath) {
            Set sc=##class(Security.Applications).Get(loginPath,.loginProps)
            If loginProps("Description")'=(marker_"|login") Throw ##class(%Exception.General).%New("Login path is already occupied by another application.")
        }
        Kill loginProps
        Set loginProps("NameSpace")="%SYS",loginProps("Description")=marker_"|login",loginProps("Enabled")=1,loginProps("AutheEnabled")=64,loginProps("CSPZENEnabled")=0,loginProps("ServeFiles")=1,loginProps("Path")=assetRoot_"/login",loginProps("Recurse")=0,loginProps("DispatchClass")=""
        If ##class(Security.Applications).Exists(loginPath) {
            Set sc=##class(Security.Applications).Modify(loginPath,.loginProps)
        } Else {
            Set sc=##class(Security.Applications).Create(loginPath,.loginProps)
            If $SYSTEM.Status.IsOK(sc) Set newLoginApp=1
        }
        If $SYSTEM.Status.IsError(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
        Set $Namespace=old
        Set ^FHIR.OpenAPI.Config($Namespace,"loginPath")=loginPath,^FHIR.OpenAPI.Config($Namespace,"assetRoot")=assetRoot,^FHIR.OpenAPI.Config($Namespace,"managedAssets")=managedAssets
        For name="index.html","app.js","style.css" Set ^FHIR.OpenAPI.Config($Namespace,"assets",name)=assets(name)
        Set ^FHIR.OpenAPI.Config($Namespace,"webPath")=webPath,^FHIR.OpenAPI.Config($Namespace,"version")="0.1.0"
    } Catch ex {
        Set sc=ex.AsStatus()
        Set $Namespace="%SYS"
        If newLoginApp Do ##class(Security.Applications).Delete(loginPath)
        If newApp Do ##class(Security.Applications).Delete(webPath)
        If newRole Do ##class(Security.Roles).Delete(role)
        If newResource Do ##class(Security.Resources).Delete(resource)
    }
    Set $Namespace=old
    Quit sc
}
/// Uninstall only cleans up web applications and static resources with ownership markers; security objects are retained for admin reference checks.
ClassMethod Uninstall() As %Status
{
    If '$SYSTEM.Security.Check("%Admin_Secure","USE") Quit $SYSTEM.Status.Error(5001,"Uninstall requires %Admin_Secure privilege.")
    Set old=$Namespace,path=$Get(^FHIR.OpenAPI.Config($Namespace,"webPath")),loginPath=$Get(^FHIR.OpenAPI.Config($Namespace,"loginPath")),marker="IRIS FHIR OpenAPI|"_old,sc=1
    Try {
        Set $Namespace="%SYS"
        If path'="",##class(Security.Applications).Exists(path) {
            Set sc=##class(Security.Applications).Get(path,.props)
            If props("Description")'=marker Throw ##class(%Exception.General).%New("Refusing to delete another application.")
            Set sc=##class(Security.Applications).Delete(path)
        }
        If loginPath'="",##class(Security.Applications).Exists(loginPath) {
            Set sc=##class(Security.Applications).Get(loginPath,.loginProps)
            If loginProps("Description")'=(marker_"|login") Throw ##class(%Exception.General).%New("Refusing to delete another login application.")
            Set sc=##class(Security.Applications).Delete(loginPath)
        }
        Set $Namespace=old
        If $Get(^FHIR.OpenAPI.Config($Namespace,"managedAssets")) {
            Set root=$Get(^FHIR.OpenAPI.Config($Namespace,"assetRoot")),expected=$SYSTEM.Util.InstallDirectory()_"csp/fhir-openapi-"_$ZConvert($Namespace,"L")
            If root'=expected Throw ##class(%Exception.General).%New("Static file directory does not match ownership boundaries; deletion rejected.")
            For name="index.html","app.js","style.css","login/index.html","login/login.js","login/login.css" {
                If ##class(%File).Exists(root_"/"_name) Set deleted=##class(%File).Delete(root_"/"_name)
            }
        }
        Kill ^FHIR.OpenAPI.Config($Namespace,"loginPath"),^FHIR.OpenAPI.Config($Namespace,"assetRoot"),^FHIR.OpenAPI.Config($Namespace,"managedAssets")
        If $SYSTEM.Status.IsOK(sc) Kill ^FHIR.OpenAPI.Config($Namespace,"assets"),^FHIR.OpenAPI.Config($Namespace,"webPath"),^FHIR.OpenAPI.Config($Namespace,"version")
        Write "Module security roles/resources are retained; they may be deleted by the admin once references are verified.",!
    } Catch ex { Set sc=ex.AsStatus() }
    Set $Namespace=old
    Quit sc
}
}
