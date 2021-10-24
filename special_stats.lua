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

core.special_stats = {}

function core.special_stats.no_weapon(weapon)
	if weapon.classes.demo then
		weapon.stat_points = -150
	else
		weapon.stat_points = -100
	end
end

function core.special_stats.banner(weapon)
	local sel = math.random(8)

	if sel == 1 then
		weapon.stats[1] = "Provides an offensive buff that causes nearby team members to do mini-crits."
	elseif sel == 2 then
		weapon.stats[1] = "Provides a defensive buff that protects nearby team members from crits, "
			.."incoming sentry damage by 50% and 35% from all other sources."
	elseif sel == 3 then
		weapon.stats[1] = "Provides a group speed buff with damage done giving health."
	elseif sel == 4 then
		weapon.stats[1] = "Provides a buff to nearby team members that doubles the push force of their weapons, "
			.."while protecting them from movement impairing effects."
	elseif sel == 5 then
		weapon.stats[1] = "Provides a supportive buff to nearby teammates that grants them health and ammo regeneration equal to a Level 3 Dispenser."
	elseif sel == 6 then
		weapon.stats[1] = "Inflicts a debuff on nearby enemies that reduces their damage by 30% and disables any damage resistances that they have."
	elseif sel == 7 then
		weapon.stats[1] = "Links you with all teammates who are nearby upon use. Whenever anyone takes damage, that damage is evenly divided between "
			.."every linked person."
	else
		weapon.stats[1] = "Provides a massive group speed and jump boost to nearby teammates, as well as 50% resistance to fall damage."
	end

	weapon.stats[2] = "Charge increases through damage done"
	weapon.stat_points = -25
end

function core.special_stats.invis_watch(weapon)
	local sel = math.random(6)

	if sel == 1 then
		weapon.stats[1] = "Cloak Type: Normal"
		weapon.stats[2] = "Alt-Fire: Turn invisible. Cannot attack while invisible. Bumping in to enemies will make you slightly visible to enemies"
	elseif sel == 2 then
		weapon.stats[1] = "Cloak Type: Motion Sensitive"
		weapon.stats[2] = "Alt-Fire: Turn invisible. Cannot attack while invisible. Bumping in to enemies will make you slightly visible to enemies"
		weapon.stats[3] = "Cloak drain rate based on movement speed"
	elseif sel == 3 then
		weapon.stats[1] = "Cloak Type: Feign Death"
		weapon.stats[2] = "Leave a fake corpse on taking damage and temporarily gain invisibility, speed and damage resistance"
		weapon.stat_points = 25
	elseif sel == 4 then
		weapon.stats[1] = "Cloak Type: Decoy"
		weapon.stats[2] = "Alt-Fire: Turn invisible. Create a non-solid illusion of yourself or your current disguise walking forward until you de-cloak"
		weapon.stat_points = 25
	elseif sel == 5 then
		weapon.stats[1] = "Cloak Type: Phase"
		weapon.stats[2] = "Alt-Fire: Turn invisible. You can pass through enemy buildings and players but dies if they're inside something when de-cloaking"
		weapon.stat_points = 25
	else
		weapon.stats[1] = "Cloak Type: Perfect Disguise"
		weapon.stats[2] = "Alt-Fire: Allow enemy shots to pass harmlessly through you. Only works while disguised. Cannot attack while this watch is active. Enemies can still bump into you"
		weapon.stat_points = 50
	end
end

