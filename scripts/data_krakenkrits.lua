-- Package script "KrakenKritsData" for Traveller (Mongoose 2E, MGT2).
-- Boxcars (a natural 12 on the attack's 2D) rolls a Telling Shot; snake eyes
-- (a natural 2) rolls a Firefight Fumble, unless the ruleset's own Combat
-- Mishaps option is on (it already rolls the book's mishap table then).
-- Effects are tracker reminders (MGT2 has no tags for these); the Referee
-- applies the numbers. Rows: { from, to, title, text, { effects } }.

GAME = {
  tag = "Kraken Krits & Fumbles Traveller",
  pfx = "KKFT_",
  icon = "action_attack",
  defaultCrit = "always",
  defaultFumble = "always",
}

local function T(name, rows) return { name = name, die = 12, rows = rows } end
local function r(n, title, text, fx) return { n, n, title, text, fx or {} } end

TABLES = {
  telling_ranged = T("Telling Shot - Ranged", {
    r(1, "Through the visor", "The target is blinded until the end of its next round (DM-2 to all checks).", { { effect = "Kraken Visor cracked (DM-2)", dur = 1 } }),
    r(2, "Armour breach", "The round finds a seam: the target's armour counts 2 points lower until patched.", { { effect = "Kraken Armour breached (-2 protection)" } }),
    r(3, "Weapon hand", "The target drops what it holds in its weapon hand.", { { note = "the target drops its weapon" } }),
    r(4, "Knocked flat", "The impact puts the target prone.", { { effect = "Prone" } }),
    r(5, "Suit puncture", "A vacc suit or environment seal fails: the target is losing air or protection.", { { effect = "Kraken Suit puncture (seal it: minor action)" } }),
    r(6, "Pinned down", "The target must take cover: it loses its next significant action.", { { effect = "Kraken Pinned down (lose next significant action)", dur = 1 } }),
    r(7, "Comms smashed", "The target's comm, earpiece or helmet link is shot away.", { { note = "the target's comms are destroyed" } }),
    r(8, "Leg wound", "Movement halved until treated with Medic.", { { effect = "Kraken Leg wound (half movement)" } }),
    r(9, "Ammunition hit", "The target's spare ammunition or power pack is ruined.", { { note = "the target loses its reloads" } }),
    r(10, "Stunned", "The shock of the hit: the target is stunned (DM-2) for 1 round.", { { effect = "Kraken Stunned (DM-2)", dur = 1 } }),
    r(11, "Bleeding", "The wound bleeds: 1 damage at the start of each round until a Medic check (8+).", { { effect = "Kraken Bleeding (1 damage a round; Medic 8+)" } }),
    r(12, "Textbook kill shot", "Add 1D damage to this attack.", { { note = "add 1D damage to this attack" } }),
  }),
  telling_melee = T("Telling Shot - Melee", {
    r(1, "Disarmed", "The target's weapon spins away 1D metres.", { { note = "the target is disarmed (weapon 1D metres away)" } }),
    r(2, "Floored", "The target goes down: prone.", { { effect = "Prone" } }),
    r(3, "Winded", "The target loses its next minor action catching its breath.", { { effect = "Kraken Winded (lose next minor action)", dur = 1 } }),
    r(4, "Broken fingers", "DM-1 to the target's attacks until treated.", { { effect = "Kraken Broken fingers (DM-1 attacks)" } }),
    r(5, "Grappled", "The attacker gets a grip: the target is grappled.", { { effect = "Kraken Grappled" } }),
    r(6, "Concussion", "The target is stunned (DM-2) for 1 round.", { { effect = "Kraken Concussed (DM-2)", dur = 1 } }),
    r(7, "Armour strap cut", "The target's armour counts 1 point lower until repaired.", { { effect = "Kraken Armour strap cut (-1 protection)" } }),
    r(8, "Thrown into cover", "The target is shoved 2 metres; the attacker chooses where.", { { note = "push the target 2 metres" } }),
    r(9, "Deep cut", "Bleeding: 1 damage each round until a Medic check (8+).", { { effect = "Kraken Bleeding (1 damage a round; Medic 8+)" } }),
    r(10, "Shaken", "The target's nerve breaks: DM-1 to all checks for 3 rounds.", { { effect = "Kraken Shaken (DM-1)", dur = 3 } }),
    r(11, "Dirty fighting", "The attacker gains a Boon on its next attack.", { { effect = "Kraken Boon next attack", dur = 1, who = "a" } }),
    r(12, "Lights out", "Add 1D damage to this attack.", { { note = "add 1D damage to this attack" } }),
  }),
  fumble_ranged = T("Firefight Fumble - Ranged", {
    r(1, "Jammed", "The weapon jams: a significant action to clear it.", { { effect = "Kraken Weapon jammed (significant action to clear)" } }),
    r(2, "Dry fire", "The magazine is empty or the power pack dead: reload.", { { note = "the attacker must reload" } }),
    r(3, "Friendly fire", "An ally in the line of fire is attacked instead (same roll -4).", { { note = "attack an ally in the line of fire at DM-4" } }),
    r(4, "Exposed", "The attacker breaks cover: attacks against it gain DM+2 until its next turn.", { { effect = "Kraken Exposed (attacks vs it DM+2)", dur = 1 } }),
    r(5, "Dropped", "The weapon slips from the attacker's grip.", { { note = "the attacker drops the weapon" } }),
    r(6, "Overheat", "The weapon overheats: it cannot fire next round.", { { effect = "Kraken Weapon overheated (no fire next round)", dur = 1 } }),
    r(7, "Recoil", "The recoil throws the attacker off: DM-2 to its next attack.", { { effect = "Kraken Recoil (DM-2 next attack)", dur = 1 } }),
    r(8, "Ricochet", "The round comes back: the attacker takes 1D damage.", { { note = "the attacker takes 1D damage" } }),
    r(9, "Sight knocked", "The sight is off true: DM-1 with this weapon until a minor action fixes it.", { { effect = "Kraken Sight knocked (DM-1 this weapon)" } }),
    r(10, "Stray round", "The shot hits something important: a window, a pipe, the hull.", { { note = "the stray shot hits scenery the Referee picks" } }),
    r(11, "Prone", "The attacker slips while firing and falls prone.", { { effect = "Prone" } }),
    r(12, "Catastrophic failure", "The weapon is broken and needs repair (Mechanic or Engineer) before it fires again.", { { note = "the weapon is broken until repaired" } }),
  }),
  fumble_melee = T("Firefight Fumble - Melee", {
    r(1, "Off balance", "Attacks against the attacker gain DM+2 until its next turn.", { { effect = "Kraken Off balance (attacks vs it DM+2)", dur = 1 } }),
    r(2, "Dropped weapon", "The weapon falls at the attacker's feet.", { { note = "the attacker drops the weapon" } }),
    r(3, "Tripped", "The attacker falls prone.", { { effect = "Prone" } }),
    r(4, "Self-inflicted", "The attacker cuts or bruises itself: 1D-2 damage.", { { note = "the attacker takes 1D-2 damage" } }),
    r(5, "Stuck", "The blade sticks in a bulkhead or armour: lose the next minor action.", { { effect = "Kraken Weapon stuck (lose next minor action)", dur = 1 } }),
    r(6, "Wrenched shoulder", "DM-1 to melee attacks for the rest of the fight.", { { effect = "Kraken Wrenched shoulder (DM-1 melee)" } }),
    r(7, "Friendly bump", "An adjacent ally is knocked aside 1 metre.", { { note = "an adjacent ally is pushed 1 metre" } }),
    r(8, "Gear snag", "A strap or holster tears: one item drops.", { { note = "one carried item drops" } }),
    r(9, "Winded", "The attacker loses its next minor action.", { { effect = "Kraken Winded (lose next minor action)", dur = 1 } }),
    r(10, "Opening", "The target gains a Boon on its next attack against the attacker.", { { note = "the target gains a Boon on its next attack" } }),
    r(11, "Broken weapon", "The weapon breaks.", { { note = "the weapon breaks" } }),
    r(12, "Bad fall", "Prone and stunned (DM-2) for 1 round.", { { effect = "Prone" }, { effect = "Kraken Stunned (DM-2)", dur = 1 } }),
  }),
}

function pickTable(sKind, rSource, rTarget, rRoll)
  local sDesc = ((rRoll and rRoll.sDesc) or ""):lower()
  local bMelee = sDesc:find("(m)", 1, true) ~= nil or sDesc:find("melee", 1, true) ~= nil
  if sKind == "crit" then return bMelee and "telling_melee" or "telling_ranged" end
  return bMelee and "fumble_melee" or "fumble_ranged"
end

-- The two dice the ruleset reads (it uses aDice[1] and aDice[2] for snake eyes)
local function natural(rRoll)
  local d1, d2 = rRoll and rRoll.aDice and rRoll.aDice[1], rRoll and rRoll.aDice and rRoll.aDice[2]
  local function v(d) return type(d) == "table" and (d.value or d.result) or 0 end
  return v(d1), v(d2)
end

GAME.pickTable = pickTable
GAME.hook = function()
  local fOrig = ActionsManager.getResultHandler("attack")
  ActionsManager.registerResultHandler("attack", function(rSource, rTarget, rRoll)
    local vResult
    if fOrig then vResult = fOrig(rSource, rTarget, rRoll) end
    local a, b = natural(rRoll)
    if a == 6 and b == 6 then
      KrakenKrits.onAttackResult(rSource, rTarget, rRoll, "crit")
    elseif a == 1 and b == 1 and not OptionsManager.isOption("COMPMISHAPS", "yes") then
      KrakenKrits.onAttackResult(rSource, rTarget, rRoll, "fumble")
    end
    return vResult
  end)
end
