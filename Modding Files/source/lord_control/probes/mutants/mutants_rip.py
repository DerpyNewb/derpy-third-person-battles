L = "script/derpy_tp/platform.lua"
T = "platform_pattern_route_reads_displacements_exactly"
MUTANTS = [
    (L, "\t\t\tif hi >= 0x8000 then hi = hi - 0x10000 end\n", "", T),
    (L, "return mr.add(mr.add(mr.add(hit, o + 4), hi * 0x10000), u16(hit, o))",
        "return mr.add(mr.add(hit, o + 4), mr.read_int32(hit, o, true))", T),
]
