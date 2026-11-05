Class FHIR.OpenAPI.Source.Request Extends %Net.HttpRequest
{
Property ConnectAddress As %String;
Property IdentityHost As %String;
/// The public GET entry point explicitly calls this class's connect and reader methods; the vendor Open/Read are private methods and cannot affect Send via override.
/// Only implements metadata GET; does not inherit automatic auth retry, proxy, or redirect behavior.
Method Get(location As %String = "", test As %Integer = 0, reset As %Boolean = 1, resetHeaderOnRedirect As %Boolean = 0) As %Status
{
    Set previous=$IO,sc=1,ownsDeadline='##class(FHIR.OpenAPI.Deadline).Active()
    If ownsDeadline Do ##class(FHIR.OpenAPI.Deadline).Start()
    Try {
        Set ..HttpResponse=##class(%Net.HttpResponse).%New()
        Set sc=..Open(.reused)
        If $SYSTEM.Status.IsError(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
        Use ..Device:(::"SCWD")
        Do $ZUtil(96,18,2,"RAW")
        Write "GET "
        If ..Https {
            // After the handshake, first verify identity, then send the URL and auth header to avoid handing credentials to a host with the wrong certificate.
            Write *-3
            Set sc=..CheckSSLCN(..IdentityHost,.certificate)
            If $SYSTEM.Status.IsError(sc) Throw ##class(%Exception.StatusException).CreateFromStatus(sc)
            Set ..SSLPeerCertificate=certificate
        }
        Set host=..IdentityHost
        If host[":" Set host="["_host_"]"
        If ((..Https)&(..Port'=443))!(('..Https)&(..Port'=80)) Set host=host_":"_..Port
        Set authorization=..GetHeader("Authorization")
        Write $ZConvert(location,"O","UTF8")," HTTP/1.1",$Char(13,10),"Host: ",host,$Char(13,10),"Accept: application/fhir+json",$Char(13,10),"Accept-Encoding: identity",$Char(13,10),"Connection: close",$Char(13,10)
        If authorization'="" Write "Authorization: ",authorization,$Char(13,10)
        Write $Char(13,10),*-3
        Set sc=..Read(..Device,15,$ZHOROLOG,"GET")
    } Catch ex { Set sc=ex.AsStatus() }
    Use previous
    If ..Device'="" { Close ..Device Set ..Device="" }
    If ownsDeadline Do ##class(FHIR.OpenAPI.Deadline).Stop()
    Quit sc
}
/// Connect to the administrator's fixed IP while preserving the logical host's SNI, Host, and certificate identity checks.
/// Do not let HttpRequest re-resolve DNS after the check, thus eliminating the address rebinding window.
Method Open(Output reused As %Boolean) As %Status
{
    Set ..OpenTimeout=##class(FHIR.OpenAPI.Deadline).Remaining(..OpenTimeout)
    Set reused=0,sc=1,dev="|TCP|"_($Random(900000000)+100000000)
    Try {
        If ..Https {
            Open dev:(..ConnectAddress:..Port:"SCWD"::8192:8192:/TCPNOXY:/TLS=..SSLConfiguration_"||"_..IdentityHost:/WRITETIMEOUT=..WriteTimeout):..OpenTimeout
        } Else {
            Open dev:(..ConnectAddress:..Port:"SCWD"::8192:8192:/TCPNOXY:/WRITETIMEOUT=..WriteTimeout):..OpenTimeout
        }
        If '$Test {
            Set sc=$SYSTEM.Status.Error(5001,"SOURCE_TIMEOUT")
        } Else {
            Set ..Device=dev,..SSLCheckIdentityInternal=$Select(..Https:..IdentityHost,1:"")
        }
    } Catch ex { Set sc=$SYSTEM.Status.Error(5001,"SOURCE_CONNECT_FAILED") }
    Quit sc
}
/// Metadata-specific HTTP/1.1 reader: each READ uses the remaining absolute budget to prevent slow trickle from resetting the timeout.
/// Supports Content-Length, chunked, and close-connection delimiting; body is always kept as raw UTF-8 bytes.
Method Read(device As %String, timeout As %Integer = 10, startTime As %Float, type As %String = "") As %Status
{
    Set sc=1,previous=$IO,response=..HttpResponse,data=..ResponseStream
    Try {
        Do ##class(FHIR.OpenAPI.Deadline).Check()
        Use device:(::"ASW")
        Do $ZUtil(96,18,2,"RAW")
        Set headers=0
        For interim=1:1:5 {
            Set line=..ReadLine(device,.headers)
            Set status=+$Piece(line," ",2)
            If (status<100)!(status>599) Throw ##class(%Exception.General).%New("SOURCE_HTTP_INVALID")
            Set response.StatusLine=line,response.StatusCode=status
            For {
                Set line=..ReadLine(device,.headers)
                Quit:line=""
                If '(line[":") Throw ##class(%Exception.General).%New("SOURCE_HTTP_INVALID")
                Set name=$ZConvert($Piece(line,":"),"U"),value=$ZStrip($Piece(line,":",2,*),"<>W")
                Do response.SetHeader(name,value)
            }
            If status'=100 Quit
        }
        Set length=response.GetHeader("Content-Length"),encoding=$ZConvert(response.GetHeader("Transfer-Encoding"),"L")
        Set response.ContentType=response.GetHeader("Content-Type")
        If response.GetHeader("Content-Encoding")'="" Throw ##class(%Exception.General).%New("SOURCE_ENCODING_UNSUPPORTED")
        Use device:(::"ASW")
        If (status=204)!(status=304)!(type="HEAD") {
            // No-body status does not wait for the server to send data.
        } ElseIf encoding="chunked" {
            For {
                Use device:(::"ASW")
                Set line=$Piece(..ReadLine(device,.headers),";",1),matcher=##class(%Regex.Matcher).%New("^[0-9A-Fa-f]{1,8}$",line)
                If 'matcher.Locate() Throw ##class(%Exception.General).%New("SOURCE_HTTP_INVALID")
                Set size=$ZHex(line)
                If size=0 {
                    For { Set line=..ReadLine(device,.headers) Quit:line="" }
                    Quit
                }
                If (data.Size+size)>10485760 Set data.LimitExceeded=1 Throw ##class(%Exception.General).%New("SOURCE_TOO_LARGE")
                Use device:(::"ASW")
                Do ..ReadBytes(device,data,size)
                Set rest="",budget=##class(FHIR.OpenAPI.Deadline).Remaining(15)
                Set rest=..PollRead(2)
                If $Length(rest)=1 Set rest=rest_..PollRead(1)
                If rest'=$Char(13,10) Throw ##class(%Exception.General).%New("SOURCE_HTTP_INVALID")
            }
        } ElseIf length'="" {
            Set matcher=##class(%Regex.Matcher).%New("^[0-9]{1,10}$",length)
            If 'matcher.Locate() Throw ##class(%Exception.General).%New("SOURCE_HTTP_INVALID")
            If length>10485760 Set data.LimitExceeded=1 Throw ##class(%Exception.General).%New("SOURCE_TOO_LARGE")
            Do ..ReadBytes(device,data,+length)
        } Else {
            For {
                Do ##class(FHIR.OpenAPI.Deadline).Check()
                Set chunk="",eof=0,budget=##class(FHIR.OpenAPI.Deadline).Remaining(15)
                Try { Set chunk=..PollRead(8192),complete=1 } Catch err {
                    If (err.Name["READ")!(err.Name["DISCONNECT") { Set eof=1,complete=1 } Else { Throw err }
                }
                If chunk'="" Do data.Write(chunk)
                Quit:eof
                If 'complete Throw ##class(%Exception.General).%New("SOURCE_TIMEOUT")
            }
        }
        Do data.Rewind()
        Set response.Data=data
    } Catch ex { Set sc=ex.AsStatus() }
    Use previous
    Quit sc
}
/// Single-line headers are protected by an independent byte cap; exceeding the length or trickle timeout is immediately rejected.
Method ReadLine(device As %String, ByRef total As %Integer) As %String
{
    Set line=""
    For {
        Set byte=..PollRead(1)
        Quit:byte=$Char(10)
        Set line=line_byte
        If $Length(line)>=16384 Throw ##class(%Exception.General).%New("SOURCE_HEADERS_TOO_LARGE")
    }
    Set total=total+$Length(line)
    If total>65536 Throw ##class(%Exception.General).%New("SOURCE_HEADERS_TOO_LARGE")
    Quit $Translate(line,$Char(13))
}
/// Read known-length blocks; the absolute budget is never reset by reading small amounts of data.
Method ReadBytes(device As %String, data As FHIR.OpenAPI.Source.BoundedStream, length As %Integer)
{
    Set remaining=length
    While remaining>0 {
        Set count=$Select(remaining>8192:8192,1:remaining),budget=##class(FHIR.OpenAPI.Deadline).Remaining(15),chunk=""
        Set chunk=..PollRead(count)
        Do data.Write(chunk)
        Set remaining=remaining-$Length(chunk)
    }
}
/// Non-blocking TCP reads prevent the lower layer from resetting the wait timer on every new byte; briefly yield the CPU when idle.
Method PollRead(count As %Integer) As %String
{
    Set idleStart=$ZHOROLOG,chunk=""
    For {
        Do ##class(FHIR.OpenAPI.Deadline).Check()
        Read chunk#count:0
        Quit:chunk'=""
        If ($ZHOROLOG-idleStart)>15 Throw ##class(%Exception.General).%New("SOURCE_TIMEOUT")
        Hang .001
    }
    Quit chunk
}
}
