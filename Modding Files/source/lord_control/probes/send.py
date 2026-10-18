"""Send a Lua file to the wh3_mcp bridge as an eval and print the result. send.py <file.lua> [timeout_s]

The game shut and a reply that is slow look the same from the files alone, so the process is checked before the send and
after a timeout: {"status": "no game"} (exit 2) when Warhammer3.exe is not running (2026-10-18: polled a closed game).
"""
import json
import os
import subprocess
import sys
import time

WH3 = r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III"
CMD, RES = WH3 + r"\wh3_mcp_command.json", WH3 + r"\wh3_mcp_result.json"


def game_running():
    out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Warhammer3.exe"], capture_output=True, text=True).stdout
    return "Warhammer3.exe" in out


if not game_running():
    print('{"status": "no game"}')
    sys.exit(2)
code = open(sys.argv[1], encoding="utf-8").read()
timeout = float(sys.argv[2]) if len(sys.argv) > 2 else 30
if os.path.exists(RES):
    os.remove(RES)
with open(CMD, "w", encoding="ascii", newline="") as f:
    f.write(json.dumps({"command": "eval", "params": {"code": code}}))
deadline = time.time() + timeout
while time.time() < deadline:
    time.sleep(0.4)
    if os.path.exists(RES):
        time.sleep(0.3)
        print(open(RES, encoding="utf-8").read())
        os.remove(RES)
        sys.exit(0)
if not game_running():
    print('{"status": "no game"}')
    sys.exit(2)
print('{"status": "timeout"}')
sys.exit(1)
