# Real mouse events into the game window (2026-10-18): brings Warhammer3 to the front, puts the cursor at a fraction of
# its client area and clicks. -fx/-fy: 0-1 across and down the client area; -button: right or left.
# Sends nothing unless the game is in front.
param([double]$fx = 0.5, [double]$fy = 0.6, [string]$button = "right")
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MS {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct PT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref PT p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
"@
$p = Get-Process -Name Warhammer3 -ErrorAction Stop | Select-Object -First 1
for ($try = 0; $try -lt 5; $try++) {
  [MS]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [MS]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
  [MS]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
  [MS]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 400
  if ([MS]::GetForegroundWindow() -eq $p.MainWindowHandle) { break }
}
if ([MS]::GetForegroundWindow() -ne $p.MainWindowHandle) { "not in front: nothing sent"; exit 1 }
$r = New-Object MS+RECT
[MS]::GetClientRect($p.MainWindowHandle, [ref]$r) | Out-Null
$pt = New-Object MS+PT
$pt.X = [int](($r.R - $r.L) * $fx); $pt.Y = [int](($r.B - $r.T) * $fy)
[MS]::ClientToScreen($p.MainWindowHandle, [ref]$pt) | Out-Null
[MS]::SetCursorPos($pt.X, $pt.Y) | Out-Null
# the game hovers before it orders: settle, nudge, settle
Start-Sleep -Milliseconds 400
[MS]::SetCursorPos($pt.X + 2, $pt.Y + 2) | Out-Null
Start-Sleep -Milliseconds 400
if ($button -eq "left") { $down, $up = 0x0002, 0x0004 } else { $down, $up = 0x0008, 0x0010 }
[MS]::mouse_event($down, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 120; [MS]::mouse_event($up, 0, 0, 0, [UIntPtr]::Zero)
"clicked " + $pt.X + "," + $pt.Y
