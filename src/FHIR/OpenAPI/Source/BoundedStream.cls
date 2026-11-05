Class FHIR.OpenAPI.Source.BoundedStream Extends %Stream.TmpBinary
{
Property LimitExceeded As %Boolean [ InitialExpression = 0 ];
/// Enforce byte limit during network receive writes, rather than checking size only after reading the entire response.
Method Write(pData As %String = "") As %Status
{
    Do ##class(FHIR.OpenAPI.Deadline).Check()
    If (..Size+$Length(pData))>10485760 {
        Set ..LimitExceeded=1
        Throw ##class(%Exception.General).%New("SOURCE_TOO_LARGE")
    }
    Quit ##super(pData)
}
}
