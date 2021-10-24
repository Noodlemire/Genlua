--[[
Genlua: TF2 Weapon Generator
Copyright (C) 2021 Noodlemire

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
--]]

core.weapon = {}

local registered = {}

local classes = {"scout", "soldier", "pyro", "demo", "engineer", "heavy", "medic", "sniper", "spy"}

local function classSlots(name)
	local slots = {"primary", "secondary", "melee"}

	if name == "spy" then
		table.remove(slots, 1)
	end

	if name == "engineer" or name == "spy" then
		table.insert(slots, "primary_PDA")
		table.insert(slots, "secondary_PDA")
	end

	if name == "spy" then
		table.insert(slots, "building")
	end

	return slots
end

local function weaponAddStat(weapon, stat)
	assert(type(weapon) == "table", "Weapon Error: improper addStat() usage. The proper format is `weapon:addStat(<stat>)")
	assert(type(stat) == "table" or type(stat) == "string", "Weapon Error: weapon:addStat() requires \"stat\" as a table or a string as its first argument.")

	table.insert(weapon.stats, stat)

	if type(stat) == "table" then
		weapon.stat_points = weapon.stat_points + stat.weight
	end
end

local function weaponSortStats(weapon)
	assert(type(weapon) == "table", "Weapon Error: improper sortStats() usage. The proper format is `weapon:sortStats()")

	local pro = {}
	local con = {}
	local med = {}

	for i = 1, #weapon.stats do
		local stat = weapon.stats[i]
		local subStat = (type(stat) == "string" and stat or stat.description):sub(1, 1)

		if subStat == "+" then
			table.insert(pro, stat)
		elseif subStat == "-" then
			table.insert(con, stat)
		else
			table.insert(med, stat)
		end
	end

	for i = 1, #pro do
		table.insert(med, pro[i])
	end
	for i = 1, #con do
		table.insert(med, con[i])
	end

	weapon.stats = med
end

local function weaponToString(weapon, level)
	assert(type(weapon) == "table", "Weapon Error: improper toString() usage. The proper format is `weapon:toString([level or 1])")

	local str = {}

	str.image = "assets/Icon"..core.utils.nameToTitle(weapon.name, true)..".png"

	str.title = "A new "

	local slotLines = {}
	for slot, classes in pairs(weapon.slots) do
		table.insert(slotLines, core.utils.nameToTitle(slot).." for the "..core.utils.andList(core.utils.namesToTitles(core.utils.getKeys(classes))))
	end

	str.title = string.upper(str.title..core.utils.andList(slotLines, true))
	str.subtitle = "Level "..level.." "..core.utils.nameToTitle(weapon.name)

	str.stats = {}
	for i = 1, #weapon.stats do
		local stat = weapon.stats[i]

		table.insert(str.stats, type(stat) == "string" and stat or stat.description)
	end

	if weapon.flags.has_crit_bonus and not weapon.flags.never_deployed
			and weapon.name ~= "sniper_rifle" and weapon.name ~= "bow" and weapon.name ~= "knife" then
		table.insert(str.stats, "-No random critical hits")
	end

	return str
end

local function hasSlot(def, goal)
	for class, slot in pairs(def.slots) do
		if slot == goal then
			return true
		end
	end
end

function core.weapon.register(name, slots, flags, on_generate)
	assert(type(name) == "string", "Weapon Error: Must provide a name as a string.")
	assert(not registered[name], "Weapon Error: Weapon type \""..name.."\" already exists.")
	assert(type(slots) == "table", "Weapon Error: Must provide slots as a table.")

	assert(core.utils.hasKeys(slots, classes),
		"Weapon Error: Must provide at least one valid class that can use this weapon. Available class names: "..core.utils.iTableToString(classes))

	local def = {slots = {}, flags = {}, on_generate = on_generate}

	for class, slot in pairs(slots) do
		local validSlots = classSlots(class)

		assert(core.utils.contains(classes, class),
			"Weapon Error: Provided class \""..class.."\" is invalid. Available class names: "..core.utils.iTableToString(classes))
		assert(core.utils.contains(validSlots, slot), 
			"Weapon Error: Provided class \""..class.."\" must be set to a valid slot. Available slot names: "..core.utils.iTableToString(validSlots))

		def.slots[class] = slot
	end

	for flag, val in pairs(flags) do
		def.flags[flag] = val
	end

	registered[name] = def
end

