// Disposable host-only image comparison/stream reader. No device or network API.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using System.Threading;
namespace KR003 {
 public sealed class VideoFrame {
  public int Index; public long Pts; public string Hash; public string Label;
  public bool CacheHit; public double OrdinaryDistance, RestrictedDistance;
 }
 public sealed class DecodedVideo {
  public VideoFrame[] Frames; public byte[] ReferencePixels;
  public long TimeBaseNumerator, TimeBaseDenominator;
  public int RecognitionCalls, CacheHits; public double TotalMillis;
 }
 public static class ReferenceVideoCore {
  public const string Version="LOCAL_TILE_MAE_RGB24_V1";
  public static bool Equal(byte[] a,byte[] b) {
   if(a==null||b==null||a.Length!=b.Length)return false;
   for(int i=0;i<a.Length;i++)if(a[i]!=b[i])return false; return true;
  }
  public static string Hash(byte[] a) {
   using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(a)).Replace("-","").ToLowerInvariant();
  }
  public static bool HasSpatialVariation(byte[] pixels) {
   if(pixels==null||pixels.Length<6||pixels.Length%3!=0)return false;
   for(int i=3;i<pixels.Length;i++)if(pixels[i]!=pixels[i%3])return true;return false;
  }
  // Maximum local mean absolute channel difference. Half-tile overlap avoids
  // hiding defects at grid boundaries. No resizing, masking or image learning.
  public static double Distance(byte[] a,byte[] b,int w,int h,int tile) {
   if(a==null||b==null||a.Length!=w*h*3||b.Length!=a.Length||tile<2)throw new InvalidDataException("PIXEL_LAYOUT");
   double worst=0;int step=Math.Max(1,tile/2);
   for(int y=0;y<h;y+=step)for(int x=0;x<w;x+=step) {
    long sum=0;int count=0;
    for(int yy=y;yy<Math.Min(y+tile,h);yy++)for(int xx=x;xx<Math.Min(x+tile,w);xx++) {
     int p=(yy*w+xx)*3;for(int c=0;c<3;c++){sum+=Math.Abs((int)a[p+c]-b[p+c]);count++;}
    }
    worst=Math.Max(worst,(double)sum/count);
   }
   return worst;
  }
  public static string Label(byte[] pixels,byte[] ordinary,byte[] restricted,int w,int h,int tile,double limit) {
   bool o=Distance(pixels,ordinary,w,h,tile)<=limit,r=Distance(pixels,restricted,w,h,tile)<=limit;
   return o==r?"UNKNOWN":o?"ORDINARY":"RESTRICTED";
  }
  static string Quote(string s) {
   if(s.IndexOf('"')>=0||s.IndexOf('\n')>=0||s.IndexOf('\r')>=0)throw new InvalidDataException("PATH");
   return "\""+s+"\"";
  }
  sealed class Cached { public byte[] Pixels; public string Hash,Label; public double O,R; }
  // Exactly one FFmpeg video decode. Original timestamps are read from showinfo
  // after RGB normalization; raw pixels are consumed in memory, not printed.
  // At most four content entries are retained; eviction affects cost, not labels.
  public static DecodedVideo Decode(string executable,string path,int w,int h,byte[] ordinary,byte[] restricted,
      int tile,double limit,bool enrollment,bool disableCache,string cancellationPath) {
   if(w<16||h<16||w>4096||h>4096)throw new InvalidDataException("DIMENSIONS");
   if(!String.IsNullOrEmpty(cancellationPath)&&File.Exists(cancellationPath))throw new InvalidDataException("CANCELLED");
   var watch=Stopwatch.StartNew();var frames=new List<VideoFrame>();var cache=new List<Cached>();
   byte[] selected=null;int calls=0,hits=0;bool timedOut=false,cancelled=false;
   using(var process=new Process()) {
    process.StartInfo=new ProcessStartInfo(executable,"-hide_banner -nostdin -loglevel info -copyts -noautorotate -i "+Quote(path)+
      " -map 0:v:0 -an -sn -dn -vf \"scale=in_color_matrix=bt709:out_color_matrix=bt709:in_range=tv:out_range=pc,format=rgb24,showinfo\" -c:v rawvideo -fps_mode passthrough -enc_time_base demux -f rawvideo pipe:1");
    process.StartInfo.UseShellExecute=false;process.StartInfo.CreateNoWindow=true;
    process.StartInfo.RedirectStandardOutput=true;process.StartInfo.RedirectStandardError=true;
    process.Start();var errors=process.StandardError.ReadToEndAsync();
    try {
    using(var timer=new Timer(delegate(object unused){
     if(watch.Elapsed.TotalSeconds>180){timedOut=true;try{process.Kill();}catch{}}
     if(!String.IsNullOrEmpty(cancellationPath)&&File.Exists(cancellationPath)){cancelled=true;try{process.Kill();}catch{}}
    },null,1000,1000)) {
     var stream=process.StandardOutput.BaseStream;int length=checked(w*h*3);
     while(true) {
      var pixels=new byte[length];int offset=0,read=0;
      while(offset<length&&(read=stream.Read(pixels,offset,length-offset))>0)offset+=read;
      if(offset==0)break;if(offset!=length)throw new InvalidDataException("PARTIAL_DECODED_FRAME");
      if(frames.Count>=18000)throw new InvalidDataException("FRAME_LIMIT");
      var row=new VideoFrame{Index=frames.Count,Hash=Hash(pixels),Label="UNASSIGNED_ENROLLMENT"};
      if(enrollment) { if(selected==null)selected=pixels; }
      else {
       Cached found=null;
       if(!disableCache)foreach(var prior in cache)if(prior.Hash==row.Hash&&Equal(prior.Pixels,pixels)){found=prior;break;}
       if(found!=null){row.Label=found.Label;row.OrdinaryDistance=found.O;row.RestrictedDistance=found.R;row.CacheHit=true;hits++;}
       else {
        calls++;row.OrdinaryDistance=Distance(pixels,ordinary,w,h,tile);row.RestrictedDistance=Distance(pixels,restricted,w,h,tile);
        bool o=row.OrdinaryDistance<=limit,r=row.RestrictedDistance<=limit;row.Label=o==r?"UNKNOWN":o?"ORDINARY":"RESTRICTED";
        if(!disableCache){if(cache.Count==4)cache.RemoveAt(0);cache.Add(new Cached{Pixels=pixels,Hash=row.Hash,Label=row.Label,O=row.OrdinaryDistance,R=row.RestrictedDistance});}
       }
      }
      frames.Add(row);
     }
     process.WaitForExit();string log=errors.Result;
     if(timedOut||cancelled||process.ExitCode!=0)throw new InvalidDataException(cancelled?"CANCELLED":timedOut?"DECODE_TIMEOUT":"DECODE_FAILED");
     var tb=Regex.Match(log,@"config in time_base:\s*(\d+)/(\d+)");
     var pts=Regex.Matches(log,@"\bn:\s*(\d+)\s+pts:\s*(-?\d+)\s+pts_time:");
     var dimensions=Regex.Matches(log,@"\bfmt:rgb24\s+.*?\bs:(\d+)x(\d+)");
     if(!tb.Success||pts.Count!=frames.Count||frames.Count<(enrollment?1:2))throw new InvalidDataException("TIMESTAMP_MAPPING");
     if(dimensions.Count!=frames.Count)throw new InvalidDataException("FRAME_LAYOUT_MAPPING");
     long previous=long.MinValue;
     for(int i=0;i<frames.Count;i++) {
      if(int.Parse(pts[i].Groups[1].Value,CultureInfo.InvariantCulture)!=i)throw new InvalidDataException("FRAME_INDEX");
      if(int.Parse(dimensions[i].Groups[1].Value)!=w||int.Parse(dimensions[i].Groups[2].Value)!=h)throw new InvalidDataException("FRAME_LAYOUT_CHANGED");
      long stamp=long.Parse(pts[i].Groups[2].Value,CultureInfo.InvariantCulture);
      if(stamp<=previous)throw new InvalidDataException("PTS_ORDER");frames[i].Pts=stamp;previous=stamp;
     }
     return new DecodedVideo{Frames=frames.ToArray(),ReferencePixels=selected,
      TimeBaseNumerator=long.Parse(tb.Groups[1].Value,CultureInfo.InvariantCulture),TimeBaseDenominator=long.Parse(tb.Groups[2].Value,CultureInfo.InvariantCulture),
      RecognitionCalls=calls,CacheHits=hits,TotalMillis=watch.Elapsed.TotalMilliseconds};
    }
    } finally { if(!process.HasExited){try{process.Kill();process.WaitForExit(5000);}catch{}} }
   }
  }
 }
}
