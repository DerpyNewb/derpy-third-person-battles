"""tp_mutate.py mutants/MUTANTS.py: for each (file, old, new, test), apply, run that one test, expect FAIL, restore byte for byte.

TESTS in the round file names the tests file under tools/ (default third_person_tests.lua; the lockstep tests are
third_person_lockstep_tests.lua). A test that did not run at all is reported NOT RUN, never as a survivor or a kill."""
import subprocess, sys
ROOT = "G:/Modding for resources"
SRC = ROOT + "/Modding Files/source/third_person/"
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"
mutants = {}
exec(open(sys.argv[1], encoding="utf-8").read(), mutants)
TESTS = ROOT + "/tools/" + mutants.get("TESTS", "third_person_tests.lua")
bad = 0
for rel, old, new, test in mutants["MUTANTS"]:
    path = SRC + rel
    orig = open(path, "rb").read()
    text = orig.decode("utf-8")
    if text.count(old) != 1:
        print("STALE  %s: %r found %d times" % (rel, old, text.count(old))); bad += 1; continue
    open(path, "wb").write(text.replace(old, new).encode("utf-8"))
    try:
        r = subprocess.run([LUA, ROOT + "/tools/third_person_harness.lua", SRC.rstrip("/"), TESTS, test],
                           capture_output=True, text=True)
    finally:
        open(path, "wb").write(orig)
    killed = "FAIL " + test in r.stdout
    if not killed and "ok   " + test not in r.stdout:
        print("NOT RUN %s: no such test in %s" % (test, TESTS)); bad += 1; continue
    print(("killed " if killed else "SURVIVED ") + test + "  <-  " + rel + ": " + new.strip()[:70])
    bad += not killed
print("%d mutants, %d survived or stale" % (len(mutants["MUTANTS"]), bad))
sys.exit(1 if bad else 0)
