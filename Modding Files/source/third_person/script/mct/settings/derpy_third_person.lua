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
	.. "is selected. Keys and camera are read each time it is switched on. It does nothing in multiplayer.")

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
for _, action in ipairs(K.order) do
	local o = m:add_new_option("key_" .. action, "dropdown")
	o:set_text(K.labels[action])
	o:set_tooltip_text("Default: " .. K.defaults[action] .. ". A key already used by an action higher in this list "
		.. "is not taken twice: this action goes back to its default.")
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
slider("combat", "combat_reload", "Reload time",
	"Percent of the unit's own reload when you shoot with one man. 100 is the game's time.", 100, 25, 300)
slider("combat", "combat_spread", "Volley scatter",
	"Tenths of a metre each shot of a several-shot volley lands from your aim. 0 sends them all to one point.", 15, 0, 50)
checkbox("combat", "combat_one_man", "Play one man of a regiment",
	"On, you play the regiment's front man: he walks, swings and shoots alone while the rest hold. Off, you move the "
	.. "whole regiment as before.", true)

m:add_new_section("display", "On the battlefield")
local bars = m:add_new_option("display_bars_show", "dropdown")
bars:set_text("Health bars")
bars:set_tooltip_text("A health bar over each unit near you, in its side's colour. A unit you cannot see shows none.")
bars:add_dropdown_values({{key = "always", text = "Always", tt = "", is_default = true},
	{key = "guide", text = "With the markers key", tt = "Only while the markers are shown (Alt unless changed under Keys).",
	is_default = false}, {key = "off", text = "Never", tt = "", is_default = false}})
bars:set_assigned_section("display")
slider("display", "display_bars_range", "Health bar distance",
	"Metres from you within which a unit shows its health bar. 1000 shows every unit on the field.", 40, 10, 1000)
checkbox("display", "display_guide_hold", "Hold to show enemies and allies",
	"Coloured markers under the men of every unit you do not command, an enemy only while you can see it. On, they show "
	.. "while the key is held (Alt unless changed under Keys). Off, a press shows or hides them.", true)

m:add_new_section("debug", "Debug")
checkbox("debug", "debug_log", "Write every order to the script log", "For bug reports. Off by default.", false)
