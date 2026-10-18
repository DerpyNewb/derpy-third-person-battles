"""Test scaffolding (2026-10-18). Real-input sprint runs, with the game running and nobody at it: per (unit type, lead) select him, start the watcher, send F2 / W 4 s / W+Shift 5 s / W 2 s / F2
through tp_keys.ps1, then average his speed over the run's last 2 s and the sprint's last 2 s."""
import json, os, re, subprocess, sys, tempfile, time
P = S = os.path.dirname(os.path.abspath(__file__))
TMP = os.environ.get("TEMP", tempfile.gettempdir())


def send(lua, wait=10):
    f = os.path.join(TMP, "leadrun_cmd.lua")
    open(f, "w").write(lua)
    r = subprocess.run(["py", "send.py", f, str(wait)], cwd=P, capture_output=True, text=True)
    if "no game" in r.stdout:
        sys.exit("no game")
    return json.loads(re.sub(r'\\(?!["\\/bfnrtu])', r'\\\\', r.stdout))["result"]["values"][0]


def sendfile(name):
    r = subprocess.run(["py", "send.py", name, "10"], cwd=P, capture_output=True, text=True)
    return r.stdout.strip()


def run(ty, lead):
    send('_G.TP_WS = nil _G.TP_WS_SECONDS = 20 _G.TP_WS_LEAD = %s _G.TP_SEL = "%s" return "set"' % (lead or "nil", ty))
    print(send('local ok, r = pcall(function() local want = _G.TP_SEL local a = bm:get_player_army() '
               'for i = 1, a:units():count() do local u = a:units():item(i) if u:type() == want then bm:clear_selection() '
               'u:select_in_ui() return "selected " .. want end end return "none" end) return ok and r or "ERR " .. tostring(r)'))
    sendfile("zz_tp_watch_sprint.lua")
    k = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", os.path.join(S, "tp_keys.ps1"),
                        "-plan", "tap:71;wait:1.5;down:57;wait:4;down:10;wait:5;up:10;wait:2;up:57;wait:1;tap:71"],
                       capture_output=True, text=True)
    if "done" not in k.stdout:
        sys.exit("keys: " + k.stdout)
    time.sleep(2)
    d = send('local T = _G.TP_WS local o = {} for i, r in ipairs(T.rows) do o[i] = r end return o')
    rows = [d[k] for k in sorted(d, key=int)] if isinstance(d, dict) else d
    pts = []
    for r in rows:
        m = re.match(r"(\S+) .* spr (\S+) .* drive (\S+) x\S+ .* m/s (\S+)", r)
        if m:
            pts.append((float(m.group(1)), m.group(2) == "true", m.group(3) == "1,0", float(m.group(4))))
    walk = [p for p in pts if p[2]]
    if not walk:
        return ty, lead, None, None, len(pts)
    t_sp = [p[0] for p in walk if p[1]]
    if not t_sp:
        return ty, lead, None, None, len(pts)
    s0, s1 = min(t_sp), max(t_sp)
    run_w = [p[3] for p in walk if not p[1] and s0 - 2 <= p[0] < s0 and p[3] >= 0]
    spr_w = [p[3] for p in walk if p[1] and s1 - 2 <= p[0] <= s1 and p[3] >= 0]
    avg = lambda xs: round(sum(xs) / len(xs), 2) if xs else None
    men = len(set(re.findall(r" man (\S+)", " ".join(rows))))
    return ty, lead, avg(run_w), avg(spr_w), men


# py tp_leadrun.py <unit type>@<lead m, or - for the shipped one> ...  (zz_tp_watch_sprint.lua; tp_keys.ps1)
plan = [x.split("@") for x in sys.argv[1:]]
for ty, lead in plan:
    r = run(ty, lead if lead != "-" else None)
    print("%-55s lead %-3s run %s sprint %s (%d men)" % (r[0], r[1] or 3, r[2], r[3], r[4]), flush=True)
