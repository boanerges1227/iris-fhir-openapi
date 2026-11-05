Class Test.FHIROpenAPI.Core Extends %UnitTest.TestCase
{
/// 构造最小的合成 R4 能力，不包含真实患者数据。
ClassMethod Capability() As %DynamicObject
{
    Quit {"resourceType":"CapabilityStatement","status":"active","kind":"instance","fhirVersion":"4.0.1","format":["json"],"implementation":{"url":"https://internal.invalid/fhir"},"rest":[{"mode":"server","resource":[{"type":"Patient","interaction":[{"code":"read"},{"code":"search-type"}],"searchParam":[{"name":"birthdate","type":"date"}]}]}]}
}
/// 防止将继承声明静默忽略而生成不完整的接口文档。
Method TestImports()
{
    Set cap=..Capability(),cap.imports=["http://example.org/capability/base"]
    Set report=##class(FHIR.OpenAPI.Report).New()
    Set model=##class(FHIR.OpenAPI.Capability.Parser).Parse(cap,report)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"CAPABILITY_IMPORTS_UNRESOLVED"))
}
/// 不同 FHIR 版本不得套用 R4 映射规则。
Method TestVersion()
{
    Set cap=..Capability(),cap.fhirVersion="5.0.0",report=##class(FHIR.OpenAPI.Report).New()
    Set model=##class(FHIR.OpenAPI.Capability.Parser).Parse(cap,report)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasErrors(report))
}
/// 不完整快照和未知修饰扩展必须阻断，防止过度声称完整性。
Method TestIncomplete()
{
    Set cap=..Capability(),cap.meta={"tag":[{"system":"http://terminology.hl7.org/CodeSystem/v3-ObservationValue","code":"SUBSETTED"}]},report=##class(FHIR.OpenAPI.Report).New()
    Set model=##class(FHIR.OpenAPI.Capability.Parser).Parse(cap,report)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"CAPABILITY_SUBSETTED"))
    Set cap=..Capability(),cap.modifierExtension=[{"url":"https://example.org/unknown","valueBoolean":true}],report=##class(FHIR.OpenAPI.Report).New()
    Set model=##class(FHIR.OpenAPI.Capability.Parser).Parse(cap,report)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"UNKNOWN_MODIFIER_EXTENSION"))
}
/// 资源名必须来自 R4 集合，不能由输入注入路径。
Method TestResourceName()
{
    Set cap=..Capability(),rest=cap.rest.%Get(0),res=rest.resource.%Get(0),res.type="../Patient",report=##class(FHIR.OpenAPI.Report).New()
    Set model=##class(FHIR.OpenAPI.Capability.Parser).Parse(cap,report)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasErrors(report))
}
/// 查询日期保留 FHIR 类型信息，冲突重复不能被后写内容覆盖。
Method TestSearchConflict()
{
    Set cap=..Capability(),rest=cap.rest.%Get(0),res=rest.resource.%Get(0)
    Do res.searchParam.%Push({"name":"birthdate","type":"token"})
    Set report=##class(FHIR.OpenAPI.Report).New(),model=##class(FHIR.OpenAPI.Capability.Parser).Parse(cap,report)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"CAPABILITY_CONFLICT"))
}
/// 序列化必须排序对象键，同时保留数组顺序。
Method TestCanonical()
{
    Set a={"z":1,"a":[2,1]},b={"a":[2,1],"z":1}
    Do $$$AssertEquals(##class(FHIR.OpenAPI.JSON).Text(a),##class(FHIR.OpenAPI.JSON).Text(b))
    Do $$$AssertEquals(##class(FHIR.OpenAPI.JSON).Text(a),"{""a"":[2,1],""z"":1}")
}
}
