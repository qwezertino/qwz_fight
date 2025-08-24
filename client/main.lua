local config = require 'config.client'
local sharedConfig = require 'config.shared'
local CombatUtils = require 'client.utils'

---@class CombatSystem
local CombatSystem = {
    inCombat = false,
    currentMovement = nil,
    isAttacking = false,
    lastAttackTime = 0,
    movementKeys = {},
    combatThread = nil,
    cameraThread = nil,
    lastLmbState = false,
    lastRmbState = false,
}

local PlayerPedId = PlayerPedId
local GetGameTimer = GetGameTimer
local Wait = Wait

function CombatSystem.Init()
    CombatUtils.Init()
    CombatSystem.SetupKeybinds()

    if config.client.ui.showInstructions then
        CombatUtils.ShowNotification(
            'Press F6 for enter fight mode',
            'inform',
            5000
        )
    end

    lib.print.info('[CombatSystem] Combat system initialized')
end

function CombatSystem.SetupKeybinds()
    lib.addKeybind({
        name = 'combat_toggle',
        description = 'Toggle fight mode',
        defaultKey = 'F6',
        onPressed = function()
            CombatSystem.ToggleCombatMode()
        end
    })

    lib.addKeybind({
        name = 'combat_exit',
        description = 'Exit fight mode',
        defaultKey = 'ESC',
        onPressed = function()
            if CombatSystem.inCombat then
                CombatSystem.ExitCombatMode()
            end
        end
    })
end

function CombatSystem.ToggleCombatMode()
    if CombatSystem.inCombat then
        CombatSystem.ExitCombatMode()
    else
        CombatSystem.EnterCombatMode()
    end
end

function CombatSystem.EnterCombatMode()
    if CombatSystem.inCombat then
        if config.client.debug then
            lib.print.warn('[CombatSystem] Already in combat mode')
        end
        return
    end

    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        CombatUtils.ShowNotification('Cannot enter combat mode in vehicle', 'error')
        return
    end

    if IsPedDeadOrDying(ped, false) then
        if config.client.debug then
            lib.print.warn('[CombatSystem] Cannot enter combat mode - player is dead/dying')
        end
        return
    end

    CombatSystem.inCombat = true

    if config.client.debug then
        lib.print.info('[CombatSystem] Entering combat mode...')
        lib.print.info(('[CombatSystem] Control IDs: W=%d, A=%d, S=%d, D=%d'):format(
            sharedConfig.controls.forward,
            sharedConfig.controls.left,
            sharedConfig.controls.backward,
            sharedConfig.controls.right
        ))
    end

    CombatUtils.PlayAnimation(ped, sharedConfig.animations.holsterOn)

    SetTimeout(1000, function()
        if CombatSystem.inCombat then
            CombatUtils.PlayAnimation(ped, sharedConfig.animations.idle)
            if config.client.debug then
                lib.print.info('[CombatSystem] Switched to idle stance')
            end
        end
    end)

    CombatUtils.PlaySound(config.client.sounds.combatEnter)
    CombatUtils.PlayScreenEffect(config.client.effects.combatEnter, 500)

    CombatUtils.ShowNotification('Combat mode activated', 'success')

    CombatSystem.StartCombatThreads()

    TriggerServerEvent('qwz_fight:enterCombat')

    lib.print.info('[CombatSystem] Entered combat mode')
end

function CombatSystem.ExitCombatMode()
    if not CombatSystem.inCombat then return end

    local ped = PlayerPedId()

    CombatSystem.inCombat = false

    CombatSystem.StopCombatThreads()

    CombatSystem.currentMovement = nil
    CombatSystem.isAttacking = false
    CombatSystem.movementKeys = {}
    CombatSystem.lastLmbState = false
    CombatSystem.lastRmbState = false

    CombatUtils.PlayAnimation(ped, sharedConfig.animations.holsterOff)

    SetTimeout(1000, function()
        CombatUtils.StopAnimation(ped, true)
    end)

    CombatUtils.PlaySound(config.client.sounds.combatExit)
    CombatUtils.PlayScreenEffect(config.client.effects.combatExit, 500)

    CombatUtils.ShowNotification('Combat mode deactivated', 'inform')

    TriggerServerEvent('qwz_fight:exitCombat')

    lib.print.info('[CombatSystem] Exited combat mode')
