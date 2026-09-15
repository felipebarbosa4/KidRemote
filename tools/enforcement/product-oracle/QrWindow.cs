// Host-only presentation. No payload text, files, device hooks or screenshots.
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
namespace KidRemote.Lab {
 public sealed class QrPresentationState {
  public bool Ready, Visible, ValidHandle, TitleMatches, TopMost, Foreground, ActivationAttempted, Closed, TimedOut, Interactive;
  public int PumpTicks;
  public long Hwnd;
  public string Title;
 }
 public sealed class QrWindow : IDisposable {
  [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder b,int count);
  [DllImport("user32.dll", EntryPoint="GetWindowLongW")] static extern int GetWindowLong(IntPtr h,int index);
  [DllImport("user32.dll")] static extern IntPtr OpenInputDesktop(uint flags,bool inherit,uint access);
  [DllImport("user32.dll")] static extern bool CloseDesktop(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetThreadDesktop(uint id);
  [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool GetUserObjectInformation(IntPtr h,int index,StringBuilder value,int length,out int needed);
  [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
  [StructLayout(LayoutKind.Sequential)] struct Flash {public uint size;public IntPtr hwnd;public uint flags,count,timeout;}
  [DllImport("user32.dll")] static extern bool FlashWindowEx(ref Flash f);
  readonly object gate=new object(); readonly ManualResetEventSlim signaled=new ManualResetEventSlim(false);
  readonly Thread thread; readonly int lifetime; readonly string title="KidRemote - QR de pareamento - "+Guid.NewGuid().ToString("N");
  byte[] png; Form form; IntPtr hwnd; bool ready,closed,expired,failed,interactive,activation; int ticks; volatile bool stopRequested; string phase="THREAD_START";
  static string DesktopName(IntPtr h){var b=new StringBuilder(256);int needed;return GetUserObjectInformation(h,2,b,512,out needed)?b.ToString():null;}
  static bool OnInputDesktop(){if(!Environment.UserInteractive)return false;var h=OpenInputDesktop(0,false,1);if(h==IntPtr.Zero)return false;try{var name=DesktopName(h);return name!=null&&name==DesktopName(GetThreadDesktop(GetCurrentThreadId()));}finally{CloseDesktop(h);}}
  public QrWindow(byte[] bytes,int timeoutMs){
   if(bytes==null||bytes.Length<8||bytes.Length>262144||timeoutMs<1000||timeoutMs>240000)throw new InvalidOperationException("INVALID:QR_PRESENTATION_FAILED");
   png=(byte[])bytes.Clone();lifetime=timeoutMs;thread=new Thread(Run);thread.IsBackground=true;thread.SetApartmentState(ApartmentState.STA);thread.Start();
   bool wake=signaled.Wait(6000);var first=Snapshot();if(!wake||!first.Ready){phase+="_PUMP"+first.PumpTicks+"_EXPIRED"+(first.TimedOut?1:0);Dispose();throw new InvalidOperationException("INVALID:QR_PRESENTATION_FAILED_"+phase);}
  }
  void Run(){
   MemoryStream stream=null;Image image=null;System.Windows.Forms.Timer timer=null;
   try{
    phase="INTERACTIVE_DESKTOP";interactive=OnInputDesktop();if(!interactive)throw new InvalidOperationException();
    // Thread-local DPI context; no process/host setting is changed.
    try{SetThreadDpiAwarenessContext(new IntPtr(-4));}catch(EntryPointNotFoundException){}
    phase="IMAGE_DECODE";stream=new MemoryStream(png,false);image=Image.FromStream(stream);if(image.Width!=512||image.Height!=512)throw new InvalidOperationException();
    phase="FORM_CREATE";form=new Form();form.Text=title;form.AutoScaleDimensions=new SizeF(96,96);form.AutoScaleMode=AutoScaleMode.Dpi;
    form.ClientSize=new Size(544,544);form.StartPosition=FormStartPosition.CenterScreen;form.TopMost=true;form.ShowInTaskbar=true;
    form.FormBorderStyle=FormBorderStyle.FixedDialog;form.MaximizeBox=false;form.MinimizeBox=false;form.BackColor=Color.White;form.Padding=new Padding(16);
    var box=new PictureBox();box.Dock=DockStyle.Fill;box.SizeMode=PictureBoxSizeMode.Zoom;box.Image=image;form.Controls.Add(box);
    var elapsed=Stopwatch.StartNew();timer=new System.Windows.Forms.Timer();timer.Interval=50;
    form.Shown+=delegate {
     lock(gate){hwnd=form.Handle;activation=true;}
     form.Activate();form.BringToFront();SetForegroundWindow(form.Handle);
     var flash=new Flash {size=(uint)Marshal.SizeOf(typeof(Flash)),hwnd=form.Handle,flags=3,count=3,timeout=0};
     if(GetForegroundWindow()!=form.Handle)FlashWindowEx(ref flash);
    };
    timer.Tick+=delegate {
     try{
      lock(gate){ticks++;}
      if(stopRequested){form.Close();return;}
      if(elapsed.ElapsedMilliseconds>=lifetime){lock(gate){expired=true;}form.Close();return;}
      var state=Snapshot();
      if(form.Visible&&!form.IsDisposed&&state.Visible&&state.ValidHandle&&state.TitleMatches&&state.TopMost&&Screen.FromControl(form).WorkingArea.Contains(form.Bounds)){
       lock(gate){ready=true;}signaled.Set();
      }else if(elapsed.ElapsedMilliseconds>4000){
       phase="WINDOW_VISIBILITY_H"+(state.ValidHandle?1:0)+"_V"+(state.Visible?1:0)+"_T"+(state.TitleMatches?1:0)+"_TOP"+(state.TopMost?1:0)+"_FORM"+(form.Visible?1:0)+"_BOUNDS"+(Screen.FromControl(form).WorkingArea.Contains(form.Bounds)?1:0)+"_W"+form.Width+"_H"+form.Height+"_DESK_W"+Screen.FromControl(form).WorkingArea.Width+"_H"+Screen.FromControl(form).WorkingArea.Height;
       lock(gate){failed=true;}signaled.Set();form.Close();}
     }catch(Exception e){phase="TIMER_"+e.GetType().Name.ToUpperInvariant();lock(gate){failed=true;}signaled.Set();form.Close();}
    };
    phase="WINDOW_VISIBILITY";if(stopRequested)throw new InvalidOperationException();timer.Start();form.Show();form.Activate();form.BringToFront();Application.Run(form);
   }catch(Exception e){phase+="_"+e.GetType().Name.ToUpperInvariant();lock(gate){failed=true;}}
   finally{
    if(timer!=null)timer.Dispose();if(form!=null)form.Dispose();if(image!=null)image.Dispose();if(stream!=null)stream.Dispose();
    if(png!=null){Array.Clear(png,0,png.Length);png=null;}lock(gate){closed=true;ready=false;}signaled.Set();
   }
  }
  public QrPresentationState Snapshot(){
   QrPresentationState state;IntPtr h;
   lock(gate){h=hwnd;state=new QrPresentationState {Ready=ready&&!failed&&!closed&&!expired,ActivationAttempted=activation,Closed=closed,TimedOut=expired,Interactive=interactive,PumpTicks=ticks,Hwnd=h.ToInt64(),Title=title};}
   // Never hold gate while messaging the UI thread through Win32.
   state.ValidHandle=h!=IntPtr.Zero&&IsWindow(h);var text=new StringBuilder(160);if(state.ValidHandle)GetWindowText(h,text,160);
   state.Visible=state.ValidHandle&&IsWindowVisible(h)&&!IsIconic(h);state.TitleMatches=text.ToString()==title;
   state.TopMost=state.ValidHandle&&(GetWindowLong(h,-20)&8)!=0;state.Foreground=state.ValidHandle&&GetForegroundWindow()==h;
   state.Ready=state.Ready&&state.Visible&&state.TopMost&&state.TitleMatches;return state;
  }
  public void Dispose(){
   stopRequested=true;
   try{if(form!=null&&!form.IsDisposed&&form.IsHandleCreated)form.BeginInvoke(new Action(delegate{form.Close();}));}catch{}
   if(thread!=Thread.CurrentThread)thread.Join(3000);
  }
 }
}
