C = "script/derpy_tp/combat.lua"
MUTANTS = [
    (C, 'if not P.play(shot.model, slot, phase == "fire" and 0 or 6) then return false end', 'P.play(shot.model, slot, phase == "fire" and 0 or 6)', 'solo_queue_rejection_retries_without_a_projectile'),
    (C, 'if not shot.started or clip == shot.slot then return end', 'if not shot.started then return end', 'solo_click_fires_one_shot'),
    (C, 'if clip == shot.slot and not shot.started then', 'if clip ~= nil and not shot.started then', 'a_shot_waits_for_its_fire_clip_not_the_idle_before_it'),
    (C, 'now >= shot.from + shot.times[shot.spawned + 1]', 'true', 'solo_projectile_delay_uses_model_time'),
    (C, 'launch(shot, shot.spawned == 1, shot.times[shot.spawned])', 'launch(shot, shot.spawned == 1, shot.times[shot.spawned]) launch(shot, false, shot.times[shot.spawned])', 'solo_click_fires_one_shot'),
    (C, 'if not P.alive(shot.unit, shot.model) then return end', 'do end', 'solo_dead_man_launches_nothing_before_the_frame_sees_it'),
    ('script/derpy_tp/platform.lua', 'and mr.read_int32(m, 0x284) == 0', '', 'platform_animation_slot_expires_with_its_native_handle'),
    ('script/derpy_tp/main.lua', 'if F.shot then P.face(F.model, E.rig.yaw)', 'if false then P.face(F.model, E.rig.yaw)', 'solo_firing_keeps_facing_without_a_walk_command'),
    (C, 'phase == "fire" and 0 or 6', '0', 'solo_aims_fires_then_reloads'),
    (C, 'phase == "fire" and 0 or 6', '6', 'solo_aims_fires_then_reloads'),
    # aim before fire (the author, 2026-10-14); 9.0 ids are AssetEditor's dlc24 list + 2
    (C, 'local aims = P.has_slot(F.model, shot.aim_slot)', 'local aims = false', 'solo_aims_fires_then_reloads'),
    (C, 'aim_len[F.utype .. shot.aim_slot] = aim_len[F.utype .. shot.aim_slot] or now - shot.at\n\t\t\t\tif shot.hold_slot then play_phase(shot, "hold", shot.hold_slot, now) else play_phase(shot, "fire", shot.fire_slot, now) end\n\t\t\t\treturn',
     'aim_len[F.utype .. shot.aim_slot] = aim_len[F.utype .. shot.aim_slot] or now - shot.at\n\t\t\t\treturn', 'solo_aims_fires_then_reloads'),
    # 2026-10-17: the raise to aim is no reload slot any more (it let men without RELOAD_1 skip the reload time)
    ('script/derpy_tp/platform.lua', 'if P.has_slot(m, 1564) then return 1564 end\n', 'if P.has_slot(m, 1564) then return 1564 end\n\t\tif P.has_slot(m, 1554) then return 1554 end\n', 'platform_reload_uses_the_active_fragment'),
    # its one use since 2026-10-17 is the high pair's check (no reload slot compares with it)
    (C, 'local SLOT_AIM = 1554 ', 'local SLOT_AIM = 1552 ', 'a_man_without_the_whole_high_pair_keeps_the_level_one'),
    (C, 'if F.unit:is_currently_flying() and P.has_slot(m, 1941) then', 'if false then', 'flying_mount_swings_use_airborne_rider_slots'),
    (C, 'elseif P.has_slot(m, 1901) then', 'elseif false then', 'mounted_swings_use_rider_slots'),
    (C, 'P.play(m, chosen, 6)', 'P.play(m, chosen)', 'rider_without_a_parent_keeps_its_own_clip'),
    (C, 'if mount and P.has_slot(mount, chosen - 1447) then P.play(mount, chosen - 1447)', 'if false then P.play(mount, chosen - 1447)', 'mounted_swings_use_rider_slots'),
    ('script/derpy_tp/abilities.lua', 'pcall(F.uc.perform_special_ability, F.uc, key, F.unit)\n', 'pcall(F.uc.perform_special_ability, F.uc, key)\n', 'ability_unknown_kind_casts_on_self'),
]
MUTANTS += [
    ("script/derpy_tp/combat.lua", "\t\tP.hold(F.model, x, z, E.rig.yaw)\n\t\tif not play_phase", "\t\tif not play_phase", "solo_shot_stops_his_walk_before_aiming"),
    ("script/derpy_tp/combat.lua", "\t\tP.hold(F.model, x, z, E.rig.yaw)\n\t\tif not play_phase(shot, aims and \"aim\" or \"fire\", aims and shot.aim_slot or shot.fire_slot, now) then return end",
     "\t\tif not play_phase(shot, aims and \"aim\" or \"fire\", aims and shot.aim_slot or shot.fire_slot, now) then return end\n\t\tP.hold(F.model, x, z, E.rig.yaw)", "solo_shot_stops_his_walk_before_aiming"),
]
SOUND = "\t\tif s[4] then play_sound(from, new_sfx(s[4], false, false)) end\n"
LOOP_END = "v(ax + jx, ay, az + jz))\n\t\tend\n\t\t-- the launch plays the projectile's sounds only; the bang is the weapon's, once a spawn (each is a discharge)\n"
MUTANTS += [
    (C, SOUND, "", "solo_shot_plays_the_weapons_fire_sound_once"),
    (C, "play_sound(from, new_sfx(s[4], false, false))", "play_sound(from, new_sfx(s[4]))", "solo_shot_plays_the_weapons_fire_sound_once"),
    (C, LOOP_END + SOUND, "v(ax + jx, ay, az + jz))\n" + SOUND + "\t\tend\n", "solo_shot_plays_the_weapons_fire_sound_once"),
]