end

function CombatSystem.StartCombatThreads()
    CombatSystem.combatThread = CreateThread(function()
        if config.client.debug then
            lib.print.info('[CombatSystem] Combat thread started')
        end

        while CombatSystem.inCombat do
            local ped = PlayerPedId()

            CombatUtils.DisableControls(sharedConfig.combat.disableControls)

            CombatSystem.HandleMovement(ped)
            -- CombatSystem.HandleAttacks(ped)
            CombatSystem.HandleDodges(ped)
            CombatSystem.HandleMouseInput(ped)

            if IsDisabledControlJustPressed(0, 200) then -- ESC key
                CombatSystem.ExitCombatMode()
                break
            end

            Wait(config.client.performance.movementUpdateRate)
        end

        if config.client.debug then
            lib.print.info('[CombatSystem] Combat thread stopped')
        end
    end)

    CombatSystem.cameraThread = CreateThread(function()
        while CombatSystem.inCombat do
            local ped = PlayerPedId()
            CombatUtils.RotatePlayerWithCamera(ped, config.client.camera.smoothness)
            Wait(config.client.performance.cameraUpdateRate)
        end
    end)
end

function CombatSystem.StopCombatThreads()
    if CombatSystem.combatThread then
        CombatSystem.combatThread = nil
    end
    if CombatSystem.cameraThread then
        CombatSystem.cameraThread = nil
    end
end

--- Handle movement input and animations
---@param ped number
function CombatSystem.HandleMovement(ped)
    if CombatSystem.isAttacking then
        if config.client.debug then
            local controls = sharedConfig.controls
            if CombatUtils.IsControlPressed(controls.forward) or
               CombatUtils.IsControlPressed(controls.backward) or
               CombatUtils.IsControlPressed(controls.left) or
               CombatUtils.IsControlPressed(controls.right) then
                lib.print.warn('[Movement Debug] Movement blocked - attack in progress')
            end
        end
        return
    end

    local controls = sharedConfig.controls
    local movement = sharedConfig.animations.movement
    local newMovement = nil

    local pressedKeys = {}

    if CombatUtils.IsControlPressed(controls.forward) then
        pressedKeys.forward = true
        newMovement = 'forward'
        if config.client.debug then
            lib.print.info('[CombatSystem] Forward key pressed (W)')
        end
    end

    if CombatUtils.IsControlPressed(controls.backward) then
        pressedKeys.backward = true
        newMovement = 'backward'
        if config.client.debug then
            lib.print.info('[CombatSystem] Backward key pressed (S)')
        end
    end

    if CombatUtils.IsControlPressed(controls.left) then
        pressedKeys.left = true
        newMovement = 'left'
        if config.client.debug then
            lib.print.info('[CombatSystem] Left key pressed (A)')
        end
    end

    if CombatUtils.IsControlPressed(controls.right) then
        pressedKeys.right = true
        newMovement = 'right'
        if config.client.debug then
            lib.print.info('[CombatSystem] Right key pressed (D)')
        end
    end

    local hasMovement = false
    for direction, pressed in pairs(pressedKeys) do
        if pressed then
            hasMovement = true
            newMovement = direction
        end
    end

    if config.client.debug and hasMovement then
        lib.print.info(('[CombatSystem] Movement detected: %s, Current: %s'):format(newMovement or 'nil', CombatSystem.currentMovement or 'nil'))
    end

    if hasMovement and newMovement ~= CombatSystem.currentMovement then
        if movement[newMovement] then
            if config.client.debug then
                lib.print.info(('[CombatSystem] Playing movement animation: %s'):format(newMovement))
            end
            CombatUtils.PlayAnimation(ped, movement[newMovement])
            CombatSystem.currentMovement = newMovement

            local coords = GetEntityCoords(ped)
            TriggerServerEvent('qwz_fight:syncAnimation', movement[newMovement], coords)
        else
            if config.client.debug then
                lib.print.error(('[CombatSystem] Movement animation not found: %s'):format(newMovement))
            end
        end
    elseif not hasMovement and CombatSystem.currentMovement then
        if not CombatSystem.isAttacking then
            if config.client.debug then
                lib.print.info('[CombatSystem] Returning to idle stance')
            end
            CombatUtils.PlayAnimation(ped, sharedConfig.animations.idle)
            CombatSystem.currentMovement = nil
        else
            if config.client.debug then
                lib.print.warn('[Movement Debug] Idle blocked - attack in progress')
            end
        end
    end
