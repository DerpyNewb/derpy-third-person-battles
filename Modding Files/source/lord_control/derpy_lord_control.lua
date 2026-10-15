-- derpy_lord_control: steer your general from behind, single-player battles only.
--   F2        lord mode on/off - selects your general, a script camera follows him
--   Shift+F2  lord mode on/off - the same, but the game's own tracking camera follows him
--   F3        walk on/off - he keeps walking where the camera faces; turn the camera to steer
--   F4        attack the nearest visible enemy in front of the camera (nearest anywhere if none)
-- Normal clicks, spells and abilities keep working: every order is released back to the player.

if bm:is_multiplayer() then return end	-- a scripted order would desync the other player

local CAM = "derpy_lord_control_cam"
local WALK = "derpy_lord_control_walk"
local CAM_TICK_MS = 100		-- the battle model's own tick; a timer cannot run faster
local WALK_TICK_MS = 400
local WALK_AHEAD = 25		-- metres ahead of the general each walk order aims at
local CHASE_BACK = 30		-- where lord mode first puts the camera: metres behind him...
local CHASE_UP = 14			-- ...and above him
local FRONT_COS = 0.5		-- "in front" = within 60 degrees of the camera's facing

local deployed, on, walking, tracking = false, false, false, false
local lord, uc

local function log(msg) out("derpy_lord_control: " .. msg) end

local function alive()
	return lord and lord:number_of_men_alive() > 0
end

-- The camera's heading on the ground, as a unit x/z pair; nil when it looks straight down.
local function facing()
	local cam = bm:camera()
	local p, t = cam:position(), cam:target()
	local dx, dz = t:get_x() - p:get_x(), t:get_z() - p:get_z()
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.01 then return nil end
	return dx / len, dz / len
end

local function find_general()
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		local u = units:item(i)
		if u:is_commanding_unit() then return u end
	end
end

local function stop_walk()
	if not walking then return end
	walking = false
	bm:remove_process(WALK)
	if alive() then
		uc:halt()
		uc:release_control()
	end
end

local set_mode

-- Slide the camera onto the general, keeping whatever angle and zoom the player has given it.
local function follow()
	if not alive() then return set_mode(false) end
	local cam = bm:camera()
	local p, t, l = cam:position(), cam:target(), lord:position()
	cam:move_to(
		battle_vector:new(l:get_x() + p:get_x() - t:get_x(), l:get_y() + p:get_y() - t:get_y(), l:get_z() + p:get_z() - t:get_z()),
		battle_vector:new(l:get_x(), l:get_y(), l:get_z()),
		CAM_TICK_MS / 1000, true, -1
	)
end

local function walk()
	if not alive() then return set_mode(false) end
	local fx, fz = facing()
	if not fx then return end
	local l = lord:position()
	uc:goto_location(battle_vector:new(l:get_x() + fx * WALK_AHEAD, l:get_y(), l:get_z() + fz * WALK_AHEAD), true)
	uc:release_control()
end

local function pick_target()
	local alliances = bm:alliances()
	local mine = bm:local_alliance()
	local my_alliance = alliances:item(mine)
	local fx, fz = facing()
	local l = lord:position()
	local front, front_d, near, near_d
	for a = 1, alliances:count() do
		if a ~= mine then
			local armies = alliances:item(a):armies()
			for i = 1, armies:count() do
				local units = armies:item(i):units()
				for j = 1, units:count() do
					local u = units:item(j)
					if u:is_valid_target() and u:number_of_men_alive() > 0 and u:is_visible_to_alliance(my_alliance) then
						local p = u:position()
						local dx, dz = p:get_x() - l:get_x(), p:get_z() - l:get_z()
						local d = math.sqrt(dx * dx + dz * dz)
						if not near_d or d < near_d then near, near_d = u, d end
						if fx and d > 0 and (dx * fx + dz * fz) / d >= FRONT_COS and (not front_d or d < front_d) then
							front, front_d = u, d
						end
					end
				end
			end
		end
	end
	return front or near
end

set_mode = function(enable, use_tracking)
	if enable == on then return end
	if enable then
		lord = find_general()
		if not alive() then return log("no living general") end
		uc = bm:get_player_army():create_unit_controller()
		uc:add_units(lord)
		lord:select_in_ui()
		tracking = use_tracking
		if tracking then
			-- the shortcut acts on the selection, so give the selection a moment to land
			bm:callback(function() common.trigger_shortcut("toggle_tracking") end, 200)
		else
			local fx, fz = facing()
			if not fx then fx, fz = 0, 1 end
			local l = lord:position()
			bm:camera():move_to(
				battle_vector:new(l:get_x() - fx * CHASE_BACK, l:get_y() + CHASE_UP, l:get_z() - fz * CHASE_BACK),
				battle_vector:new(l:get_x(), l:get_y(), l:get_z()),
				0, false, -1
			)
			bm:repeat_callback(follow, CAM_TICK_MS, CAM)
		end
	else
		stop_walk()
		bm:remove_process(CAM)
		if tracking then common.trigger_shortcut("toggle_tracking") end
	end
	on = enable
	log(enable and ("lord mode on, " .. (tracking and "tracking" or "script") .. " camera") or "lord mode off")
end

local KEYS = {
	script_F2 = function() set_mode(not on, false) end,
	script_shift_F2 = function() set_mode(not on, true) end,
	script_F3 = function()
		if not on then return end
		if walking then return stop_walk() end
		walking = true
		walk()
		bm:repeat_callback(walk, WALK_TICK_MS, WALK)
	end,
	script_F4 = function()
		if not on or not alive() then return end
		local target = pick_target()
		if not target then return log("no visible enemy") end
		stop_walk()		-- the next walk order would cancel the attack
		uc:attack_unit(target, true, true)
		uc:release_control()
	end,
}

bm:register_phase_change_callback("Deployed", function() deployed = true end)

core:add_listener(
	"derpy_lord_control_keys",
	"ShortcutPressed",
	function(context) return deployed and KEYS[context.string] ~= nil end,
	function(context) KEYS[context.string]() end,
	true
)
