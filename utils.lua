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

core.utils = {}

function core.utils.andList(strings, moreCommas)
	if #strings == 1 then
		return strings[1]
	elseif #strings == 2 then
		return strings[1]..(moreCommas and "," or "").." and "..strings[2]
	else
		local output = ""

		for i = 1, #strings-1 do
			output = output..strings[i]..", "
		end

		return output.."and "..strings[#strings]
	end
end

function core.utils.clone(obj)
	local clone = {}

	for k, v in pairs(obj) do
		if type(v) == "table" then
			clone[k] = core.utils.clone(v)
		else
			clone[k] = v
		end
	end

	return clone
end

function core.utils.contains(obj, target)
	for k, v in pairs(obj) do
		if v == target then
			return true
		end
	end
end

function core.utils.distance(a, b)
	return math.abs(a - b)
end

function core.utils.dump(t, l)
	if type(t) ~= "table" then
		return tostring(t)
	end

	local s = "{"
	l = l or 1

	for k, v in pairs(t) do
		for i = 1, l do
			s = s.."    "
		end

		s = s.."\n"..k.." = "

		if type(v) == "table" then
			s = s..core.utils.dump(v, l + 1)
		else
			s = s..v
		end
	end

	return s.."\n}"
end

function core.utils.gate(min, val, max)
	if min > val then
		return min
	elseif val > max then
		return max
	else
		return val
	end
end

function core.utils.gateOut(min, val, max)
	local med = (min + max) / 2

	if min < val and val < med then
		return min
	elseif med <= val and val < max then
		return max
	else
		return val
	end
end

function core.utils.getKeys(obj)
	local keys = {}

	for k in pairs(obj) do
		table.insert(keys, k)
	end

	return keys
end

function core.utils.hasKeys(obj, keys)
	for _, k in ipairs(keys) do
		if obj[k] then
			return true
		end
	end
end

function core.utils.iTableToString(obj)
	local str = "{"

	for i = 1, #obj do
		str = str..obj[i]..", "
	end

	if str == "{" then return "{}" end

	return str:sub(1, #str-2).."}"
end

function core.utils.namesToTitles(names)
	local titles = {}

	for i = 1, #names do
		titles[i] = core.utils.nameToTitle(names[i])
	end

	return titles
end

function core.utils.nameToTitle(name, removeSpaces)
	local title = ""

	name = name:gsub("pda", "PDA"):gsub("_", " ")

	for i = 1, #name do
		local ch = name:sub(i, i)

		if i == 1 then
			title = ch:upper()
		else
			local prev = name:sub(i - 1, i - 1)

			if prev == " " and ch ~= " " then
				ch = ch:upper()
			end

			title = title..ch
		end
	end

	if removeSpaces then
		title = title:gsub(" ", "")
	end

	return title
end

function core.utils.nearest(goal, ...)
	local nums = {...}
	local nearest = nums[1]

	for i = 2, #nums do
		if nums[i] == goal then
			return goal
		end

		if math.abs(goal - nums[i]) < math.abs(goal - nearest) then
			nearest = nums[i]
		elseif math.abs(goal - nums[i]) == math.abs(goal - nearest) then
			nearest = math.random(2) == 1 and nearest or nums[i]
		end
	end

	return nearest
end

function core.utils.numKeys(obj)
	local count = 0

	for _ in pairs(obj) do
		count = count + 1
	end

	return count
end

--Fengari appears to lack math.pow
core.utils.pow = math.pow or function(a, b)
	local val = 1

	for i = 1, b do
		val = val * a
	end

	return val
end

function core.utils.randomChances(chanceTable, chanceKey)
	local keys = core.utils.getKeys(chanceTable)

	local sum = 0

	for _, k in ipairs(keys) do
		if chanceKey then
			sum = sum + chanceTable[k][chanceKey]
		else
			sum = sum + chanceTable[k]
		end
	end

	if sum == 0 then return end

	local sel = math.random(sum)
	local selSum = 0

	for _, k in ipairs(keys) do
		if chanceKey then
			selSum = selSum + chanceTable[k][chanceKey]
		else
			selSum = selSum + chanceTable[k]
		end

		if selSum >= sel then
			return k, chanceTable[k]
		end
	end
end

function core.utils.randomSelection(obj)
	local keys = core.utils.getKeys(obj)
	local key = keys[math.random(#keys)]

	return key, obj[key]
end

function core.utils.round(n, p)
	p = p or 1
	return math.floor(n / p + 0.5) * p
end

function core.utils.try(func, ...)
	local ret = nil

	local f = function(...)
		ret = func(...)
	end
	
	xpcall(f, function(err)
		print(err)
		print(debug.traceback())
		ret = "-"..err
	end, ...)

	return ret
end

function core.utils.weightRandom(wFunc, a, b, tries)
	local result = math.random(a, b)

	for i = 2, (tries or 2) do
		local try = math.random(a, b)

		result = wFunc(result, try)
	end

	return result
end