end

--- Handle attack input
---@param ped number
function CombatSystem.HandleAttacks(ped)
    if config.client.debug then
        local controls = sharedConfig.controls
        if CombatUtils.IsControlJustPressed(controls.attack) then
            lib.print.info('[Attack Debug] Legacy LMB handler triggered (disabled)')
        end
        if CombatUtils.IsControlJustPressed(controls.heavyAttack) then
            lib.print.info('[Attack Debug] Legacy RMB handler triggered (disabled)')
        end
    end
end

--- Perform attack
---@param ped number
---@param isHeavy boolean
function CombatSystem.PerformAttack(ped, isHeavy)
    if CombatSystem.isAttacking then return end

    CombatSystem.isAttacking = true
    CombatSystem.lastAttackTime = GetGameTimer()

    local attackAnim = CombatUtils.GetRandomAttack()
    if not attackAnim then
        CombatSystem.isAttacking = false
        return
    end

        CombatUtils.PlayAnimation(ped, attackAnim)

    local soundName = isHeavy and config.client.sounds.heavyAttack or config.client.sounds.attack
    CombatUtils.PlaySound(soundName)

    -- CombatUtils.PlayScreenEffect(config.client.effects.attackEffect, 200)

    local coords = GetEntityCoords(ped)
    TriggerServerEvent('qwz_fight:syncAnimation', attackAnim, coords)
    TriggerServerEvent('qwz_fight:performAttack', nil, {
        type = isHeavy and 'heavy' or 'normal',
        animation = attackAnim
    })

    SetTimeout(attackAnim.duration or 1000, function()
        if CombatSystem.inCombat then
            CombatUtils.PlayAnimation(ped, sharedConfig.animations.idle)
        end
        CombatSystem.isAttacking = false
    end)
end

--- Handle mouse input separately
---@param ped number
function CombatSystem.HandleMouseInput(ped)
    if config.client.debug then
        local lmbPressed = IsControlPressed(0, 24)
        local rmbPressed = IsControlPressed(0, 25)
        local lmbDisabledPressed = IsDisabledControlPressed(0, 24)
        local rmbDisabledPressed = IsDisabledControlPressed(0, 25)
        local lmbJustPressed = IsControlJustPressed(0, 24)
        local rmbJustPressed = IsControlJustPressed(0, 25)
        local lmbDisabledJustPressed = IsDisabledControlJustPressed(0, 24)
        local rmbDisabledJustPressed = IsDisabledControlJustPressed(0, 25)

        if lmbPressed or rmbPressed or lmbDisabledPressed or rmbDisabledPressed or
           lmbJustPressed or rmbJustPressed or lmbDisabledJustPressed or rmbDisabledJustPressed then
            lib.print.info(('[Mouse Debug] LMB: pressed=%s, disabled=%s, just=%s, disJust=%s | RMB: pressed=%s, disabled=%s, just=%s, disJust=%s'):format(
                tostring(lmbPressed), tostring(lmbDisabledPressed), tostring(lmbJustPressed), tostring(lmbDisabledJustPressed),
                tostring(rmbPressed), tostring(rmbDisabledPressed), tostring(rmbJustPressed), tostring(rmbDisabledJustPressed)
            ))
        end
    end

    if CombatSystem.isAttacking then
        if config.client.debug then
            lib.print.warn('[Mouse Debug] Attack blocked - already attacking')
        end
        return
    end

    local currentTime = GetGameTimer()
    local timeSinceLastAttack = currentTime - CombatSystem.lastAttackTime
    if timeSinceLastAttack < sharedConfig.combat.animationTimeout.attack then
        if config.client.debug then
            lib.print.warn(('[Mouse Debug] Attack blocked - timeout (time since last: %d, required: %d)'):format(
                timeSinceLastAttack, sharedConfig.combat.animationTimeout.attack
            ))
        end
        return
    end

    local lmbTriggered = IsControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 24) or
                        IsControlJustPressed(0, 237) or IsDisabledControlJustPressed(0, 237)
    local rmbTriggered = IsControlJustPressed(0, 25) or IsDisabledControlJustPressed(0, 25) or
                        IsControlJustPressed(0, 238) or IsDisabledControlJustPressed(0, 238)

    if not CombatSystem.lastLmbState and (IsControlPressed(0, 24) or IsDisabledControlPressed(0, 24)) then
        if config.client.debug then
            lib.print.info('[Mouse Debug] LMB state change detected (pressed)')
        end
        lmbTriggered = true
    end
    if not CombatSystem.lastRmbState and (IsControlPressed(0, 25) or IsDisabledControlPressed(0, 25)) then
        if config.client.debug then
            lib.print.info('[Mouse Debug] RMB state change detected (pressed)')
        end
        rmbTriggered = true
    end

    CombatSystem.lastLmbState = IsControlPressed(0, 24) or IsDisabledControlPressed(0, 24)
    CombatSystem.lastRmbState = IsControlPressed(0, 25) or IsDisabledControlPressed(0, 25)

    if lmbTriggered then
        if config.client.debug then
            lib.print.info('[Mouse Debug] LMB attack triggered!')
        end
        CombatSystem.PerformAttack(ped, false)
    end

    if rmbTriggered then
        if config.client.debug then
            lib.print.info('[Mouse Debug] RMB attack triggered!')
        end
        CombatSystem.PerformAttack(ped, true)
    end
