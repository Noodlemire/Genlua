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

core.stats = {}

local registered = {}
local categories = {}
local metaCategories = {}

local function weaponHasCategory(weapon, category, matchValue)
	local instances = 0

	for i = 1, #weapon.stats do
		local stat = weapon.stats[i]

		if type(stat) == "table" and stat.category == category and (not matchValue or (matchValue >= 0) == (stat.weight >= 0)) then
			instances = instances + 1
		end
	end

	return instances
end

local function weaponHasMatchingValueCategories(weapon, matchValue, ...)
	local args = {...}
	local instances = 0

	for i = 1, #args do
		instances = instances + weaponHasCategory(weapon, args[i], matchValue)
	end

	return instances
end

local function weaponHasDuplicate(weapon, statA)
	for i = 1, #weapon.stats do
		local statB = weapon.stats[i]

		if type(statB) == "table" and statB.id == statA.id then
			return true
		end
	end
end

local function statCanBePositive(points)
	if not points or (type(points) == "number" and points >= 0) or (type(points) == "table" and points.min and points.min >= 0) then
		return true
	end

	if type(points) == "table" then
		for i = 1, #points do
			if points[i] >= 0 then
				return true
			end
		end
	end
end

local function statCanBeNegative(points)
	if not points or (type(points) == "number" and points <= 0) or (type(points) == "table" and points.max and points.max <= 0) then
		return true
	end

	if type(points) == "table" then
		for i = 1, #points do
			if points[i] <= 0 then
				return true
			end
		end
	end
end

