-- MCT page for Third-Person Battles. MCT loads every .lua under script/mct/settings/, so this runs only
-- when MCT is installed; without it every key and value keeps its default. Key names, defaults and
-- labels come from script/derpy_tp/keys, the file the battle script reads too.
local mct = get_mct and get_mct()
if not mct then return end
local chunk = loadfile("/script/derpy_tp/keys")
if not chunk then return end
local K = chunk()

local m = mct:register_mod("derpy_third_person")
m:set_title("Third-Person Battles")
m:set_author("derpy")
m:set_description("Play one unit from behind in battle. F2 takes the selected unit, or your general when none "
	.. "is selected. Keys and camera are read each time it is switched on.")

local function slider(section, key, text, tooltip, default, min, max)
	local o = m:add_new_option(key, "slider")
	o:set_text(text)
	o:set_tooltip_text(tooltip)
	o:slider_set_precision(0)
	o:slider_set_min_max(min, max)
	o:slider_set_step_size(1, 0)
	o:set_default_value(default)
	o:set_assigned_section(section)
end

local function checkbox(section, key, text, tooltip, default)
	local o = m:add_new_option(key, "checkbox")
	o:set_text(text)
	o:set_tooltip_text(tooltip)
	o:set_default_value(default)
	o:set_assigned_section(section)
end

m:add_new_section("keys", "Keys")
-- the pairs that may share one key (keys.lua K.shares): each one's tooltip names the other
local partner = {}
for a, b in pairs(K.shares) do partner[a], partner[b] = b, a end
for _, action in ipairs(K.order) do
	local o = m:add_new_option("key_" .. action, "dropdown")
	o:set_text(K.labels[action])
	local tip = "Default: " .. K.defaults[action] .. ". A key already used by an action higher in this list "
		.. "is not taken twice: this action goes back to its default."
	if partner[action] then
		tip = tip .. ' The one exception: it shares its key with "' .. K.labels[partner[action]]
			.. '", as the two never work at the same time.'
	end
	o:set_tooltip_text(tip)
	local list = {}
	for i, name in ipairs(K.names) do list[i] = {key = name, text = name, tt = "", is_default = name == K.defaults[action]} end
	o:add_dropdown_values(list)
	o:set_assigned_section("keys")
end

m:add_new_section("camera", "Camera")
slider("camera", "camera_sensitivity", "Mouse speed", "How far the camera turns for each pixel the mouse moves.", 4, 1, 20)
slider("camera", "camera_smoothing", "Turn smoothing",
	"Hundredths of a second the view takes to catch up with the mouse. 0 turns at once; higher is smoother and softer.", 5, 0, 30)
checkbox("camera", "camera_invert_y", "Invert up and down", "Moving the mouse up looks down.", false)
slider("camera", "camera_distance", "Distance behind", "Metres from the unit to the camera.", 6, 3, 15)
local side = m:add_new_option("camera_shoulder", "dropdown")
side:set_text("Aiming shoulder")
side:set_tooltip_text("Where the camera sits in ranged mode: over his right or left shoulder, or above his head.")
side:add_dropdown_values({{key = "right", text = "Right", tt = "", is_default = true},
	{key = "left", text = "Left", tt = "", is_default = false}, {key = "top", text = "Top", tt = "", is_default = false}})
side:set_assigned_section("camera")
slider("camera", "camera_zoom_speed", "Zoom speed", "How fast holding + or - zooms, in tenths.", 12, 5, 30)
slider("camera", "camera_height", "Height", "Tenths of a metre the camera sits above the unit.", 25, 10, 80)
slider("camera", "camera_lag", "Follow delay",
	"Hundredths of a second the camera trails the unit. Lower is tighter; 0 follows each step at once.", 45, 0, 100)
slider("camera", "camera_aim_back", "Aiming distance",
	"Tenths of a metre the camera sits behind the shoulder in ranged mode.", 32, 15, 80)
slider("camera", "camera_melee_distance", "Distance in melee",
	"Tenths of a metre from the unit to the camera while it fights hand to hand. It never goes further out than "
	.. "Distance behind.", 35, 15, 150)

m:add_new_section("combat", "Combat")
checkbox("combat", "combat_walk_hold", "Hold to walk",
	"On, you walk only while the walk key is held. Off, a press switches between running and walking.", false)
slider("combat", "move_turn_rate", "Turning speed",
	"Degrees a second one man turns toward a new direction. Higher turns sharper.", 360, 90, 1440)
slider("combat", "combat_swing_cooldown", "Time between swings",
	"Tenths of a second between two attacks. Forced swings deal damage, so this keeps them fair.", 40, 5, 100)
slider("combat", "combat_charge_cooldown", "Time between charge attacks",
	"Tenths of a second between two charge attacks.", 100, 0, 600)
slider("combat", "combat_jump_cooldown", "Time between jump attacks",
	"Tenths of a second between two jump attacks.", 100, 5, 300)
