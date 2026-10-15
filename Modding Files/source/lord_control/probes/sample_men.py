"""Sample men's memory while their regiment fires (live process, read-only).
    sample_men.py <out.npz> <seconds> <obj hex> <model hex> [<model hex> ...]
Saves t, ammo (obj+0x3d90) and each model's first SPAN bytes as raw uint8 rows."""
import struct, sys, time
import numpy as np
import memscan

SPAN = 0x4000
out, secs, obj = sys.argv[1], float(sys.argv[2]), int(sys.argv[3], 16)
models = [int(a, 16) for a in sys.argv[4:]]
h = memscan.open_game()
T, A, M = [], [], [[] for _ in models]
t0 = time.time()
while time.time() - t0 < secs:
    T.append(time.time() - t0)
    A.append(struct.unpack("<i", memscan.read(h, obj + 0x3d90, 4))[0])
    for k, m in enumerate(models):
        M[k].append(np.frombuffer(memscan.read(h, m, SPAN), dtype=np.uint8))
    time.sleep(0.1)
np.savez(out, t=np.array(T), ammo=np.array(A), models=np.array([np.array(x) for x in M]))
print("samples", len(T), "ammo", A[0], "->", A[-1])
