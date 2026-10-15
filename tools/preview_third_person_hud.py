"""Render the third-person HUD as the shipped Lua leaves it, over a battle screenshot, and check it.

    py tools/preview_third_person_hud.py             draw .skilltree_cache/ui_preview/tp_hud_<w>.png at 1600/1920/2560
    py tools/preview_third_person_hud.py --check     validate the twui with TWUI Studio's reader; no drawing
    py tools/preview_third_person_hud.py --selftest  prove the contrast and fit checks can fail

WHERE EVERY PART IS comes from the harness: tools/third_person_hud_dump.lua runs the SHIPPED hud.lua against the
fake UI tree and writes each part's position, size, visibility, image and text (the same route as the Iron
Court's IC_DUMP). The art is CA's, pulled out of the ui packs by preview_guilds_panel.extract_art and drawn with
TWUI Studio's rendering.raster. Text is PIL's font: positions are exact, glyph widths approximate.
"""
import io
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import preview_guilds_panel as PG  # noqa: E402
import gen_third_person_hud as GEN  # noqa: E402

ROOT = PG.ROOT
FOLDER = os.path.dirname(GEN.UI_FILE)
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"
GROUND = os.path.join(ROOT, "docs", "mockups", "tp_hud_ground.png")   # a battle screenshot, no UI
WIDTHS = (1600, 1920, 2560)
LOW, OVER = [], []
TEXT = tuple(int(GEN.HUD["text"][i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def _lum(rgb):
    c = [v / 255.0 for v in rgb[:3]]
    c = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast(canvas, box, size):
    """The text colour against the brightest tenth of what is under the box (text is read against the bright end)."""
    x, y, w, h = box
    crop = canvas.crop((int(x), int(y), int(x + max(w, 1)), int(y + max(h, 1)))).convert("RGB")
    data = crop.get_flattened_data() if hasattr(crop, "get_flattened_data") else crop.getdata()
    ls = sorted(_lum(p) for p in data)
    bg = ls[int(len(ls) * 0.9)] if ls else 0
    return (_lum(TEXT) + 0.05) / (bg + 0.05)


def _font(size):
    from PIL import ImageFont
    for name in ("georgia.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", name), size)
        except OSError:
            pass
    return ImageFont.load_default()


def too_wide(text, box_w, size):
    from PIL import Image, ImageDraw
    d = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    return d.textlength(text, font=_font(size)) > box_w - 4


def dump():
    """[(id, x, y, w, h, visible, image, text)] as the shipped hud.lua left the harness's tree."""
    out = os.path.join(tempfile.gettempdir(), "tp_hud_dump.tsv")
    env = dict(os.environ, TP_HUD_DUMP=out)
    src = os.path.join(ROOT, "Modding Files", "source", "third_person").replace(os.sep, "/")
    r = subprocess.run([LUA, os.path.join(ROOT, "tools", "third_person_harness.lua"), src,
                        os.path.join(ROOT, "tools", "third_person_hud_dump.lua"), "dump"],
                       capture_output=True, text=True, env=env)
    if r.returncode:
        raise SystemExit("the dump scene failed:\n" + r.stdout + r.stderr)
    rows = []
    for line in io.open(out, encoding="utf-8").read().splitlines():
        pid, x, y, w, h, vis, img, text = (line.split("\t") + [""] * 8)[:8]
        rows.append((pid, float(x), float(y), float(w), float(h), vis == "true", img, text))
    return rows


def _asset(path):
    from pathlib import Path
    p = os.path.join(PG.UI, os.path.relpath(path, "ui").replace("/", os.sep))
    return Path(p) if os.path.isfile(p) else None


def render(width):
    """One picture at this screen width, scaled from the 1920 the harness lays out at."""
    from PIL import Image, ImageDraw
    model, rendering = PG._studio()
    doc = model.Document(io.open(GEN.UI_FILE, encoding="utf-8").read())
    named = dict((c.get("id", c.tag), c) for c in doc.components)
    rows = dump()
    _n, missing = PG.extract_art("hud", extra=sorted({r[6] for r in rows if r[6]}), folder=FOLDER)
    if missing:
        raise SystemExit("art not found in CA's packs: %s" % missing)
    scale = width / 1920.0
    size = (width, int(1080 * scale + 0.5))
    if os.path.isfile(GROUND):
        canvas = Image.open(GROUND).convert("RGBA").resize(size)
    else:
        canvas = Image.new("RGBA", size, (96, 104, 88, 255))
    draw = ImageDraw.Draw(canvas)
    texts = []
    for pid, x, y, w, h, vis, image, text in rows:
        comp = named.get(pid)
        if not vis or comp is None:
            continue
        X, Y = x * scale, y * scale
        W, Hh = max(1, int(w * scale + 0.5)), max(1, int(h * scale + 0.5))
        # image 0 is what the Lua last set with SetImagePath, else the file's own
        slots, images = [], {}
        box = comp.child("componentimages")
        if box is not None:
            for n in box.children:
                if n.get("this"):
                    slots.append(n.get("this"))
                    images[n.get("this")] = n.get("imagepath")
        if image and slots:
            images[slots[0]] = image
        st = doc.state(comp)
        metrics = st.child("imagemetrics") if st is not None else None
        for n in (metrics.children if metrics is not None else []):
            asset = _asset(images.get(n.get("componentimage")) or "")
            if asset:
                canvas.alpha_composite(rendering.raster(asset, W, Hh, n), (int(X), int(Y)))
        if text.strip():
            texts.append((pid, X, Y, W, Hh, text, st.child("component_text")))
    # text last, over every plate, the way the engine draws a label over its own and its elders' art
    for pid, X, Y, W, Hh, text, ct in texts:
        px = int(int(ct.get("font_m_size")) * scale + 0.5)
        f = _font(px)
        tw = draw.textlength(text, font=f)
        align = ct.get("texthalign")
        tx = X + (W - tw) / 2 if align == "Center" else (X + W - tw - 4 if align == "Right" else X + 4)
        ty = Y + (Hh - px) / 2 - 1
        ratio = contrast(canvas, (tx, ty, tw, px), px)
        if ratio < 4.5:
            LOW.append("%d: %.1f:1  %s %r" % (width, ratio, pid, text))
        if too_wide(text, W, px):
            OVER.append("%d: %s %r is wider than its %dpx box" % (width, pid, text, W))
        draw.text((tx, ty), text, fill=TEXT, font=f)
    out = os.path.join(PG.CACHE, "tp_hud_%d.png" % width)
    canvas.convert("RGB").save(out)
    return out


def main(argv):
    if "--selftest" in argv:
        return 0 if selftest() else 1
    problems = PG.validate("hud", folder=FOLDER)
    for p in problems:
        print("FINDING: %s" % p)
    if "--check" in argv:
        print("--check: %d finding(s)" % len(problems))
        return 1 if problems else 0
    for w in WIDTHS:
        print("drew %s" % render(w))
    for line in LOW + OVER:
        print("FINDING: %s" % line)
    return 1 if (problems or LOW or OVER) else 0


def selftest():
    from PIL import Image
    bright = Image.new("RGBA", (200, 40), (250, 245, 230, 255))
    dark = Image.new("RGBA", (200, 40), (10, 10, 10, 255))
    ok = True
    if contrast(bright, (0, 0, 200, 40), 12) >= 4.5:
        print("NOT CAUGHT: pale text on a pale ground passed")
        ok = False
    if contrast(dark, (0, 0, 200, 40), 12) < 4.5:
        print("WRONG: pale text on black failed")
        ok = False
    if not too_wide("Numpad 9" * 4, 56, 12):
        print("NOT CAUGHT: a label four times its slot passed")
        ok = False
    print("selftest ok" if ok else "selftest FAILED")
    return ok


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