slider("combat", "combat_reload", "Reload time (one man)",
	"How long the one man you play takes to reload, as a percent of the game's time: lower is faster. 25 reloads in a "
	.. 'quarter of the time, 300 takes three times as long. Only with "Play one man of a regiment" on, for a man who '
	.. "shoots alone: a whole regiment, a hero, a monster with a crew such as a stegadon, and artillery reload at the "
	.. "game's own speed.", 100, 25, 300)
slider("combat", "combat_spread", "Volley scatter",
	"Tenths of a metre each shot of a several-shot volley lands from your aim. 0 sends them all to one point.", 15, 0, 50)
checkbox("combat", "combat_one_man", "Play one man of a regiment",
	"On, you play the regiment's front man: he walks, swings and shoots alone while the rest hold. Off, you move the "
	.. "whole regiment as before.", true)

m:add_new_section("display", "On the battlefield")
local bars = m:add_new_option("display_bars_show", "dropdown")
bars:set_text("Health bars")
bars:set_tooltip_text("A health bar over each unit near you, in its side's colour, with its morale under it. An icon beside "
	.. "them shows when its morale wavers or breaks, and when a spell or ability is working on it. A unit you cannot see "
	.. "shows none.")
bars:add_dropdown_values({{key = "always", text = "Always", tt = "", is_default = true},
	{key = "guide", text = "With the markers key", tt = "Only while the markers are shown (Alt unless changed under Keys).",
	is_default = false}, {key = "off", text = "Never", tt = "", is_default = false}})
bars:set_assigned_section("display")
slider("display", "display_bars_range", "Health bar distance",
	"Metres from you within which a unit shows its health bar. 1000 shows every unit on the field.", 40, 10, 1000)
checkbox("display", "display_guide_hold", "Hold to show enemies and allies",
	"Coloured markers under the men of every unit you do not command, an enemy only while you can see it. On, they show "
	.. "while the key is held (Alt unless changed under Keys). Off, a press shows or hides them.", true)
checkbox("display", "display_guide_banners", "Unit banners with the markers",
	"On, the game's own banners come back over every unit while the markers show: what each unit is, its side, its "
	.. "health and morale. The health bars step aside meanwhile. Off, the key shows the markers alone.", true)

m:add_new_section("command", "Command mode")
local style = m:add_new_option("command_style", "dropdown")
style:set_text("Command style")
style:set_tooltip_text("Vanilla: the game's own controls, the camera on you. Right-click and drag to order, click to "
	.. "select, the number keys pick units, a middle click frees the cursor. Bannerlord: the number keys pick groups, clicks "
	.. "and F keys give the orders.")
style:add_dropdown_values({{key = "vanilla", text = "Vanilla", tt = "", is_default = true},
	{key = "bannerlord", text = "Bannerlord", tt = "", is_default = false}})
style:set_assigned_section("command")
local speed = m:add_new_option("command_speed", "dropdown")
speed:set_text("Battle speed in command mode")
speed:set_tooltip_text("How fast the battle runs while you give orders. Play your general or a hero and press the "
	.. "command key (Q unless changed under Keys). Multiplayer battles keep their speed.")
speed:add_dropdown_values({{key = "normal", text = "Normal", tt = "", is_default = false},
	{key = "half", text = "Half", tt = "", is_default = false}, {key = "quarter", text = "Quarter", tt = "", is_default = true},
	{key = "paused", text = "Paused", tt = "", is_default = false}})
speed:set_assigned_section("command")
slider("command", "command_distance", "Command view distance",
	"Metres behind you the camera moves out to while you give orders. 0 keeps the view as it is.", 20, 0, 40)
checkbox("command", "command_any_unit", "Any unit can command",
	"Off, only your general and heroes can give orders in command mode. On, any unit you play can.", false)

-- one dropdown a stat, its steps from script/derpy_tp/stats, the list the battle script and the build read too
local stats = loadfile("/script/derpy_tp/stats")
local T = stats and stats()
if T then
	m:add_new_section("stats", "Unit stats")
	for _, stat in ipairs(T.order) do
		local s = T.stats[stat]
		local o = m:add_new_option("stat_" .. stat, "dropdown")
		o:set_text(s.label)
		o:set_tooltip_text("Raises or lowers the " .. s.label:lower() .. " of the unit you play"
			.. (s.points and " by the points shown" or " by a percent of its own") .. ", for as long as you play it. It shows "
			.. "in the unit's list of effects. Not in multiplayer.")
		local list = {{key = "none", text = "None", tt = "", is_default = true}}
		for _, step in ipairs(T.steps(stat)) do
			list[#list + 1] = {key = T.step_key(step), text = T.text(stat, step), tt = "", is_default = false}
		end
		o:add_dropdown_values(list)
		o:set_assigned_section("stats")
	end
end

m:add_new_section("debug", "Debug")
checkbox("debug", "debug_log", "Write every order to the script log", "For bug reports. Off by default.", false)
