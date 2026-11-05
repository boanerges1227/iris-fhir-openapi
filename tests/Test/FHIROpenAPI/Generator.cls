Class Test.FHIROpenAPI.Generator Extends %UnitTest.TestCase
{
/// 使用显式公开地址，防止内部源地址进入 servers。
ClassMethod Options() As %DynamicObject
{
    Quit {"publicBaseUrl":"https://api.example.org/fhir/r4/","info":{"title":"FHIR API","version":"1.0.0"},"security":{"mode":"bearer"}}
}
/// 生成辅助仅调用真实 Parser、Options 与 Generator。
ClassMethod Build(cap, ByRef report, options = "")
{
    Set report=##class(FHIR.OpenAPI.Report).New()
    If '$IsObject(options) Set options=..Options()
    Set options=##class(FHIR.OpenAPI.Options).Validate(options,report)
    Set model=##class(FHIR.OpenAPI.Capability.Parser).Parse(cap,report)
    Quit ##class(FHIR.OpenAPI.Generator).Generate(model,options,report)
}
/// 读取与搜索路径准确，日期搜索不能被误建模成 JSON date。
Method TestReadAndSearch()
{
    Set spec=..Build(##class(Test.FHIROpenAPI.Core).Capability(),.report)
    Do $$$AssertTrue(spec.paths.%IsDefined("/Patient/{id}"))
    Do $$$AssertTrue(spec.paths.%IsDefined("/Patient/_search"))
    Set search=spec.paths.%Get("/Patient").get,param=search.parameters.%Get(0)
    Do $$$AssertEquals(param.schema.type,"string")
    Do $$$AssertEquals(spec.servers.%Get(0).url,"https://api.example.org/fhir/r4")
    Do $$$AssertEquals(spec.openapi,"3.0.3")
}
/// batch 与 transaction 必须合并一个根 POST，不能静默覆盖。
Method TestRootMerge()
{
    Set cap=##class(Test.FHIROpenAPI.Core).Capability(),rest=cap.rest.%Get(0),rest.interaction=[{"code":"batch"},{"code":"transaction"}]
    Set spec=..Build(cap,.report),op=spec.paths.%Get("/").post
    Set types=spec.components.schemas.BundleRequest.properties.type.enum
    Do $$$AssertEquals(types.%Size(),2)
    Do $$$AssertTrue(op.responses.%IsDefined("200"))
    Do $$$AssertTrue('(##class(FHIR.OpenAPI.Report).HasErrors(report)))
}
/// 集合条件更新允许无客户端 id 的创建，不依赖 updateCreate。
Method TestConditionalUpdate()
{
    Set cap=##class(Test.FHIROpenAPI.Core).Capability(),r=cap.rest.%Get(0).resource.%Get(0)
    Set r.interaction=[{"code":"update"}]
    Do r.%Set("conditionalUpdate",1,"boolean"),r.%Set("updateCreate",0,"boolean")
    Set options=..Options(),dummy=0
    Do options.%Set("includeConditionalInteractions",1,"boolean")
    Set spec=..Build(cap,.report,options)
    Do $$$AssertTrue(spec.paths.%Get("/Patient").put.responses.%IsDefined("201"))
    Do $$$AssertTrue('(spec.paths.%Get("/Patient/{id}").put.responses.%IsDefined("201")))
    Do $$$AssertTrue('(spec.paths.%Get("/Patient/{id}").put.responses.%IsDefined("204")))
}
/// 条件创建命中返回200，删除保留202，条件读保留304。
Method TestConditionalResponses()
{
    Set cap=##class(Test.FHIROpenAPI.Core).Capability(),r=cap.rest.%Get(0).resource.%Get(0)
    Set r.interaction=[{"code":"read"},{"code":"create"},{"code":"delete"}],r.conditionalRead="full-support"
    Do r.%Set("conditionalCreate",1,"boolean")
    Set spec=..Build(cap,.report)
    Do $$$AssertTrue(spec.paths.%Get("/Patient").post.responses.%IsDefined("200"))
    Do $$$AssertTrue(spec.paths.%Get("/Patient/{id}").delete.responses.%IsDefined("202"))
    Do $$$AssertTrue(spec.paths.%Get("/Patient/{id}").get.responses.%IsDefined("304"))
}
/// 未声明补丁媒体类型时不猜测支持 JSON Patch。
Method TestPatchFormats()
{
    Set cap=##class(Test.FHIROpenAPI.Core).Capability(),r=cap.rest.%Get(0).resource.%Get(0),r.interaction=[{"code":"patch"}]
    Set spec=..Build(cap,.report)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"PATCH_FORMAT_UNRESOLVED"))
    Do $$$AssertTrue('(spec.paths.%IsDefined("/Patient/{id}")))
    Set cap.patchFormat=["application/json-patch+json"],spec=..Build(cap,.report)
    Do $$$AssertTrue(spec.paths.%Get("/Patient/{id}").patch.requestBody.content.%IsDefined("application/json-patch+json"))
}
/// 全部资源和交互均由声明决定，不能膨胀到其他资源。
Method TestFiltering()
{
    Set cap=##class(Test.FHIROpenAPI.Core).Capability(),options=..Options(),options.resources={"exclude":["Patient"]}
    Set spec=..Build(cap,.report,options)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"EMPTY_EXPORT"))
}
/// 未知配置字段和拼错的资源筛选必须拒绝。
Method TestOptions()
{
    Set options=..Options(),options.securty={},report=##class(FHIR.OpenAPI.Report).New()
    Set normalized=##class(FHIR.OpenAPI.Options).Validate(options,report)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasCode(report,"CONFIG_UNKNOWN_FIELD"))
    Set options=..Options(),options.publicBaseUrl="https://user:password@example.org/fhir",report=##class(FHIR.OpenAPI.Report).New()
    Set normalized=##class(FHIR.OpenAPI.Options).Validate(options,report)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Report).HasErrors(report))
}
/// 产物允许 FHIR 扩展并具有自包含引用，重复生成稳定。
Method TestSchemaAndDeterminism()
{
    Set cap=##class(Test.FHIROpenAPI.Core).Capability(),spec=..Build(cap,.report),other=..Build(cap,.second)
    Do $$$AssertEquals(##class(FHIR.OpenAPI.JSON).Text(spec),##class(FHIR.OpenAPI.JSON).Text(other))
    Do $$$AssertTrue(spec.components.schemas.Patient.additionalProperties)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Validator).Check(spec,report))
    Do spec.paths.%Get("/Patient/{id}").get.responses.%Set("200",{"$ref":"#/components/responses/Missing"})
    Do $$$AssertTrue('(##class(FHIR.OpenAPI.Validator).Check(spec,report)))
}
/// Bundle 作为可读资源时，不能覆盖 batch 使用的共享 Bundle 结构。
Method TestBundleResourceAndTransaction()
{
    Set cap=##class(Test.FHIROpenAPI.Core).Capability(),rest=cap.rest.%Get(0)
    Do rest.resource.%Push({"type":"Bundle","interaction":[{"code":"read"}]})
    Set rest.interaction=[{"code":"transaction"}]
    Set spec=..Build(cap,.report)
    Do $$$AssertTrue(spec.paths.%IsDefined("/Bundle/{id}"))
    Do $$$AssertTrue(spec.components.schemas.BundleRequest.properties.%IsDefined("type"))
}
/// metadata 独立开关不应被标准交互筛选列表意外排除。
Method TestMetadataSelection()
{
    Set options=..Options(),options.interactions={"include":["read"]}
    Do options.%Set("includeMetadata",1,"boolean")
    Set spec=..Build(##class(Test.FHIROpenAPI.Core).Capability(),.report,options)
    Do $$$AssertTrue(spec.paths.%IsDefined("/metadata"))
}
/// 使用完整 R4 名称集合和一万搜索参数验证规模，不虚构不存在的150种资源。
Method TestLargeCapability()
{
    Set cap=##class(Test.FHIROpenAPI.Core).Capability(),resources=[],names=##class(FHIR.OpenAPI.Capability.Parser).ResourceNames(),total=0
    For i=2:1:$Length(names,"|")-1 {
        Set name=$Piece(names,"|",i),r={"type":(name),"interaction":[{"code":"read"},{"code":"search-type"}],"searchParam":[]}
        For j=1:1:69 {
            If total=10000 Quit
            Do r.searchParam.%Push({"name":("param"_j),"type":"string"})
            Set total=total+1
        }
        Do resources.%Push(r)
    }
    Set cap.rest.%Get(0).resource=resources,report=##class(FHIR.OpenAPI.Report).New()
    Set model=##class(FHIR.OpenAPI.Capability.Parser).Parse(cap,report),options=##class(FHIR.OpenAPI.Options).Validate(..Options(),report),start=$ZHOROLOG
    Set spec=##class(FHIR.OpenAPI.Generator).Generate(model,options,report),elapsed=$ZHOROLOG-start
    Do $$$AssertTrue(elapsed<5)
    Do $$$AssertEquals(total,10000)
    Do $$$AssertTrue(##class(FHIR.OpenAPI.Validator).Check(spec,report))
    Set stream=##class(FHIR.OpenAPI.JSON).Canonical(spec)
    Do $$$AssertTrue(stream.Size<26214400)
    Write "BENCHMARK resources=",resources.%Size()," searchParams=",total," generateSeconds=",elapsed," characters=",stream.Size,!
}
/// 可申请的 scope 不等于所有接口的必需 scope。
Method TestOAuthRequiredScopes()
{
    Set options=..Options(),options.security={"mode":"oauth2","flows":{"clientCredentials":{"tokenUrl":"https://auth.example.org/token","scopes":{"system/read":"系统读取"}},"authorizationCode":{"authorizationUrl":"https://auth.example.org/authorize","tokenUrl":"https://auth.example.org/token","scopes":{"patient/read":"患者读取"}}}}
    Set spec=..Build(##class(Test.FHIROpenAPI.Core).Capability(),.report,options)
    Do $$$AssertEquals(spec.security.%Get(0).FHIRAuth.%Size(),0)
}
/// OperationOutcome 自身的写操作不能产生两份完全相同的 oneOf。
Method TestOutcomeSuccessBody()
{
    Set cap=##class(Test.FHIROpenAPI.Core).Capability(),cap.rest.%Get(0).resource=[{"type":"OperationOutcome","interaction":[{"code":"create"}]}]
    Set spec=..Build(cap,.report),shape=spec.paths.%Get("/OperationOutcome").post.responses.%Get("201").content.%Get("application/fhir+json").schema
    Do $$$AssertTrue('(shape.%IsDefined("oneOf")))
}
/// 覆盖报告按声明交互分类，并保留每个未解析操作的可识别信息。
Method TestCoverageReport()
{
    Set cap=##class(Test.FHIROpenAPI.Core).Capability(),r=cap.rest.%Get(0).resource.%Get(0)
    Set r.interaction=[{"code":"read"},{"code":"patch"}],r.operation=[{"name":"custom-one","definition":"http://example.org/op1"},{"name":"custom-two","definition":"http://example.org/op2"}],cap.rest.%Get(0).interaction=[{"code":"transaction"}]
    Set options=..Options(),options.interactions={"include":["read","patch"]},spec=..Build(cap,.report,options)
    Do $$$AssertEquals(report.counts.excludedInteractions,1)
    Do $$$AssertEquals(report.counts.generatedInteractions,1)
    Do $$$AssertEquals(report.counts.unsupportedInteractions,1)
    Do $$$AssertEquals(report.omittedOperations.%Size(),2)
    Do $$$AssertEquals(report.omittedOperations.%Get(0).definition,"http://example.org/op1")
}
}
