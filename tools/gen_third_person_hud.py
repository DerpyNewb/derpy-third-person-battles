"""Generate the third-person HUD: ui/derpy_tp/hud.twui.xml and script/derpy_tp/hud_layout.lua, from one dict.

    py tools/gen_third_person_hud.py             write both files
    py tools/gen_third_person_hud.py --check     build in memory and check it; writes nothing; exit 1 on a finding
    py tools/gen_third_person_hud.py --selftest  break each check once and see it caught

Spec: docs/superpowers/specs/2026-10-14-third-person-hud-design.md. Every size, colour and font is in HUD; the
Lua reads its numbers from the generated hud_layout.lua, so the two cannot disagree.
"""
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_tp_emitter as EM  # noqa: E402

SRC = os.path.join(EM.ROOT, "Modding Files", "source", "third_person")
UI_FILE = os.path.join(SRC, "ui", "derpy_tp", "hud.twui.xml")
LUA_FILE = os.path.join(SRC, "script", "derpy_tp", "hud_layout.lua")
LUAC = r"C:\Program Files (x86)\Lua\5.1\luac.exe"

# EVERY number the panel draws with, from CA's native art sizes (measured 2026-10-14 out of the ui packs: card
# 60x130; CA's battle ability button is a 59px icon on spell_dial_spell_frame drawn 69x69 at -5,-5; the key sits
# on number_frame_lozenge_18px; text plates are tooltip_frame, as CA's battle tooltips). The preview's
# render-compare-refine pass changes these, and only these.
HUD = {
    "margin": 24,                      # design px from the screen's edges
    "text": "#FFF8D7FF",               # CA's body text
    "portrait": (60, 130),
    "column": 320,                     # the plate beside the portrait: name, men, health bar, a caster's winds bar
    # the author, 2026-10-15: "should be also health and winds of magic(if wizard) on the unit panel". Each bar row is
    # CA's stat icon, the bar, then its figure; "fig" fits "12000 / 12000" in body_12
    "row_icon": 20, "fig": 84,
    "magic": "#41E1E1FF",              # CA's ui_colours "magic", 65 225 225: the winds bar's fill
    "stamina": "#A0FF37FF",            # CA's ui_colours "fatigue_fresh", 160 255 55: the stamina bar's fill
    "gap": 6, "pad": 8,                # portrait to plate; plate border to its text
    "bar_h": 19, "fill_in": (3, 4),    # bar_back height; the fill's inset inside bar_frame (x, y)
    "slot": 69, "icon": 59, "slot_gap": 8, "slots": 10,
    "key": (72, 18), "key_y": 63,      # the key's lozenge: size, and its top under the slot's rim
    "cool_plate": (44, 22),            # the same lozenge behind the cooldown seconds, centred on the icon
    "armed": 79,                       # CA's selected ability: spell_dial_spell_selected 79x79 at the icon's -10,-10
    "target": (320, 28), "target_y": 44,  # the armed ability's target label: size, and its top below screen centre
    "arrow": (52, 40), "arrow_lift": 3,  # the arrow over its target: CA's 68x53 event arrow at 0.77; tip, m above him
    "dim": "#FFFFFF82",                # CA's own tint on ability_inactive
    "windup": "#C0FFFFFF",             # CA's tint on the timer ring's wind_up state
    "right": (170, 64), "mode": 22,
    # the action buttons (the author, 2026-10-15: "the cooldown of each including melee and ranged"): CA's ability
    # button, right-aligned over the right plate, only those the unit can use, packed by hud.lua
    # 2026-10-16 ("shift button as the charge or sprint button ... make z as the toggable walk"): walk and sprint took the
    # run and charge buttons' places
    "actions": ("walk", "sprint", "attack", "fire", "jump", "fly", "cheer"), "stack": 8,
    "fonts": {"name": ("header_14", 14), "men": ("body_12", 12), "key": ("body_12", 12),
              "cool": ("header_14", 14), "ammo": ("header_20_bold", 20), "target": ("header_14", 14)},
    "ring": ((0.0, 3.141593), (0.0, -3.141593)),  # per half (L1 right, L2 left), empty -> full, radians, measured 2026-10-14
}
# The bar over every other unit (players, 2026-10-19: "a health bar each unit and a ally or enemy highlight"), briefed
# against CA's battle unit banner (ui3.pack ui/battle ui/unit_banner.twui.xml): its health bar is 40x10, a #000000 base
# with a #3B3B3B well, the fill, and the loss behind it in #AA0000 (DelayedHealthPercent). Pinned over the unit as CA's
# dev UI pins template_3d_unit (ContextWorldSpaceComponent on CcoBattleUnit.Position), filled and coloured by side as
# CA's reinforcement panel fills its unit bars (ContextFillBar, ContextColourSetter on AllianceColour; the authored
# colour is CA's alliance_player green, kept if the setter gives nothing), hidden by the engine while the player cannot
# see the unit (IsVisible). A unit takes the lowest lift at least its men's height + clear (data.lua bodies): one
# layout per lift, offset_y being the callback's own property
BAR = {
    "size": (40, 10), "base": "#000000FF", "well": "#3B3B3BFF", "delayed": "#AA0000FF", "fill": "#A2EC17FF",
    "lifts": (2.5, 3.5, 4.5, 6, 8, 11, 15, 22, 37), "clear": 0.7,
}
BAR_FILE = os.path.join(SRC, "ui", "derpy_tp", "bar_%d.twui.xml")
ART = {
    "card": "ui/units/icons/wh3_main_cth_inf_iron_hail_gunners_0.png",   # replaced at run time by the unit's card
    "bar": "ui/skins/default/bar_white.png",  # CA's banner and reinforcement bars, tinted
    "icon": "ui/battle ui/ability_icons/0_placeholder_active_abilitiy&spell.png",
    "slot": "ui/skins/default/spell_dial_spell_frame.png",
    "inactive": "ui/skins/default/ability_inactive.png",
    "armed": "ui/skins/default/spell_dial_spell_selected.png",
    "key": "ui/skins/default/number_frame_lozenge_18px.png",
    "bar_back": "ui/skins/default/bar_back.png",
    "bar_frame": "ui/skins/default/bar_frame.png",
    "bar_fill": "ui/skins/default/ammo_bar.png",
    "winds_fill": "ui/skins/default/army_schem_str_bar_fill.png",  # CA's grey bar fill, tinted HUD["magic"]
    "icon_men": "ui/skins/default/icon_entity_small.png",
    "icon_hp": "ui/skins/default/icon_stat_health.png",
    "icon_winds": "ui/skins/default/icon_magic_pool.png",
    "icon_stamina": "ui/battle ui/ability_icons/fatigue_restore.png",  # CA's tired-and-fresh legs
    "plate": "ui/skins/default/tooltip_frame.png",
    "melee": "ui/skins/default/icon_status_melee.png",
    "ranged": "ui/skins/default/icon_stat_ranged_damage.png",
    "arrow": "ui/skins/default/arrow_event_target_down.png",
    # CA's running ability: the green timer ring, left and right halves over the icon (hud_battle, button_ability)
    "active_l": "ui/skins/default/timer_ring1_ability_green.png",
    "active_r": "ui/skins/default/timer_ring2_ability_green.png",
    # its wind_up state: the plain ring at #C0FFFFFF
    "windup_l": "ui/skins/default/timer_ring1_ability.png",
    "windup_r": "ui/skins/default/timer_ring2_ability.png",
    # the action icons, CA's own 59px ability art, picked by eye 2026-10-15: an axe blow, a gun sight, a charging
    # warrior, a ground slam
    # 2026-10-16: a striding leg for the walk, the charge's warrior for the sprint, CA's tactical-map compass for the
    # minimap
    "act_walk": "ui/battle ui/ability_icons/fatigue_immune.png",
    "act_sprint": "ui/battle ui/ability_icons/wh_main_character_abilities_deadly_onslaught.png",
    "act_map": "ui/skins/default/icon_medium_tactical_map.png",
    "act_attack": "ui/battle ui/ability_icons/wh_main_lord_abilities_deathblow.png",
    "act_fire": "ui/battle ui/ability_icons/wh2_dlc13_lord_abilities_kill_shot.png",
    "act_jump": "ui/battle ui/ability_icons/wh3_dlc24_character_abilities_giant_leap.png",
    # 2026-10-15 (the author: "show also button huds for flying, cheer and hide UI"): CA's flying-unit emblem, its war
    # horn rally, and its concealment eye; flying_low was CA's pink placeholder
    "act_fly": "ui/battle ui/ability_icons/flying.png",
    "act_cheer": "ui/battle ui/ability_icons/force_rally.png",
    "act_hide": "ui/battle ui/ability_icons/hide_forest.png",
}


