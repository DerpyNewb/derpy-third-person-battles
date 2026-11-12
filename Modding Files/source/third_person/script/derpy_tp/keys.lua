-- The keys the MCT page offers, their Windows virtual-key codes, and the actions with their
-- defaults and labels. The MCT page and the battle script both loadfile this, so they cannot
-- disagree. A name can stand for two keys: "+" is the main-row plus and the numpad plus.
local K = {names = {}, vk = {}}

local function add(name, code) K.names[#K.names + 1] = name K.vk[name] = code end
local function run(names, first) for i = 1, #names do add(names[i], first + i - 1) end end

add("Left mouse", 0x01) add("Right mouse", 0x02) add("Middle mouse", 0x04) add("Mouse 4", 0x05) add("Mouse 5", 0x06)
run({"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W",
	"X", "Y", "Z"}, 0x41)
run({"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}, 0x30)
run({"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"}, 0x70)
run({"Numpad 0", "Numpad 1", "Numpad 2", "Numpad 3", "Numpad 4", "Numpad 5", "Numpad 6", "Numpad 7", "Numpad 8",
	"Numpad 9"}, 0x60)
add("Shift", 0x10) add("Ctrl", 0x11) add("Alt", 0x12) add("Space", 0x20) add("Tab", 0x09) add("Caps Lock", 0x14)
add("Enter", 0x0D) add("Backspace", 0x08) add("Insert", 0x2D) add("Delete", 0x2E) add("Home", 0x24) add("End", 0x23)
add("Page Up", 0x21) add("Page Down", 0x22) add("Up", 0x26) add("Down", 0x28) add("Left", 0x25) add("Right", 0x27)
add("+", {0xBB, 0x6B}) add("-", {0xBD, 0x6D})

K.order = {"toggle", "forward", "back", "left", "right", "walk", "sprint", "look_free", "lock", "attack", "mode", "jump", "fly", "zoom_in",
	"zoom_out", "cheer", "hide_ui", "minimap", "view", "guide", "page", "ability_1", "ability_2", "ability_3", "ability_4", "ability_5", "ability_6", "ability_7", "ability_8", "ability_9",
	"ability_10", "command", "cmd_follow", "cmd_charge", "cmd_hold", "cmd_unit_1", "cmd_unit_2", "cmd_unit_3", "cmd_unit_4",
	"cmd_unit_5", "cmd_unit_6", "cmd_unit_7", "cmd_unit_8", "cmd_unit_9", "cmd_unit_10", "cmd_page", "cmd_pause", "cmd_speed",
	-- last: a key a player already gave an action above keeps it, and these fall back (settings.lua)
	"man_left", "man_right", "block"}

K.defaults = {toggle = "F2", forward = "W", back = "S", left = "A", right = "D", walk = "Z", sprint = "Shift",
	look_free = "Middle mouse", lock = "Middle mouse", attack = "Left mouse", mode = "Right mouse", jump = "E", fly = "Space", zoom_in = "+", zoom_out = "-",
	cheer = "O", hide_ui = "P", minimap = "M", view = "V", guide = "Alt", page = "T",
	ability_1 = "1", ability_2 = "2", ability_3 = "3", ability_4 = "4", ability_5 = "5", ability_6 = "6",
	ability_7 = "7", ability_8 = "8", ability_9 = "9", ability_10 = "0",
	command = "Q", cmd_follow = "F1", cmd_charge = "F3", cmd_hold = "F4", cmd_unit_10 = "0", cmd_page = "E",
	cmd_pause = "Space", cmd_speed = "Shift",
	-- beside Z and the move keys; the game's own on them only nudge its camera, off while third person is on (K.game)
	man_left = "X", man_right = "C", block = "F"}
-- the number row picks the units, one card each (the author, 2026-10-23: "USE THE NUM ROW FOR SELECTING UNITS"; it was
-- the numpad)
for n = 1, 9 do K.defaults["cmd_unit_" .. n] = tostring(n) end
-- the MCT page's AZERTY box: a default on one of these keys moves to the key at its place on an AZERTY keyboard (Windows
-- key codes follow the layout). Keys chosen by hand stay (a player, 2026-11-03)
K.azerty = {W = "Z", Z = "W", A = "Q", Q = "A"}

K.labels = {toggle = "Third person on and off", forward = "Walk forward", back = "Walk back", left = "Walk left",
	right = "Walk right", walk = "Walk (press to switch, or hold: see Combat)",
	look_free = "Free the mouse while held; in command mode, Vanilla style, a click frees or takes it back",
	lock = "Lock on to the enemy ahead, lords and heroes first (click; click again to let go)",
	attack = "Attack and fire", mode = "Melee or ranged; artillery aiming",
	sprint = "Sprint and charge (hold while moving; click to attack)", jump = "Jump attack",
	fly = "Fly or land (flying units)", zoom_in = "Zoom in", zoom_out = "Zoom out", cheer = "Cheer",
	hide_ui = "Hide or show the interface (works paused)", minimap = "Show or hide the minimap",
	view = "First or third person view",
	guide = "Markers and unit banners (hold, or press: see On the battlefield)",
	page = "Next page of the ability bar (abilities, spells)",
	ability_1 = "Ability 1", ability_2 = "Ability 2", ability_3 = "Ability 3", ability_4 = "Ability 4",
	ability_5 = "Ability 5", ability_6 = "Ability 6", ability_7 = "Ability 7", ability_8 = "Ability 8",
	ability_9 = "Ability 9", ability_10 = "Ability 10",
	command = "Command mode: order your army (press; see Command mode)",
	cmd_follow = "Command mode: follow me (Bannerlord style)", cmd_charge = "Command mode: charge (Bannerlord style)",
	cmd_hold = "Command mode: hold (Bannerlord style)",
	cmd_unit_10 = "Command mode: select unit 10 (unit 20 after the page key; Vanilla style)",
	cmd_page = "Command mode: units 1-10, 11-20 (Vanilla style)", cmd_pause = "Command mode: pause",
	cmd_speed = "Command mode: slow or normal speed (tap; Vanilla style)",
	man_left = "Play the entity to the left in your regiment", man_right = "Play the entity to the right in your regiment",
	block = "Block while held (a lord, hero or monster, uses stamina)"}
for n = 1, 9 do K.labels["cmd_unit_" .. n] = "Command mode: select unit " .. n .. " (Vanilla style)" end
-- in command mode's Bannerlord style the number row picks a group (command.lua C.name), 0 everyone
for n, group in pairs({"infantry", "ranged", "cavalry", "monsters", "artillery", "heroes", [10] = "everyone"}) do
	K.labels["ability_" .. n] = K.labels["ability_" .. n] .. " (command mode, Bannerlord style: " .. group .. ")"
end

-- an action that may sit on another's key: the lock-on is a click (main.lua), the free mouse a hold, so the middle
-- button carries both (a player, 2026-10-21, asked for the lock-on; the author: "maybe middle mouse button click").
-- Command mode's Vanilla keys are live only in the mode, where the jump, the fly, the sprint and the abilities are off
-- (main.lua)
K.shares = {lock = "look_free", cmd_page = "jump", cmd_pause = "fly", cmd_speed = "sprint"}
for n = 1, 10 do K.shares["cmd_unit_" .. n] = "ability_" .. n end

-- the game's shortcut on each key it binds without a modifier, of the keys above (default_keys, read 2026-10-15): while
-- third person is on, the one on a key an action has is off (P paused the game as it hid the interface). M and Shift
-- the game binds only with a modifier. T cycles the reinforcement spawn zone (default_keys.xml, read 2026-10-20); X and
-- C raise and tilt its camera (read 2026-11-02); F is its melee mode (default_keys_osx.xml, read 2026-11-11)
K.game = {P = "toggle_pause", O = "visibility_toggle_radar", K = "toggle_ui", Space = "show_allied_units_proxies",
	Z = "cam_down", T = "cycle_next_spawn_zone", X = "cam_up", C = "rot_d", F = "battle_land_melee"}
-- and its control groups on the bare 0-9 (CA's keymap, read 2026-10-23): the number row casts his skills, and picks the
-- units in command mode
for n = 0, 9 do K.game[tostring(n)] = "usegroup" .. n end
-- the game's shortcut on each key it binds with Alt (default_keys, read 2026-10-19): off on an action's key while third
-- person is on and Alt is the guide key, held with those keys
K.game_alt = {X = "toggle_sfx", M = "toggle_music", K = "toggle_ui_with_borders", ["0"] = "button_group_management_6",
	["1"] = "battle_land_spell_1", ["2"] = "battle_land_spell_2", ["3"] = "battle_land_spell_3",
	["4"] = "battle_land_spell_4", ["5"] = "battle_land_spell_5", ["6"] = "battle_land_spell_6"}

return K
