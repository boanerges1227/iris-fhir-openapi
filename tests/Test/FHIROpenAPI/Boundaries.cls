Class Test.FHIROpenAPI.Boundaries Extends %UnitTest.TestCase
{
/// 错误嵌套结构是输入错误，不应变成500或导致旧状态泄漏。
Method TestMalformedCapability()
{
    For mode="rest","resource","interaction","searchParam" {
        Set request=##class(Test.FHIROpenAPI.Service).Request(),cap=request.source.capability
        If mode="rest" Set cap.rest=["invalid"]
        If mode="resource" Set cap.rest.%Get(0).resource=["invalid"]
        If mode="interaction" Set cap.rest.%Get(0).resource.%Get(0).interaction=["invalid"]
        If mode="searchParam" Set cap.rest.%Get(0).resource.%Get(0).searchParam=["invalid"]
        Set sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
        Do $$$AssertEquals(result.httpStatus,422)
        Do $$$AssertTrue('$IsObject(result.openapi))
    }
}
/// 配置中的嵌套数组/标量不能被当作合法对象或 JSON 布尔值。
Method TestMalformedOptions()
{
    For field="info","resources","security" {
        Set request=##class(Test.FHIROpenAPI.Service).Request()
        Do request.%Set(field,[])
        Set sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
        Do $$$AssertEquals(result.httpStatus,400)
    }
}
/// 未知交互不能被忽略后声称完整；固定查询键不能注入控制字符。
Method TestUnknownInteraction()
{
    Set request=##class(Test.FHIROpenAPI.Service).Request(),r=request.source.capability.rest.%Get(0).resource.%Get(0)
    Do r.interaction.%Push({"code":"delete-history"})
    Set sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
    Do $$$AssertEquals(result.httpStatus,422)
}
/// 含分隔符的伪成员不能跨过两个合法枚举，未知字段也必须拒绝。
Method TestExactMembers()
{
    For kind="resource","interaction","option" {
        Set request=##class(Test.FHIROpenAPI.Service).Request(),r=request.source.capability.rest.%Get(0).resource.%Get(0)
        If kind="resource" Set r.type="Account|ActivityDefinition"
        If kind="interaction" Set r.interaction=[{"code":"read|vread"}]
        If kind="option" Do request.%Set("info|resources",{})
        Set sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
        Do $$$AssertEquals(result.httpStatus,$Select(kind="option":400,1:422))
    }
}
/// 被消费的 FHIR 标志与修饰字段必须严格验证。
Method TestMalformedFHIRFields()
{
    For mode="modifier","tag","delete","kind","search" {
        Set request=##class(Test.FHIROpenAPI.Service).Request(),cap=request.source.capability,r=cap.rest.%Get(0).resource.%Get(0)
        If mode="modifier" Set cap.modifierExtension="bad"
        If mode="tag" Set cap.meta={"tag":["bad"]}
        If mode="delete" Set r.conditionalDelete="typo",r.interaction=[{"code":"delete"}]
        If mode="kind" Set cap.kind="typo"
        If mode="search" Set r.searchParam.%Get(0).documentation={}
        Set sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
        Do $$$AssertEquals(result.httpStatus,422)
    }
}
/// 非字符串 API 元信息和非法 OAuth scopes 不能进入成功产物。
Method TestCopiedOptionTypes()
{
    For mode="version","title","scopes","description","flow" {
        Set request=##class(Test.FHIROpenAPI.Service).Request()
        If mode="version" Set request.info.version=1
        If mode="title" Do request.info.%Set("title",1,"boolean")
        If mode="description" Set request.info.description={}
        If mode="scopes" Set request.security={"mode":"oauth2","flows":{"clientCredentials":{"tokenUrl":"https://auth.example.org/token","scopes":[]}}}
        If mode="flow" Set request.security={"mode":"oauth2","flows":{"implicit":{"authorizationUrl":"https://auth.example.org/authorize","tokenUrl":"https://auth.example.org/token","scopes":{}}}}
        Set sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
        Do $$$AssertEquals(result.httpStatus,400)
    }
}
/// 字节限制以最终 UTF-8 计量；大段中文不得按字符数低估。
Method TestUTF8Size()
{
    Set request=##class(Test.FHIROpenAPI.Service).Request(),r=request.source.capability.rest.%Get(0).resource.%Get(0)
    Set r.interaction=[{"code":"search-type"},{"code":"update"},{"code":"delete"}],r.conditionalDelete="multiple",r.searchParam=[]
    Do r.%Set("conditionalUpdate",1,"boolean"),request.%Set("includeConditionalInteractions",1,"boolean")
    Set text=$Translate($Justify("",140000)," ",$Char(20013))
    For i=1:1:20 { Do r.searchParam.%Push({"name":("p"_i),"type":"string","documentation":(text)}) }
    Set sc=##class(FHIR.OpenAPI.Service).Generate(request,.result)
    Do $$$AssertEquals(result.httpStatus,422)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(result.report,"OUTPUT_TOO_LARGE"))
}
/// 已到期的执行上下文必须在实际工作中中止，不等完成后才标记超时。
Method TestDeadline()
{
    Do ##class(FHIR.OpenAPI.Deadline).Start(-1)
    Set timedOut=0
    Try { Set stream=##class(FHIR.OpenAPI.JSON).Canonical({"test":"value"}) } Catch ex { Set timedOut=(ex.Name="GENERATION_TIMEOUT") }
    Do ##class(FHIR.OpenAPI.Deadline).Stop()
    Do $$$AssertTrue(timedOut)
}
}
