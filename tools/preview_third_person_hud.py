"""Render the third-person HUD as the shipped Lua leaves it, over a battle screenshot, and check it.

    py tools/preview_third_person_hud.py             draw .skilltree_cache/ui_preview/tp_hud_<w>.png at 1600/1920/2560
    py tools/preview_third_person_hud.py --check     validate the twui with TWUI Studio's reader; no drawing
    py tools/preview_third_person_hud.py --bars      draw the unit bar (ui/derpy_tp/bar_1) for each side, tp_bars_<w>.png
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


def dump(page=1):
    """[(id, x, y, w, h, visible, image, text)] as the shipped hud.lua left the harness's tree, on that page of the bar."""
    out = os.path.join(tempfile.gettempdir(), "tp_hud_dump.tsv")
    env = dict(os.environ, TP_HUD_DUMP=out, TP_HUD_PAGE=str(page))
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


def render(width, page=1):
    """One picture at this screen width, scaled from the 1920 the harness lays out at, on that page of the bar."""
    from PIL import Image, ImageDraw
    model, rendering = PG._studio()
    doc = model.Document(io.open(GEN.UI_FILE, encoding="utf-8").read())
    named = dict((c.get("id", c.tag), c) for c in doc.components)
    rows = dump(page)
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
        if pid == "radar_group" and vis:  # CA's radar, which the engine draws: its box, as a stand-in
            box = (x * scale, y * scale, (x + w) * scale, (y + h) * scale)
            draw.ellipse(box, fill=(28, 32, 26, 255), outline=(150, 118, 70, 255), width=max(2, int(4 * scale)))
            draw.text((box[0] + 40 * scale, box[1] + h * scale / 2 - 8), "CA minimap", fill=TEXT, font=_font(int(14 * scale)))
            continue
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
            LOW.append("%d p%d: %.1f:1  %s %r" % (width, page, ratio, pid, text))
        if too_wide(text, W, px):
            OVER.append("%d p%d: %s %r is wider than its %dpx box" % (width, page, pid, text, W))
        draw.text((tx, ty), text, fill=TEXT, font=f)
    out = os.path.join(PG.CACHE, "tp_hud_%d.png" % width if page == 1 else "tp_hud_%d_p%d.png" % (width, page))
    canvas.convert("RGB").save(out)
    return out


# What AllianceColour answers, from CA's ui_colours (db.pack, read with tools/read_vanilla_db.py): the fill's colour by
# side, which the engine sets and no file carries
SIDES = (("ours", "#A2EC17"), ("ally", "#68CEFF"), ("enemy", "#FF2D2D"))




# a row: health, its loss, morale, MoraleState, ActiveEffectState
ROWS = ((1.0, 1.0, 1.0, 1, None), (0.66, 0.8, 0.55, 4, "positive"), (0.25, 0.4, 0.15, 6, "negative"))


