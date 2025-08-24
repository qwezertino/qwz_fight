---@class CombatServer
local CombatServer = {}

local sharedConfig = require 'config.shared'

CombatServer.activeCombatSessions = {}

---@param playerId number
RegisterNetEvent('qwz_fight:enterCombat', function(playerId)
    local src = source or playerId

    if not src then return end

    CombatServer.activeCombatSessions[src] = {
        startTime = os.time(),
        playerPed = GetPlayerPed(src),
        inCombat = true
    }

    TriggerClientEvent('qwz_fight:playerEnteredCombat', -1, src)

    if sharedConfig.combat.enabled then
        lib.print.info(('[CombatServer] Player %d entered combat mode'):format(src))
    end
end)

---@param playerId number
RegisterNetEvent('qwz_fight:exitCombat', function(playerId)
    local src = source or playerId

    if not src then return end

    if CombatServer.activeCombatSessions[src] then
        local session = CombatServer.activeCombatSessions[src]
        local duration = os.time() - session.startTime

        CombatServer.activeCombatSessions[src] = nil

        TriggerClientEvent('qwz_fight:playerExitedCombat', -1, src)

        lib.print.info(('[CombatServer] Player %d exited combat mode (duration: %d seconds)'):format(src, duration))
    end
end)

---@param animData table
---@param coords table
RegisterNetEvent('qwz_fight:syncAnimation', function(animData, coords)
    local src = source

    if not src or not CombatServer.activeCombatSessions[src] then
        return
    end

    TriggerClientEvent('qwz_fight:receiveAnimationSync', -1, src, animData, coords)
end)

---@param targetId number
---@param attackData table
RegisterNetEvent('qwz_fight:performAttack', function(targetId, attackData)
    local src = source

    if not src or not CombatServer.activeCombatSessions[src] then
        return
    end

    if targetId and CombatServer.activeCombatSessions[targetId] then
        TriggerClientEvent('qwz_fight:receiveAttack', targetId, src, attackData)
    end

    TriggerClientEvent('qwz_fight:attackPerformed', -1, src, targetId, attackData)
end)

---@param playerId number
---@return boolean
function CombatServer.IsPlayerInCombat(playerId)
    return CombatServer.activeCombatSessions[playerId] ~= nil
end

---@return table
function CombatServer.GetPlayersInCombat()
    local players = {}
    for playerId, session in pairs(CombatServer.activeCombatSessions) do
        table.insert(players, {
            id = playerId,
            startTime = session.startTime,
            duration = os.time() - session.startTime
        })
    end
    return players
end

---@param playerId number
function CombatServer.ForceExitCombat(playerId)
    if CombatServer.activeCombatSessions[playerId] then
        CombatServer.activeCombatSessions[playerId] = nil
        TriggerClientEvent('qwz_fight:forceExitCombat', playerId)
        TriggerClientEvent('qwz_fight:playerExitedCombat', -1, playerId)
    end
end

AddEventHandler('playerDropped', function(reason)
    local src = source
    if CombatServer.activeCombatSessions[src] then
        CombatServer.activeCombatSessions[src] = nil
        TriggerClientEvent('qwz_fight:playerExitedCombat', -1, src)
    end
end)

lib.addCommand('combatinfo', {
    help = 'Показать информацию о боевых сессиях',
    restricted = 'group.admin'
}, function(source)
    local players = CombatServer.GetPlayersInCombat()

    if #players == 0 then
        TriggerClientEvent('chat:addMessage', source, {
            args = {'[Combat System]', 'Нет активных боевых сессий'}
        })
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        args = {'[Combat System]', ('Активных боевых сессий: %d'):format(#players)}
    })

    for _, player in ipairs(players) do
        local playerName = GetPlayerName(player.id)
        TriggerClientEvent('chat:addMessage', source, {
            args = {'[Combat System]', ('Игрок: %s (ID: %d) - %d сек.'):format(playerName, player.id, player.duration)}
        })
    end
end)

lib.addCommand('forceexitcombat', {
    help = 'Принудительно вывести игрока из боевого режима',
    params = {
        { name = 'id', type = 'playerId', help = 'ID игрока' }
    },
    restricted = 'group.admin'
}, function(source, args)
    local targetId = args.id

    if not CombatServer.IsPlayerInCombat(targetId) then
        TriggerClientEvent('chat:addMessage', source, {
            args = {'[Combat System]', 'Игрок не находится в боевом режиме'}
        })
        return
    end

    CombatServer.ForceExitCombat(targetId)

    local playerName = GetPlayerName(targetId)
    TriggerClientEvent('chat:addMessage', source, {
        args = {'[Combat System]', ('Игрок %s принудительно выведен из боевого режима'):format(playerName)}
    })
end)

exports('IsPlayerInCombat', CombatServer.IsPlayerInCombat)
exports('GetPlayersInCombat', CombatServer.GetPlayersInCombat)
exports('ForceExitCombat', CombatServer.ForceExitCombat)

lib.print.info('[CombatServer] Combat system server initialized')

return CombatServer