end

--- Handle dodge input
---@param ped number
function CombatSystem.HandleDodges(ped)
    if CombatSystem.isAttacking then
        if config.client.debug then
            local controls = sharedConfig.controls
            if CombatUtils.IsControlJustPressed(controls.dodge) then
                lib.print.warn('[Dodge Debug] Dodge blocked - attack in progress')
            end
        end
        return
    end

    local controls = sharedConfig.controls

    if not CombatUtils.IsControlJustPressed(controls.dodge) then
        return
    end

    local dodges = sharedConfig.animations.dodges
        local dodgeDirection = 'backward'

    if CombatSystem.currentMovement == 'left' then
        dodgeDirection = 'left'
    elseif CombatSystem.currentMovement == 'right' then
        dodgeDirection = 'right'
    end

    local dodgeAnim = dodges[dodgeDirection]
    if dodgeAnim then
        CombatUtils.PlayAnimation(ped, dodgeAnim)
        CombatUtils.PlaySound(config.client.sounds.dodge)

        local coords = GetEntityCoords(ped)
        TriggerServerEvent('qwz_fight:syncAnimation', dodgeAnim, coords)

        SetTimeout(dodgeAnim.duration or 600, function()
            if CombatSystem.inCombat then
                CombatUtils.PlayAnimation(ped, sharedConfig.animations.idle)
            end
        end)
    end
end

-- Network events
RegisterNetEvent('qwz_fight:receiveAnimationSync', function(playerId, animData, coords)
    if config.client.debug then
        lib.print.info(('[CombatSystem] Received animation sync from player %d'):format(playerId))
    end
end)

RegisterNetEvent('qwz_fight:forceExitCombat', function()
    CombatSystem.ExitCombatMode()
    CombatUtils.ShowNotification('Forced exit from combat mode', 'error')
end)

-- Handle resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if CombatSystem.inCombat then
            CombatSystem.ExitCombatMode()
        end
        CombatUtils.Cleanup()
    end
end)

