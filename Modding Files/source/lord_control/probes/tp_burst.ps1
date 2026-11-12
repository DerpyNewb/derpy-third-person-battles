# burst.ps1 <outdir> <count> : PrintWindow grabs of the Warhammer3 window only, as fast as they come; file name = ms since start
param([string]$dir, [int]$n = 30, [int]$gap = 0)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class PW2 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
}
"@
New-Item -ItemType Directory -Force $dir | Out-Null
$h = (Get-Process Warhammer3 | Select-Object -First 1).MainWindowHandle
$wr = New-Object PW2+RECT; [PW2]::GetWindowRect($h, [ref]$wr) | Out-Null
$cr = New-Object PW2+RECT; [PW2]::GetClientRect($h, [ref]$cr) | Out-Null
$p = New-Object PW2+POINT; [PW2]::ClientToScreen($h, [ref]$p) | Out-Null
$ww = $wr.R - $wr.L; $wh = $wr.B - $wr.T
$cw = $cr.R - $cr.L; $ch = $cr.B - $cr.T
$rect = New-Object System.Drawing.Rectangle ($p.X - $wr.L), ($p.Y - $wr.T), $cw, $ch
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$frames = @()
for ($i = 0; $i -lt $n; $i++) {
  $bmp = New-Object System.Drawing.Bitmap $ww, $wh
  $g = [System.Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
  [PW2]::PrintWindow($h, $dc, 2) | Out-Null; $g.ReleaseHdc($dc); $g.Dispose()
  $frames += ,@($sw.ElapsedMilliseconds, $bmp)
  if ($gap -gt 0) { Start-Sleep -Milliseconds $gap }
}
foreach ($f in $frames) {
  $crop = $f[1].Clone($rect, $f[1].PixelFormat)
  $crop.Save((Join-Path $dir ("{0:D5}.png" -f $f[0])), [System.Drawing.Imaging.ImageFormat]::Png)
  $crop.Dispose(); $f[1].Dispose()
}
"$n frames in $($sw.ElapsedMilliseconds) ms"
