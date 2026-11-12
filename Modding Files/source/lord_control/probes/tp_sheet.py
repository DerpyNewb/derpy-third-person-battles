"""sheet.py <dir> <out.png> [x0 y0 x1 y1] [cols]: every frame in dir cropped and tiled, labelled with its ms."""
import os, sys
from PIL import Image, ImageDraw
d, out = sys.argv[1], sys.argv[2]
box = tuple(int(v) for v in sys.argv[3:7]) if len(sys.argv) >= 7 else None
cols = int(sys.argv[7]) if len(sys.argv) >= 8 else 6
fs = sorted(f for f in os.listdir(d) if f.endswith(".png"))
ims = []
for f in fs:
    im = Image.open(os.path.join(d, f)).convert("RGB")
    if box: im = im.crop(box)
    im.thumbnail((320, 320))
    ImageDraw.Draw(im).text((4, 4), f[:-4], fill=(255, 0, 0))
    ims.append(im)
w, h = ims[0].size
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, h * rows))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols) * w, (i // cols) * h))
sheet.save(out)
print(len(ims), sheet.size)
