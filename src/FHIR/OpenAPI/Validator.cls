Class FHIR.OpenAPI.Validator Extends %RegisteredObject
{
/// Validate generation invariants; formal acceptance requires an independent OpenAPI validator.
ClassMethod Check(spec As %DynamicObject, report) As %Boolean
{
    Set it=spec.paths.%GetIterator()
    While it.%GetNext(.path,.item) {
        Set methods=item.%GetIterator()
        While methods.%GetNext(.method,.op) {
            Set id=op.%Get("operationId")
            If (id="")!$Data(ids(id)) Do ##class(FHIR.OpenAPI.Report).Add(report,"OPENAPI_OPERATION_ID_INVALID","error","Missing or duplicate operationId.",path)
            Set ids(id)=1
            If '$IsObject(op.%Get("responses")) Do ##class(FHIR.OpenAPI.Report).Add(report,"OPENAPI_RESPONSE_INVALID","error","Operation has no response.",path) Continue
            If 'op.responses.%Size() Do ##class(FHIR.OpenAPI.Report).Add(report,"OPENAPI_RESPONSE_INVALID","error","Operation has no response.",path)
            Set params=op.parameters
            For i=0:1:params.%Size()-1 {
                Set p=params.%Get(i)
                If p.%Get("in")="path",'p.%Get("required") Do ##class(FHIR.OpenAPI.Report).Add(report,"OPENAPI_PATH_PARAMETER_INVALID","error","Path parameter must be required.",path)
            }
        }
    }
    Do ..References(spec,spec,report)
    Quit '##class(FHIR.OpenAPI.Report).HasErrors(report)
}
/// Walk internal references segment by segment along JSON Pointer to avoid omissions and external dependencies.
ClassMethod References(value, root, report)
{
    If '$IsObject(value) Quit
    Do ##class(FHIR.OpenAPI.Deadline).Check()
    If 'value.%IsA("%DynamicArray"),value.%IsDefined("$ref") {
        Set ref=value.%Get("$ref"),node=root,ok=($Extract(ref,1,2)="#/")
        For i=2:1:$Length(ref,"/") {
            If 'ok Quit
            Set key=$Replace($Replace($Piece(ref,"/",i),"~1","/"),"~0","~")
            If '$IsObject(node) Set ok=0 Quit
            If 'node.%IsDefined(key) Set ok=0 Quit
            Set node=node.%Get(key)
        }
        If 'ok Do ##class(FHIR.OpenAPI.Report).Add(report,"OPENAPI_REFERENCE_INVALID","error","Found invalid or external reference.",ref)
    }
    Set it=value.%GetIterator()
    While it.%GetNext(.key,.child) { If $IsObject(child) Do ..References(child,root,report) }
}
}
