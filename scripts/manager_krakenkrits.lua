-- Kraken Krits & Fumbles engine (generated: kraken-extensions/krits/build.py).
-- On a critical hit or a fumble it rolls the game's table and applies the
-- result where Fantasy Grounds can: conditions and penalties as tracker
-- effects, extra or self damage as real damage rolls, "maximum damage" and
-- "extra die" on the attacker's next damage roll. What cannot be automated
-- (instant death, maiming, dropped gear) is announced to the GM in chat.
--
-- The game's data package (KrakenKritsData) gives the tables, which table an
-- attack uses, the option list and how the ruleset reports crits and fumbles.

local Public = {}
local GAME          -- KrakenKritsData.GAME
local OOB_MARK = "krakenkrits_mark"
local OOB_RESOLVE = "krakenkrits_resolve"

local MARK_MAX = "Kraken Krit: maximum damage"
local MARK_DIE = "Kraken Krit: extra damage die"
local MARK_X = "Kraken Krit: damage x"
local MARK_MIN = "Kraken Krit: minimum damage"
local MARK_DBL = "Kraken Krit: double dice and bonus"

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function opt(sKey) return OptionsManager.getOption(GAME.pfx .. sKey) end

local function actorName(rActor)
  return (rActor and ActorManager.getDisplayName(rActor)) or "?"
end

local function chat(sText, bGMOnly)
  local msg = { text = sText, font = "systemfont", icon = GAME.icon or "action_attack_crit" }
  if bGMOnly then
    msg.secret = true
    Comm.addChatMessage(msg)
  else
    Comm.deliverChatMessage(msg)
  end
end

local function rollDice(sDice)
  -- "2d6+1" -> total (host side, shown in the chat line)
  local n, s, m = tostring(sDice or ""):match("^(%d*)d(%d+)([%+%-]?%d*)$")
  if not s then return tonumber(sDice) or 0 end
  local total = 0
  for _ = 1, (tonumber(n) or 1) do total = total + math.random(1, tonumber(s)) end
  return total + (tonumber(m) or 0)
end

local function chance(sSetting)
  if sSetting == "off" or sSetting == nil or sSetting == "" then return false end
  if sSetting == "half" then return math.random(1, 2) == 1 end
  if sSetting == "third" then return math.random(1, 3) == 1 end
  return true
end

---------------------------------------------------------------------------
-- Applying results
---------------------------------------------------------------------------
local function addEffect(rActor, sLabel, nDur, bGMOnly)
  local nodeCT = rActor and ActorManager.getCTNode(rActor)
  if not nodeCT then return false end
  EffectManager.addEffect("", "", nodeCT, {
    sName = sLabel, nDuration = nDur or 0, nGMOnly = bGMOnly and 1 or 0, nInit = 0,
  }, true)
  return true
end

-- CoreRPG d20 damage roll (3.5E, 2E, SiegeCore and C&C all build on it)
local function makeDamageRoll(rSource, sDice, sType, sLabel)
  if GAME.makeDamageRoll then return GAME.makeDamageRoll(rSource, sDice, sType, sLabel) end
  local tDice, nMod = DiceManager.convertStringToDice(sDice, true)
  if ActionDamageD20 and ActionDamageD20.getRoll then
    return ActionDamageD20.getRoll(rSource, { label = sLabel, clauses = { { dice = tDice, modifier = nMod or 0, dmgtype = sType or "" } } })
  end
  if ActionDamage and ActionDamage.getRoll then
    return ActionDamage.getRoll(rSource, { label = sLabel, dice = tDice, modifier = nMod or 0, dmgtype = sType or "" })
  end
  return nil
end

-- A real damage roll in chat, applied to rTarget the ruleset's own way
local function damageRoll(rSource, rTarget, sDice, sType, sTitle)
  if not rTarget then return false end
  local rRoll = makeDamageRoll(rSource, sDice, sType, "Kraken Krit: " .. sTitle)
  if not rRoll then return false end
  ActionsManager.actionDirect(rSource, "damage", { rRoll }, { { rTarget } })
  return true
end

