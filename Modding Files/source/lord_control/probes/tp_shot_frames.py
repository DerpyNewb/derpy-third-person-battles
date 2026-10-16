"""Screenshots of one third-person shot, 2026-10-16 (the author: "strteltzi sitll suffering from the same ranged animation
issue, aim high -> shoot level"). Waits until the game is in front and nobody has touched a key or the mouse for IDLE s,
checks third person is on a ranged man, fires one shot through the pack (zz_tp_one_shot.lua) and grabs the screen every
STEP s for SECS s into OUT. Read only apart from the one shot.

    py tp_shot_frames.py [out_dir]
"""
import ctypes
import ctypes.wintypes as W
import json
import os
import subprocess
import sys
import time

from PIL import ImageGrab

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "shot_frames")
IDLE, STEP, SECS, WAIT = 10, 0.2, 4.4, 900


class LASTINPUT(ctypes.Structure):
    _fields_ = [("cbSize", W.UINT), ("dwTime", W.DWORD)]


def idle_s():
    li = LASTINPUT(ctypes.sizeof(LASTINPUT), 0)
    ctypes.windll.user32.GetLastInputInfo(ctypes.byref(li))
    return (ctypes.windll.kernel32.GetTickCount() - li.dwTime) / 1000


def front_is_game():
    pid = W.DWORD()
    ctypes.windll.user32.GetWindowThreadProcessId(ctypes.windll.user32.GetForegroundWindow(), ctypes.byref(pid))
    out = subprocess.run(["tasklist", "/FI", "PID eq %d" % pid.value, "/FO", "CSV", "/NH"], capture_output=True, text=True)
    return "Warhammer3" in out.stdout


def send(probe):
    out = subprocess.run([sys.executable, os.path.join(HERE, "send.py"), os.path.join(HERE, probe), "10"],
                         capture_output=True, text=True, cwd=HERE).stdout.strip().splitlines()
    return json.loads(out[-1])["result"]["values"][0] if out else "no reply"


def main():
    end = time.time() + WAIT
    while time.time() < end and not (front_is_game() and idle_s() >= IDLE):
        time.sleep(1)
    if time.time() >= end:
        print("the game was never in front and idle for %d s" % IDLE)
        return 1
    state = send("zz_tp_state.lua")
    print(state)
    if "on true" not in state or "ranged true" not in state:
        print("third person is not on a ranged man")
        return 1
    os.makedirs(OUT, exist_ok=True)
    print(send("zz_tp_one_shot.lua"))
    t0 = time.time()
    for i in range(int(SECS / STEP) + 1):
        while time.time() < t0 + i * STEP:
            time.sleep(0.01)
        img = ImageGrab.grab()
        img.thumbnail((1280, 1280))
        img.save(os.path.join(OUT, "f%02d_%.1fs.png" % (i, time.time() - t0)))
    print("saved %d frames to %s" % (i + 1, OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
