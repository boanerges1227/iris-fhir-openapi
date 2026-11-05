Class Test.FHIROpenAPI.Service Extends %UnitTest.TestCase
{
/// 构造文件来源请求，内容与公开认证均为合成数据。
ClassMethod Request() As %DynamicObject
{
    Set r=##class(Test.FHIROpenAPI.Generator).Options()
    Set r.source={"kind":"file","capability":(##class(Test.FHIROpenAPI.Core).Capability())}
    Quit r
}
/// 统一服务应生成产物，strict 对 warning 必须阻断。
Method TestGenerateAndStrict()
{
    Set request=..Request(),sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
    Do $$$AssertEquals(result.httpStatus,200)
    Do $$$AssertTrue($IsObject(result.openapi))
    Set request.failurePolicy="strict",sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
    Do $$$AssertEquals(result.httpStatus,422)
    Do $$$AssertTrue('$IsObject(result.openapi))
}
/// 两次相同输入的规范完全相同，改变快照时拒绝旧选择。
Method TestSnapshot()
{
    Set request=..Request(),sc=##class(FHIR.OpenAPI.Service).Inspect(request,.preview)
    Set request.expectedSourceHash=preview.sourceHash,sc=##class(FHIR.OpenAPI.Service).Generate(request,.first)
    Set sc=##class(FHIR.OpenAPI.Service).Generate(request,.second)
    Do $$$AssertEquals(##class(FHIR.OpenAPI.JSON).Text(first.openapi),##class(FHIR.OpenAPI.JSON).Text(second.openapi))
    Set request.source.capability.name="Changed",sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
    Do $$$AssertEquals(result.httpStatus,409)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(result.report,"SOURCE_CHANGED"))
}
/// 上传文件不得通过任意服务端路径读取，拼错数据源字段必须拒绝。
Method TestSourceValidation()
{
    Set request=..Request(),request.source.path="/etc/passwd",sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
    Do $$$AssertEquals(result.httpStatus,400)
    Set request=..Request(),request.resources={"include":["Patien"]},sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
    Do $$$AssertEquals(result.httpStatus,400)
}
/// 命名空间规范化不能使不同 namespace 共用同一个安全资源。
Method TestResourceIdentity()
{
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Access).Resource("ABC-DEF")'=##class(FHIR.OpenAPI.Access).Resource("ABC_DEF"))
}
/// 复用 CLI 输出变量时，坏输入也必须清空旧规范并返回本次错误报告。
Method TestCLIOutputs()
{
    Set input=##class(FHIR.OpenAPI.JSON).Canonical(..Request()),sc=##class(FHIR.OpenAPI.CLI).Generate(input,.spec,.report)
    Do $$$AssertStatusOK(sc)
    Set bad=##class(%Stream.TmpCharacter).%New()
    Do bad.Write("{invalid"),bad.Rewind()
    Set sc=##class(FHIR.OpenAPI.CLI).Generate(bad,.spec,.report)
    Do $$$AssertTrue($SYSTEM.Status.IsError(sc))
    Do $$$AssertEquals(spec,"")
    Set parsed=##class(%DynamicObject).%FromJSON(report)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(parsed,"CONFIG_INVALID"))
}
/// HTTP 并发测试使用的临时锁持有者，绝不作为产品方法发布。
ClassMethod HoldSlots()
{
    Lock +^FHIR.OpenAPI.Runtime($Namespace,"slot",1):0
    Lock +^FHIR.OpenAPI.Runtime($Namespace,"slot",2):0
    Write "SLOTS_HELD",!
    Hang 3
    Lock
}
}
