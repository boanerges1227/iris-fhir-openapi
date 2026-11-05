Class FHIR.OpenAPI.Generator Extends %RegisteredObject
{
/// Pure generation entry point: no network/DB access, only consumes the capability model and explicit configuration.
ClassMethod Generate(model As %DynamicObject, options As %DynamicObject, report As %DynamicObject) As %DynamicObject
{
    Set spec={"openapi":"3.0.3","info":(options.info),"servers":[{"url":(options.publicBaseUrl)}],"paths":{},"components":{"schemas":(##class(FHIR.OpenAPI.Schema.Gateway).Build())},"x-fhir-version":"4.0.1","x-fhir-schema-level":"gateway","x-generator-version":"0.1.0"}
    Do ##class(FHIR.OpenAPI.Mapping.Security).Apply(spec,options.security,report)
    Do ##class(FHIR.OpenAPI.Report).Add(report,"GATEWAY_SCHEMA_SIMPLIFIED","info","Simplified structure; not full FHIR/IG validation.")
    Set selected=0,declared=0,excluded=0,generated=0,unsupported=0
    For field="include","exclude" {
        Set filter=options.resources.%Get(field)
        If '$IsObject(filter) Continue
        For i=0:1:filter.%Size()-1 {
            If 'model.resources.%IsDefined(filter.%Get(i)) Do ##class(FHIR.OpenAPI.Report).Add(report,"RESOURCE_FILTER_UNKNOWN","error","Resource not declared in source.","/resources/"_field)
        }
    }
    Set iter=model.resources.%GetIterator()
    While iter.%GetNext(.resource,.r) {
    Do ##class(FHIR.OpenAPI.Deadline).Check()
        Set include=1
        If options.resources.%IsDefined("include") Set include=##class(FHIR.OpenAPI.Options).Contains(options.resources.include,resource)
        If ##class(FHIR.OpenAPI.Options).Contains(options.resources.%Get("exclude"),resource) Set include=0
        Set declared=declared+r.interactions.%Size()
        If 'include Set excluded=excluded+r.interactions.%Size() Continue
        Set selected=selected+1
        If 'spec.components.schemas.%IsDefined(resource) Do spec.components.schemas.%Set(resource,##class(FHIR.OpenAPI.Schema.Gateway).Resource(resource))
        If r.profiles.%Size() {
            Do spec.components.schemas.%Get(resource).%Set("x-fhir-profiles",r.profiles)
            Do ##class(FHIR.OpenAPI.Report).Add(report,"PROFILE_NOT_EXPANDED","warning","Profile references preserved; field constraints were not generated.","",resource)
        }
        If r.searchParams.%Size() Do ##class(FHIR.OpenAPI.Report).Add(report,"SEARCH_SEMANTICS_PARTIAL","warning","Repeats, modifiers, and chained queries are not fully modeled; values are passed as raw strings.","",resource)
        Set flags=##class(FHIR.OpenAPI.JSON).Copy(r.flags),flags.patchFormats=model.patchFormats
        Set it=r.interactions.%GetIterator()
        While it.%GetNext(.code,.v) {
            If options.interactions.%IsDefined("include"),'##class(FHIR.OpenAPI.Options).Contains(options.interactions.include,code) Set excluded=excluded+1 Continue
            Set path="/"_resource,method="get",supported=1
            If code="read" Set path=path_"/{id}"
            If code="vread" Set path=path_"/{id}/_history/{vid}"
            If code="create" Set method="post"
            If code="update" Set path=path_"/{id}",method="put"
            If code="delete" Set path=path_"/{id}",method="delete"
            If code="history-instance" Set path=path_"/{id}/_history"
            If code="history-type" Set path=path_"/_history"
            If code="patch" {
                Set path=path_"/{id}",method="patch",supported=0
                For i=0:1:model.patchFormats.%Size()-1 {
                    If (model.patchFormats.%Get(i)="application/json-patch+json")!(model.patchFormats.%Get(i)="application/fhir+json") Set supported=1
                }
                If 'supported Do ##class(FHIR.OpenAPI.Report).Add(report,"PATCH_FORMAT_UNRESOLVED","warning","Patch format not declared for initial release support; PATCH omitted.","",resource,code)
                If flags.%Get("conditionalUpdate") Do ##class(FHIR.OpenAPI.Report).Add(report,"CONDITIONAL_PATCH_NOT_MODELED","warning","Initial release does not export collection-level conditional PATCH.","",resource,code)
            }
            If 'supported Set unsupported=unsupported+1 Continue
            If code="search-type",'options.searchMethods.%Size() Set excluded=excluded+1 Continue
            Set generated=generated+1
            If code="search-type" {
                If ##class(FHIR.OpenAPI.Options).Contains(options.searchMethods,"GET") Do ##class(FHIR.OpenAPI.Mapping.Interactions).Add(spec,path,"get",code,resource,flags,r.searchParams,options,report)
                If ##class(FHIR.OpenAPI.Options).Contains(options.searchMethods,"POST") Do ##class(FHIR.OpenAPI.Mapping.Interactions).Add(spec,path_"/_search","post",code,resource,flags,r.searchParams,options,report)
            } Else {
                Do ##class(FHIR.OpenAPI.Mapping.Interactions).Add(spec,path,method,code,resource,flags,r.searchParams,options,report)
            }
            If options.includeConditionalInteractions {
                If code="update",flags.%Get("conditionalUpdate") Do ##class(FHIR.OpenAPI.Mapping.Interactions).Add(spec,"/"_resource,"put",code,resource,flags,r.searchParams,options,report,1)
                If code="delete",flags.%Get("conditionalDelete","not-supported")'="not-supported" Do ##class(FHIR.OpenAPI.Mapping.Interactions).Add(spec,"/"_resource,"delete",code,resource,flags,r.searchParams,options,report,1)
            }
        }
    }
    // Every declared interaction must fall into exactly one of: generated, excluded, or unsupported; HTTP methods are counted separately.
    For code="batch","transaction","history-system","search-system" {
        If 'model.interactions.%IsDefined(code) Continue
        If options.interactions.%IsDefined("include"),'##class(FHIR.OpenAPI.Options).Contains(options.interactions.include,code) Set excluded=excluded+1 Continue
        If code="search-system",'options.searchMethods.%Size() Set excluded=excluded+1 Continue
        Set generated=generated+1
    }
    Set rootTypes=[],rootReplies=[],hasBatch=0
    For code="batch","transaction" {
        If 'model.interactions.%IsDefined(code) Continue
        If options.interactions.%IsDefined("include"),'##class(FHIR.OpenAPI.Options).Contains(options.interactions.include,code) Continue
        Do rootTypes.%Push(code),rootReplies.%Push(code_"-response")
        Set hasBatch=1
    }
    If hasBatch {
        Set req=##class(FHIR.OpenAPI.JSON).Copy(spec.components.schemas.Bundle),req.properties.type.enum=rootTypes
        Set resp=##class(FHIR.OpenAPI.JSON).Copy(spec.components.schemas.Bundle),resp.properties.type.enum=rootReplies
        Do req.required.%Push("type"),resp.required.%Push("type")
        Set spec.components.schemas.BundleRequest=req,spec.components.schemas.BundleResponse=resp
        // Shared root POST is generated only once; filtering is already done above, so a single code won't cause another capability to be dropped.
        Set rootOptions=##class(FHIR.OpenAPI.JSON).Copy(options),rootOptions.interactions={}
        Do ##class(FHIR.OpenAPI.Mapping.Interactions).Add(spec,"/","post","batch","System",{},model.searchParams,rootOptions,report)
        Set spec.paths.%Get("/").post.summary="batch / transaction (declared Bundle.type only)"
    }
    If model.interactions.%IsDefined("history-system") Do ##class(FHIR.OpenAPI.Mapping.Interactions).Add(spec,"/_history","get","history-system","System",{},model.searchParams,options,report)
    If model.interactions.%IsDefined("search-system") {
        If ##class(FHIR.OpenAPI.Options).Contains(options.searchMethods,"GET") Do ##class(FHIR.OpenAPI.Mapping.Interactions).Add(spec,"/","get","search-system","System",{},model.searchParams,options,report)
        If ##class(FHIR.OpenAPI.Options).Contains(options.searchMethods,"POST") Do ##class(FHIR.OpenAPI.Mapping.Interactions).Add(spec,"/_search","post","search-system","System",{},model.searchParams,options,report)
    }
    If options.includeMetadata Do ##class(FHIR.OpenAPI.Mapping.Interactions).Add(spec,"/metadata","get","metadata","System",{},model.searchParams,options,report)
    If 'spec.paths.%Size() Do ##class(FHIR.OpenAPI.Report).Add(report,"EMPTY_EXPORT","error","No interfaces to export after filtering.")
    Set report.counts.selectedResources=selected,report.counts.declaredInteractions=declared+model.interactions.%Size(),report.counts.excludedInteractions=excluded,report.counts.generatedInteractions=generated,report.counts.unsupportedInteractions=unsupported
    Set report.counts.customOperations=model.operations.%Size(),report.counts.skippedCustomOperations=model.operations.%Size()
    Set operations=0,it=spec.paths.%GetIterator()
    While it.%GetNext(.path,.item) { Set operations=operations+item.%Size() }
    Set report.counts.generatedOperations=operations
    Quit spec
}
}
