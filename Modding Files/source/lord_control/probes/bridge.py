"""Send one command to the wh3_mcp bridge and print its result (send.py is the eval-only form).

    bridge.py <command> [params json] [timeout_s]
    bridge.py ping
    bridge.py get_situation
    bridge.py attack '{"attacker_cqi": 12, "target_cqi": 34}'
"""
import json
import os
import sys
import time

WH3 = r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III"
CMD, RES = WH3 + r"\wh3_mcp_command.json", WH3 + r"\wh3_mcp_result.json"


def send(command, params=None, timeout=30):
    if os.path.exists(RES):
        os.remove(RES)
    with open(CMD, "w", encoding="ascii", newline="") as f:
        f.write(json.dumps({"command": command, "params": params or {}}))
    deadline = time.time() + timeout
    while time.time() < deadline:
        time.sleep(0.4)
        if os.path.exists(RES):
            time.sleep(0.3)
            try:
                out = json.load(open(RES, encoding="utf-8"))
            except ValueError:
                continue
            os.remove(RES)
            return out
    return {"status": "timeout"}


if __name__ == "__main__":
    params = json.loads(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else {}
    timeout = float(sys.argv[3]) if len(sys.argv) > 3 else 30
    print(json.dumps(send(sys.argv[1], params, timeout), indent=1)[:20000])