function core.weapon.create(class, slot)
	if class == "any" then class = nil end
	if slot == "any" then slot = nil end

	assert(not class or core.utils.contains(classes, class), 
		"Weapon Error: If a class name is provided, it must be valid. Available class names: "..core.utils.iTableToString(classes))

	local options = {}

	for name, def in pairs(registered) do
		if (not class and not slot) or
				(class and not slot and def.slots[class]) or
				(not class and slot and hasSlot(def, slot)) or
				(class and slot and def.slots[class] == slot) then

			table.insert(options, name)
		end
	end

	if class then
		assert(#options > 0, 
			"Weapon Error: No weapons of type \""..(slot or "").."\" exist for class \""..class
			.."\". Available slot names: "..core.utils.iTableToString(classSlots(class)))
	end

	local wep_type = options[math.random(#options)]
	local wep_def = core.utils.clone(registered[wep_type])
	local num_classes = core.utils.numKeys(wep_def.slots)
	local available_classes = {}
	local available_slots = {}

	if num_classes > 1 then
		for c, s in pairs(wep_def.slots) do
			if (not slot or s == slot) and (c == class or (not wep_def.flags.never_multi_class and math.random(1, 1 + math.ceil(num_classes / 2)) == 1)) then
				available_classes[c] = s
			end
		end
	end

	if core.utils.numKeys(available_classes) == 0 then
		local slots = wep_def.slots

		if slot then
			slots = {}

			for c, s in pairs(wep_def.slots) do
				if s == slot then
					slots[c] = s
				end
			end
		end

		local c, s = core.utils.randomSelection(slots)
		available_classes = {[c] = s}
	end

	for class, slot in pairs(available_classes) do
		available_slots[slot] = available_slots[slot] or {}
		available_slots[slot][class] = true
	end

	local weapon = {
		name = wep_type,
		classes = available_classes,
		slots = available_slots,
		flags = wep_def.flags,
		stats = {},
		stat_points = 0,

		addStat = weaponAddStat,
		sortStats = weaponSortStats,
		toString = weaponToString
	}

	if wep_def.on_generate then
		wep_def.on_generate(weapon)
	end

	return weapon
end



core.weapon.register("scattergun", {scout = "primary"}, {clip = 6, reserve = 32, damage = 6, interval = 0.625, bullets_per_shot = 10, spread = true, falloff = true})
core.weapon.register("peppergun", {scout = "primary"}, {clip = 4, reserve = 36, reload_whole_clip = true, damage = 12, interval = 0.36, bullets_per_shot = 4, spread = true, falloff = true}, function(weapon)
	weapon.stats[1] = "Reloads its entire clip at once"
end)
core.weapon.register("bat", {scout = "melee"}, {damage = 35, interval = 0.5})

core.weapon.register("rocket_launcher", {soldier = "primary"}, {clip = 4, reserve = 20, damage = 90, interval = 0.8, splash = 146, projectile = true, falloff = true, cant_destroy_stickybombs = true})
core.weapon.register("banner", {soldier = "secondary"}, {charge_build = true, charge_result = true, activation_time = 3, duration = 10, never_altfire = true}, core.special_stats.banner)

core.weapon.register("flame_thrower", {pyro = "primary"}, {reserve = 200, damage = 13, interval = 0.075, afterburn = 4, airblast = true, altfire = true, no_reload = true, no_on_hit = true, reload_to_activate = true, falloff = true, cant_destroy_stickybombs = true}, function(weapon)
	weapon.stats[1] = "+Extinguishing teammates restores 20 health"
end)
core.weapon.register("flare_gun", {pyro = "secondary"}, {reserve = 16, damage = 30, afterburn = 4, projectile = true, gravity = true}, function(weapon)
	weapon.stats[1] = "This weapon will reload automatically while holstered"
	weapon.stat_points = -50
end)

core.weapon.register("grenade_launcher", {demo = "primary"}, {clip = 4, reserve = 16, damage = 100, interval = 0.6, splash = 146, never_altfire = true, projectile = true, gravity = true, falloff = true, cant_destroy_stickybombs = true})
core.weapon.register("stickybomb_launcher", {demo = "secondary"}, {clip = 8, reserve = 24, damage = 120, interval = 0.6, splash = 146, hold_to_charge = true, altfire = true, projectile = true, gravity = true, falloff = true, cant_destroy_stickybombs = true})

core.weapon.register("minigun", {heavy = "primary"}, {reserve = 200, damage = 9, interval = 0.105, bullets_per_shot = 4, spread = true, altfire = true, no_reload = true, reload_to_activate = true, falloff = true})

core.weapon.register("construction_PDA", {engineer = "primary_PDA"}, {})
core.weapon.register("destruction_PDA", {engineer = "secondary_PDA"}, {})

core.weapon.register("syringe_gun", {medic = "primary"}, {clip = 40, reserve = 150, reload_whole_clip = true, damage = 10, interval = 0.105, spread = true, projectile = true, gravity = true, no_reflect = true, falloff = true, regeneration = true})
core.weapon.register("medigun", {medic = "secondary"}, {altfire = true, regeneration = true}, core.special_stats.medigun)

core.weapon.register("sniper_rifle", {sniper = "primary"}, {reserve = 26, damage = 150, hold_to_charge = true, altfire = true, has_crit_bonus = true, instakill_goal = true, reload_to_activate = true})
core.weapon.register("bow", {sniper = "primary"}, {reserve = 12, damage = 120, hold_to_charge = true, projectile = true, gravity = true, instakill_goal = true})
core.weapon.register("SMG", {sniper = "secondary"}, {clip = 25, reserve = 75, reload_whole_clip = true, damage = 8, interval = 0.105, spread = true, falloff = true})

core.weapon.register("revolver", {spy = "secondary"}, {clip = 6, reserve = 24, reload_whole_clip = true, damage = 40, interval = 0.5, spread = true, never_altfire = true, falloff = true})
core.weapon.register("knife", {spy = "melee"}, {damage = 40, interval = 0.8, never_altfire = true, has_crit_bonus = true, instakill_goal = true})
core.weapon.register("disguise_kit", {spy = "primary_PDA"}, {never_altfire = true})
core.weapon.register("invis_watch", {spy = "secondary_PDA"}, {recharge = 30, duration = 10, never_deployed = true, altfire = true}, core.special_stats.invis_watch)
core.weapon.register("sapper", {spy = "building"}, {never_altfire = true})



core.weapon.register("pistol",
	{scout = "secondary", engineer = "secondary"},
	{clip = 12, reserve = 36, reload_whole_clip = true, damage = 15, interval = 0.15, spread = true, falloff = true}
)

core.weapon.register("throwing_weapon",
	{scout = "secondary", soldier = "secondary", engineer = "secondary", sniper = "secondary", spy = "secondary"},
	{recharge = 5.1, damage = 50, projectile = true, gravity = true},
	function(weapon)
		weapon.stat_points = -50
	end
)

core.weapon.register("shotgun",
	{soldier = "secondary", pyro = "secondary", engineer = "primary", heavy = "secondary"},
	{clip = 6, reserve = 32, damage = 6, interval = 0.625, bullets_per_shot = 10, spread = true, falloff = true}
)

core.weapon.register("indivisible_particle_smasher",
	{soldier = "secondary", pyro = "secondary", engineer = "primary", heavy = "secondary"},
	{clip = 4, no_ammo = true, no_reflect = true, less_building_damage = true, damage = 60, interval = 0.8, projectile = true, falloff = true, damage_change = "player_vs_building"},
	function(weapon)
		weapon.stats[1] = "+Does not require ammo"
		weapon.stats[2] = "+Projectile cannot be deflected"
		weapon.stats[3] = "-Deals only 20% damage to buildings"
		weapon.stat_points = -50
		core.notes.put("IPS")
	end
)

core.weapon.register("crossbow",
	{medic = "primary", sniper = "primary"},
	{reserve = 38, damage = 75, projectile = true, gravity = true, never_multi_class = true},
	function(weapon)
		weapon.stats[1] = "Fires special bolts that deal increased damage based on distance traveled"
		weapon.stats[2] = "This weapon will reload automatically while holstered"
		weapon.stat_points = -50

		if weapon.classes.medic then
			weapon.stats[3] = "-No headshots"
		else
			weapon.flags.instakill_goal = true
		end
	end
)

core.weapon.register("lunchbox",
	{scout = "secondary", soldier = "secondary", engineer = "secondary", heavy = "secondary", sniper = "secondary"},
	{recharge = 30, activation_time = 1.2, duration = 8, never_multi_class = true, never_altfire = true},
	core.special_stats.lunchbox)

core.weapon.register("jar",
	{scout = "secondary", soldier = "secondary", pyro = "secondary", engineer = "secondary", heavy = "secondary", sniper = "secondary"},
	{recharge = 20, projectile = true, gravity = true, splash = 200, required_category = "splash_effect"},
	function(weapon)
		weapon.stats[1] = "+Extinguishing teammates reduces cooldown by -20%"
		weapon.stat_points = -50
	end
)

core.weapon.register("backpack", {pyro = "secondary", heavy = "secondary", medic = "primary", sniper = "secondary"},
	{never_deployed = true}, core.special_stats.no_weapon)

core.weapon.register("boots", {scout = "secondary", soldier = "secondary", demo = "primary", engineer = "secondary", sniper = "secondary"},
	{never_deployed = true}, core.special_stats.no_weapon)

core.weapon.register("shield", {demo = "secondary", heavy = "secondary"},
	{recharge = 12, damage = 50, never_deployed = true, never_altfire = true, never_multi_class = true}, core.special_stats.shield)

core.weapon.register("melee",
	{soldier = "melee", pyro = "melee", demo = "melee", engineer = "melee", heavy = "melee", medic = "melee", sniper = "melee"},
	{damage = 65, interval = 0.8},
	function(weapon)
		if weapon.classes.demo then
			weapon.flags.never_altfire = true
		end
	end
)

core.weapon.register("sword",
	{soldier = "melee", demo = "melee"},
	{damage = 65, interval = 0.8, long_range_and_slow_deploy = true},
	function(weapon)
		weapon.stats[1] = "This weapon has a large melee range and deploys and holsters slower"

		if weapon.classes.demo then
			weapon.flags.never_altfire = true
			weapon.flags.has_crit_bonus = true
		end
	end
)
