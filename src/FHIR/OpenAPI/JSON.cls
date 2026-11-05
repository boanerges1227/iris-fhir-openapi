Class FHIR.OpenAPI.JSON Extends %RegisteredObject
{
/// Deep-copy a JSON object to prevent generation from mutating the caller's original capability snapshot.
ClassMethod Copy(value)
{
    Set stream=##class(%Stream.TmpCharacter).%New()
    Do value.%ToJSON(stream),stream.Rewind()
    Quit ##class(%DynamicAbstractObject).%FromJSON(stream)
}
/// Recursively sort object keys and serialize as a stream; array order is preserved as-is.
ClassMethod Canonical(value) As %Stream.Object
{
    Set out=##class(%Stream.TmpCharacter).%New()
    Do ..WriteValue(out,value,"object"),out.Rewind()
    Quit out
}
/// Small-document text interface for assertions and configuration, not for the full export file.
ClassMethod Text(value) As %String
{
    Set stream=..Canonical(value)
    Quit stream.Read(3641144)
}
/// Write a JSON value to a stream; key sorting uses a prefix to avoid numeric keys triggering numeric ordering.
ClassMethod WriteValue(out As %Stream.Object, value, kind As %String)
{
    Do ##class(FHIR.OpenAPI.Deadline).Check()
    If $IsObject(value) {
        If value.%IsA("%DynamicArray") {
            Do out.Write("[")
            For i=0:1:value.%Size()-1 {
                If i Do out.Write(",")
                Do ..WriteValue(out,value.%Get(i),value.%GetTypeOf(i))
            }
            Do out.Write("]")
        } Else {
            Do out.Write("{")
            Set iter=value.%GetIterator()
            While iter.%GetNext(.key,.item) { Set keys("x"_key)=key }
            Set key="",n=0
            For { Set key=$Order(keys(key)) Quit:key=""
                If n Do out.Write(",")
                Set name=keys(key)
                Do ..WriteValue(out,name,"string"),out.Write(":"),..WriteValue(out,value.%Get(name),value.%GetTypeOf(name))
                Set n=n+1
            }
            Do out.Write("}")
        }
    } Else {
        Set a=[]
        Do a.%Push(value,kind)
        Set encoded=a.%ToJSON()
        Do out.Write($Extract(encoded,2,*-1))
    }
}
/// Unified final UTF-8 byte stream generation; size limit is measured in actual encoded bytes.
ClassMethod Bytes(value, maxBytes As %Integer = 0) As %Stream.Object
{
    Set chars=..Canonical(value),out=##class(%Stream.TmpBinary).%New(),carry=""
    While 'chars.AtEnd {
        Do ##class(FHIR.OpenAPI.Deadline).Check()
        Set chunk=carry_chars.Read(32768),carry=""
        // Avoid the chunk boundary splitting a UTF-16 surrogate pair; carry the high surrogate to the next chunk.
        If 'chars.AtEnd,$Length(chunk) {
            Set last=$Ascii(chunk,$Length(chunk))
            If (last>=55296)&(last<=56319) Set carry=$Extract(chunk,*),chunk=$Extract(chunk,1,*-1)
        }
        Set encoded=$ZConvert(chunk,"O","UTF8")
        If maxBytes,(out.Size+$Length(encoded)>maxBytes) Throw ##class(%Exception.General).%New("OUTPUT_TOO_LARGE")
        Do out.Write(encoded)
    }
    Do out.Rewind()
    Quit out
}
}