local function statlistFindMatchingValue(def, points, skip_tol)
	if type(def.points) ~= "table" or #def.points == 0 then
		return false
	end

	if not points then
		return def.points[math.random(#def.points)]
	end

	if skip_tol then
		local closest = def.points[1]

		for i = 2, #def.points do
			if core.utils.distance(def.points[i], points) == core.utils.distance(closest, points) then
				closest = math.random(2) == 1 and def.points[i] or closest
			elseif core.utils.distance(def.points[i], points) < core.utils.distance(closest, points) then
				closest = def.points[i]
			end
		end

		return closest
	else
		for i = 1, #def.points do
			if core.utils.distance(def.points[i], points) <= math.max(10, points * .2) then
				return def.points[i]
			end
		end
	end
end

local function statIsUsable(weapon, def, points, skip_rng)
	if not def.requirement(weapon) then
		return false
	end

	if weaponHasDuplicate(weapon, def) then
		return false
	end

	if not skip_rng then
		if math.random() > core.utils.pow(0.85, weaponHasCategory(weapon, def.category)) then
			return false
		end

		local tol = math.max(10, (points or 0) * .2)

		if points then
			if type(def.points) == "number" and core.utils.distance(def.points, points) > tol then
				return false
			end

			if type(def.points) == "table" and #def.points > 0 and not statlistFindMatchingValue(def, points) then
				return false
			end

			if type(def.points) == "table" and #def.points == 0 and
						(not def.points.min or not def.points.max or def.points.min - tol > points or points > def.points.max + tol) then

				return false
			end
		end
	end

	if points and (statCanBePositive(points) ~= statCanBePositive(def.points)) and (statCanBeNegative(points) ~= statCanBeNegative(def.points)) then
		return false
	end

	return true
end

function core.stats.registerCategory(category, chance, onCreate)
	assert(type(category) == "string", "Category Error: Category must be provided as a string.")
	assert(not categories[category], "Category Error: Attempt to register pre-existing category: "..category)
	assert(type(chance) == "number", "Category Error: Chance must be provided as a number.")
	assert(not onCreate or type(onCreate) == "function", "Category Error: If provided, onCreate must be a function.")

	categories[category] = {chance = chance, onCreate = onCreate}
end

function core.stats.registerStat(category, points, description, requirement, onCreate)
	assert(type(category) == "string", "Stat Error: Category must be provided as a string.")
	assert(categories[category], "Stat Error: Attempt to register a stat for non-existent category: "..category)
	assert(type(points) == "number" or type(points) == "table", "Stat Error: Points must be provided as a number or table as {min = <number>, max = <number>}.")
	assert(type(description) == "string" or type(description) == "function", "Stat Error: Description must be provided as a number or string-returning function.")
	assert(type(requirement) == "function", "Stat Error: Requirement must be provided as a boolean-returning function.")
	assert(not onCreate or type(onCreate) == "function", "Stat Error: If provided, onCreate must be a function.")

	local stat = {category = category, requirement = requirement}

	if categories[category].onCreate or onCreate then
		stat.onCreate = function(stat, weapon)
			if categories[category].onCreate then
				categories[category].onCreate(stat, weapon)
			end

			if onCreate then
				onCreate(stat, weapon)
			end
		end
	end

	if type(points) == "number" or not (points.min and points.max) then
		stat.points = points
	else
		if points.min <= points.max then
			stat.points = {min = points.min, max = points.max}
		else
			stat.points = {min = points.max, max = points.min}
		end
	end

	if type(description) == "string" then
		stat.description = function()
			return description
		end
	else
		stat.description = description
	end

	if not registered[category] then
		registered[category] = {}
	end

	table.insert(registered[category], stat)

	stat.id = category..#registered[category]
end

function core.stats.registerMetaCategory(...)
	local args = {...}
	assert(#args >= 2, "Stat Error: \"core.stats.registerMetaCategory()\" requires at least two categories as strings.")

	local cats = {}

	for i = 1, #args do
		local cat = args[i]
		assert(type(cat) == "string", "Stat Error: \"core.stats.registerMetaCategory()\" requires all given arguments to be strings.")
		assert(categories[cat], "Stat Error: \"core.stats.registerMetaCategory()\" was given a non-existent category name: "..cat)

		cats[cat] = true
	end

	table.insert(metaCategories, cats)
end

function core.stats.create(weapon, points, try_again)
	assert(type(weapon) == "table", "Stats Error: First argument \"weapon\" in function create() must be provided as a table.")

	if points then
		points = core.utils.round(points, 5)
	end

	print("Creating stat with point request: "..(points or "nil"))

	local stats_to_try = core.utils.clone(registered)
	local cats_to_try = core.utils.clone(categories)
	local stat_valid = false
	local cat, i, def = nil, nil, nil

	if weapon.flags.required_category then
		stats_to_try = {[weapon.flags.required_category] = core.utils.clone(registered[weapon.flags.required_category])}
		cats_to_try = {[weapon.flags.required_category] = core.utils.clone(categories[weapon.flags.required_category])}
		cats_to_try[weapon.flags.required_category].chance = 1
		points = nil
	end

	repeat
		repeat
			if not next(stats_to_try) then
				cat = nil
				break
			end

			cat = core.utils.randomChances(cats_to_try, "chance")

			if cat and #stats_to_try[cat] == 0 then
				stats_to_try[cat] = nil
				cats_to_try[cat] = nil
			end
		until(not cat or (stats_to_try[cat] and #stats_to_try[cat] > 0))

		if not cat then
			break
		end

		repeat
			if #stats_to_try[cat] == 0 then
				stats_to_try[cat] = nil
				cats_to_try[cat] = nil
				break
			end

			i = math.random(#stats_to_try[cat])
			def = table.remove(stats_to_try[cat], i)

			stat_valid = statIsUsable(weapon, def, points, try_again)
		until(stat_valid)
	until(stat_valid)

	if def and (stat_valid or statIsUsable(weapon, def, points, true)) then
		if type(def.points) == "number" then
			points = def.points
		else
			local mat = statlistFindMatchingValue(def, points, true)
			if mat then
				points = mat
			else
				assert(def.points.min and def.points.max, "Goal: "..(points or "nil").."\ndef: "..core.utils.dump(def.points))

				if points then
					points = core.utils.gateOut(-5, core.utils.gate(def.points.min, points, def.points.max), 5)
				else
					points = core.utils.gateOut(-5, math.random(def.points.min, def.points.max), 5)
				end
			end
		end

		print("Next stat weight: "..(points or "nil"))

		if def.category == weapon.flags.required_category then
			weapon.flags.required_category = nil
		end
	else
		if try_again then
			print("Stat Warning: Unable to generate a stat for requested point value "..(points or "nil").." for weapon type \""..weapon.name.."\"")
			table.insert(weapon.stats, "-Warning: Ran out of valid stats to generate. Weapon may be outside of requested tolerance.")

			return
		else
			return core.stats.create(weapon, points, true)
		end
	end

	local stat = {val = points, weight = points, category = def.category, id = def.id}

	if def.onCreate then
		def.onCreate(stat, weapon)
	end

	local metaMatches = {[def.category] = true}
	for i = 1, #metaCategories do
		if metaCategories[i][def.category] then
			for cat in pairs(metaCategories[i]) do
				metaMatches[cat] = true
			end
		end
	end
	local weightMult = core.utils.pow(1.4, weaponHasMatchingValueCategories(weapon, stat.weight, table.unpack(core.utils.getKeys(metaMatches))))
	stat.weight = stat.weight * weightMult

	stat.weight = core.utils.round(stat.weight)

	stat.description = def.description(stat, weapon)

	return stat
end



core.stats.registerCategory("building", 100, function(stat, weapon)
	core.notes.put("engineerBuildings")
end)

core.stats.registerCategory("charge_build", 50, function(stat, weapon)
	stat.weight = stat.weight / 3
	weapon.flags.charge_build = true
	weapon.flags.required_category = "charge_result"
end)

core.stats.registerCategory("airblast", 80)
core.stats.registerCategory("ammo", 70)
core.stats.registerCategory("bullets_per_shot", 75)
core.stats.registerCategory("charge_rate", 50)
core.stats.registerCategory("charge_result", 0)
core.stats.registerCategory("cloak", 100)
core.stats.registerCategory("critical", 30)
core.stats.registerCategory("critical_capability", 15)
core.stats.registerCategory("damage", 125)
core.stats.registerCategory("destruction", 40)
core.stats.registerCategory("drain", 15)
core.stats.registerCategory("firing_speed", 100)
core.stats.registerCategory("fuse_time", 100)
core.stats.registerCategory("jump", 70)
core.stats.registerCategory("knockback", 60)
core.stats.registerCategory("max_health", 50)
core.stats.registerCategory("minigun", 100)
core.stats.registerCategory("movement", 125)
core.stats.registerCategory("recharge", 75)
core.stats.registerCategory("reload", 125)
core.stats.registerCategory("resistance", 75)
core.stats.registerCategory("sapper", 100)
core.stats.registerCategory("self_heal", 50)
core.stats.registerCategory("shield", 75)
core.stats.registerCategory("shot_behavior", 100)
core.stats.registerCategory("splash_effect", 75)
core.stats.registerCategory("status_cure", 15)
core.stats.registerCategory("status_effect", 100)
core.stats.registerCategory("stealth", 50)
core.stats.registerCategory("stickybomb", 100)
core.stats.registerCategory("switch_speed", 80)
core.stats.registerCategory("uber", 75)



core.stats.registerMetaCategory("damage", "firing_speed", "bullets_per_shot", "shot_behavior", "critical", "critical_capability")
core.stats.registerMetaCategory("damage", "firing_speed", "ammo", "reload", "stickybomb")
core.stats.registerMetaCategory("firing_speed", "knockback", "airblast")
core.stats.registerMetaCategory("self_heal", "resistance")
core.stats.registerMetaCategory("jump", "knockback", "movement")
core.stats.registerMetaCategory("sapper", "destruction")
core.stats.registerMetaCategory("status_effect", "splash_effect")



core.stats.registerStat("airblast", {min = -150, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+Airblast cost decreased by "..stat.val.."%"
		else
			return "-Airblast cost increased by "..(-stat.val).."%"
		end
	end,
	function(weapon)
		return weapon.flags.airblast
	end,
	function(stat, weapon)
		if stat.val < 0 then
			stat.weight = stat.weight / 3
		end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("ammo", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% clip size"
	end,
	function(weapon)
		return weapon.flags.clip
	end,
	function(stat, weapon)
		if not weapon.flags.clip then return end
		local change = stat.val
		if change > 0 then change = change * 2 end

		local clip = math.max(core.utils.round((change + 100) / 100 * weapon.flags.clip), 0)

		if weapon.flags.clip - clip == 0 then
			clip = clip + 1
		end

		stat.val = core.utils.round((clip / weapon.flags.clip - 1) * 100)
		stat.weight = stat.val

		if weapon.flags.reload_whole_clip then
			stat.weight = math.ceil(stat.weight * 1.5)
		end
	end
)

core.stats.registerStat("ammo", 50, "+On kill: Clip size increased by +25%, up to a maximum of +100%", function(weapon)
	return weapon.flags.damage and weapon.flags.clip
end)

core.stats.registerStat("ammo", {-36, 36},
	function(stat, weapon)
		if stat.val > 0 then
			return "+On kill: Enemies drop a large ammo kit instead of a medium one"
		else
			return "-On kill: Enemies drop a small ammo kit instead of a medium one"
		end
	end,
	function(weapon)
		return weapon.flags.damage and weapon.flags.reserve
	end,
	function(stat, weapon)
		if weapon.flags.never_deployed then
			stat.weight = stat.weight / 4
		end

		if weapon.classes.medic or weapon.classes.sniper or weapon.classes.spy then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("ammo", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% max reserve ammo on all of wearer's weapons"
	end,
	function(weapon)
		return (weapon.flags.reserve or (not weapon.slots.primary and not weapon.slots.secondary)) and not weapon.classes.spy and not weapon.classes.medic
	end,
	function(stat, weapon)
		if stat.val < 0 then
			stat.val = stat.val / 2
		end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("ammo", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% max primary ammo on wearer"
	end,
	function(weapon)
		return (weapon.flags.reserve or not weapon.slots.primary) and not weapon.classes.spy
	end,
	function(stat, weapon)
		stat.val = stat.val * (stat.val > 0 and 2 or 1)

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.name == "shield" and not weapon.classes.heavy then
			stat.weight = stat.weight * 0.75
		end
	end
)

core.stats.registerStat("ammo", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% max secondary ammo on wearer"
	end,
	function(weapon)
		return (weapon.flags.reserve or not weapon.slots.secondary) and not weapon.classes.medic
	end,
	function(stat, weapon)
		stat.val = stat.val * (stat.val > 0 and 2 or 1)

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.name == "stickybomb_launcher" then
			stat.weight = stat.weight * 1.50
		end

		if weapon.classes.engineer then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("ammo", {-100, -75, 75, 100},
	function(stat, weapon)
		if stat.weight > 0 then
			return "+While holstered, "..stat.val.." reserve ammo per second for this weapon is regenerated"
		else
			return "-While holstered, "..(-stat.val).." reserve ammo per second for this weapon is depleted"
		end
	end,
	function(weapon)
		return weapon.flags.reserve and weapon.flags.reserve >= 20
	end,
	function(stat, weapon)
		stat.val = core.utils.round((math.abs(stat.val) - 50) / 500 * weapon.flags.reserve)

		if stat.val == 0 then
			stat.val = stat.val + 1
		end
	end
)

core.stats.registerStat("building", -50, "Replaces the Sentry with a fast-building Mini-Sentry that costs less but can't be upgraded", function(weapon)
	return weapon.classes.engineer == "melee" and core.utils.numKeys(weapon.classes) == 1 and weaponHasCategory(weapon, "building") == 0
end)

core.stats.registerStat("building", -50, "Replaces the Sentry with a 100 metal mobile Drone that creates a massive explosion once it reaches the enemy", function(weapon)
	return weapon.classes.engineer == "melee" and core.utils.numKeys(weapon.classes) == 1 and weaponHasCategory(weapon, "building") == 0
end)

core.stats.registerStat("building", 50, "Replaces the Level 3 Sentry's rockets with an Airblast module that automatically reflects players and projectiles that get too close",
	function(weapon)
		return weapon.classes.engineer == "melee" and core.utils.numKeys(weapon.classes) == 1 and weaponHasCategory(weapon, "building") == 0
	end,
	function(stat, weapon)
		weapon.flags.airblast = true
	end
)

core.stats.registerStat("building", -50, "Replaces the Dispenser with a fast-building Mini-Dispenser that provides more healing but less metal and ammo, and can't be upgraded. Costs 50 metal to build", function(weapon)
	return weapon.classes.engineer == "primary_PDA" and weaponHasCategory(weapon, "building") == 0
end)

core.stats.registerStat("building", -25, "Replaces the Dispenser with a Forcefield Generator to block enemies and attacks. The Forcefield is generated by a reserve of metal that only its owner can draw from", function(weapon)
	return weapon.classes.engineer == "primary_PDA" and weaponHasCategory(weapon, "building") == 0
end)

core.stats.registerStat("building", -50, "Replaces the Teleporters with two Mini-Teleporter Exits that can be thrown, for 20 metal each. Destroy one to be sent to its location", function(weapon)
	return weapon.classes.engineer == "secondary_PDA" and weaponHasCategory(weapon, "building") == 0
end)

core.stats.registerStat("building", -25, "Replaces the Teleporters a Speed Pad and Jump Pad to offer teammates more mobility", function(weapon)
	return weapon.classes.engineer == "secondary_PDA" and weaponHasCategory(weapon, "building") == 0
end)

core.stats.registerStat("bullets_per_shot", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% bullets per shot"
	end,
	function(weapon)
		return weapon.flags.bullets_per_shot
	end,
	function(stat, weapon)
		local bps = weapon.flags.bullets_per_shot
		local bullets = core.utils.round((stat.val + 100) / 100 * bps)

		if bps - bullets == 0 then
			bullets = bullets + 1
		end

		stat.val = core.utils.round((bullets / bps - 1) * 100)
	end
)

core.stats.registerStat("charge_build", 45, "On hit: Builds Charge",
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed and not weapon.flags.hold_to_charge and not weapon.flags.charge_build and not weapon.flags.recharge
	end,
	function(stat, weapon)
		stat.weight = stat.weight / 3
		weapon.flags.charge_build = true
	end
)

core.stats.registerStat("charge_build", 45, "Gain Charge by dealing damage with any weapon",
	function(weapon)
		return not weapon.flags.damage and not weapon.flags.hold_to_charge and not weapon.flags.charge_build and not weapon.flags.recharge and not weapon.name == "medigun"
	end,
	function(stat, weapon)
		stat.weight = stat.weight / 3
		weapon.flags.charge_build = true
	end
)

core.stats.registerStat("charge_rate", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+Max charge time decreased by "..stat.val.."%"
		else
			return "-Max charge time increased by "..(-stat.val).."%"
		end
	end,
	function(weapon)
		return weapon.flags.hold_to_charge
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val * 1.5, 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.name == "bow" then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("charge_rate", -25, "-Charge reduced on air jumps", function(weapon)
	return weapon.flags.charge_build and (weapon.classes.scout or weapon.flags.bonus_jumps) and not weapon.flags.hold_to_charge and not weapon.flags.no_bonus_jumps
end)

core.stats.registerStat("charge_rate", -25, "-Charge reduced when hit", function(weapon)
	return weapon.flags.charge_build
end)

core.stats.registerStat("charge_result", 50, "When Charge is full, activate to gain multiple air jumps",
	function(weapon)
		return not weapon.flags.no_bonus_jumps and not (weapon.flags.altfire or weapon.flags.never_altfire)
	end,
	function(stat, weapon)
		weapon.flags.bonus_jumps = true
	end
)

core.stats.registerStat("charge_result", 50, "+Run speed increased with Charge", function(weapon)
	return not weapon.flags.hold_to_charge
end)

core.stats.registerStat("charge_result", {60, 180},
	function(stat, weapon)
		if stat.val == 60 then
			return "+When Charge is full, activate to become Mini-Crit-Boosted for the charge's duration."
		else
			return "+When Charge is full, activate to become Crit-Boosted for the charge's duration."
		end
	end,
	function(weapon)
		return not (weapon.flags.altfire or weapon.flags.never_altfire)
	end,
	function(stat, weapon)
		core.special_stats.handleCrits(stat, weapon, stat.val, 60, 180)
	end
)

core.stats.registerStat("charge_result", 50, "Alt-Fire: Launch a projectile that slows your opponents",
	function(weapon)
		return not weapon.flags.projectile and not weapon.flags.never_deployed and not (weapon.flags.altfire or weapon.flags.never_altfire)
	end,
	function(stat, weapon)
		weapon.flags.projectile = true
		weapon.flags.gravity = true
	end
)

core.stats.registerStat("charge_result", 50, "Alt-Fire: Launch a projectile that makes your opponents bleed",
	function(weapon)
		return not weapon.flags.projectile and not weapon.flags.never_deployed and not (weapon.flags.altfire or weapon.flags.never_altfire)
	end,
	function(stat, weapon)
		weapon.flags.projectile = true
		weapon.flags.gravity = true
		weapon.flags.bleed = true
	end
)

core.stats.registerStat("charge_result", 50, "Alt-Fire: Launch a projectile that deals splash damage",
	function(weapon)
		return not weapon.flags.projectile and not weapon.flags.never_deployed and not (weapon.flags.altfire or weapon.flags.never_altfire)
	end,
	function(stat, weapon)
		weapon.flags.projectile = true
		weapon.flags.gravity = true
		weapon.flags.splash = true
	end
)

core.stats.registerStat("cloak", {min = -50, max = 50},
	function(stat, weapon)
		local upto = weapon.flags.falloff and "up to " or ""

		if stat.val > 0 then
			return "+On hit: Gain "..upto..stat.val.."% more cloak"
		else
			return "-On hit: Lose "..upto..(-stat.val).."% of your own cloak"
		end
	end,
	function(weapon)
		return weapon.flags.damage and weapon.classes.spy and core.utils.numKeys(weapon.classes) == 1
	end,
	function(stat, weapon)
		local int = (weapon.flags.interval or 1) / 2
		stat.val = core.utils.round(stat.val * int)

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("cloak", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% cloak meter from ammo boxes"
	end,
	function(weapon)
		return weapon.classes.spy and core.utils.numKeys(weapon.classes) == 1
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)
		stat.val = stat.val * 2
	end
)

core.stats.registerStat("cloak", {min = -50, max = 50},
	function(stat, weapon)
		local cond = " on wearer"

		if weapon.name == "invis_watch" then
			cond = ""
		end

		return (stat.val > 0 and "+" or "")..stat.val.."% cloak duration"..cond
	end,
	function(weapon)
		return weapon.classes.spy and core.utils.numKeys(weapon.classes) == 1
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)
	end
)

core.stats.registerStat("cloak", -50, "-No cloak from ammo boxes while this effect is active", function(weapon)
	return weapon.name == "invis_watch"
end)

core.stats.registerStat("cloak", {min = -100, max = -50},
	function(stat, weapon)
		return "-Upon activation, "..stat.val.."% cloak meter is instantly drained"
	end,
	function(weapon)
		return weapon.name == "invis_watch"
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)
		stat.val = stat.val + 25
	end
)
	

core.stats.registerStat("critical", {40, 100},
	function(stat, weapon)
		if stat.val == 40 then
			return "+Mini-Crits targets when fired at their back"
		else
			return "+Always Crits targets when fired at their back"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.splash and not weapon.flags.instakill_goal
	end,
	function(stat, weapon)
		core.special_stats.handleCrits(stat, weapon, stat.val, 40, 100)

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("critical", {20, 50},
	function(stat, weapon)
		if stat.val == 20 then
			return "+Mini-Crits burning targets"
		else
			return "+Always Crits burning targets"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.instakill_goal
	end,
	function(stat, weapon)
		core.special_stats.handleCrits(stat, weapon, stat.val, 20, 50)

		if weapon.flags.splash then
			stat.weight = stat.weight * 1.5
		end
		if weapon.classes.pyro then
			stat.weight = stat.weight * 2
		end
		if weapon.name == "flame_thrower" then
			stat.weight = stat.weight * 3
		end

		if weapon.slots.melee and not (weapon.classes.pyro or weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("critical", {75, 195}, 
	function(stat, weapon)
		if stat.val == 75 then
			return "+Deals Mini-Crits while user is airborne"
		else
			return "+Always Crits while user is airborne"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed and not weapon.flags.hold_to_charge
			and not weapon.flags.projectile and not weapon.flags.instakill_goal
	end,
	function(stat, weapon)
		core.special_stats.handleCrits(stat, weapon, stat.val, 75, 195)

		if weapon.classes.scout or weapon.classes.demo or weapon.classes.soldier then
			stat.weight = stat.weight * 1.5
		end

		if weapon.slots.melee then
			stat.weight = stat.weight / 3
		end
	end
)

core.stats.registerStat("critical", {50, 120},
	function(stat, weapon)
		if stat.val == 50 then
			return "+Mini-Crits while the wielder is blast jumping"
		else
			return "+Always Crits while the wielder is blast jumping"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed and (weapon.classes.soldier or weapon.classes.demo)
	end,
	function(stat, weapon)
		core.special_stats.handleCrits(stat, weapon, stat.val, 75, 195)

		if weapon.slots.melee then
			stat.weight = stat.weight / 3
		end
	end
)

core.stats.registerStat("critical", {15, 40},
	function(stat, weapon)
		if stat.val == 15 then
			return "+Mini-Crits wet players"
		else
			return "+Always Crits wet players"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.instakill_goal
	end,
	function(stat, weapon)
		core.special_stats.handleCrits(stat, weapon, stat.val, 15, 40)

		if weapon.slots.melee and not (weapon.classes.scout or weapon.classes.demo or weapon.classes.sniper) then
			stat.weight = stat.weight * 0.667
		end

		if weapon.flags.jarate or weapon.flags.milk or weapon.classes.scout == "primary" or weapon.classes.sniper == "primary" then
			stat.weight = stat.weight * 2
		end
	end
)

core.stats.registerStat("critical", {20, 50},
	function(stat, weapon)
		if stat.val == 20 then
			return "+Mini-Crits targets launched airborn by explosions, grapple hooks, or rocket packs"
		else
			return "+Always Crits targets launched airborn by explosions, grapple hooks, or rocket packs"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.slots.melee and not weapon.flags.never_deployed and not weapon.flags.instakill_goal
	end,
	function(stat, weapon)
		core.special_stats.handleCrits(stat, weapon, stat.val, 20, 50)

		if weapon.classes.soldier or weapon.classes.demo then
			stat.weight = stat.weight * 1.5
		end
	end
)

core.stats.registerStat("critical", {60, 180},
	function(stat, weapon)
		if stat.val <= 5 then
			return "+On kill: Become Mini-Crit-Boosted for 5 seconds"
		else
			return "+On kill: Become Crit-Boosted for 5 seconds"
		end
	end,
	function(weapon)
		return weapon.flags.charge_build and not (weapon.flags.altfire or weapon.flags.never_altfire)
	end,
	function(stat, weapon)
		core.special_stats.handleCrits(stat, weapon, stat.val, 60, 180)

		if weapon.slots.melee and not (weapon.flags.demo or weapon.flags.engineer or weapon.flags.spy) then
			stat.weight = stat.weight / 3
		end
	end
)

core.stats.registerStat("critical_capability", {-60, -40, 40},
	function(stat, weapon)
		if stat.val == 40 then
			return "+Crits whenever it would normally Mini-Crit"
		elseif stat.val == -40 then
			return "-Mini-Crits whenever it would normally Crit"
		else
			return "-This weapon cannot deal Critical Hits by any means"
		end
	end,
	function(weapon)
		return weapon.flags.damage and weapon.name ~= "knife" and not weapon.flags.has_crit_bonus and not weapon.flags.has_minicrit_bonus
	end,
	function(stat, weapon)
		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer or weapon.classes.sniper) then
			stat.weight = stat.weight / 2
		end

		if stat.val > 0 then
			weapon.flags.no_minicrit_bonus = true
		else
			weapon.flags.no_crit_bonus = true
		end
	end
)

core.stats.registerStat("damage", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% damage bonus"
		else
			return stat.val.."% damage penalty"
		end
	end,
	function(weapon)
		return weapon.flags.damage and weapon.name ~= "knife" and weapon.flags.damage_change ~= "player_vs_building"
	end,
	function(stat, weapon)
		local damage = math.max(core.utils.round((stat.val + 100) / 100 * weapon.flags.damage), 0)

		if weapon.flags.damage - damage == 0 then
			damage = damage + 1
		end

		stat.val = core.utils.round((damage / weapon.flags.damage - 1) * 100)

		if weapon.name == "sniper_rifle" then
			if stat.val >= 17 then --Quickscope headshot deals over 175 damage
				stat.weight = stat.weight * 1.4
			end

			if stat.val >= 33 then --Quickscope headshot deals over 200 damage
				stat.weight = stat.weight * 1.4
			end
		end

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end

		weapon.flags.damage_change = "all"
	end
)

core.stats.registerStat("damage", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% damage bonus when below 50% health"
		else
			return stat.val.."% damage penalty when below 50% health"
		end
	end,
	function(weapon)
		return weapon.flags.damage and weapon.name ~= "knife"
	end,
	function(stat, weapon)
		local damage = math.max(core.utils.round((stat.val + 100) / 100 * weapon.flags.damage), 0)

		if weapon.flags.damage - damage == 0 then
			damage = damage + 1
		end

		stat.val = core.utils.round((damage / weapon.flags.damage - 1) * 100)

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end

		stat.weight = stat.weight * core.utils.pow(0.5, weaponHasCategory(weapon, "self_heal"))
	end
)

core.stats.registerStat("damage", 75, "+On hit: One target at a time is Marked For Death",
	function(weapon)
		return weapon.flags.damage and not weapon.flags.splash and not weapon.flags.bullets_per_shot and not weapon.instakill_goal
	end,
	function(stat, weapon)
		if weapon.flags.recharge or (weapon.slots.melee and not (weapon.classes.soldier or weapon.classes.demo)) then
			stat.weight = stat.weight / 3
		end

		weapon.flags.no_splash = true
	end
)

core.stats.registerStat("damage", -100, "-You cannot attack until the effect wears off.", function(weapon)
	return weapon.flags.recharge and not weapon.flags.projectile and weapon.name ~= "invis_watch"
end)

core.stats.registerStat("damage", {min = 20, max = 60},
	function(stat, weapon)
		return "Deals "..stat.val.."x falling damage to the player you land on"
	end,
	function(weapon)
		return weapon.name == "boots"
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val / 20)

		if weapon.classes.soldier or weapon.classes.demo then
			stat.weight = stat.weight * 2
		end
	end
)

core.stats.registerStat("damage", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% afterburn damage bonus"
		else
			return stat.val.."% afterburn damage penalty"
		end
	end,
	function(weapon)
		return weapon.flags.afterburn
	end,
	function(stat, weapon)
		local damage = math.max(core.utils.round((stat.val + 100) / 100 * weapon.flags.afterburn), 0)

		if weapon.flags.afterburn - damage == 0 then
			damage = damage + 1
		end

		stat.val = core.utils.round((damage / weapon.flags.afterburn - 1) * 100)

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("damage", 50, "+Damage increases up to +100% based on remaining duration of afterburn on the target",
	function(weapon)
		return weapon.flags.damage and (weapon.flags.afterburn or weapon.classes.pyro) and weapon.name ~= "flame_thrower"
	end,
	function(stat, weapon)
		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("damage", {min = 10, max = 50},
	function(stat, weapon)
		return "+Damage increases up to +"..stat.val.."% based on remaining duration of bleed on the target"
	end,
	function(weapon)
		return weapon.flags.damage and (weapon.flags.bleed or weapon.classes.scout or
			(not weapon.slots.melee and (weapon.classes.engineer or weapon.classes.sniper)))
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val * 2, 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if not weapon.flags.bleed and not weapon.classes.scout then
			stat.weight = stat.weight / 2
		end

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("damage", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% damage vs players"
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed and weapon.name ~= "knife" and weapon.flags.damage_change ~= "all"
	end,
	function(stat, weapon)
		local damage = math.max(core.utils.round((stat.val + 100) / 100 * weapon.flags.damage), 0)

		if weapon.flags.damage - damage == 0 then
			damage = damage + 1
		end

		stat.val = core.utils.round((damage / weapon.flags.damage - 1) * 100)

		if weapon.name == "sniper_rifle" then
			if stat.val >= 17 then --Quickscope headshot deals over 175 damage
				stat.weight = stat.weight * 1.4
			end

			if stat.val >= 33 then --Quickscope headshot deals over 200 damage
				stat.weight = stat.weight * 1.4
			end
		end

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end

		weapon.flags.damage_change = "player_vs_building"
	end
)

core.stats.registerStat("damage", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% greater damage bonus from charging"
		else
			return stat.val.."% smaller damage bonus from charging"
		end
	end,
	function(weapon)
		return weapon.flags.damage and weapon.flags.hold_to_charge
	end,
	function(stat, weapon)
		local damage = math.max(core.utils.round((stat.val + 100) / 100 * weapon.flags.damage), 0)

		if weapon.flags.damage - damage == 0 then
			damage = damage + 1
		end

		stat.val = core.utils.round((damage / weapon.flags.damage - 1) * 100)
	end
)

core.stats.registerStat("destruction", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% damage vs buildings"
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed and weapon.name ~= "knife" and weapon.name ~= "indivisible_particle_smasher"
			and weapon.flags.damage_change ~= "all"
	end,
	function(stat, weapon)
		local damage = math.max(core.utils.round((stat.val * 2 + 100) / 100 * weapon.flags.damage), 0)

		if weapon.flags.damage - damage == 0 then
			damage = damage + 1
		end

		stat.val = core.utils.round((damage / weapon.flags.damage - 1) * 100)

		if weapon.slots.melee or weapon.name == "sniper_rifle" then
			stat.weight = stat.weight / 2
		end

		weapon.flags.damage_change = "player_vs_building"
	end
)

core.stats.registerStat("destruction", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% sapper damage bonus"
		else
			return stat.val.."% sapper damage penalty"
		end
	end,
	function(weapon)
		return weapon.name == "sapper"
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val * 2, 4)
		stat.weight = core.utils.round(stat.weight, 4)
	end
)

core.stats.registerStat("destruction", {min = -50, max = -10},
	function(stat, weapon)
		return "-Only "..stat.val.." sapper"..(stat.val == 1 and "" or "s").." can be placed at once"
	end,
	function(weapon)
		return weapon.name == "sapper"
	end,
	function(stat, weapon)
		stat.val = 6 + core.utils.round(stat.val / 10)
		stat.weight = core.utils.round(stat.weight, 10)
	end
)

core.stats.registerStat("destruction", 25, "+Able to damage sappers", function(weapon)
	return weapon.flags.damage and not weapon.flags.never_deployed and not weapon.flags.recharge and weapon.classes.engineer ~= "melee"
		and weapon.name ~= "knife" and weapon.name ~= "indivisible_particle_smasher"
end)

core.stats.registerStat("destruction", -50, "-Damage cannot remove sappers", function(weapon)
	return weapon.classes.engineer == "melee" and core.utils.numKeys(weapon.classes) == 1
end)

core.stats.registerStat("destruction", 35, "+Able to destroy enemy stickybombs", function(weapon)
	return weapon.flags.damage and weapon.flags.cant_destroy_stickybombs
end)

core.stats.registerStat("drain", {min = -25, max = 25},
	function(stat, weapon)
		local upto = weapon.flags.falloff and "up to " or ""

		if stat.val > 0 then
			return "+On hit: Victim loses "..upto..stat.val.."% of their cloak"
		else
			return "-On hit: Victim gains "..upto..(-stat.val).."% of their cloak"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.instakill_goal
	end,
	function(stat, weapon)
		local int = (weapon.flags.interval or 1) / 2
		stat.val = core.utils.round(stat.val * int)

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("drain", {min = -25, max = 25},
	function(stat, weapon)
		local upto = weapon.flags.falloff and "up to " or ""

		if stat.val > 0 then
			return "+On hit: Victim loses "..upto..stat.val.."% Medigun Charge"
		else
			return "-On hit: Victim gains "..upto..(-stat.val).."% Medigun Charge"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.instakill_goal
	end,
	function(stat, weapon)
		local int = (weapon.flags.interval or 1) / 2
		stat.val = core.utils.round(stat.val * int)

		if weapon.classes.medic or weapon.classes.engineer or (weapon.slots.melee and not weapon.classes.demo) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("firing_speed", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% firing speed"
	end,
	function(weapon)
		return weapon.flags.interval and weapon.name ~= "flame_thrower"
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)
		weapon.flags.interval = weapon.flags.interval * (100 + stat.val) / 100

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer or weapon.classes.spy) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("firing_speed", {min = -50, max = 100},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% firing speed while blast jumping"
	end,
	function(weapon)
		return (weapon.classes.soldier or weapon.classes.demo) and weapon.flags.interval
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val, 5)
		stat.weight = stat.val / 2

		if stat.val < 0 and (weapon.name == "shotgun" or weapon.slots.melee) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("fuse_time", {min = -25, max = 25},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% fuse time on grenades"
	end,
	function(weapon)
		return weapon.name == "grenade_launcher"
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)
	end
)

core.stats.registerStat("jump", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% greater jump height "..core.special_stats.whileInUse(weapon)
		else
			return stat.val.."% reduced jump height "..core.special_stats.whileInUse(weapon)
		end
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		if stat.val < 0 then
			stat.val = stat.val / 2
		end

		if weapon.classes.scout then
			stat.weight = stat.weight * 1.5
		end

		if stat.val < 0 and (weapon.slots.primary_PDA or weapon.slots.secondary_PDA or weapon.slots.building) then
			stat.weight = stat.weight / 2
		end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("jump", {-120, 40},
	function(stat, weapon)
		if stat.val > 0 then
			return "+Grants an additional mid-air jump "..core.special_stats.whileInUse(weapon)
		else
			return "-User cannot jump mid-air while this is active"
		end
	end,
	function(weapon)
		return weapon.classes.scout and not weapon.flags.bonus_jumps and not weapon.flags.never_deployed
	end,
	function(stat, weapon)
		if stat.val > 0 then
			weapon.flags.bonus_jumps = true
		else
			weapon.flags.no_bonus_jumps = true
		end

		if weapon.flags.recharge then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("jump", {min = -20, max = 60},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% increased air control when blast jumping"
		else
			return stat.val.."% decreased air control when blast jumping"
		end
	end,
	function(weapon)
		return (weapon.classes.soldier or weapon.classes.demo) and weapon.flags.never_deployed
	end,
	function(stat, weapon)
		stat.val = stat.val * 5

		if weapon.name == "shield" then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("knockback", 25, "Knockback on the target and user", function(weapon)
	return weapon.flags.damage and not weapon.flags.never_deployed and weapon.name ~= "flame_thrower"
end)

core.stats.registerStat("knockback", {min = -40, max = 40},
	function(stat, weapon)
		local source = "damage"

		if weapon.flags.airblast then
			source = "airblast"
		end

		if stat.val > 0 then
			return "+"..stat.val.."% increased push force to other players from "..source
		else
			return stat.val.."% decreased push force to other players from "..source
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.instakill_goal and (weapon.flags.airblast or weapon.flags.splash)
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val * (stat.val > 0 and 5 or 2), 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.flags.airblast then
			stat.weight = stat.weight * 1.5
		elseif stat.val > 0 then
			if not weapon.flags.splash and not weapon.slots.melee then
				if weapon.flags.interval then
					stat.weight = stat.weight * (0.5 / weapon.flags.interval)
				else
					stat.weight = stat.weight / 2
				end
			elseif weapon.slots.melee and (weapon.classes.scout or weapon.classes.pyro) then
				stat.weight = stat.weight / 2
			end
		end
	end
)

core.stats.registerStat("knockback", {min = -20, max = 20},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% resistance to push force taken from damage "..core.special_stats.whileInUse(weapon)
		else
			return stat.val.."% vulnerability to push force taken from damage "..core.special_stats.whileInUse(weapon)
		end
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		if stat.val < 0 then
			stat.val = core.utils.round(stat.val / 2)
		end

		stat.val = stat.val * 5
	end
)

core.stats.registerStat("knockback", {min = -20, max = 20},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% resistance to push force taken from airblast "..core.special_stats.whileInUse(weapon)
		else
			return stat.val.."% vulnerability to push force taken from airblast "..core.special_stats.whileInUse(weapon)
		end
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		if stat.val < 0 then
			stat.val = core.utils.round(stat.val / 2)
		end

		stat.val = stat.val * 5

		if weapon.name == "sword" or weapon.name == "shield" then
			stat.weight = stat.weight * 2
		end
	end
)

core.stats.registerStat("knockback", {min = -25, max = 25},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% increased push force from self damage"
		else
			return stat.val.."% reduced push force from self damage"
		end
	end,
	function(weapon)
		return weapon.flags.damage and weapon.flags.splash
	end,
	function(stat, weapon)
		stat.val = stat.val * 3

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("max_health", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.." max health on wearer"
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		if not weapon.classes.heavy or core.utils.numKeys(weapon.classes) > 1 then
			stat.val = stat.val / 2
		end

		if weapon.classes.medic then
			stat.weight = stat.weight * 1.25
		end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("max_health", {min = -80, max = 80},
	function(stat, weapon)
		if stat.weight > 0 then
			return "+Maximum health grows up to "..stat.val.."% while deployed"
		else
			return "-Maximum health drains down to "..stat.val.."% while deployed"
		end
	end,
	function(weapon)
		return not weapon.flags.never_deployed and not weapon.flags.recharge
	end,
	function(stat, weapon)
		if stat.val > 0 then
			stat.val = math.max(core.utils.round(stat.val / 2, 10), 10)
			stat.weight = stat.val * 2
		else
			stat.val = 100 - math.max(core.utils.round(-stat.val, 20), 20)
			stat.weight = stat.val - 100

			if weapon.name == "medigun" then
				stat.weight = stat.weigh * 4
			elseif weapon.slots.primary or weapon.name == "stickybomb_launcher" or (weapon.slots.melee and (weapon.classes.demo or weapon.classes.engineer or weapon.classes.spy)) then
				stat.weight = stat.weight * 2.25
			end
		end

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer or weapon.classes.spy) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("minigun", {min = -50, max = 50},
	function(stat, weapon)
		local cond = "wearer's minigun is spun up and they're"

		if weapon.name == "minigun" then
			cond = "spun up and wearer is"
		end

		if stat.val > 0 then
			return "+"..stat.val.."% damage resistance when "..cond.." below 50% health"
		else
			return stat.val.."% damage vulnerability when "..cond.." below 50% health"
		end
	end,
	function(weapon)
		return weapon.name == "minigun" or (weapon.classes.heavy and weapon.flags.never_deployed and core.utils.numKeys(weapon.classes) == 1)
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)
	end
)

core.stats.registerStat("minigun", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% faster spin up time"
		else
			return stat.val.."% slower spin up time"
		end
	end,
	function(weapon)
		return weapon.name == "minigun"
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)
	end
)

core.stats.registerStat("minigun", {min = -50, max = 50},
	function(stat, weapon)
		local cond = "wearer's minigun is "

		if weapon.name == "minigun" then
			cond = ""
		end

		if stat.val > 0 then
			return "+"..stat.val.."% reduced movement speed penalty when "..cond.."spun up"
		else
			return stat.val.."% worse movement speed penalty when "..cond.."spun up"
		end
	end,
	function(weapon)
		return weapon.name == "minigun" or (weapon.classes.heavy and weapon.flags.never_deployed and core.utils.numKeys(weapon.classes) == 1)
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)
	end
)

core.stats.registerStat("minigun", {min = -80, max = 80},
	function(stat, weapon)
		if stat.val > 0 then
			return "+Regenerates an additional "..stat.val.." ammo per second while spun up"
		else
			return "-Consumes an additional "..(-stat.val).." ammo per second while spun up"
		end
	end,
	function(weapon)
		return weapon.name == "minigun"
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val / 20)
		if stat.val == 0 then
			stat.val = 1
		end

		stat.weight = stat.val * 20
	end
)

core.stats.registerStat("movement", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% faster movement speed "..core.special_stats.whileInUse(weapon)
		else
			return stat.val.."% slower movement speed "..core.special_stats.whileInUse(weapon)
		end
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		if not weapon.classes.heavy then
			stat.val = stat.val / 2
		end
		if stat.val < 0 and (weapon.slots.primary_PDA or weapon.slots.secondary_PDA or weapon.slots.building) and not weapon.flags.never_deployed then
			stat.weight = stat.weight / 2
		end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("movement", 50, "+On hit teammate: Boost both players' speed for several seconds",
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed and weapon.name ~= "minigun"
	end,
	function(stat, weapon)
		core.notes.put("bothPlayers")
	end
)

core.stats.registerStat("movement", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+On hit: Gain a speed boost for "..stat.val.." second"..(stat.val == 1 and "" or "s")
		else
			return "-On hit: Wearer is slowed for "..(-stat.val).." second"..(stat.val == -1 and "" or "s")
		end
	end,
	function(weapon)
		return weapon.flags.damage
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val / 10)

		if stat.val == 0 then
			stat.val = 1
		end

		stat.weight = stat.val * 10

		if weapon.name == "sniper_rifle" or weapon.classes.pyro == "melee" or weapon.name == "minigun" then
			stat.weight = stat.weight / 2
		end

		if weapon.name == "flame_thrower" then
			stat.weight = stat.weight * 2
		end
	end
)

core.stats.registerStat("movement", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+On kill: Gain a speed boost for "..stat.val.." second"..(stat.val == 1 and "" or "s")
		else
			return "-On kill: Wearer is slowed for "..(-stat.val).." second"..(stat.val == -1 and "" or "s")
		end
	end,
	function(weapon)
		return weapon.flags.damage
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val / 5)

		if stat.val == 0 then
			stat.val = 1
		end

		stat.weight = stat.val * 5

		if weapon.name == "sniper_rifle" or (weapon.slots.melee and not (weapon.classes.demo or weapon.classes.spy)) or weapon.flags.never_deployed then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("movement", {-50, 50}, 
	function(stat, weapon)
		if stat.val > 0 then
			return "+While deployed, move speed increases up to +60% as user becomes injured"
		else
			return "-While deployed, move speed decreases down to -30% as user becomes injured"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed
	end
)

core.stats.registerStat("movement", 30, "+Killing blows on burning players grant a speed boost",
	function(weapon)
		return weapon.flags.damage and (weapon.classes.pyro or weapon.flags.afterburn)
	end,
	function(stat, weapon)
		if weapon.name == "flame_thrower" then
			stat.weight = stat.weight * 1.667
		end

		if weapon.slots.melee then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("movement", 30, "+Killing blows on bleeding players grant a speed boost",
	function(weapon)
		return weapon.flags.damage and (weapon.flags.bleed or weapon.classes.scout or
			(not weapon.slots.melee and (weapon.classes.engineer or weapon.classes.sniper)))
	end,
	function(stat, weapon)
		if weapon.slots.melee then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("movement", {min = 10, max = 40},
	function(stat, weapon)
		return "+"..stat.val.."% increase in turning control while charging"
	end,
	function(weapon)
		return weapon.name == "shield" or (weapon.classes.demo and weapon.classes.demo ~= "secondary")
			or (weapon.classes.heavy and weapon.classes.heavy ~= "secondary")
	end,
	function(stat, weapon)
		stat.weight = core.utils.round(stat.weight, 10)
		stat.val = stat.weight * 5

		if weapon.name ~= "shield" and weapon.classes.heavy then
			core.notes.put("heavyCharge")
		end
	end
)

core.stats.registerStat("movement", {-30, 80},
	function(stat, weapon)
		if stat.val > 0 then
			return "+On hit: Slows the target briefly"
		else
			return "-On hit: Gives the enemy a brief speed boost"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed and not weapon.flags.instakill_goal and weapon.name ~= "flame_thrower"
	end
)

core.stats.registerStat("recharge", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% increase in recharge rate"
		else
			return stat.val.."% decrease in recharge rate"
		end
	end,
	function(weapon)
		return weapon.flags.recharge
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)
	end
)

core.stats.registerStat("recharge", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+On hit with any weapon: +"..stat.val.."% more charge"
		else
			return "-On hit with any weapon: "..stat.val.."% charge is drained"
		end
	end,
	function(weapon)
		return weapon.flags.recharge and not weapon.classes.pyro and not weapon.classes.heavy
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val / 10)
		stat.weight = core.utils.round(stat.weight, 10)
	end
)

core.stats.registerStat("reload", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% reload speed"
	end,
	function(weapon)
		return weapon.flags.reserve and not weapon.flags.no_reload
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)

		if weapon.flags.reload_whole_clip then
			stat.weight = stat.weight / 2
		elseif weapon.flags.clip then
			stat.weight = stat.weight * weapon.flags.clip / 6
		end
	end
)

core.stats.registerStat("reload", {min = 20, max = 100}, "This weapon reloads its entire clip at once",
	function(weapon)
		return weapon.flags.clip and not weapon.flags.reload_whole_clip
	end,
	function(stat, weapon)
		stat.val = 100 * weapon.flags.clip / 6
		stat.weight = stat.val

		weapon.flags.reload_whole_clip = true
	end
)

core.stats.registerStat("reload", 30, "This weapon will reload automatically while holstered", function(weapon)
	return weapon.flags.clip
end)

core.stats.registerStat("reload", {-50, 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "-").."On hit: 1 ammo is instantly "..(stat.val > 0 and "reloaded into" or "unloaded from").." the clip"
	end,
	function(weapon)
		return weapon.flags.clip and weapon.name ~= "stickybomb_launcher"
	end
)

core.stats.registerStat("reload", {-50, 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "-").."On miss: 1 ammo is instantly "..(stat.val > 0 and "reloaded into" or "unloaded from").." the clip"
	end,
	function(weapon)
		return weapon.flags.clip and weapon.name ~= "stickybomb_launcher"
	end
)

core.stats.registerStat("reload", {min = -50, max = 100},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% reload speed while blast jumping"
	end,
	function(weapon)
		return (weapon.classes.soldier or weapon.classes.demo) and weapon.flags.reserve and not weapon.flags.no_reload
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val, 5)
		stat.weight = stat.val / 2

		if stat.val < 0 and (weapon.name == "shotgun" or weapon.slots.melee) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("resistance", {min = -30, max = 30},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% explosive resistance "..core.special_stats.whileInUse(weapon)
		else
			return stat.val.."% explosive vulnerability "..core.special_stats.whileInUse(weapon)
		end
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		stat.val = stat.val * 2 + (stat.val > 0 and 10 or -10)

		if stat.val < 0 and (weapon.slots.primary_PDA or weapon.slots.secondary_PDA or weapon.slots.building) and not weapon.flags.never_deployed then
			stat.weight = stat.weight / 2
		end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("resistance", {min = -30, max = 30},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% fire resistance "..core.special_stats.whileInUse(weapon)
		else
			return stat.val.."% fire vulnerability "..core.special_stats.whileInUse(weapon)
		end
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		stat.val = stat.val * 2 + (stat.val > 0 and 10 or -10)

		if stat.val < 0 and (weapon.slots.primary_PDA or weapon.slots.secondary_PDA or weapon.slots.building) and not weapon.flags.never_deployed then
			stat.weight = stat.weight / 2
		end

		if weapon.classes.spy then
			stat.weight = stat.weight * 1.5
		end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("resistance", {min = -15, max = 15},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% melee resistance "..core.special_stats.whileInUse(weapon)
		else
			return stat.val.."% melee vulnerability "..core.special_stats.whileInUse(weapon)
		end
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		stat.val = stat.val * 4 + (stat.val > 0 and 10 or -10)

		if stat.val < 0 and (weapon.slots.primary_PDA or weapon.slots.secondary_PDA or weapon.slots.building) and not weapon.flags.never_deployed then
			stat.weight = stat.weight * 2 / 3
		end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("resistance", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% bullet resistance "..core.special_stats.whileInUse(weapon)
		else
			return stat.val.."% bullet vulnerability "..core.special_stats.whileInUse(weapon)
		end
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)

		if weapon.classes.sniper == "primary" and stat.val >= 20 then --Quickscope headshot deals under 125 damage
			stat.weight = stat.weight * 2
		elseif weapon.classes.medic then
			stat.weight = stat.weight * 1.25
		end

		if stat.val < 0 and (weapon.slots.primary_PDA or weapon.slots.secondary_PDA or weapon.slots.building) and not weapon.flags.never_deployed then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("resistance", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% damage resistance "..core.special_stats.whileInUse(weapon)
		else
			return stat.val.."% damage vulnerability "..core.special_stats.whileInUse(weapon)
		end
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val / 2, 5)

		if weapon.classes.sniper == "primary" and stat.val >= 20 then --Quickscope headshot deals under 125 damage
			stat.weight = stat.weight * 2
		elseif weapon.classes.medic then
			stat.weight = stat.weight * 1.5
		end

		if stat.val < 0 and (weapon.slots.primary_PDA or weapon.slots.secondary_PDA or weapon.slots.building) and not weapon.flags.never_deployed then
			stat.weight = stat.weight / 2
		end

		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("resistance", {min = -40, max = 40},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% resistance to self damage while deployed"
		else
			return stat.val.."% vulnerability to self damage while deployed"
		end
	end,
	function(weapon)
		return weapon.flags.splash and weapon.flags.damage
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val * 2, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("resistance", -50,
	function(stat, weapon)
		if weapon.flags.recharge and not weapon.flags.projectile then
			return "-You are Marked For Death while the effect is active, and for a short period after it ends"
		else
			return "-You are Marked For Death while deployed, and for a short period after switching weapons"
		end
	end,
	function(weapon)
		return weapon.flags.recharge or not weapon.flags.never_deployed
	end,
	function(stat, weapon)
		if (weapon.slots.primary_PDA or weapon.slots.secondary_PDA or weapon.slots.building) and not weapon.flags.never_deployed then
			stat.weight = stat.weight / 2
		end

		if (weapon.slots.primary and not weapon.classes.medic) or weapon.classes.medic == "secondary" or
				(weapon.slots.melee and (weapon.classes.demo or weapon.classes.engineer or weapon.classes.spy)) then

			stat.weight = stat.weight * 1.5
		end
	end
)

core.stats.registerStat("sapper", 50, "+Reverses enemy building construction", function(weapon)
	return weapon.name == "sapper" and weaponHasCategory(weapon, "sapper") == 0
end)

core.stats.registerStat("sapper", 25, "Sapped buildings won't get disabled, but will shoot/benefit players of both teams", function(weapon)
	return weapon.name == "sapper" and weaponHasCategory(weapon, "sapper") == 0
end)

core.stats.registerStat("sapper", 25, "Sapper won't drain building health, but you can use Alt-Fire to detonate it", function(weapon)
	return weapon.name == "sapper" and weaponHasCategory(weapon, "sapper") == 0
end)

core.stats.registerStat("self_heal", {min = -150, max = 30},
	function(stat, weapon)
		local desc = nil

		if stat.val > 0 then
			desc = "+On hit: Gain up to +"..stat.val.." health"
		else
			desc = "-On hit: Drains up to "..stat.val.." of user's health"
		end

		if weapon.flags.falloff and (stat.val > 1 or stat.val < -1) then
			desc = desc.." based on damage dealt"
		end

		return desc
	end,
	function(weapon)
		return weapon.flags.damage
	end,
	function(stat, weapon)
		stat.val = stat.val * (weapon.flags.interval or 1)

		if stat.val > 0 then
			stat.val = math.ceil(stat.val)
		else
			stat.val = math.floor(stat.val / 15)
		end

		if weapon.flags.never_deployed then
			stat.weight = stat.weight / 2
		end

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer or weapon.classes.spy) then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("self_heal", {min = 50, max = 200},
	function(stat, weapon)
		local upto = weapon.flags.falloff and "up to " or ""
		local based = weapon.flags.falloff and " based on damage dealt" or ""

		return "+On kill: Gain "..upto.."+"..stat.val.."% of max health"..based..", which may overheal"
	end,
	function(weapon)
		return weapon.flags.damage
	end,
	function(stat, weapon)
		if weapon.flags.never_deployed then
			stat.weight = stat.weight / 2
		end

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer or weapon.classes.spy) then
			stat.weight = stat.weight / 2
		end

		if weapon.name == "sniper_rifle" then
			stat.weight = stat.weight * 2
		end

		stat.val = core.utils.round(stat.val / 10) * 10
		stat.weight = core.utils.round(stat.weight / 10) * 10
	end
)

core.stats.registerStat("self_heal", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% healing from Health Packs on wearer"
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)

		if weapon.classes.engineer and core.utils.numKeys(weapon.classes) == 1 then
			stat.weight = stat.weight * 0.75
		end

		if weapon.classes.soldier or weapon.classes.heavy or weapon.classes.medic then
			stat.weight = stat.weight * 1.5
		end

		if stat.val < 0 then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("self_heal", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% healing from Medics on wearer"
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)

		if not (weapon.classes.scout or weapon.classes.soldier or weapon.classes.pyro or weapon.classes.demo or weapon.classes.heavy) then
			stat.weight = stat.weight * 0.60
		end

		if stat.val < 0 then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("self_heal", {min = -50, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% healing from Dispensers on wearer"
	end,
	function(weapon)
		return true
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)

		if weapon.classes.engineer then
			stat.weight = stat.weight * 1.4
		end

		if stat.val < 0 then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("self_heal", {min = -120, max = 120},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.." health regenerated per second "..core.special_stats.whileInUse(weapon)
		else
			local phrase = "health drained per second"

			if weapon.flags.regeneration then
				phrase = "less health regenerated per second"
			end
			
			return stat.val.." "..phrase.." "..core.special_stats.whileInUse(weapon)
		end
	end,
	function(weapon)
		return not weapon.classes.medic or core.utils.numKeys(weapon.classes) == 1
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val / 40)

		if stat.val == 0 then
			stat.val = 1
		end

		stat.weight = stat.val * 40

		if weapon.classes.medic or stat.val > 0 then
			stat.weight = stat.weight / 4
		end

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer or weapon.classes.spy) then
			stat.weight = stat.weight / 3
		end
	end
)

core.stats.registerStat("self_heal", {20, 40, 80},
	function(stat, weapon)
		if stat.val <= 20 then
			return "+On kill: A small health pack is dropped"
		elseif stat.val <= 40 then
			return "+On kill: A medium health pack is dropped"
		else
			return "+On kill: A large health pack is dropped"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed and not weapon.classes.sniper == "primary"
	end,
	function(stat, weapon)
		if weapon.flags.never_deployed then
			stat.weight = stat.weight * 0.75
		end

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer or weapon.classes.spy) then

			stat.weight = stat.weight * 0.5
		end
	end
)

core.stats.registerStat("shield", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then	
			return "+"..stat.val.." second increase in charge duration"
		else
			return stat.val.." second decrease in charge duration"
		end
	end,
	function(weapon)
		return weapon.name == "shield" or (not weapon.slots.secondary and (weapon.classes.demo or weapon.classes.heavy))
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val / 50, 0.1)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.name ~= "shield" and weapon.classes.heavy then
			core.notes.put("heavyCharge")
		end
	end
)

core.stats.registerStat("shield", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+Melee kills refill "..stat.val.."% of the charge meter"
		else
			return "-Melee kills drain "..(-stat.val).."% of the charge meter"
		end
	end,
	function(weapon)
		return weapon.name == "shield" or (not weapon.flags.never_deployed and (weapon.classes.demo == "melee" or weapon.classes.heavy == "melee"))
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val * (stat.val > 0 and 1.5 or 0.5), 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.classes.heavy then
			stat.weight = stat.weight / 2

			if weapon.name ~= "shield" then
				core.notes.put("heavyCharge")
			end
		end
	end
)

core.stats.registerStat("shield", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+Melee hits refill "..stat.val.."% of the charge meter"
		else
			return "-Melee hits drain "..(-stat.val).."% of the charge meter"
		end
	end,
	function(weapon)
		return weapon.name == "shield" or (not weapon.flags.never_deployed and (weapon.classes.demo == "melee" or weapon.classes.heavy == "melee"))
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val * (stat.val > 0 and 0.5 or 0.3), 5)
		stat.weight = core.utils.round(stat.weight, 10)

		if weapon.classes.heavy then
			stat.weight = stat.weight / 2

			if weapon.name ~= "shield" and weapon.classes.heavy then
				core.notes.put("heavyCharge")
			end
		end
	end
)

core.stats.registerStat("shield", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+Primary Weapon kills refill "..stat.val.."% of the charge meter"
		else
			return "-Primary Weapon kills drain "..(-stat.val).."% of the charge meter"
		end
	end,
	function(weapon)
		return weapon.name == "shield" or (not weapon.flags.never_deployed and (weapon.classes.demo == "primary" or weapon.classes.heavy == "primary"))
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val * (stat.val > 0 and 1.5 or 0.5), 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.classes.demo then
			stat.weight = stat.weight / 2
		end

		if weapon.name ~= "shield" and weapon.classes.heavy then
			core.notes.put("heavyCharge")
		end
	end
)

core.stats.registerStat("shield", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+Primary Weapon hits refill "..stat.val.."% of the charge meter"
		else
			return "-Primary Weapon hits drain "..(-stat.val).."% of the charge meter"
		end
	end,
	function(weapon)
		return weapon.name == "shield" or (not weapon.flags.never_deployed and (weapon.classes.demo == "primary" or weapon.classes.heavy == "primary"))
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val * (stat.val > 0 and 0.5 or 0.3), 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.classes.demo then
			stat.weight = stat.weight / 2
		end

		if weapon.classes.heavy then
			stat.val = core.utils.round(stat.val / 5)

			if weapon.name ~= "shield" and weapon.classes.heavy then
				core.notes.put("heavyCharge")
			end
		end
	end
)

core.stats.registerStat("shield", 40, "Ammo Boxes give Charge instead of Ammo when collected",
	function(weapon)
		return weapon.name == "shield" or (weapon.slots.melee and (weapon.classes.demo or weapon.classes.heavy))
	end,
	function(stat, weapon)
		if not weapon.classes.demo then
			stat.weight = stat.weight / 2
		end

		if weapon.name ~= "shield" and weapon.classes.heavy then
			core.notes.put("heavyCharge")
		end
	end
)

core.stats.registerStat("shot_behavior", {min = 30, max = 50},
	function(stat, weapon)
		return "+"..(weapon.flags.projectile and "Projectiles" or "Shots")
			.." from this weapon can bounce off of walls up to "..stat.val.." time"..(stat.val == 1 and "" or "s").." and still hit an enemy"
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.slots.melee and not weapon.flags.never_deployed and not weapon.flags.harmless_shatter
			and weapon.name ~= "stickybomb_launcher" and weapon.name ~= "flame_thrower"
	end,
	function(stat, weapon)
		stat.val = math.floor(stat.val / 10) - 2
		stat.weight = math.floor(stat.weight / 10) * 10

		weapon.flags.bounce = true
	end
)

core.stats.registerStat("shot_behavior", {min = 30, max = 50},
	function(stat, weapon)
		if stat.val >= 5 then
			return "+Shots from this weapon can pierce enemies"
		else
			return "+Shots from this weapon can pierce up to "..stat.val.." enem"..(stat.val == 1 and "y" or "ies")
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.slots.melee and not weapon.flags.never_deployed
			and not weapon.flags.projectile and weapon.name ~= "flame_thrower"
	end,
	function(stat, weapon)
		stat.val = math.floor(stat.val / 5) - 5
		stat.weight = math.floor(stat.weight / 5) * 5
	end
)

core.stats.registerStat("shot_behavior", {min = -40, max = 40},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% projectile speed"
	end,
	function(weapon)
		return weapon.flags.projectile and weapon.name ~= "stickybomb_launcher"
	end,
	function(stat, weapon)
		if stat.val < 0 then
			stat.val = stat.val / 2
		end

		stat.val = core.utils.round(stat.val / 2) * 5
		stat.weight = core.utils.round(stat.weight, 2)
	end
)

core.stats.registerStat("shot_behavior", {min = -25, max = 25},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% splash radius"
	end,
	function(weapon)
		return weapon.flags.splash
	end,
	function(stat, weapon)
		if stat.val > 0 then
			stat.val = stat.val * 2
		end

		if weapon.flags.damage then
			stat.weight = stat.weight * 2
		end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("shot_behavior", {min = -25, max = 50},
	function(stat, weapon)
		return (stat.val > 0 and "+" or "")..stat.val.."% splash radius while blast jumping"
	end,
	function(weapon)
		return (weapon.classes.soldier or weapon.classes.demo) and weapon.flags.splash
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val, 5)
		stat.weight = stat.val / 2

		if weapon.flags.damage then
			stat.weight = stat.weight * 2
		end
	end
)

core.stats.registerStat("shot_behavior", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% more accurate"
		else
			return stat.val.."% less accurate"
		end
	end,
	function(weapon)
		return weapon.flags.spread
	end,
	function(stat, weapon)
		core.special_stats.round5(stat)
	end
)

core.stats.registerStat("shot_behavior", {-50, 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+Successive shots become up to 100% more accurate"
		else
			return "-Successive shots become down to 50% less accurate"
		end
	end,
	function(weapon)
		return weapon.flags.spread
	end
)

core.stats.registerStat("shot_behavior", 50, "+On hit anything: Explodes, dealing splash damage",
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed and not weapon.flags.splash and not weapon.flags.no_splash
	end,
	function(stat, weapon)
		if weapon.slots.melee and not weapon.flags.projectile then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("shot_behavior", 50, "+All players connected via Medigun beams are hit",
	function(weapon)
		return weapon.flags.damage and weapon.name ~= "knife"
	end,
	function(stat, weapon)
		if weapon.slots.melee and not weapon.flags.projectile then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("shot_behavior", -40, "-Projectiles shatter harmlessly upon hitting terrain",
	function(weapon)
		return weapon.flags.damage and weapon.flags.splash and not weapon.flags.bounce and weapon.name ~= "stickybomb_launcher"
	end,
	function(stat, weapon)
		weapon.flags.harmless_shatter = true
	end
)

core.stats.registerStat("splash_effect", 50, "+Splashes enemies in jarate",
	function(weapon)
		return weapon.flags.splash and not weapon.flags.has_minicrit_bonus
	end,
	function(stat, weapon)
		if weapon.flags.damage then
			weapon.flags.has_minicrit_bonus = true
		end
		if not weapon.flags.recharge then
			stat.weight = stat.weight * 2
		end

		weapon.flags.jarate = true
	end
)

core.stats.registerStat("splash_effect", 50, "+Splashes enemies in milk",
	function(weapon)
		return weapon.flags.splash
	end,
	function(stat, weapon)
		if not weapon.flags.recharge then
			stat.weight = stat.weight * 2
		end

		weapon.flags.milk = true
	end
)

core.stats.registerStat("splash_effect", 50, "+Splash creates clouds of gasoline",
	function(weapon)
		return weapon.flags.splash and not weapon.classes.pyro
	end,
	function(stat, weapon)
		if not weapon.flags.recharge then
			stat.weight = stat.weight * 2
		end
	end
)

core.stats.registerStat("splash_effect", 50, "+Splashes enemies in sticky tar that slows their movements",
	function(weapon)
		return weapon.flags.splash
	end,
	function(stat, weapon)
		if not weapon.flags.recharge then
			stat.weight = stat.weight * 3
		end
	end
)

core.stats.registerStat("status_cure", {-60, 30},
	function(stat, weapon)
		if stat.val > 0 then
			return "+On hit teammate: Extinguishes them"
		else
			return "-On hit: Extinguishes the enemy"
		end
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.never_deployed and not weapon.flags.recharge
			and weapon.name ~= "flame_thrower" and not weapon.flags.instakill_goal
	end,
	function(stat, weapon)
		if stat.val < 0 then
			if not (weapon.classes.pyro or weapon.flags.afterburn) then
				stat.weight = stat.weight / 3
			end
		end

		if weapon.flags.splash or weapon.flags.bullets_per_shot then
			stat.weight = stat.weight * 2
		end
	end
)

core.stats.registerStat("status_effect", {min = 10, max = 50},
	function(stat, weapon)
		local desc = "+On hit: Make enemy bleed for up to "..stat.val.." seconds"

		if weapon.flags.falloff then
			desc = desc.." based on damage dealt"
		end

		return desc
	end,
	function(weapon)
		return weapon.flags.damage and weapon.name ~= "knife"
	end,
	function(stat, weapon)
		stat.val = math.ceil(stat.val / 5)
		stat.weight = stat.val * 5

		if weapon.flags.never_deployed or weapon.flags.instakill_goal then
			stat.weight = stat.weight / 2
		end

		if weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer) then
			stat.weight = stat.weight / 2
		end

		weapon.flags.bleed = true
	end
)

core.stats.registerStat("status_effect", {min = 10, max = 50},
	function(stat, weapon)
		local desc = "+On hit: Ignite enemy for up to "..stat.val.." seconds"

		if weapon.flags.falloff then
			desc = desc.." based on damage dealt"
		end

		return desc
	end,
	function(weapon)
		return weapon.flags.damage and not weapon.flags.afterburn
	end,
	function(stat, weapon)
		stat.val = math.ceil(stat.val / 5)
		stat.weight = stat.val * 5

		if weapon.flags.never_deployed or weapon.flags.instakill_goal then
			stat.weight = stat.weight / 2
		end

		if weapon.classes.pyro == "melee" then
			stat.weight = stat.weight / 3
		elseif weapon.slots.melee and not (weapon.classes.demo or weapon.classes.engineer or weapon.classes.spy) then
			stat.weight = stat.weight / 2
		end

		weapon.flags.afterburn = stat.val
	end
)

core.stats.registerStat("stealth", 25,
	function(stat, weapon)
		if weapon.name == "minigun" then
			return "+Silent Killer: No barrel spin sound"
		elseif weapon.name == "knife" then
			return "+Silent Killer: No attack noise from backstabs"
		else
			return "+Silent Killer: This weapon's noises are reduced to 25% of their usual volume"
		end
	end,
	function(weapon)
		return weapon.name == "minigun" or (weapon.classes.spy and weapon.flags.damage)
	end
)

core.stats.registerStat("stealth", -15, "-Fires tracer rounds", function(weapon)
	return weapon.name == "sniper_rifle"
end)

core.stats.registerStat("stickybomb", {min = -80, max = 80},
	function(stat, weapon)
		return (stat.val >= 0 and "+" or "")..stat.val.." max stickybomb"..((stat.val == 1 or stat.val == -1) and "" or "s").." out at once"
	end,
	function(weapon)
		return weapon.name == "stickybomb_launcher"
	end,
	function(stat, weapon)
		if stat.val < 0 then
			stat.val = math.min(stat.val * 0.5, -10)
		end

		stat.val = core.utils.round(stat.val / 10)
		stat.weight = core.utils.round(stat.weight, 10)
	end
)

core.stats.registerStat("stickybomb", {min = -80, max = 80},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.." second faster stickybomb arm time"
		else
			return stat.val.." second slower stickybomb arm time"
		end
	end,
	function(weapon)
		return weapon.name == "stickybomb_launcher"
	end,
	function(stat, weapon)
		if stat.val > 0 then
			stat.val = stat.val * 0.75
		end

		stat.val = core.utils.round(stat.val / 100, 0.1)
		stat.weight = core.utils.round(stat.weight, 5)
	end
)

core.stats.registerStat("stickybomb", -35, "-All explosives and flamethrowers can destroy your stickybombs", function(weapon)
	return weapon.name == "stickybomb_launcher"
end)

core.stats.registerStat("switch_speed", {min = -25, max = 25},
	function(stat, weapon)
		if stat.val > 0 then
			return "+This weapon deploys "..stat.val.."% faster"
		else
			return "-This weapon deploys "..(-stat.val).."% slower"
		end
	end,
	function(weapon)
		return not weapon.flags.never_deployed and weapon.name ~= "sword"
	end,
	function(stat, weapon)
		stat.val = stat.val * 2
		if stat.val > 0 then stat.val = stat.val * 2 end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.classes.heavy and core.utils.numKeys(weapon.classes) == 0 then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("switch_speed", {min = -25, max = 25},
	function(stat, weapon)
		if stat.val > 0 then
			return "+This weapon holsters "..stat.val.."% faster"
		else
			return "-This weapon holsters "..(-stat.val).."% slower"
		end
	end,
	function(weapon)
		return not weapon.flags.never_deployed and weapon.name ~= "sword"
	end,
	function(stat, weapon)
		stat.val = stat.val * 2
		if stat.val > 0 then stat.val = stat.val * 2 end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.classes.heavy and core.utils.numKeys(weapon.classes) == 0 then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("switch_speed", {min = -50, max = 50},
	function(stat, weapon)
		if stat.val > 0 then
			return "+"..stat.val.."% faster switch speed for all of wearer's weapons"
		else
			return stat.val.."% slower switch speed for all of wearer's weapons"
		end
	end,
	function(weapon)
		return weapon.flags.never_deployed
	end,
	function(stat, weapon)
		if stat.val < 0 then stat.val = stat.val / 2 end

		stat.val = core.utils.round(stat.val, 5)
		stat.weight = core.utils.round(stat.weight, 5)

		if weapon.classes.heavy and core.utils.numKeys(weapon.classes) == 0 then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("uber", {min = -50, max = 50},
	function(stat, weapon)
		local upto = weapon.flags.falloff and "up to " or ""

		if stat.val > 0 then
			return "+On hit: Gain "..upto..stat.val.."% Medigun Charge"
		else
			return "-On hit: Lose "..upto..(-stat.val).."% of your own Medigun Charge"
		end
	end,
	function(weapon)
		return weapon.flags.damage and weapon.classes.medic and core.utils.numKeys(weapon.classes) == 1
	end,
	function(stat, weapon)
		local int = (weapon.flags.interval or 1) / 2
		stat.val = core.utils.round(stat.val * int)

		if weapon.slots.melee then
			stat.weight = stat.weight / 2
		end
	end
)

core.stats.registerStat("uber", {min = -100, max = 100},
	function(stat, weapon)
		local cond = " on wearer"

		if weapon.name == "medigun" then
			cond = ""
		end

		return (stat.val > 0 and "+" or "")..stat.val.."% ÜberCharge Rate"..cond
	end,
	function(weapon)
		return weapon.classes.medic and core.utils.numKeys(weapon.classes) == 1
	end,
	function(stat, weapon)
		stat.val = core.utils.round(stat.val / 4)
		stat.weight = stat.val * 4

		if weapon.name == "medigun" then
			stat.weight = stat.weight / 2
		else
			stat.weight = stat.weight * 1.5
		end
	end
)



local catsum, statsum = 0, 0
for cat, stat in pairs(registered) do
	catsum = catsum + 1

	for i = 1, #stat do
		statsum = statsum + 1
	end
end
print("Number of registered categories: "..catsum.."\nNumber of registered stats: "..statsum.."\n\n")

