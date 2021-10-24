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

core.notes = {}

local registered = {}
local notebook = {}

function core.notes.register(name, note)
	assert(type(name) == "string", "Note Error: Name must be provided as a string.")
	assert(type(note) == "string", "Note Error: Note must be provided as a string.")
	assert(not registered[name], "Note Error: A note by the name of \""..name.."\" already exists.")

	registered[name] = note
end

function core.notes.clear()
	notebook = {}
end

function core.notes.put(name)
	assert(type(name) == "string", "Note Error: Name in set() must be provided as a string.")
	assert(registered[name], "Note Error: Attempt to set a note by the name of \""..name.."\", which doesn't exist.")

	notebook[name] = true
end

function core.notes.get()
	local n = {}

	for name in pairs(notebook) do
		table.insert(n, registered[name])
	end

	return n
end



core.notes.register("bothPlayers", "\"Both players\" is the same wording used by the Disciplinary Action.")

core.notes.register("engineerBuildings", "Sentry replacements only appear on melee weapons, Dispenser replacements on Construction PDAs, and "
	.."Teleporters on Destruction PDAs in order to prevent theoretical conflicts from equipping any two weapons at once.")

core.notes.register("fly", "Imagine it like swimming through the air. You get to be mobile, but not enough that nobody can ever airshot you.")

core.notes.register("heavyCharge", "In case you haven't seen one yet, it's possible for this generator to make Charge Shields for heavies.")

core.notes.register("heavyShield", "This is a reference to Shounic's video about any class equipping any weapon, where one of the strategies "
	.."was to equip a Shield as the Heavy and charge at people while revving the minigun.")

core.notes.register("IPS", "Based on the Pomson for its 60 base damage, rather than the Righteous Bison's pitiful 20.")