local function applyFx(fx, rAttacker, rVictim, tOut)
  local rWho = (fx.who == "a") and rAttacker or rVictim
  local sWho = actorName(rWho)
  if fx.effect then
    if opt("AUTO") ~= "no" and addEffect(rWho, fx.effect, fx.dur) then
      table.insert(tOut, fx.effect .. " -> " .. sWho)
    else
      table.insert(tOut, "(" .. sWho .. ": " .. fx.effect .. ")")
    end
  end
  if fx.dmg then
    if opt("AUTO") == "no" or not damageRoll(rAttacker, rWho, fx.dmg, fx.type or "", fx.title or "extra damage") then
      table.insert(tOut, "(" .. sWho .. " takes " .. fx.dmg .. " damage)")
    end
  end
  if fx.mark then
    -- maximum damage / extra die / multiplier on the attacker's next damage roll
    local sMark = (fx.mark == "max" and MARK_MAX) or (fx.mark == "die" and MARK_DIE) or (fx.mark == "min" and MARK_MIN)
      or (fx.mark == "double" and MARK_DBL) or (MARK_X .. tostring(fx.mark))
    if opt("AUTO") ~= "no" and addEffect(rAttacker, sMark, 1) then
      table.insert(tOut, sMark .. " (next damage roll)")
    else
      table.insert(tOut, "(" .. sMark .. ")")
    end
  end
  if fx.death then
    if opt("DEATH") == "apply" and opt("AUTO") ~= "no" and damageRoll(rAttacker, rWho, "999", "", "instant death") then
      table.insert(tOut, "INSTANT DEATH -> " .. sWho)
    else
      table.insert(tOut, "GM: INSTANT DEATH for " .. sWho .. " if you allow it (Options: instant death results)")
    end
  end
  if fx.note then
    table.insert(tOut, "GM: " .. fx.note)
  end
end

local function findRow(tTable, nRoll)
  for _, row in ipairs(tTable.rows) do
    if nRoll >= row[1] and nRoll <= row[2] then return row end
  end
  return nil
end

-- sKind "crit" or "fumble"
function Public.resolve(sKind, rSource, rTarget, rRoll, sForceTable, nForceRoll)
  local sTable = sForceTable or GAME.pickTable(sKind, rSource, rTarget, rRoll)
  if not sTable then return end
  local tTable = KrakenKritsData.TABLES[sTable]
  if not tTable then
    chat("[KRAKEN KRIT] No table " .. tostring(sTable) .. ".", true)
    return
  end
  local nRoll = tonumber(nForceRoll) or math.random(1, tTable.die)
  local row = findRow(tTable, nRoll)
  if not row then return end
  local tOut = {}
  for _, fx in ipairs(row[5] or {}) do
    applyFx(fx, rSource, (sKind == "fumble" and not fx.who) and rSource or rTarget, tOut)
  end
  local sTag = (sKind == "fumble") and "[KRAKEN FUMBLE]" or "[KRAKEN CRITICAL]"
  local sText = (row[4] ~= "" and row[4] ~= row[3]) and (" " .. row[4]) or ""
  local sLine = string.format("%s %s: %s d%d = %d: %s.%s", sTag, actorName(rSource), tTable.name, tTable.die, nRoll, row[3], sText)
  if #tOut > 0 then sLine = sLine .. "\r[APPLIED] " .. table.concat(tOut, "; ") end
  chat(sLine, OptionsManager.isOption(GAME.pfx .. "SHOW", "gm"))
end

local function actorPath(rActor)
  return rActor and (ActorManager.getCTNodeName(rActor) ~= "" and ActorManager.getCTNodeName(rActor)
    or ActorManager.getCreatureNodeName(rActor)) or ""
end

-- The ruleset's attack result. sResult: "crit", "fumble", "hit", "miss".
-- Attacks resolve on the machine that rolled them; the host does the rest.
function Public.onAttackResult(rSource, rTarget, rRoll, sResult)
  if not rSource or (sResult ~= "crit" and sResult ~= "fumble") then return end
  if not Session.IsHost then
    Comm.deliverOOBMessage({ type = OOB_RESOLVE, sResult = sResult, sSource = actorPath(rSource),
      sTarget = actorPath(rTarget), sDesc = rRoll and rRoll.sDesc or "", sRange = rRoll and rRoll.sRange or "",
      sRollType = rRoll and rRoll.sType or "" }, "")
    return
  end
  if (rRoll and rRoll.sType == "critconfirm") and sResult ~= "crit" then return end
  if not ActorManager.isPC(rSource) and opt("NPC") == "no" then return end
  if sResult == "crit" and chance(opt("CRIT")) then
    Public.resolve("crit", rSource, rTarget, rRoll)
  elseif sResult == "fumble" and chance(opt("FUMBLE")) then
    Public.resolve("fumble", rSource, rTarget, rRoll)
  end
