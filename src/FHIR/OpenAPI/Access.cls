Class FHIR.OpenAPI.Access Extends %RegisteredObject
{
/// Include normalized namespace and digest in the name to avoid collisions like ABC-DEF vs. ABC_DEF.
ClassMethod Resource(namespace As %String = "") As %String
{
    If namespace="" Set namespace=$Namespace
    Set namespace=$ZConvert(namespace,"U"),digest=$SYSTEM.Encryption.SHAHash(256,namespace),hex="",digits="0123456789abcdef"
    For i=1:1:12 {
        Set byte=$Ascii(digest,i),hex=hex_$Extract(digits,(byte\16)+1)_$Extract(digits,(byte#16)+1)
    }
    Quit "FHIR_OpenAPI_"_$Extract($Translate(namespace,"%-.","___"),1,8)_"_"_hex
}
/// All business entry points check the same permission; direct Service calls cannot bypass REST.
ClassMethod Allowed() As %Boolean
{
    Quit $SYSTEM.Security.Check(..Resource(),"USE")
}
}
