"""Send a probe, then screenshot the game at given seconds after the send. 2026-10-14.

    tp_timed_shots.py <probe.lua> <out prefix> <secs,secs,...>

Writes <prefix>_<secs>.png (960 wide) through wh3-mcp/tools/screenshot.ps1; prints the send's result first."""
import subprocess
import sys
import time

MAXW = "0"
SHOT = r"G:\Modding for resources\wh3-mcp\tools\screenshot.ps1"


def main(argv):
    probe, prefix, times = argv[0], argv[1], [float(t) for t in argv[2].split(",")]
    t0 = time.time()
    subprocess.run([sys.executable, "send.py", probe, "8"], check=False)
    for t in times:
        wait = t0 + t - time.time()
        if wait > 0:
            time.sleep(wait)
        out = "%s_%s.png" % (prefix, ("%g" % t).replace(".", "p"))
        subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", SHOT,
                        "-OutFile", out, "-MaxWidth", MAXW], check=False, capture_output=True)
        print("%.2fs %s" % (time.time() - t0, out))


if __name__ == "__main__":
    main(sys.argv[1:])