-- Test command for debugging controls
RegisterCommand('testcontrols', function()
    if not CombatSystem.inCombat then
        lib.print.warn('[CombatSystem] Not in combat mode')
        return
    end

    CreateThread(function()
        lib.print.info('[CombatSystem] Testing controls for 10 seconds...')
        local startTime = GetGameTimer()

        while GetGameTimer() - startTime < 10000 do
            local controls = sharedConfig.controls

            if IsDisabledControlPressed(0, controls.forward) then
                lib.print.info('[CombatSystem] W (forward) pressed - Control ID: ' .. controls.forward .. ' (DISABLED)')
            end
            if IsDisabledControlPressed(0, controls.left) then
                lib.print.info('[CombatSystem] A (left) pressed - Control ID: ' .. controls.left .. ' (DISABLED)')
            end
            if IsDisabledControlPressed(0, controls.backward) then
                lib.print.info('[CombatSystem] S (backward) pressed - Control ID: ' .. controls.backward .. ' (DISABLED)')
            end
            if IsDisabledControlPressed(0, controls.right) then
                lib.print.info('[CombatSystem] D (right) pressed - Control ID: ' .. controls.right .. ' (DISABLED)')
            end
            if IsDisabledControlPressed(0, controls.attack) then
                lib.print.info('[CombatSystem] LMB (attack) pressed - Control ID: ' .. controls.attack .. ' (DISABLED)')
            end
            if IsDisabledControlPressed(0, controls.heavyAttack) then
                lib.print.info('[CombatSystem] RMB (heavy attack) pressed - Control ID: ' .. controls.heavyAttack .. ' (DISABLED)')
            end

            if IsDisabledControlPressed(0, 237) then -- Alternative LMB
                lib.print.info('[CombatSystem] Alternative LMB (237) pressed')
            end
            if IsDisabledControlPressed(0, 238) then -- Alternative RMB
                lib.print.info('[CombatSystem] Alternative RMB (238) pressed')
            end
            if IsDisabledControlPressed(0, controls.dodge) then
                lib.print.info('[CombatSystem] SPACE (dodge) pressed - Control ID: ' .. controls.dodge .. ' (DISABLED)')
            end

            Wait(100)
        end

        lib.print.info('[CombatSystem] Control testing finished')
    end)
end, false)

-- Mouse-specific test command
RegisterCommand('testmouse', function()
    if not CombatSystem.inCombat then
        lib.print.warn('[Mouse Test] Not in combat mode')
        return
    end

    CreateThread(function()
        lib.print.info('[Mouse Test] Testing mouse for 15 seconds (detailed logging)...')
        local startTime = GetGameTimer()

        while GetGameTimer() - startTime < 15000 do
            local methods = {
                {id = 24, name = "LMB_Normal", func = function() return IsControlPressed(0, 24) end},
                {id = 24, name = "LMB_JustPressed", func = function() return IsControlJustPressed(0, 24) end},
                {id = 24, name = "LMB_Disabled", func = function() return IsDisabledControlPressed(0, 24) end},
                {id = 24, name = "LMB_DisabledJust", func = function() return IsDisabledControlJustPressed(0, 24) end},
                {id = 25, name = "RMB_Normal", func = function() return IsControlPressed(0, 25) end},
                {id = 25, name = "RMB_JustPressed", func = function() return IsControlJustPressed(0, 25) end},
                {id = 25, name = "RMB_Disabled", func = function() return IsDisabledControlPressed(0, 25) end},
                {id = 25, name = "RMB_DisabledJust", func = function() return IsDisabledControlJustPressed(0, 25) end},
                {id = 237, name = "ALT_LMB_Normal", func = function() return IsControlPressed(0, 237) end},
                {id = 237, name = "ALT_LMB_Disabled", func = function() return IsDisabledControlPressed(0, 237) end},
                {id = 238, name = "ALT_RMB_Normal", func = function() return IsControlPressed(0, 238) end},
                {id = 238, name = "ALT_RMB_Disabled", func = function() return IsDisabledControlPressed(0, 238) end},
            }

            for _, method in ipairs(methods) do
                if method.func() then
                    lib.print.info(('[Mouse Test] %s (ID: %d) = TRUE'):format(method.name, method.id))
                end
            end

            Wait(50)
        end

        lib.print.info('[Mouse Test] Mouse testing finished')
    end)
end, false)

-- Test attack blocking command
RegisterCommand('testattackblock', function()
    if not CombatSystem.inCombat then
        lib.print.warn('[Attack Block Test] Not in combat mode')
        return
    end

    lib.print.info('[Attack Block Test] Starting test - try moving during attacks!')
    lib.print.info('[Attack Block Test] Press LMB to attack, then immediately press WASD')
    lib.print.info('[Attack Block Test] Movement should be blocked during attack animation')
end, false)

-- Initialize when resource starts
CreateThread(function()
    Wait(1000)
    CombatSystem.Init()
end)

