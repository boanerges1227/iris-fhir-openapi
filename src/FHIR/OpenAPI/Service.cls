Class FHIR.OpenAPI.Service Extends %RegisteredObject
{
/// Preview and generation both invoke the permission-protected service; metadata and credentials are never persisted.
ClassMethod Inspect(request As %DynamicObject, ByRef result As %DynamicObject) As %Status
{
    Quit ..Execute(request,.result,0)
}
/// Generation entry point; the specification must be null on failure — no partial-success object download.
ClassMethod Generate(request As %DynamicObject, ByRef result As %DynamicObject) As %Status
{
    Quit ..Execute(request,.result,1)
}
/// Allocate two concurrent slots with a process lock; released automatically on exception or process exit.
ClassMethod Execute(request, ByRef result, generate As %Boolean) As %Status
{
    Set report=##class(FHIR.OpenAPI.Report).New(),result={"status":"error","httpStatus":422,"openapi":null,"report":(report)},slot=0,start=$ZHOROLOG
    If '##class(FHIR.OpenAPI.Access).Allowed() {
        Set result.httpStatus=403
        Do ##class(FHIR.OpenAPI.Report).Add(report,"FORBIDDEN","error","Requires module administrator USE privilege.")
        Quit 1
    }
    For n=1:1:2 {
        Lock +^FHIR.OpenAPI.Runtime($Namespace,"slot",n):0
        If $Test Set slot=n Quit
    }
    If 'slot Set result.httpStatus=429 Do ##class(FHIR.OpenAPI.Report).Add(report,"BUSY","error","Two concurrent task limit reached.") Quit 1
    Do ##class(FHIR.OpenAPI.Deadline).Start()
    Try {
        Do ..Process(request,result,generate)
        Set report.elapsedSeconds=$ZHOROLOG-start
        If report.elapsedSeconds>30 {
            Set result.openapi="",result.httpStatus=504
            Do result.%Set("openapi","","null")
            Do ##class(FHIR.OpenAPI.Report).Add(report,"GENERATION_TIMEOUT","error","Generation exceeded the 30-second limit.")
        }
        If result.httpStatus=200 Set result.status=report.status
    } Catch ex {
        Set name=ex.Name
        Set result.httpStatus=$Select(name="GENERATION_TIMEOUT":504,name="OUTPUT_TOO_LARGE":422,1:500),result.correlationId=$SYSTEM.Util.CreateGUID()
        Do result.%Set("openapi","","null")
        Do ##class(FHIR.OpenAPI.Report).Add(report,$Select(name="GENERATION_TIMEOUT":"GENERATION_TIMEOUT",name="OUTPUT_TOO_LARGE":"OUTPUT_TOO_LARGE",1:"INTERNAL_ERROR"),"error","Request timed out, output exceeded byte limit, or an internal error occurred; refer to diagnostic codes.")
        // Do not log exception text: upstream HTTP exceptions may contain URLs or authentication fields.
    }
    Do ##class(FHIR.OpenAPI.Deadline).Stop()
    Lock -^FHIR.OpenAPI.Runtime($Namespace,"slot",slot)
    // Only log non-sensitive summaries; log errors must not alter generation results.
    Try {
        Set message="FHIR.OpenAPI user="_$Username_" namespace="_$Namespace_" status="_result.httpStatus_" hash="_report.%Get("sourceHash")_" operations="_report.counts.%Get("generatedOperations",0)_" elapsed="_report.%Get("elapsedSeconds",0)
        Do ##class(%SYS.System).WriteToConsoleLog(message,0,0,"FHIR.OpenAPI")
    } Catch ignored {}
    Quit 1
}
/// Chain validation, collection, snapshot comparison, generation, and checking to keep semantics consistent across entry points.
ClassMethod Process(request, result, generate As %Boolean)
{
    Set report=result.report
    Do ##class(FHIR.OpenAPI.Options).Keys(request,"|source|expectedSourceHash|publicBaseUrl|info|resources|interactions|searchMethods|includeMetadata|includeConditionalInteractions|security|schemaMode|failurePolicy|",report)
    If '$IsObject(request) Set result.httpStatus=400 Quit
    Set source=request.%Get("source")
    If '##class(FHIR.OpenAPI.Source.Base).Validate(source,report) Set result.httpStatus=400 Quit
    If generate {
        Set raw=##class(FHIR.OpenAPI.JSON).Copy(request)
        If 'raw.%IsDefined("includeMetadata") Do raw.%Set("includeMetadata",(source.kind'="file"),"boolean")
        Set options=##class(FHIR.OpenAPI.Options).Validate(raw,report)
    }
    If ##class(FHIR.OpenAPI.Report).HasErrors(report) Set result.httpStatus=400 Quit
    Set cap=##class(FHIR.OpenAPI.Source.Base).Fetch(source,report,.context)
    If ##class(FHIR.OpenAPI.Report).HasErrors(report) {
        Set result.httpStatus=$Select(##class(FHIR.OpenAPI.Report).HasCode(report,"SOURCE_TIMEOUT"):504,##class(FHIR.OpenAPI.Report).HasCode(report,"SOURCE_TOO_LARGE"):413,source.kind="http":502,1:422)
        Quit
    }
    Set stream=##class(FHIR.OpenAPI.JSON).Bytes(cap),hash=$SYSTEM.Encryption.Base64Encode($SYSTEM.Encryption.SHAHashStream(256,stream,.sc))
    If $SYSTEM.Status.IsError(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
    Set result.sourceHash=hash,report.sourceHash=hash,report.source=context
    If request.%IsDefined("expectedSourceHash"),request.expectedSourceHash'=hash {
        Set result.httpStatus=409
        Do ##class(FHIR.OpenAPI.Report).Add(report,"SOURCE_CHANGED","error","Source snapshot has changed; please re-preview.")
        Quit
    }
    Set model=##class(FHIR.OpenAPI.Capability.Parser).Parse(cap,report)
    If ##class(FHIR.OpenAPI.Report).HasErrors(report) Quit
    If 'generate {
        Set result.resources=[],it=model.resources.%GetIterator()
        While it.%GetNext(.name,.r) { Do result.resources.%Push({"type":(name),"interactions":(r.interactions),"searchParameterCount":(r.searchParams.%Size())}) }
        Set result.systemInteractions=model.interactions,result.fhirVersion=model.fhirVersion,result.httpStatus=200
        Quit
    }
    Set spec=##class(FHIR.OpenAPI.Generator).Generate(model,options,report)
    Do spec.%Set("x-source-hash",hash)
    Set valid=##class(FHIR.OpenAPI.Validator).Check(spec,report)
    If 'valid Quit
    If options.failurePolicy="strict",report.status="warning" {
        Do ##class(FHIR.OpenAPI.Report).Add(report,"STRICT_POLICY_REJECTED","error","Strict mode rejects a spec containing warnings.")
        Quit
    }
    Set stream=##class(FHIR.OpenAPI.JSON).Bytes(spec,26214400)
    Set report.outputBytes=stream.Size,result.openapi=spec,result.httpStatus=200
}
}
