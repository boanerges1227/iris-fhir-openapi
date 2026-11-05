Class Test.FHIROpenAPI.Sources Extends %UnitTest.TestCase
{
/// 未登记的来源不能通过本机元数据服务访问内部地址。
Method TestHTTPAllowlist()
{
    Set report=##class(FHIR.OpenAPI.Report).New(),context={}
    Set cap=##class(FHIR.OpenAPI.Source.HTTP).Fetch({"kind":"http","baseUrl":"http://127.0.0.1:1/fhir"},report,.context)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"SOURCE_NOT_ALLOWED"))
}
/// 带用户信息的 URL 必须拒绝，不能将密码传播到网络和日志。
Method TestURLCredentials()
{
    Set report=##class(FHIR.OpenAPI.Report).New(),context={}
    Set cap=##class(FHIR.OpenAPI.Source.HTTP).Fetch({"kind":"http","baseUrl":"http://user:secret@127.0.0.1/fhir"},report,.context)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"SOURCE_URL_INVALID"))
}
/// 本地来源只接受当前命名空间中的明确端点路径。
Method TestLocalPath()
{
    Set report=##class(FHIR.OpenAPI.Report).New(),context={}
    Set cap=##class(FHIR.OpenAPI.Source.Local).Fetch({"kind":"local","endpoint":"../other"},report,.context)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"LOCAL_ENDPOINT_INVALID"))
}
/// 实际访问合成 HTTP 服务，验证固定 IP 连接、认证和接收时限流。
Method TestHTTPIntegration()
{
    For path="fhir","redirect","private","invalid","large" {
        Set sc=##class(FHIR.OpenAPI.Config).RegisterSource("http://127.0.0.1:8091/"_path,"127.0.0.1","",1)
        Do $$$AssertStatusOK(sc)
    }
    Set source={"kind":"http","baseUrl":"http://127.0.0.1:8091/fhir"},report=##class(FHIR.OpenAPI.Report).New(),context={}
    Set cap=##class(FHIR.OpenAPI.Source.HTTP).Fetch(source,report,.context)
    Do $$$AssertTrue($IsObject(cap))
    If $IsObject(cap) Do $$$AssertEquals(cap.resourceType,"CapabilityStatement")
    Do $$$AssertEquals(context.visibility,"anonymous-source")
    For path="redirect","private","invalid","large" {
        Set source.baseUrl="http://127.0.0.1:8091/"_path,report=##class(FHIR.OpenAPI.Report).New()
        Set cap=##class(FHIR.OpenAPI.Source.HTTP).Fetch(source,report,.context)
        Set expected=$Select(path="redirect":"SOURCE_REDIRECT_BLOCKED",path="private":"SOURCE_AUTH_FAILED",path="large":"SOURCE_TOO_LARGE",1:"SOURCE_RESPONSE_INVALID")
        Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,expected))
    }
    Set source.baseUrl="http://127.0.0.1:8091/private",source.auth={"kind":"bearer","token":"synthetic-token"},report=##class(FHIR.OpenAPI.Report).New()
    Set cap=##class(FHIR.OpenAPI.Source.HTTP).Fetch(source,report,.context)
    Do $$$AssertTrue($IsObject(cap))
    Do $$$AssertTrue('(##class(FHIR.OpenAPI.JSON).Text(report)["synthetic-token"))
    Do $$$AssertEquals(context.visibility,"authenticated-source")
}
/// HTTPS 不得使用 VerifyPeer=None，且已登记配置被调低后也必须拒绝。
Method TestTLSVerificationPolicy()
{
    Set old=$Namespace,$Namespace="%SYS"
    Set p("Enabled")=1,p("Mode")=0,p("VerifyPeer")=0
    If ##class(Security.SSLConfigs).Exists("FHIRAPIUnsafe") { Set sc=##class(Security.SSLConfigs).Modify("FHIRAPIUnsafe",.p) } Else { Set sc=##class(Security.SSLConfigs).Create("FHIRAPIUnsafe",.p) }
    Set $Namespace=old
    Set sc=##class(FHIR.OpenAPI.Config).RegisterSource("https://localhost:8443/unsafe","127.0.0.1","FHIRAPIUnsafe")
    Do $$$AssertTrue($SYSTEM.Status.IsError(sc))
    Set $Namespace="%SYS",p("VerifyPeer")=2,p("CAFile")="/workspace/.local/tls-cert.pem"
    Set sc=##class(Security.SSLConfigs).Modify("FHIRAPIUnsafe",.p),$Namespace=old
    Set sc=##class(FHIR.OpenAPI.Config).RegisterSource("https://localhost:8443/unsafe","127.0.0.1","FHIRAPIUnsafe")
    Do $$$AssertStatusOK(sc)
    Set $Namespace="%SYS",p("VerifyPeer")=0
    Set sc=##class(Security.SSLConfigs).Modify("FHIRAPIUnsafe",.p),$Namespace=old
    Set report=##class(FHIR.OpenAPI.Report).New(),context={}
    Set cap=##class(FHIR.OpenAPI.Source.HTTP).Fetch({"kind":"http","baseUrl":"https://localhost:8443/unsafe"},report,.context)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"SOURCE_TLS_CONFIG_UNSAFE"))
}
/// 慢速逐字节响应必须在剩余预算内退出，不等响应全部收完。
Method TestHTTPDeadline()
{
    Set sc=##class(FHIR.OpenAPI.Config).RegisterSource("http://127.0.0.1:8091/slow","127.0.0.1","",1)
    Set report=##class(FHIR.OpenAPI.Report).New(),context={},start=$ZHOROLOG
    Do ##class(FHIR.OpenAPI.Deadline).Start(.2)
    Set cap=##class(FHIR.OpenAPI.Source.HTTP).Fetch({"kind":"http","baseUrl":"http://127.0.0.1:8091/slow"},report,.context)
    Do ##class(FHIR.OpenAPI.Deadline).Stop()
    Do $$$AssertTrue(($ZHOROLOG-start)<1.5)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"SOURCE_TIMEOUT"))
}
/// 未解析域名仍能经登记 IP 连接，证明公开 GET 没有退回厂商的私有 DNS 连接。
Method TestPinnedDestination()
{
    Set sc=##class(FHIR.OpenAPI.Config).RegisterSource("http://metadata-source.invalid:8091/fhir","127.0.0.1","",1)
    Set report=##class(FHIR.OpenAPI.Report).New(),context={}
    Set cap=##class(FHIR.OpenAPI.Source.HTTP).Fetch({"kind":"http","baseUrl":"http://metadata-source.invalid:8091/fhir"},report,.context)
    Do $$$AssertTrue($IsObject(cap))
}
/// 真实 TLS 握手验证可信链、逻辑主机名和不受信的同名证书三种情况。
Method TestTLSActual()
{
    Set old=$Namespace,$Namespace="%SYS"
    For name="FHIRAPITestTrusted","FHIRAPITestUntrusted" {
        Kill p
        Set p("Enabled")=1,p("Type")=0,p("VerifyPeer")=2,p("CAFile")=$Select(name="FHIRAPITestTrusted":"/workspace/.local/tls-cert.pem",1:"/etc/ssl/certs/ca-certificates.crt")
        If ##class(Security.SSLConfigs).Exists(name) { Set sc=##class(Security.SSLConfigs).Modify(name,.p) } Else { Set sc=##class(Security.SSLConfigs).Create(name,.p) }
    }
    Set $Namespace=old
    For mode="trusted","wrong-host","untrusted" {
        Set url=$Select(mode="wrong-host":"https://127.0.0.1:8443/fhir",1:"https://localhost:8443/"_mode)
        Set ssl=$Select(mode="untrusted":"FHIRAPITestUntrusted",1:"FHIRAPITestTrusted")
        Set sc=##class(FHIR.OpenAPI.Config).RegisterSource(url,"127.0.0.1",ssl)
        Do $$$AssertStatusOK(sc)
        Set report=##class(FHIR.OpenAPI.Report).New(),context={},cap=##class(FHIR.OpenAPI.Source.HTTP).Fetch({"kind":"http","baseUrl":(url)},report,.context)
        Do $$$AssertEquals($IsObject(cap),(mode="trusted"))
    }
}
}
