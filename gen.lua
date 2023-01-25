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



math.randomseed(os.time())
core = {}
local args = {...}
local js = nil

xpcall(function() js = require("js") end, function() end)

local document = js and js.global.document

if js then
	print("HTML is in use")
else
	print("HTML is not in use")
end

core.settings = {
	class = args[1] or "any",
	slot = args[2] or "any",
	goal = tonumber(args[3]) or 0,
	intensity = tonumber(args[4]) or 8,
	tolerance = tonumber(args[5]) or 10
}

dofile("./utils.lua")
dofile("./notes.lua")
dofile("./special_stats.lua")
dofile("./weapon.lua")
dofile("./stats.lua")



local wrap = function(goal)
	return function(...)
		return core.utils.nearest(goal, ...)
	end
end

local function useInt(int_rem)
	return math.abs(int_rem) > core.settings.tolerance
end

function core.generate()
	core.notes.clear()

	local weapon = core.weapon.create(core.settings.class, core.settings.slot)
	local int = core.settings.intensity
	int = int + math.random(-core.utils.round(int * 0.15), core.utils.round(int * 0.15))
	local int_rem = int * (math.random(1, 2) == 1 and 10 or -10)
	local start_rem = int_rem

	while true do
		local stat = nil
		local goal = useInt(int_rem) and start_rem or core.settings.goal
		print("Next Goal: "..goal)
		print("Weapon Stat Points: "..weapon.stat_points)

		if weapon.stat_points > goal + core.settings.tolerance then
			stat = core.utils.try(core.stats.create, weapon, core.utils.weightRandom(wrap(-50), goal - weapon.stat_points, -core.settings.tolerance))
		elseif weapon.stat_points < goal - core.settings.tolerance then
			stat = core.utils.try(core.stats.create, weapon, core.utils.weightRandom(wrap(50), core.settings.tolerance, goal - weapon.stat_points))
		end

		if stat then
			weapon:addStat(stat)

			if stat.weight and useInt(int_rem) then
				int_rem = int_rem - stat.weight
			end

			if type(stat) == "string" then
				break
			end
		elseif useInt(int_rem) then
			int_rem = 0
		else
			break
		end

		print()
	end

	print("\n\n")

	weapon:sortStats()

	local strData = weapon:toString(int)

	if js then
		document:getElementById("weaponImg").src = strData.image

		document:getElementById("weaponTitle").textContent = strData.title
		document:getElementById("weaponSubtitle").textContent = strData.subtitle

		local stats = ""

		for i = 1, #strData.stats do
			local stat = strData.stats[i]

			if stat:sub(1, 1) == "+" then
				stats = stats.."<p class=\"positive\">"..stat.."</p>"
			elseif stat:sub(1, 1) == "-" then
				stats = stats.."<p class=\"negative\">"..stat.."</p>"
			else
				stats = stats.."<p class=\"neutral\">"..stat.."</p>"
			end
		end

		local notes = core.notes.get()

		if #notes > 0 then
			stats = stats.."<br><p class=\"neutral\">Notes:</p>"
		end

		for i = 1, #notes do
			stats = stats.."<br><p class=\"neutral\">"..notes[i].."</p>"
		end

		document:getElementById("weaponStats").innerHTML = stats
	else
		print("\27[93m"..strData.title.."\27[0m\n")
		print("\27[90;40m"..strData.subtitle.."\27[0m\n")

		for i = 1, #strData.stats do
			local stat = strData.stats[i]

			if stat:sub(1, 1) == "+" then
				print("\27[96m"..stat.."\27[0m")
			elseif stat:sub(1, 1) == "-" then
				print("\27[91m"..stat.."\27[0m")
			else
				print(stat)
			end
		end

		local notes = core.notes.get()

		if #notes > 0 then
			print("\nNotes:")
		end

		for i = 1, #notes do
			print(notes[i])
		end
	end
end

if not js then
	core.generate()
end