def render_bars(width):
    """The unit bar (ui/derpy_tp/bar_1, as shipped) for each side at full, two-thirds and a quarter health with the
    loss behind it, the morale strip under it and the morale and effect icons beside it, over the battle screenshot, at
    the size the engine draws it on this screen. Each pin's box stands its bottom centre on the unit's point, as the
    engine places it (measured 2026-10-19), and draws what it carries at its own corner."""
    from PIL import Image, ImageDraw
    model, rendering = PG._studio()
    xml = io.open(GEN.BAR_FILE % 1, encoding="utf-8").read()
    doc = model.Document(xml)
    named = dict((c.get("id", c.tag), c) for c in doc.components)
    icons = [s[1] for s in GEN.MORALE_STATES] + [s[1] for s in GEN.EFFECT_STATES]
    _n, missing = PG.extract_art("hud", extra=[GEN.ART["bar"]] + icons, folder=FOLDER)
    if missing:
        raise SystemExit("art not found in CA's packs: %s" % missing)
    scale = width / 1920.0
    size = (width, int(1080 * scale + 0.5))
    canvas = Image.open(GROUND).convert("RGBA").resize(size) if os.path.isfile(GROUND) else Image.new("RGBA", size, (96, 104, 88, 255))
    draw = ImageDraw.Draw(canvas)

    def corner(pid, cx, cy):
        pw, ph = GEN._box(xml, pid)
        return cx - pw * scale / 2, cy - ph * scale

    def icon(path, tint, offset, x, y):
        side = int(GEN.BAR["icon"] * scale + 0.5)
        img = Image.open(str(_asset(path))).convert("RGBA").resize((side, side))
        if tint:  # CA's white leadership icon under the state's colour
            want = [int(tint[i:i + 2], 16) for i in (1, 3, 5)]
            px = img.load()
            for i in range(side):
                for j in range(side):
                    r, g, b, a = px[i, j]
                    px[i, j] = (r * want[0] // 255, g * want[1] // 255, b * want[2] // 255, a)
        canvas.alpha_composite(img, (int(x + offset[0] * scale), int(y + offset[1] * scale)))

    def layer(comp, x, y, frac, colour=None):
        st = doc.state(comp)
        box = comp.child("componentimages")
        paths = dict((n.get("this"), n.get("imagepath")) for n in box.children) if box is not None else {}
        for n in st.child("imagemetrics").children:
            ox, oy = (float(v) for v in n.get("offset", "0,0").split(","))
            w = max(1, int(float(n.get("width")) * frac * scale + 0.5))
            h = max(1, int(float(n.get("height")) * scale + 0.5))
            img = rendering.raster(_asset(paths[n.get("componentimage")]), w, h, n)
            if colour:  # bar_white under the authored colour, re-tinted by its shading to the side's
                was = int(n.get("colour")[3:5], 16) or 1
                want = [int(colour[i:i + 2], 16) for i in (1, 3, 5)]
                px = img.load()
                for i in range(img.size[0]):
                    for j in range(img.size[1]):
                        r, g, b, a = px[i, j]
                        k = min(1.0, g / float(was))
                        px[i, j] = (int(want[0] * k), int(want[1] * k), int(want[2] * k), a)
            canvas.alpha_composite(img, (int(x + ox * scale), int(y + oy * scale)))

    for col, (side, colour) in enumerate(SIDES):
        for row, (hp, lost, morale, state, effect) in enumerate(ROWS):
            cx, cy = (800 + col * 160) * scale, (446 + row * 60) * scale  # the unit's point
            x, y = corner("pin", cx, cy)
            layer(named["base"], x, y, 1)
            layer(named["delayed"], x, y, lost)
            layer(named["fill"], x, y, hp, colour)
            x, y = corner("pin_morale", cx, cy)
            layer(named["morale_base"], x, y, 1)
            layer(named["morale"], x, y, morale)
            if state >= GEN.BAR["morale_from"]:
                _name, path, tint, offset = GEN.MORALE_STATES[state]
                icon(path, tint, offset, *corner("pin_state", cx, cy))
            for name, path, offset in GEN.EFFECT_STATES:
                if name == effect:
                    icon(path, None, offset, *corner("pin_effects", cx, cy))
        draw.text(((760 + col * 160) * scale, 390 * scale), side, fill=TEXT, font=_font(int(14 * scale)))
    out = os.path.join(PG.CACHE, "tp_bars_%d.png" % width)
    canvas.convert("RGB").save(out)
    return out


def main(argv):
    if "--selftest" in argv:
        return 0 if selftest() else 1
    if "--bars" in argv:
        for w in WIDTHS:
            print("drew %s" % render_bars(w))
        return 0
    problems = PG.validate("hud", folder=FOLDER)
    for p in problems:
        print("FINDING: %s" % p)
    if "--check" in argv:
        print("--check: %d finding(s)" % len(problems))
        return 1 if problems else 0
    for w in WIDTHS:
        print("drew %s" % render(w))
    print("drew %s" % render(1920, 3))  # the spells page (the dump scene's third)
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