def _parts():
    """[(id, group, dx, dy, w, h, kw)] in draw order; dx, dy from the group's top-left, design px."""
    H, P = HUD, []
    pw, ph = H["portrait"]
    pad, bh = H["pad"], H["bar_h"]
    cx, col = pw + H["gap"], H["column"]
    ix, iw = cx + pad, col - 2 * pad     # the plate's inside
    fx, fy = H["fill_in"]
    f = H["fonts"]
    ri, fig = H["row_icon"], H["fig"]
    bx = ix + ri + 4                     # a bar row: icon, bar, figure
    bw = iw - (ri + 4) - 6 - fig
    sy = ph - pad - bh                   # stamina on the plate's floor (the author, 2026-10-16: "add stamina bar")
    hy = sy - 4 - bh                     # health above it
    wy = hy - 4 - bh                     # a caster's winds above it
    my = wy - 4 - 18                     # men above that
    ny = my - 22                         # name above that
    # first, so every part after it draws over the unit bars made in it (hud.lua); at the screen's corner, where the
    # engine's own placing of each bar starts
    P.append(("bars", "screen", 0, 0, 1, 1, {}))
    P.append(("portrait", "left", 0, 0, pw, ph, {"image": ART["card"]}))
    # the plate a caster's four rows sit on, and the one for the other three (hud.lua shows one, lifts LIFTED for it)
    P.append(("plate_left", "left", cx, ny - pad, col, ph - ny + pad, {"image": ART["plate"], "imagemargin": 8}))
    P.append(("plate_left_short", "left", cx, ny + _lift() - pad, col, ph - ny - _lift() + pad,
              {"image": ART["plate"], "imagemargin": 8}))
    P.append(("name", "left", ix, ny, iw, 22, {"text": " ", "fontcat": f["name"][0], "size": f["name"][1]}))
    P.append(("men_icon", "left", ix, my - 1, ri, ri, {"image": ART["icon_men"]}))
    P.append(("men", "left", bx, my, iw - (ri + 4), 18, {"text": " ", "fontcat": f["men"][0], "size": f["men"][1]}))
    for bar, y, fill, fig_id, tint in (("winds", wy, "winds_fill", "winds", H["magic"]),
                                       ("health", hy, "bar_fill", "hp", None),
                                       ("stamina", sy, "winds_fill", "stamina", H["stamina"])):
        P.append((fig_id + "_icon", "left", ix, y + (bh - ri) // 2, ri, ri, {"image": ART["icon_" + bar.replace("health", "hp")]}))
        P.append((bar + "_back", "left", bx, y, bw, bh, {"image": ART["bar_back"], "imagemargin": 6}))
        kw = {"image": ART[fill]}
        if tint:
            kw["colour_img"] = tint
        P.append((bar + "_fill", "left", bx + fx, y + fy, bw - 2 * fx, bh - 2 * fy, kw))
        P.append((bar + "_frame", "left", bx, y, bw, bh, {"image": ART["bar_frame"], "imagemargin": 6}))
        P.append((fig_id, "left", ix + iw - fig, y, fig, bh, {"text": " ", "fontcat": f["men"][0],
                                                               "size": f["men"][1], "align": "Right"}))
    sl, ic = H["slot"], H["icon"]
    io_ = (sl - ic) // 2
    kw_, kh = H["key"]
    for n in range(1, H["slots"] + 1):
        x = (n - 1) * (sl + H["slot_gap"])
        s = "slot_%d_" % n
        P.append((s + "frame", "bar", x, 0, sl, sl, {"image": ART["slot"]}))
        P.append((s + "icon", "bar", x + io_, io_, ic, ic, {"image": ART["icon"]}))
        for half in ("active_l", "active_r"):
            P.append((s + half, "bar", x + io_, io_, ic, ic, {"image": ART[half]}))
        for half in ("windup_l", "windup_r"):
            P.append((s + half, "bar", x + io_, io_, ic, ic, {"image": ART[half], "colour_img": H["windup"]}))
        # CA's inactive button: ability_inactive at #FFFFFF82 over the icon (hud_battle.twui.xml, button_ability)
        P.append((s + "dim", "bar", x + io_, io_, ic, ic, {"image": ART["inactive"], "colour_img": H["dim"]}))
        ao = (H["armed"] - ic) // 2      # CA's selected state: the ring over the icon, 10px out on every side
        P.append((s + "armed", "bar", x + io_ - ao, io_ - ao, H["armed"], H["armed"], {"image": ART["armed"]}))
        cw, ch = H["cool_plate"]
        cpx, cpy = x + (sl - cw) // 2, (sl - ch) // 2
        P.append((s + "coolplate", "bar", cpx, cpy, cw, ch, {"image": ART["key"]}))
        P.append((s + "cool", "bar", cpx, cpy, cw, ch, {"text": " ", "fontcat": f["cool"][0], "size": f["cool"][1],
                                                        "align": "Center"}))
        kx = x + (sl - kw_) // 2
        P.append((s + "keyplate", "bar", kx, H["key_y"], kw_, kh, {"image": ART["key"]}))
        P.append((s + "key", "bar", kx, H["key_y"], kw_, kh, {"text": " ", "fontcat": f["key"][0],
                                                              "size": f["key"][1], "align": "Center"}))
    for a in H["actions"]:  # each from its own button's corner: hud.lua packs the shown ones
        s = "act_%s_" % a
        P.append((s + "frame", "actions", 0, 0, sl, sl, {"image": ART["slot"]}))
        P.append((s + "icon", "actions", io_, io_, ic, ic, {"image": ART["act_" + a]}))
        for half in ("active_l", "active_r"):  # lit while on: the walk, the sprint, flight
            P.append((s + half, "actions", io_, io_, ic, ic, {"image": ART[half]}))
        P.append((s + "dim", "actions", io_, io_, ic, ic, {"image": ART["inactive"], "colour_img": H["dim"]}))
        cw, ch = H["cool_plate"]
        cpx, cpy = (sl - cw) // 2, (sl - ch) // 2
        P.append((s + "coolplate", "actions", cpx, cpy, cw, ch, {"image": ART["key"]}))
        P.append((s + "cool", "actions", cpx, cpy, cw, ch, {"text": " ", "fontcat": f["cool"][0], "size": f["cool"][1],
                                                           "align": "Center"}))
        kx = (sl - kw_) // 2
        P.append((s + "keyplate", "actions", kx, H["key_y"], kw_, kh, {"image": ART["key"]}))
        P.append((s + "key", "actions", kx, H["key_y"], kw_, kh, {"text": " ", "fontcat": f["key"][0],
                                                                 "size": f["key"][1], "align": "Center"}))
    # hide the interface, in the top-right corner (the author, 2026-10-15: "move the hide ui buttons elsewhere to not
    # crowd the actions bar"), and the minimap beside it (2026-10-16: "pressing M should show mini map"), lit while shown;
    # the same button, on its key. hud.lua puts CA's radar under them
    for b, x in (("map", 0), ("hide", sl + H["slot_gap"])):
        kx = x + (sl - kw_) // 2
        P.append((b + "_frame", "toggle", x, 0, sl, sl, {"image": ART["slot"]}))
        P.append((b + "_icon", "toggle", x + io_, io_, ic, ic, {"image": ART["act_" + b]}))
        if b == "map":
            for half in ("active_l", "active_r"):
                P.append((b + "_" + half, "toggle", x + io_, io_, ic, ic, {"image": ART[half]}))
        P.append((b + "_keyplate", "toggle", kx, H["key_y"], kw_, kh, {"image": ART["key"]}))
        P.append((b + "_key", "toggle", kx, H["key_y"], kw_, kh, {"text": " ", "fontcat": f["key"][0],
                                                                 "size": f["key"][1], "align": "Center"}))
    rw, rh = H["right"]
    md = H["mode"]
    P.append(("plate_right", "right", 0, 0, rw, rh, {"image": ART["plate"], "imagemargin": 8}))
    P.append(("mode", "right", 2 * pad - 6, 2 * pad - 6, md, md, {"image": ART["melee"]}))
    P.append(("ammo", "right", 40, 6, rw - 40 - pad, 26, {"text": " ", "fontcat": f["ammo"][0], "size": f["ammo"][1],
                                                         "align": "Right"}))
    ay = rh - pad - bh
    P.append(("ammo_back", "right", pad, ay, rw - 2 * pad, bh, {"image": ART["bar_back"], "imagemargin": 6}))
    P.append(("ammo_fill", "right", pad + fx, ay + fy, rw - 2 * pad - 2 * fx, bh - 2 * fy, {"image": ART["bar_fill"]}))
    P.append(("ammo_frame", "right", pad, ay, rw - 2 * pad, bh, {"image": ART["bar_frame"], "imagemargin": 6}))
    tw, th = H["target"]
    P.append(("target_plate", "centre", 0, 0, tw, th, {"image": ART["plate"], "imagemargin": 8}))
    P.append(("target", "centre", pad, 0, tw - 2 * pad, th, {"text": " ", "fontcat": f["target"][0],
                                                            "size": f["target"][1], "align": "Center"}))
    # placed with the label, then moved every frame onto the projected unit (hud.lua H.mark)
    P.append(("target_arrow", "centre", 0, 0, H["arrow"][0], H["arrow"][1], {"image": ART["arrow"]}))
    for _pid, _g, _dx, _dy, _w, _h, kw in P:
        if "text" in kw:
            kw.setdefault("colour", H["text"])
    return P


def _lift():
    """How far the rows above the winds bar drop when there is none: one bar row."""
    return HUD["bar_h"] + 4


LIFTED = ("name", "men_icon", "men")


def _groups():
    H = HUD
    n, sl = H["slots"], H["slot"]
    return {"left": (H["portrait"][0] + H["gap"] + H["column"], H["portrait"][1]),
            "bar": (n * sl + (n - 1) * H["slot_gap"], H["key_y"] + H["key"][1]),
            "right": H["right"], "centre": H["target"],
            "actions": (len(H["actions"]) * (sl + H["slot_gap"]) - H["slot_gap"], H["key_y"] + H["key"][1]),
            "toggle": (2 * sl + H["slot_gap"], H["key_y"] + H["key"][1]), "screen": (1, 1)}


def build_bar(n):
    """The bar layout for lift n (1-based): root > derpy_tp_bar (hud.lua shows and hides it) > pin (pinned) > base
    (hidden while unseen) > delayed, fill. The engine sets the pinned component's own visibility every frame (shown while
    on screen: measured 2026-10-19, a SetVisible on it was undone within 2 s), so hud.lua's goes on a plain parent.
    A fill's 100% is its parent's size (CA's ContextFillBar doc), and every child lands at its parent's corner on a
    component made at run time, so all share one box; the base's black edge draws a pixel outside it."""
    w, h = BAR["size"]
    unit = "CcoBattleUnit"
    root = EM.C("root", 1, 1)
    top = root.add(EM.C("derpy_tp_bar", w, h))
    pin = top.add(EM.C("pin", w, h, callbacks=[
        ("ContextWorldSpaceComponent", unit, "Position", {"depth_disabled": 1, "offset_y": BAR["lifts"][n - 1]})]))
    base = pin.add(EM.C("base", w, h, callbacks=[("ContextVisibilitySetter", unit, "IsVisible")], layers=[
        {"path": ART["bar"], "offset": (-1, -1), "dw": 2, "dh": 2, "margin": 1, "colour": BAR["base"], "dock": None},
        {"path": ART["bar"], "offset": (0, 0), "dw": 0, "dh": 0, "margin": 1, "colour": BAR["well"], "dock": None}]))
    base.add(EM.C("delayed", w, h, image=ART["bar"], imagemargin=1, colour_img=BAR["delayed"], callbacks=[
        ("ContextFillBar", unit, "DelayedHealthPercent", {"update_constant": 100})]))
    base.add(EM.C("fill", w, h, image=ART["bar"], imagemargin=1, colour_img=BAR["fill"], callbacks=[
        ("ContextFillBar", unit, "HealthPercent", {"update_constant": ""}),
        ("ContextColourSetter", unit, "AllianceColour")]))
    EM.assign(root, "D7B%d" % n)
    return EM.layout(root, "Third-Person Battles unit bar, lift %s m - GENERATED by tools/gen_third_person_hud.py"
                     % BAR["lifts"][n - 1])


def _lua(v):
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(round(v, 6))
    if isinstance(v, int):
        return str(v)
    if isinstance(v, (list, tuple)):
        return "{" + ", ".join(_lua(x) for x in v) + "}"
    raise TypeError(v)


def build():
    parts = _parts()
    # the engine drops the file's <root> and builds root's child as the component created (measured 2026-10-14);
    # a file without <root> makes CreateComponent answer nil
    root = EM.C("root", 1, 1)
    hud = root.add(EM.C("derpy_tp_hud", 1, 1))
    for pid, _g, _dx, _dy, w, h, kw in parts:
        hud.add(EM.C(pid, w, h, **kw))
    EM.assign(root, "D7A0")
    xml = EM.layout(root, "Third-Person Battles HUD - GENERATED by tools/gen_third_person_hud.py")
    g = _groups()
    width = dict((p[0], p[4]) for p in parts)
    lines = ["-- GENERATED by tools/gen_third_person_hud.py from its HUD dict: do not edit.",
             "return {",
             '\tfile = "ui/derpy_tp/hud",',
             "\tmargin = %d," % HUD["margin"],
             '\tprobe = "slot_1_frame", -- the part whose drawn size against its design size gives the UI scale',
             "\tslots = %d," % HUD["slots"],
             "\tgroups = {left = %s, bar = %s, right = %s, centre = %s, actions = %s, toggle = %s, screen = %s}," % (
                 _lua(g["left"]), _lua(g["bar"]), _lua(g["right"]), _lua(g["centre"]), _lua(g["actions"]),
                 _lua(g["toggle"]), _lua(g["screen"])),
             '\tbar = {file = "ui/derpy_tp/bar_", lifts = %s, clear = %s}, -- the unit bars: file .. n for lift n, m' % (
                 _lua(BAR["lifts"]), _lua(BAR["clear"])),
             "\tactions = %s, -- in order; hud.lua packs the shown ones against the right edge" % _lua(HUD["actions"]),
             "\taction_pitch = %d, -- one button and its gap" % (HUD["slot"] + HUD["slot_gap"]),
             "\tstack = %d, -- the actions' gap above the right plate" % HUD["stack"],
             "\ttarget_y = %d, -- the target label's top, design px below screen centre" % HUD["target_y"],
             "\tarrow_lift = %s, -- m above the unit's position the arrow's tip points at" % _lua(HUD["arrow_lift"]),
             "\tring = %s, -- radians, each half ring (L1, L2) from empty to full" % _lua(HUD["ring"]),
             "\tart = {melee = %s, ranged = %s}," % (_lua(ART["melee"]), _lua(ART["ranged"])),
             "\tfill = {health_fill = %d, ammo_fill = %d, winds_fill = %d, stamina_fill = %d}," % (
                 width["health_fill"], width["ammo_fill"], width["winds_fill"], width["stamina_fill"]),
             "\tlift = %d, -- design px the rows above a caster's winds bar drop for any other unit" % _lift(),
             "\tlifted = {%s}," % ", ".join("%s = true" % k for k in LIFTED),
             "\tat = {"]
    for pid, grp, dx, dy, _w, _h, _kw in parts:
        lines.append('\t\t["%s"] = {"%s", %d, %d},' % (pid, grp, dx, dy))
    lines.append("\t},")
    lines.append("\tsize = {")
    for pid, _grp, _dx, _dy, w, h, _kw in parts:
        lines.append('\t\t["%s"] = {%d, %d},' % (pid, w, h))
    lines += ["\t},", "}", ""]
    return xml, "\n".join(lines)


def check(xml, lua):
    bad = []
    have = EM._game_assets()
    for p in sorted(set(re.findall(r'imagepath="([^"]+)"', xml))):
        if p.replace("&amp;", "&") not in have:
            bad.append("no such art in CA's ui packs: %s" % p)
    for c in set(re.findall(r'font_m_colour="([^"]+)"', xml)):
        if c != HUD["text"]:
            bad.append("text colour %s is not HUD['text']" % c)
    for c in set(re.findall(r'fontcat_name="([^"]+)"', xml)):
        if c not in EM.FONTCATS:
            bad.append("font category %s is not one the game has" % c)
    hier = xml.split("<hierarchy>")[1].split("</hierarchy>")[0]
    comps = xml.split("<components>")[1]
    first = re.search(r"<([\w]+)", hier)
    if not first or first.group(1) != "root":
        bad.append("the file must open with <root>: without it CreateComponent answers nil")
    nodes = re.findall(r'<[\w]+ this="([^"]+)"', hier)
    defs = re.findall(r'\n\t\t<[\w]+\n\t\t\tthis="([^"]+)"', comps)
    for gid in sorted(set(nodes) ^ set(defs)):
        bad.append("guid %s is in one of hierarchy/components only" % gid)
    if 'interactive="true"' in xml:
        bad.append("an interactive component: the HUD must never take the mouse")
    ids = set(re.findall(r'\n\t\t\tid="([\w]+)"', comps)) - {"root", "derpy_tp_hud"}
    placed = set(re.findall(r'\["([\w]+)"\] = \{"', lua))
    for pid in sorted(ids - placed):
        bad.append("%s is not placed by hud_layout.lua" % pid)
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf-8") as fh:
        fh.write(lua)
    r = subprocess.run([LUAC, "-p", fh.name], capture_output=True, text=True)
    os.remove(fh.name)
    if r.returncode:
        bad.append("luac: hud_layout.lua does not parse: %s" % r.stderr.strip())
    if "\\" in lua:
        bad.append("a backslash cannot cross the bridge loader")
    return bad


def check_bar(xml, n):
    """A bar layout against what it promises: CA's art, paired GUIDs, nothing that takes the mouse, the pin on the unit at
    its lift, the fills under the base (their 100% is their parent), the fill coloured by side."""
    bad = []
    have = EM._game_assets()
    for p in sorted(set(re.findall(r'imagepath="([^"]+)"', xml))):
        if p not in have:
            bad.append("bar %d: no such art in CA's ui packs: %s" % (n, p))
    hier = xml.split("<hierarchy>")[1].split("</hierarchy>")[0]
    comps = xml.split("<components>")[1]
    for gid in sorted(set(re.findall(r'<[\w]+ this="([^"]+)"', hier))
                      ^ set(re.findall(r'\n\t\t<[\w]+\n\t\t\tthis="([^"]+)"', comps))):
        bad.append("bar %d: guid %s is in one of hierarchy/components only" % (n, gid))
    if 'interactive="true"' in xml:
        bad.append("bar %d: an interactive component would take the mouse off the battle" % n)
    shape = re.sub(r'\s*this="[^"]+"', "", hier)
    if not re.search(r"<root>\s*<derpy_tp_bar>\s*<pin>\s*<base>\s*<delayed/>\s*<fill/>\s*</base>\s*</pin>\s*"
                     r"</derpy_tp_bar>\s*</root>", shape):
        bad.append("bar %d: not root > derpy_tp_bar > pin > base > delayed, fill" % n)
    top = re.search(r"\n\t\t<derpy_tp_bar\n.*?\n\t\t</derpy_tp_bar>", comps, re.S)
    if not top or "callback_with_context" in top.group(0):
        bad.append("bar %d: a callback on the component hud.lua shows and hides (a pin's own visibility is the "
                   "engine's)" % n)
    pin = re.search(r'callback_id="ContextWorldSpaceComponent"\s+context_object_id="CcoBattleUnit"\s+'
                    r'context_function_id="Position">(.*?)</callback_with_context>', xml, re.S)
    lift = pin and re.search(r'name="offset_y"\s+value="([^"]+)"', pin.group(1))
    if not lift or float(lift.group(1)) != BAR["lifts"][n - 1]:
        bad.append("bar %d: the pin is not on CcoBattleUnit.Position at %s m" % (n, BAR["lifts"][n - 1]))
    for fn in ("HealthPercent", "DelayedHealthPercent"):
        if not re.search(r'callback_id="ContextFillBar"\s+context_object_id="CcoBattleUnit"\s+context_function_id="%s"' % fn, xml):
            bad.append("bar %d: no fill on %s" % (n, fn))
    if not re.search(r'callback_id="ContextColourSetter"\s+context_object_id="CcoBattleUnit"\s+'
                     r'context_function_id="AllianceColour"', xml):
        bad.append("bar %d: the fill is not coloured by side" % n)
    if not re.search(r'callback_id="ContextVisibilitySetter"\s+context_object_id="CcoBattleUnit"\s+'
                     r'context_function_id="IsVisible"', xml):
        bad.append("bar %d: a unit the player cannot see would show its bar" % n)
    return bad


def bars():
    return [build_bar(n) for n in range(1, len(BAR["lifts"]) + 1)]


def _pin_on_top(xml):
    """The selftest's break: the world-space callback moved up onto derpy_tp_bar, as shipped at 15:41 on 2026-10-19."""
    cb = re.search(r"\t\t\t<callbackwithcontextlist>\s*<callback_with_context\s+callback_id=\"ContextWorldSpaceComponent\""
                   r".*?</callbackwithcontextlist>\n", xml, re.S).group(0)
    xml = xml.replace(cb, "", 1)
    top = re.search(r"\n\t\t<derpy_tp_bar\n.*?\n\t\t</derpy_tp_bar>", xml, re.S).group(0)
    return xml.replace(top, top.replace("\t\t\t<states>", cb + "\t\t\t<states>", 1), 1)


def check_all(xml, lua, bar_xmls):
    bad = check(xml, lua)
    for n, b in enumerate(bar_xmls, 1):
        bad += check_bar(b, n)
    return bad


def selftest():
    xml, lua = build()
    bad = check_all(xml, lua, bars())
    if bad:
        print("the clean build has findings:\n  " + "\n  ".join(bad))
        return False
    breaks = [
        ("an art path no ui pack has", xml.replace("spell_dial_spell_frame.png", "spell_dial_spell_framex.png", 1), lua,
         "no such art"),
        ("a text colour from no dict", xml.replace(HUD["text"], "#FFFFFFFF", 1), lua, "text colour"),
        ("a font category the game lacks", xml.replace('fontcat_name="body_12"', 'fontcat_name="body_13"', 1), lua,
         "font category"),
        ("a hierarchy node with no definition", re.sub(r'(<slot_3_cool this=")[^"]+', r"\1DEADBEEF", xml, count=1), lua,
         "guid"),
        ("an interactive component", xml.replace('name="standard"', 'name="standard"\n\t\t\t\t\tinteractive="true"', 1),
         lua, "interactive"),
        ("a part the layout does not place", xml, lua.replace('["slot_7_key"]', '["slot_7_kez"]', 1), "not placed"),
        ("a layout that does not parse", xml, lua + "\n}", "luac"),
        ("a file without <root>", xml.replace("<root this=", "<frame this=", 1).replace("</root>", "</frame>", 1), lua,
         "<root>"),
    ]
    ok = True
    for what, x, l, want in breaks:
        got = check(x, l)
        if not any(want in g for g in got):
            print("NOT CAUGHT: %s (got %s)" % (what, got))
            ok = False
        else:
            print("caught: %s" % what)
    b = build_bar(3)
    bar_breaks = [
        ("a bar at another lift", b.replace('value="4.5"', 'value="45"', 1), "Position at"),
        ("a bar on no unit", b.replace('context_function_id="Position"', 'context_function_id="Positoin"', 1), "Position at"),
        ("a fill on no health", b.replace('"HealthPercent"', '"HealthPercnt"', 1), "no fill on HealthPercent"),
        ("a fill in one colour", b.replace('"AllianceColour"', '"AllianceColor"', 1), "coloured by side"),
        ("a bar the player cannot see shown", b.replace('"IsVisible"', '"IsVisibel"', 1), "cannot see"),
        ("a fill that is no child of the base", re.sub(r"(<fill this=\"[^\"]+\"/>)\s*</base>", r"</base>\1", b, count=1),
         "not root"),
        ("an art path no ui pack has", b.replace("bar_white.png", "bar_whit.png", 1), "no such art"),
        ("a bar that takes the mouse", b.replace('name="standard"', 'name="standard"\n\t\t\t\t\tinteractive="true"', 1),
         "interactive"),
        ("the pin on the component hud.lua hides", _pin_on_top(b), "shows and hides"),
    ]
    for what, x, want in bar_breaks:
        got = check_bar(x, 3)
        if not any(want in g for g in got):
            print("NOT CAUGHT: %s (got %s)" % (what, got))
            ok = False
        else:
            print("caught: %s" % what)
    return ok


def main(argv):
    if "--selftest" in argv:
        return 0 if selftest() else 1
    xml, lua = build()
    bar_xmls = bars()
    bad = check_all(xml, lua, bar_xmls)
    for b in bad:
        print("FINDING: %s" % b)
    if bad:
        return 1
    if "--check" in argv:
        print("--check: clean, nothing written")
        return 0
    os.makedirs(os.path.dirname(UI_FILE), exist_ok=True)
    with open(UI_FILE, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(xml)
    with open(LUA_FILE, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(lua)
    for n, b in enumerate(bar_xmls, 1):
        with open(BAR_FILE % n, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(b)
    print("wrote %s, %s and %d unit bars" % (UI_FILE, LUA_FILE, len(bar_xmls)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