function core.special_stats.lunchbox(weapon)
	local sel = math.random(8)

	if sel == 1 then
		weapon.stats[1] = "Use to gain Mini-Crits for a period of time"
	elseif sel == 2 then
		weapon.stats[1] = "Use to become immune to Critical Hits for a period of time"
	elseif sel == 3 then
		weapon.stats[1] = "Use to give yourself 15 health/second regeneration that can overheal for a period of time"
		weapon.flags.regeneration = true
	elseif sel == 4 then
		weapon.stats[1] = "Use to temporarily boost your max health by 50 for a period of time"
	elseif sel == 5 then
		weapon.stats[1] = "Use to grant yourself infinite ammo for a period of time"
	elseif sel == 6 then
		weapon.stats[1] = "Use to float through the air for a period of time"
	elseif sel == 7 then
		weapon.stats[1] = "Use to grant yourself a 50% speed boost for a period of time"
	else
		weapon.stats[1] = "Use to give yourself 25 health/second regeneration for a period of time"
		weapon.flags.regeneration = true
	end

	weapon.stat_points = -50

	if weapon.classes.heavy then
		weapon.flags.activation_time = 4.3
		weapon.flags.altfire = true
		weapon.flags.share_medpack = true

		sel = math.random(6)
		if sel == 1 then
			weapon.stats[2] = "Alt-Fire: Share a large health kit with a friend"
			weapon.stat_points = weapon.stat_points / 2
		elseif sel == 2 then
			weapon.stats[2] = "Alt-Fire: Share a medium health kit with a friend"
		elseif sel == 3 then
			weapon.stats[2] = "Alt-Fire: Share a small health kit with a friend"
			weapon.stat_points = weapon.stat_points * 2
		elseif sel == 4 then
			weapon.stats[2] = "Alt-Fire: Share a large ammo kit with a friend"
		elseif sel == 5 then
			weapon.stats[2] = "Alt-Fire: Share a medium ammo kit with a friend"
			weapon.stat_points = weapon.stat_points * 2
		else
			weapon.stats[2] = "Alt-Fire: Share a small ammo kit with a friend"
			weapon.stat_points = weapon.stat_points * 3
		end
	end
end

function core.special_stats.medigun(weapon)
	local sel = math.random(8)

	if sel == 1 then
		weapon.stats[1] = "ÜberCharge grants invulnerability"
	elseif sel == 2 then
		weapon.stats[1] = "ÜberCharge grants 100% Critical Hits"
		weapon.stat_points = -25
	elseif sel == 3 then
		weapon.stats[1] = "ÜberCharge grants immunity to Critical Hits, movement impairing effects, and all negative status effects. "
			.."Also grants 40% resistance to all damage types."
		weapon.stat_points = -25
	elseif sel == 4 then
		weapon.stats[1] = "ÜberCharge grants 300% healing rate and immunity to movement impairing effects"
		weapon.stat_points = -50
	elseif sel == 5 then
		weapon.stats[1] = "ÜberCharge grants Mini-Crits and infinite clip and reserve ammo"
		weapon.stat_points = -50
	elseif sel == 6 then
		weapon.stats[1] = "ÜberCharge grants healing to all allies within its range"
		weapon.stat_points = -75
	elseif sel == 7 then
		weapon.stats[1] = "ÜberCharge grants self-healing even after holstering this weapon"
		weapon.stat_points = -100
	else
		weapon.stats[1] = "ÜberCharge grants the ability to fly. Also grants fall damage immunity that can last after the ÜberCharge "
			.."itself ends, until landing on the ground."
		weapon.stat_points = -100
		core.notes.put("fly")
	end
end

function core.special_stats.shield(weapon)
	local stat = ": Charge toward your enemies and remove debuffs."

	if weapon.classes.heavy then
		stat = "Reload"..stat
		weapon.stat_points = -30
		core.notes.put("heavyShield")
	else
		local sel = math.random(3)
		stat = "Alt-Fire"..stat.." "

		if sel == 1 then
			stat = stat.."Gain a critical melee strike after impacting an enemy."
			weapon.stat_points = -30
		elseif sel == 2 then
			stat = stat.."Gain a critical melee strike after impacting an enemy at a distance."
			weapon.stat_points = -60
		else
			stat = stat.."Gain a mini-crit melee strike after impacting an enemy at a distance."
			weapon.stat_points = -90
		end
	end

	weapon.stats[1] = stat
end



function core.special_stats.whileInUse(weapon)
	if ((weapon.flags.recharge or weapon.flags.charge_build) and weapon.flags.projectile) or weapon.flags.never_deployed then
		return "on wearer"
	elseif (weapon.flags.recharge or weapon.flags.charge_build) and not weapon.flags.damage then
		return "while the effect is active"
	else
		return "while deployed"
	end
end

function core.special_stats.round5(stat)
	stat.val = core.utils.round(stat.val, 5)
	stat.weight = stat.val
end

function core.special_stats.handleCrits(stat, weapon, critType, minicritCost, critCost)
	if critType == critCost and weapon.flags.no_crit_bonus then
		stat.val = minicritCost
	elseif critType == minicritCost and weapon.flags.no_minicrit_bonus then
		stat.val = critCost
	end

	critType = stat.val
	stat.weight = stat.val

	if critType == critCost then
		weapon.flags.has_crit_bonus = true
	else
		weapon.flags.has_minicrit_bonus = true
	end
end
