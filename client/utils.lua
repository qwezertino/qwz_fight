---@class CombatUtils
---@field private animDict string
---@field private currentAnim table
local CombatUtils = {}

local sharedConfig = require 'config.shared'
local clientConfig = require 'config.client'

local PlayerPedId = PlayerPedId
local RequestAnimDict = RequestAnimDict
local HasAnimDictLoaded = HasAnimDictLoaded
local TaskPlayAnim = TaskPlayAnim
local ClearPedTasks = ClearPedTasks
local IsEntityPlayingAnim = IsEntityPlayingAnim
local GetEntityCoords = GetEntityCoords
local GetEntityHeading = GetEntityHeading
local SetEntityHeading = SetEntityHeading

CombatUtils.loadedDicts = {}
CombatUtils.currentAnim = nil

---@param dict string
---@return boolean
function CombatUtils.LoadAnimDict(dict)
    if CombatUtils.loadedDicts[dict] then
        return true
    end

    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 5000 do
            Wait(10)
            timeout = timeout + 10
        end

        if HasAnimDictLoaded(dict) then
            CombatUtils.loadedDicts[dict] = true
            if clientConfig.client.debug then
                lib.print.info(('[CombatUtils] Loaded animation dict: %s'):format(dict))
            end
            return true
        else
            lib.print.error(('[CombatUtils] Failed to load animation dict: %s'):format(dict))
            return false
        end
    end

    CombatUtils.loadedDicts[dict] = true
    return true
end

---@param ped number
---@param animData table
---@param blendIn? number
---@param blendOut? number
---@return boolean
function CombatUtils.PlayAnimation(ped, animData, blendIn, blendOut)
    if not animData or not animData.name then
        lib.print.error('[CombatUtils] Invalid animation data')
        return false
    end

    local dict = animData.dict or sharedConfig.animations.dict

    if not CombatUtils.LoadAnimDict(dict) then
        return false
    end

    local flag = animData.flag or 1
    blendIn = blendIn or 8.0
    blendOut = blendOut or 8.0
    local duration = animData.duration or -1

    TaskPlayAnim(ped, dict, animData.name, blendIn, blendOut, duration, flag, 0, false, false, false)

    CombatUtils.currentAnim = {
        dict = dict,
        name = animData.name,
        loop = animData.loop or false,
        startTime = GetGameTimer()
    }

    if clientConfig.client.debug then
        lib.print.info(('[CombatUtils] Playing animation: %s -> %s'):format(dict, animData.name))
    end

    return true
end

---@param ped number
---@param fadeOut? boolean
function CombatUtils.StopAnimation(ped, fadeOut)
    if fadeOut then
        ClearPedTasks(ped)
    else
        ClearPedTasks(ped)
    end
    CombatUtils.currentAnim = nil
end

---@param ped number
---@param dict? string
---@param anim? string
---@return boolean
function CombatUtils.IsPlayingAnim(ped, dict, anim)
    if dict and anim then
        return IsEntityPlayingAnim(ped, dict, anim, 3)
    end

    if CombatUtils.currentAnim then
        return IsEntityPlayingAnim(ped, CombatUtils.currentAnim.dict, CombatUtils.currentAnim.name, 3)
    end

    return false
end

---@return table
function CombatUtils.GetRandomAttack()
    local attacks = sharedConfig.animations.attacks
    if #attacks == 0 then
        return nil
    end

    local randomIndex = math.random(1, #attacks)
    return attacks[randomIndex]
end

---@param soundName string
---@param soundSet? string
function CombatUtils.PlaySound(soundName, soundSet)
    if not clientConfig.client.sounds.enabled then
        return
    end

    soundSet = soundSet or 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    PlaySoundFrontend(-1, soundName, soundSet, true)
end

---@param message string
---@param type? string
---@param duration? number
function CombatUtils.ShowNotification(message, type, duration)
    if not clientConfig.client.notifications.enabled then
        return
    end

    lib.notify({
        title = 'Combat System',
        description = message,
        type = type or 'inform',
        position = clientConfig.client.notifications.position,
        duration = duration or clientConfig.client.notifications.duration
    })
end

---@param effectName string
---@param duration? number
function CombatUtils.PlayScreenEffect(effectName, duration)
    if not effectName or effectName == false then return end

    StartScreenEffect(effectName, duration or 1000, false)

    if duration then
        SetTimeout(duration, function()
            StopScreenEffect(effectName)
        end)
    end
end

---@param ped number
---@param smoothness? number
function CombatUtils.RotatePlayerWithCamera(ped, smoothness)
    smoothness = smoothness or clientConfig.client.camera.smoothness

    local camRot = GetGameplayCamRot(0)
    local currentHeading = GetEntityHeading(ped)
    local targetHeading = camRot.z

    local angleDiff = targetHeading - currentHeading
    if angleDiff > 180 then
        angleDiff = angleDiff - 360
    elseif angleDiff < -180 then
        angleDiff = angleDiff + 360
    end

    local newHeading = currentHeading + (angleDiff * smoothness)
    SetEntityHeading(ped, newHeading)
end

---@param controls table
function CombatUtils.DisableControls(controls)
    for _, control in ipairs(controls) do
        DisableControlAction(0, control, true)
    end
end

--- Check if control is just pressed once (works with disabled controls)
---@param control number
---@return boolean
function CombatUtils.IsControlJustPressed(control)
    local justPressed = IsDisabledControlJustPressed(0, control)
    if justPressed and clientConfig.client.debug then
        lib.print.info(('[CombatUtils] Disabled control just pressed: %d'):format(control))
    end
    return justPressed
end

--- Check if control is being held (works with disabled controls)
---@param control number
---@return boolean
function CombatUtils.IsControlPressed(control)
    local pressed = IsDisabledControlPressed(0, control)
    if pressed and clientConfig.client.debug then
        lib.print.info(('[CombatUtils] Disabled control pressed: %d'):format(control))
    end
    return pressed
end

--- Check if control was just released (works with disabled controls)
---@param control number
---@return boolean
function CombatUtils.IsControlJustReleased(control)
    local justReleased = IsDisabledControlJustReleased(0, control)
    if justReleased and clientConfig.client.debug then
        lib.print.info(('[CombatUtils] Disabled control just released: %d'):format(control))
    end
    return justReleased
end

function CombatUtils.Init()
    local dictsToLoad = {
        sharedConfig.animations.dict,
        'r9@sword@atk@root@one',
        'r9@sword@dodge@root@one',
        'r9@sword@hitreact@root@one'
    }

    CreateThread(function()
        for _, dict in ipairs(dictsToLoad) do
            CombatUtils.LoadAnimDict(dict)
        end

        if clientConfig.client.debug then
            lib.print.info('[CombatUtils] Initialization complete')
        end
    end)
end

function CombatUtils.Cleanup()
    for dict, _ in pairs(CombatUtils.loadedDicts) do
        RemoveAnimDict(dict)
    end
    CombatUtils.loadedDicts = {}
    CombatUtils.currentAnim = nil

    if clientConfig.client.debug then
        lib.print.info('[CombatUtils] Cleanup complete')
    end
end

return CombatUtils
