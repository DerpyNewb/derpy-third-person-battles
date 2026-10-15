L = "script/derpy_tp/platform.lua"
MUTANTS = [
    (L, "local function rva(p, off) return mr.add(mr.add(base, u16(p, off + 2) * 0x10000), u16(p, off)) end",
        "local function rva(p, off) return at(base, mr.read_int32(p, off)) end", "platform_reads_rvas_above_float32"),
    (L, 'P.build = string.format("%04x%04x", u16(base, pe + 10), u16(base, pe + 8))',
        "P.build = mr.read_int32(base, pe + 8)", "platform_reads_rvas_above_float32"),
]
