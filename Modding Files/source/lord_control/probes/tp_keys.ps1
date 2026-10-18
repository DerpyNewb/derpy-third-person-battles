# Real key events into the game window: brings Warhammer3 to the front, then runs a plan of steps.
# A step is "down:VK", "up:VK", "tap:VK" or "wait:SECONDS". VK in hex (0x57 W, 0x10 Shift, 0x71 F2).
param([string]$plan)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KS {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint type);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
"@
$p = Get-Process -Name Warhammer3 -ErrorAction Stop | Select-Object -First 1
# Windows refuses SetForegroundWindow from a background process unless a key went in first: an Alt tap lifts the lock
for ($try = 0; $try -lt 5; $try++) {
  [KS]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [KS]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
  [KS]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
  [KS]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 400
  if ([KS]::GetForegroundWindow() -eq $p.MainWindowHandle) { break }
}
# never a key into another window
if ([KS]::GetForegroundWindow() -ne $p.MainWindowHandle) { "not in front: nothing sent"; exit 1 }
foreach ($step in $plan.Split(";")) {
  $s = $step.Trim()
  if ($s -eq "") { continue }
  $kind, $arg = $s.Split(":")
  if ($kind -eq "wait") { Start-Sleep -Milliseconds ([int]([double]$arg * 1000)); continue }
  if ([KS]::GetForegroundWindow() -ne $p.MainWindowHandle) { "lost the front at " + $s + ": stopped"; foreach ($k in 0x57, 0x10, 0x41, 0x44, 0x53) { [KS]::keybd_event([byte]$k, 0, 2, [UIntPtr]::Zero) }; exit 1 }
  $vk = [byte][Convert]::ToInt32($arg, 16)
  $scan = [byte][KS]::MapVirtualKey($vk, 0)
  if ($kind -eq "down" -or $kind -eq "tap") { [KS]::keybd_event($vk, $scan, 0, [UIntPtr]::Zero) }
  if ($kind -eq "tap") { Start-Sleep -Milliseconds 120 }
  if ($kind -eq "up" -or $kind -eq "tap") { [KS]::keybd_event($vk, $scan, 2, [UIntPtr]::Zero) }
}
"done"
