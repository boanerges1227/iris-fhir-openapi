Class FHIR.OpenAPI.Deadline Extends %RegisteredObject
{
/// Deadline lives in the current process; not enabled by default when calling pure core directly.
ClassMethod Start(seconds As %Numeric = 30)
{
    Set ^||FHIROpenAPIDeadline=$ZHOROLOG+seconds
}
/// Actively interrupt during iteration and stream I/O; do not wait until generation completes before checking time.
ClassMethod Check()
{
    If $Data(^||FHIROpenAPIDeadline),($ZHOROLOG>=^||FHIROpenAPIDeadline) Throw ##class(%Exception.General).%New("GENERATION_TIMEOUT")
}
/// A single network wait must not exceed the remaining budget of the current request.
ClassMethod Remaining(fallback As %Numeric = 15) As %Numeric
{
    Do ..Check()
    Set remaining=fallback
    If $Data(^||FHIROpenAPIDeadline) Set remaining=$Select((^||FHIROpenAPIDeadline-$ZHOROLOG)<fallback:(^||FHIROpenAPIDeadline-$ZHOROLOG),1:fallback)
    Quit remaining
}
/// Request end must clean up process state to prevent the next request from inheriting an expired timer.
ClassMethod Stop()
{
    Kill ^||FHIROpenAPIDeadline
}
/// Data sources can establish their own budget when called directly; service calls inherit the outer budget.
ClassMethod Active() As %Boolean
{
    Quit $Data(^||FHIROpenAPIDeadline)>0
}
}
