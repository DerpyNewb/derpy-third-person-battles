"""Check the third-person pack's command pattern against Warhammer3.exe ON DISK (the game may be shut).

    py tools/third_person_patterns.py              one match, and it agrees with platform.lua's BUILDS row
    py tools/third_person_patterns.py --selftest   the matcher and the rip-relative maths on a made-up blob

PATTERN and BUILDS are read out of Modding Files/source/third_person/script/derpy_tp/platform.lua, so
the Lua stays the one source. For a build the table does not know, prints the row to add. The exe's
section names are scrambled; its code is the section at RVA 0x1000.
"""
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLATFORM = os.path.join(ROOT, "Modding Files", "source", "third_person", "script", "derpy_tp", "platform.lua")
EXE = r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\Warhammer3.exe"
FIELDS = ("cmd_type", "battle", "cmd_push", "battle_sub", "gate_a", "gate_b", "queue")


def read_lua(text):
    block = text[text.index("local PATTERN ="):]
    block = block[:block.index("\n\n")]
    pattern = "".join(re.findall(r'"([^"]*)"', block))
    builds = {}
    for m in re.finditer(r'\["([0-9a-f]{8})"\] = \{([^}]*)\}', text):
        builds[m.group(1)] = {k: int(v, 16) for k, v in re.findall(r"(\w+) = 0x([0-9a-f]+)", m.group(2))}
    return pattern, builds


def inexact(row):
    """the fields game Lua would round: its numbers are float32, so a literal needs 24 significant bits or fewer"""
    return [k for k, v in row.items() if struct.unpack("<f", struct.pack("<f", v))[0] != v]


def regex(pattern):
    return re.compile(b"".join(b"." if t == "??" else re.escape(bytes([int(t, 16)])) for t in pattern.split()), re.S)


def resolve(code, va, hit):
    def rip(off):
        return va + hit + off + 4 + struct.unpack_from("<i", code, hit + off)[0]

    def imm(off):
        return struct.unpack_from("<i", code, hit + off)[0]
    return {"cmd_type": rip(3), "battle": rip(0x23), "cmd_push": rip(0x4d),
            "battle_sub": imm(0x2a), "gate_a": imm(0x31), "gate_b": imm(0x3a), "queue": imm(0x48)}


def code_section(path):
    with open(path, "rb") as f:
        head = f.read(0x1000)
        pe = struct.unpack_from("<I", head, 0x3c)[0]
        stamp = struct.unpack_from("<I", head, pe + 8)[0]
        n = struct.unpack_from("<H", head, pe + 6)[0]
        sec = pe + 24 + struct.unpack_from("<H", head, pe + 20)[0]
        for i in range(n):
            vsz, va, rsz, raw = struct.unpack_from("<IIII", head, sec + i * 40 + 8)
            if va == 0x1000:
                f.seek(raw)
                return stamp, va, f.read(min(vsz, rsz))
    raise SystemExit("no section at RVA 0x1000 in %s" % path)


def check():
    pattern, builds = read_lua(open(PLATFORM, encoding="utf-8").read())
    stamp, va, code = code_section(EXE)
    hits = [m.start() for m in regex(pattern).finditer(code)]
    print("exe build 0x%08x: the pattern matches %d time(s)" % (stamp, len(hits)))
    if len(hits) != 1:
        return 1
    got = resolve(code, va, hits[0])
    print("  at exe+0x%x: %s" % (va + hits[0], ", ".join("%s = 0x%x" % (k, got[k]) for k in FIELDS)))
    bad = ["%s %s: 0x%x rounds in float32 game Lua" % (b, k, row[k]) for b, row in builds.items() for k in inexact(row)]
    row = builds.get("%08x" % stamp)
    if row is None:
        for b in bad:
            print("INEXACT " + b)
        print("unknown build - add to BUILDS once Task 13's live check passes on it:")
        print('\t["%08x"] = {%s},' % (stamp, ", ".join("%s = 0x%x" % (k, got[k]) for k in FIELDS)))
        for k in inexact(got):
            print("  %s cannot be a literal: it rounds in float32 game Lua" % k)
        return 1
    bad += ["%s: row 0x%x, exe 0x%x" % (k, row.get(k, -1), got[k]) for k in FIELDS if row.get(k) != got[k]]
    for b in bad:
        print("DISAGREES " + b)
    return 1 if bad else 0


def selftest():
    pattern = ("48 8D 05 ?? ?? ?? ?? 48 89 44 24 30 48 89 74 24 38 66 44 89 74 24 40 44 88 7C 24 42 89 7C 24 44 "
               "48 8B 05 ?? ?? ?? ?? 48 8B 88 ?? ?? ?? ?? 40 38 B9 ?? ?? ?? ?? 75 ?? 40 38 B9 ?? ?? ?? ?? 75 ?? "
               "48 8D 54 24 30 48 8B 89 ?? ?? ?? ?? E8")
    body = bytearray(int(t, 16) if t != "??" else 0 for t in pattern.split()) + bytearray(4)
    for off, val in ((3, 0x100), (0x23, -0x20), (0x2a, 0x468), (0x31, 0x3b0), (0x3a, 0x3b1), (0x48, 0x644e8), (0x4d, 0x40)):
        struct.pack_into("<i", body, off, val)
    blob = bytes(16) + bytes(body) + bytes(16)
    hits = [m.start() for m in regex(pattern).finditer(blob)]
    assert hits == [16], hits
    got = resolve(blob, 0x1000, 16)
    assert got["cmd_type"] == 0x1000 + 16 + 3 + 4 + 0x100, hex(got["cmd_type"])
    assert got["battle"] == 0x1000 + 16 + 0x23 + 4 - 0x20, hex(got["battle"])
    assert got["cmd_push"] == 0x1000 + 16 + 0x4d + 4 + 0x40, hex(got["cmd_push"])
    assert (got["battle_sub"], got["gate_a"], got["gate_b"], got["queue"]) == (0x468, 0x3b0, 0x3b1, 0x644e8), got
    assert len(list(regex(pattern).finditer(blob + blob))) == 2, "a second copy must count as two"
    text = ('local BUILDS = {\n\t["6ac6d907"] = {cmd_type = 0x3901cd0, cmd_push = 0x2e969ac},\n}\n'
            'local PATTERN = "48 8D "\n\t.. "05 ??"\n\nlocal X = 1\n')
    p, b = read_lua(text)
    assert p == "48 8D 05 ??" and b["6ac6d907"]["cmd_push"] == 0x2e969ac, (p, b)
    assert inexact({"cmd_push": 0x2e969ac, "queue": 0x644e8}) == [], "24 significant bits are exact in float32"
    assert inexact({"battle": 0x2e969ad}) == ["battle"], "26 significant bits are not"
    print("selftest ok")
    return 0


if __name__ == "__main__":
    sys.exit(selftest() if sys.argv[1:2] == ["--selftest"] else check())