end

---------------------------------------------------------------------------
-- Next damage roll: maximum, extra die, multiplier (runs where the dice roll)
---------------------------------------------------------------------------
local function findMark(rSource)
  local nodeCT = rSource and ActorManager.getCTNode(rSource)
  if not nodeCT then return nil end
  for _, nodeEffect in ipairs(DB.getChildList(nodeCT, "effects")) do
    local sLabel = DB.getValue(nodeEffect, "label", "")
    if sLabel == MARK_MAX or sLabel == MARK_DIE or sLabel == MARK_MIN or sLabel == MARK_DBL or sLabel:sub(1, #MARK_X) == MARK_X then
      return nodeEffect, sLabel
    end
  end
  return nil
end

local function dieSides(d)
  local s = (type(d) == "table") and (d.type or "") or tostring(d or "")
  return tonumber(s:match("d(%d+)")) or 0, s:sub(1, 1) == "-"
end

function Public.adjustDamageRoll(rSource, rRoll)
  -- the table's own extra and self damage rolls never use the marker
  if (rRoll.sDesc or ""):find("Kraken Krit:", 1, true) then return end
  local nodeEffect, sLabel = findMark(rSource)
  if not nodeEffect then return end
  if sLabel == MARK_MAX then
    for _, d in ipairs(rRoll.aDice or {}) do
      local n, bNeg = dieSides(d)
      if type(d) == "table" and n > 0 and not bNeg then d.result = n; d.value = n end
    end
    rRoll.sDesc = (rRoll.sDesc or "") .. " [KRAKEN KRIT: MAX]"
  elseif sLabel == MARK_MIN then
    for _, d in ipairs(rRoll.aDice or {}) do
      local n, bNeg = dieSides(d)
      if type(d) == "table" and n > 0 and not bNeg then d.result = 1; d.value = 1 end
    end
    rRoll.sDesc = (rRoll.sDesc or "") .. " [KRAKEN FUMBLE: MIN]"
  elseif sLabel == MARK_DBL then
    local tAdd = {}
    for _, d in ipairs(rRoll.aDice or {}) do
      local n, bNeg = dieSides(d)
      if type(d) == "table" and n > 0 and not bNeg then
        local r = math.random(1, n)
        table.insert(tAdd, { type = "d" .. n, result = r, value = r })
      end
    end
    for _, d in ipairs(tAdd) do table.insert(rRoll.aDice, d) end
    rRoll.nMod = (rRoll.nMod or 0) * 2
    rRoll.sDesc = (rRoll.sDesc or "") .. " [KRAKEN KRIT: DOUBLE]"
  elseif sLabel == MARK_DIE then
    local first = (rRoll.aDice or {})[1]
    local n = dieSides(first)
    if n > 0 then
      local r = math.random(1, n)
      table.insert(rRoll.aDice, { type = "d" .. n, result = r, value = r })
      rRoll.sDesc = (rRoll.sDesc or "") .. " [KRAKEN KRIT: +1d" .. n .. "]"
    end
  else
    local nX = tonumber(sLabel:sub(#MARK_X + 1)) or 2
    for _, d in ipairs(rRoll.aDice or {}) do
      local n, bNeg = dieSides(d)
      if type(d) == "table" and n > 0 and not bNeg then d.result = n * nX; d.value = n * nX end
    end
    rRoll.nMod = (rRoll.nMod or 0) * nX
    rRoll.sDesc = (rRoll.sDesc or "") .. " [KRAKEN KRIT: MAX x" .. nX .. "]"
  end
  -- used up: the host removes the marker (players cannot write the tracker)
  if Session.IsHost then
    DB.deleteNode(nodeEffect)
  else
    Comm.deliverOOBMessage({ type = OOB_MARK, sPath = DB.getPath(nodeEffect) }, "")
  end
end

local function handleResolve(msgOOB)
  if not Session.IsHost then return end
  local rSource = ActorManager.resolveActor(msgOOB.sSource)
  local rTarget = (msgOOB.sTarget or "") ~= "" and ActorManager.resolveActor(msgOOB.sTarget) or nil
  Public.onAttackResult(rSource, rTarget, { sDesc = msgOOB.sDesc, sRange = msgOOB.sRange, sType = msgOOB.sRollType }, msgOOB.sResult)
end

local function handleMarkUsed(msgOOB)
  if Session.IsHost and msgOOB.sPath then
    local node = DB.findNode(msgOOB.sPath)
    if node then DB.deleteNode(node) end
  end
end

local _fOrigPostRoll
local function onDamagePostRoll(rSource, rRoll)
  Public.adjustDamageRoll(rSource, rRoll)
  if _fOrigPostRoll then _fOrigPostRoll(rSource, rRoll) end
end

---------------------------------------------------------------------------
-- Options and commands
---------------------------------------------------------------------------
local function registerOptions()
  local function choice(sKey, sBaseVal, sBaseLabel, sValues, sLabels, sDefault)
    OptionsManager.registerOptionData({
      sKey = GAME.pfx .. sKey, sGroupRes = "option_header_krakenkrits",
      tCustom = { baseval = sBaseVal, baselabelres = sBaseLabel, values = sValues, labelsres = sLabels, default = sDefault },
    })
  end
  local tTables = GAME.tableChoices
  if tTables then
    choice("MODE", tTables.base, tTables.baselabel, tTables.values, tTables.labels, tTables.default)
  end
  choice("CRIT", "off", "option_val_off", "always|half|third", "option_val_kkf_always|option_val_kkf_half|option_val_kkf_third", GAME.defaultCrit or "always")
  choice("FUMBLE", "off", "option_val_off", "always|half|third", "option_val_kkf_always|option_val_kkf_half|option_val_kkf_third", GAME.defaultFumble or "third")
  choice("AUTO", "yes", "option_val_kkf_auto", "no", "option_val_kkf_chatonly", "yes")
  choice("NPC", "yes", "option_val_kkf_everyone", "no", "option_val_kkf_pconly", "yes")
  choice("SHOW", "all", "option_val_kkf_everyone_sees", "gm", "option_val_kkf_gm_sees", "all")
  if GAME.hasDeath then
    choice("DEATH", "gm", "option_val_kkf_death_gm", "apply", "option_val_kkf_death_apply", "gm")
  end
end

local function handleSlash(_, sParams)
  local sCmd, sRest = (sParams or ""):match("^(%S*)%s*(.-)$")
  sCmd = (sCmd or ""):lower()
  if sCmd == "crit" or sCmd == "fumble" then
    -- /krakenkrits crit [table]: test roll for the first tracker entry vs the second
    local tCT = CombatManager.getCombatantNodes()
    local rA, rB
    for _, node in pairs(tCT) do
      if not rA then rA = ActorManager.resolveActor(node) elseif not rB then rB = ActorManager.resolveActor(node) end
    end
    Public.resolve(sCmd, rA, rB, { sDesc = sRest ~= "" and ("[ATTACK (M)] " .. sRest) or "[ATTACK (M)] Longsword" }, nil)
  elseif sCmd == "tables" then
    local t = {}
    for k, v in pairs(KrakenKritsData.TABLES) do table.insert(t, v.name or k) end
    table.sort(t)
    Comm.addChatMessage({ text = "[" .. GAME.tag .. "] Tables: " .. table.concat(t, ", ") })
  else
    Comm.addChatMessage({ text = "[" .. GAME.tag .. "] Settings: Options > Kraken Krits & Fumbles. /krakenkrits crit [weapon] | fumble [weapon] | tables" })
  end
end

function Public.getGame() return GAME end

function onInit()
  GAME = KrakenKritsData.GAME
  for k, fn in pairs(Public) do KrakenKrits[k] = fn end
  registerOptions()
  OOBManager.registerOOBMsgHandler(OOB_MARK, handleMarkUsed)
  OOBManager.registerOOBMsgHandler(OOB_RESOLVE, handleResolve)
  _fOrigPostRoll = ActionsManager.getPostRollHandler("damage")
  ActionsManager.registerPostRollHandler("damage", onDamagePostRoll)
  if GAME.hook then GAME.hook() end
  if Session.IsHost then
    Comm.registerSlashHandler("krakenkrits", handleSlash, "crit [weapon]|fumble [weapon]|tables")
  end
end

function onTabletopInit()
  local bridge = AgentBridge or ClaudeBridge
  if Session.IsHost and bridge and bridge.registerPackage then
    bridge.registerPackage("KrakenKrits", KrakenKrits)
    bridge.registerPackage("KrakenKritsData", KrakenKritsData)
  end
end
