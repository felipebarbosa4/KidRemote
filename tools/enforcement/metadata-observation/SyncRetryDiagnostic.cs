using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

// Restricted flat RetryStore writer schema, not a permissive general JSON parser.
// Raw bytes/binding are transient arguments only. No raw text enters errors/results.
public static class Od51RetryDiagnostic {
    static readonly Regex Member = new Regex(
        @"\G[ \t\r\n]*""(?<key>[A-Za-z_]+)""[ \t\r\n]*:[ \t\r\n]*(?<value>true|false|-?(?:0|[1-9][0-9]*)|""[A-Za-z0-9_:-]*"")[ \t\r\n]*(?<end>[,}])",
        RegexOptions.CultureInvariant, TimeSpan.FromSeconds(1));
    static readonly string[] Required = {"format","pending","stopped","attempt","boot","due","delay","identity"};
    static Dictionary<string,object> Empty(string status, string failure) {
        return new Dictionary<string,object>(StringComparer.Ordinal) {
            {"status",status},{"failureCode",failure},{"checksumValidity","NOT_CHECKED"},
            {"schemaValidity","NOT_CHECKED"},{"pending",null},{"stopped",null},{"reason",null},
            {"attemptCount",null},{"delayMs",null},{"bootRecorded",null},{"deadlineRecorded",null},
            {"legacyReasonDerived",null}
        };
    }
    static string Crc(byte[] bytes) {
        uint crc=0xffffffffU;
        foreach(byte b in bytes) { crc ^= b; for(int i=0;i<8;i++) crc=(crc>>1)^((crc&1)!=0?0xedb88320U:0U); }
        return (crc^0xffffffffU).ToString("x8",CultureInfo.InvariantCulture);
    }
    static long Number(Dictionary<string,string> d,string key,long min,long max) {
        long n;
        if(!Regex.IsMatch(d[key],@"\A-?(?:0|[1-9][0-9]*)\z") ||
           !Int64.TryParse(d[key],NumberStyles.AllowLeadingSign,CultureInfo.InvariantCulture,out n) || n<min || n>max)
            throw new InvalidOperationException("RETRY_SCHEMA_INVALID");
        return n;
    }
    static bool Flag(Dictionary<string,string> d,string key) {
        if(d[key]!="true" && d[key]!="false") throw new InvalidOperationException("RETRY_SCHEMA_INVALID");
        return d[key]=="true";
    }
    public static Dictionary<string,object> Summarize(string frame) {
        var result=Empty("INVALID","RETRY_FRAME_INVALID");
        try {
            if(frame==null || frame.Length>4096) return Empty("INVALID","RETRY_BOUNDS");
            Match status=Regex.Match(frame,@"\AOD51RETRY\|HEX1\|(MISSING|NONREGULAR|UNREADABLE|TOO_LARGE)\r?\n\z");
            if(status.Success) return Empty(status.Groups[1].Value,"RETRY_"+status.Groups[1].Value);
            Match prefix=Regex.Match(frame,@"\AOD51RETRY\|HEX1\|DATA\r?\n");
            Match suffix=Regex.Match(frame,@"\r?\nOD51RETRY\|(END|CHANGED|READ_FAILED)\r?\n\z");
            if(!prefix.Success || !suffix.Success || suffix.Index<prefix.Length) return result;
            if(suffix.Groups[1].Value=="CHANGED") return Empty("CHANGED","RETRY_CHANGED_DURING_READ");
            if(suffix.Groups[1].Value=="READ_FAILED") return Empty("UNREADABLE","RETRY_UNREADABLE");
            string hex=frame.Substring(prefix.Length,suffix.Index-prefix.Length);
            // Transport whitespace never changes checksum-covered payload bytes.
            if(!Regex.IsMatch(hex,@"\A[ \t\r\n]*(?:[0-9a-f]{2}(?:[ \t\r\n]+[0-9a-f]{2})*)?[ \t\r\n]*\z"))
                return Empty("INVALID","RETRY_HEX_INVALID");
            MatchCollection pairs=Regex.Matches(hex,@"[0-9a-f]{2}");
            if(pairs.Count>1024) return Empty("INVALID","RETRY_BOUNDS");
            byte[] payload=new byte[pairs.Count];
            for(int i=0;i<pairs.Count;i++) payload[i]=Byte.Parse(pairs[i].Value,NumberStyles.HexNumber,CultureInfo.InvariantCulture);
            var utf8=new UTF8Encoding(false,true);
            string raw;
            try { raw=utf8.GetString(payload); } catch(DecoderFallbackException) { return Empty("INVALID","RETRY_ENCODING_INVALID"); }
            if(raw.Length<11 || raw[8]!='\n' || !Regex.IsMatch(raw.Substring(0,8),@"\A[0-9a-f]{8}\z")) return Empty("INVALID","RETRY_ENVELOPE_INVALID");
            string body=raw.Substring(9);
            if(Crc(utf8.GetBytes(body))!=raw.Substring(0,8)) {
                result=Empty("INVALID","RETRY_CHECKSUM_INVALID");result["checksumValidity"]="INVALID";return result;
            }
            result=Empty("INVALID","RETRY_SCHEMA_INVALID");result["checksumValidity"]="VALID";result["schemaValidity"]="INVALID";
            var values=new Dictionary<string,string>(StringComparer.Ordinal);
            int pos=0;while(pos<body.Length && " \t\r\n".IndexOf(body[pos])>=0) pos++;
            if(pos>=body.Length || body[pos++]!='{') return result;
            while(true) {
                Match m=Member.Match(body,pos);
                if(!m.Success || m.Index!=pos || values.Count>=9) return result;
                string key=m.Groups["key"].Value;
                if(Array.IndexOf(Required,key)<0 && key!="reason" || values.ContainsKey(key)) return result;
                values.Add(key,m.Groups["value"].Value);pos+=m.Length;
                if(m.Groups["end"].Value=="}") break;
            }
            if(body.Substring(pos).Trim(' ','\t','\r','\n').Length!=0) return result;
            foreach(string k in Required) if(!values.ContainsKey(k)) return result;
            if(values.Count!=8 && values.Count!=9) return result;
            Number(values,"format",1,1);
            bool pending=Flag(values,"pending"), stopped=Flag(values,"stopped");
            long count=Number(values,"attempt",0,30), boot=Number(values,"boot",-1,Int32.MaxValue);
            long due=Number(values,"due",0,Int64.MaxValue), delay=Number(values,"delay",0,86400000);
            // Validate the opaque binding's syntax only. Never echo/hash it or authenticate identity.
            string binding=values["identity"];
            if(binding!= "\"\"" && !Regex.IsMatch(binding,@"\A""[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}:[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}""\z")) return result;
            bool legacy=!values.ContainsKey("reason");
            string reason=legacy?(stopped?"AUTH":"NONE"):values["reason"];
            if(!legacy) {if(!Regex.IsMatch(reason,@"\A""(?:NONE|AUTH|PROTOCOL|STORAGE)""\z")) return result;reason=reason.Substring(1,reason.Length-2);}
            result=Empty("OBSERVED","NONE");result["checksumValidity"]="VALID";result["schemaValidity"]="VALID";
            result["pending"]=pending;result["stopped"]=stopped;result["reason"]=reason;result["attemptCount"]=count;
            result["delayMs"]=delay;result["bootRecorded"]=boot>=0;result["deadlineRecorded"]=due>0;result["legacyReasonDerived"]=legacy;
            return result;
        } catch { return result; }
    }
}
