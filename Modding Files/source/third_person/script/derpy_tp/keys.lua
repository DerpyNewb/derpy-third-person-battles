-- The keys the MCT page offers, their Windows virtual-key codes, and the 30 actions with their
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
	"ability_10"}

K.defaults = {toggle = "F2", forward = "W", back = "S", left = "A", right = "D", walk = "Z", sprint = "Shift",
	look_free = "Middle mouse", lock = "Middle mouse", attack = "Left mouse", mode = "Right mouse", jump = "E", fly = "Space", zoom_in = "+", zoom_out = "-",
	cheer = "O", hide_ui = "P", minimap = "M", view = "V", guide = "Alt", page = "T",
	ability_1 = "1", ability_2 = "2", ability_3 = "3", ability_4 = "4", ability_5 = "5", ability_6 = "6",
	ability_7 = "7", ability_8 = "8", ability_9 = "9", ability_10 = "0"}

K.labels = {toggle = "Third person on and off", forward = "Walk forward", back = "Walk back", left = "Walk left",
	right = "Walk right", walk = "Walk (press to switch, or hold: see Combat)", look_free = "Free the mouse while held",
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
	ability_9 = "Ability 9", ability_10 = "Ability 10"}

-- an action that may sit on another's key: the lock-on is a click (main.lua), the free mouse a hold, so the middle
-- button carries both (a player, 2026-10-21, asked for the lock-on; the author: "maybe middle mouse button click")
K.shares = {lock = "look_free"}

-- the game's shortcut on each key it binds without a modifier, of the keys above (default_keys, read 2026-10-15): while
-- third person is on, the one on a key an action has is off (P paused the game as it hid the interface). M and Shift
-- the game binds only with a modifier. T cycles the reinforcement spawn zone (default_keys.xml, read 2026-10-20)
K.game = {P = "toggle_pause", O = "visibility_toggle_radar", K = "toggle_ui", Space = "show_allied_units_proxies",
	Z = "cam_down", T = "cycle_next_spawn_zone"}
-- the game's shortcut on each key it binds with Alt (default_keys, read 2026-10-19): off on an action's key while third
-- person is on and Alt is the guide key, held with those keys
K.game_alt = {X = "toggle_sfx", M = "toggle_music", K = "toggle_ui_with_borders", ["0"] = "button_group_management_6",
	["1"] = "battle_land_spell_1", ["2"] = "battle_land_spell_2", ["3"] = "battle_land_spell_3",
	["4"] = "battle_land_spell_4", ["5"] = "battle_land_spell_5", ["6"] = "battle_land_spell_6"}

return K
