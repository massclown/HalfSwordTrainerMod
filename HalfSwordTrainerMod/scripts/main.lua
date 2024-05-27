-- Half Sword Trainer Mod v0.10 by massclown
-- https://github.com/massclown/HalfSwordTrainerMod
-- Requirements: UE4SS 2.5.2 (or newer) and a Blueprint mod HSTM_UI (see repo)
------------------------------------------------------------------------------
local mod_version = "0.10"
------------------------------------------------------------------------------
local maf = require 'maf'
local UEHelpers = require("UEHelpers")
local GetGameplayStatics = UEHelpers.GetGameplayStatics
local GetWorldContextObject = UEHelpers.GetWorldContextObject
local GetKismetSystemLibrary = UEHelpers.GetKismetSystemLibrary
local GetKismetMathLibrary = UEHelpers.GetKismetMathLibrary
------------------------------------------------------------------------------
-- Saved copies of player stats before buffs
local savedRSR = 0
local savedMP = 0
local savedRegenRate = 0
-- Our buffed stats that we set
local maxRSR = 1000
local maxMP = 200
local maxRegenRate = 10000
------------------------------------------------------------------------------
local GameSpeedDelta = 0.1
local DefaultGameSpeed = 1.0
local DefaultSloMoGameSpeed = 0.5
local SloMoGameSpeed = DefaultSloMoGameSpeed
------------------------------------------------------------------------------
-- Variables tracking things we change or want to observe and display in HUD
local AutoSpawnEnabled = true          -- this is the default, UI is 'HSTM_Flag_AutospawnNPCs'
local AutoSpawnChangeRequested = false -- this handles the restoring of scores and levels when resuming NPC autospawn and level progression
local SpawnFrozenNPCs = false          -- we can change it, UI flag is 'HSTM_Flag_SpawnFrozenNPCs'

local SlowMotionEnabled = false
local Frozen = false
local SuperStrength = false

-- Those are copies of player's (or level's) object properties
local OGWillie = nil
local OGlevel = 0
local OGscore = 0
local GameSpeed = 1.0
local Invulnerable = false
local level = 0
local PlayerScore = 0
local PlayerTeam = 0
local PlayerHealth = 0
local PlayerConsciousness = 0
local PlayerTonus = 0

-- Cached from the spawn UI (HSTM_Slider_WeaponSize)
local WeaponScaleMultiplier = 1.0
local WeaponScaleX = true
local WeaponScaleY = true
local WeaponScaleZ = true
local WeaponScaleBladeOnly = false
local ScaleObjects = false

-- Player body detailed health data
local HH = 0  -- 'Head Health'
local NH = 0  -- 'Neck Health'
local BH = 0  -- 'Body Health'
local ARH = 0 -- 'Arm_R Health'
local ALH = 0 -- 'Arm_L Health'
local LRH = 0 -- 'Leg_R Health'
local LLH = 0 -- 'Leg_L Health'

-- Player joint detailed health data
local HJH = 0  -- "Head Joint Health"
local TJH = 0  -- "Torso Joint Health"
local HRJH = 0 -- "Hand R Joint Health"
local ARJH = 0 -- "Arm R Joint Health"
local SRJH = 0 -- "Shoulder R Joint Health"
local HLJH = 0 -- "Hand L Joint Health"
local ALJH = 0 -- "Arm L Joint Health"
local SLJH = 0 -- "Shoulder L Joint Health"
local TRJH = 0 -- "Thigh R Joint Health"
local LRJH = 0 -- "Leg R Joint Health"
local FRJH = 0 -- "Foot R Joint Health"
local TLJH = 0 -- "Thigh L Joint Health"
local LLJH = 0 -- "Leg L Joint Health"
local FLJH = 0 -- "Foot L Joint Health"

-- Chosen NPC team from the UI dropdown
local NPCTeam = 0

-- Various UI-related stuff
local ModUIHUDVisible = true
local ModUISpawnVisible = true
local CrosshairVisible = true
local ModUIHUDUpdateLoopEnabled = true
-- everything that we spawned
local spawned_things = {}

-- The actors from the hook
--local intercepted_actors = {}

-- Flag to distinguish between normal client restarts and resurrection
local ResurrectionWasRequested = false

-- Item/NPC tables for the spawn menus in the UI
local all_armor = {}
local all_weapons = {}
local all_characters = {}
local all_objects = {}

local custom_loadout = {}

local NullRotation = { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }
local NullLocation = { X = 0.0, Y = 0.0, Z = 0.0 }
local DefaultScale1x = { X = 1.0, Y = 1.0, Z = 1.0 }
------------------------------------------------------------------------------
function Log(Message)
    print("[HalfSwordTrainerMod] " .. Message)
end

function Logf(...)
    print("[HalfSwordTrainerMod] " .. string.format(...))
end

function ErrLog(Message)
    print("[HalfSwordTrainerMod] [ERROR] " .. Message)
    print(debug.traceback() .. "\n")
end

function ErrLogf(...)
    print("[HalfSwordTrainerMod] [ERROR] " .. string.format(...))
    print(debug.traceback() .. "\n")
end

function string:contains(sub)
    return self:find(sub, 1, true) ~= nil
end

function string:starts_with(start)
    return self:sub(1, #start) == start
end

function string:ends_with(ending)
    return ending == "" or self:sub(- #ending) == ending
end

------------------------------------------------------------------------------
function table.shallow_copy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

------------------------------------------------------------------------------
-- Conversion between UE4SS representation of UE structures and maf
------------------------------------------------------------------------------
function vec2maf(vector)
    return maf.vec3(vector.X, vector.Y, vector.Z)
end

function maf2vec(vector)
    return { X = vector.x, Y = vector.y, Z = vector.z }
end

function maf2rot(vector)
    return { Pitch = vector.x, Yaw = vector.y, Roll = vector.z }
end

-- quaternion to pitch+yaw+roll (yaw-pitch-roll order, ZYX, yaw inverted)
function mafrotator2rot(quat)
    local x, y, z, w = quat:unpack()
    local threshold = 0.499999
    local test = x * z - w * y
    local yaw, pitch, roll

    yaw = math.deg(math.atan(2.0 * (w * z + x * y), 1.0 - 2.0 * (y * y + z * z)))

    if math.abs(test) > threshold then
        local sign = test > 0 and 1 or -1
        pitch = sign * 90.0
        roll = sign * yaw - math.deg(2.0 * math.atan(x, w))
        return { Pitch = pitch, Yaw = yaw, Roll = roll }
    else
        pitch = math.asin(2.0 * (test))
        roll = math.atan(-2.0 * (w * x + y * z), 1.0 - 2.0 * (x * x + y * y))
        return { Pitch = math.deg(pitch), Yaw = yaw, Roll = math.deg(roll) }
    end
end

-- UE pitch+yaw+roll to quaternion (yaw-pitch-roll order, ZYX, yaw inverted)
function rot2mafrotator(vector)
    local p = math.rad(vector.Pitch)
    local y = math.rad(vector.Yaw)
    local r = math.rad(vector.Roll)

    local SP, SY, SR;
    local CP, CY, CR;

    SP = math.sin(p / 2)
    SY = math.sin(y / 2)
    SR = math.sin(r / 2)

    CP = math.cos(p / 2)
    CY = math.cos(y / 2)
    CR = math.cos(r / 2)

    local X = CR * SP * SY - SR * CP * CY
    local Y = -CR * SP * CY - SR * CP * SY
    local Z = CR * CP * SY - SR * SP * CY
    local W = CR * CP * CY + SR * SP * SY
    return maf.quat(X, Y, Z, W)
end

function LogMafVec(mafVector)
    Logf("{X=%f, Y=%f, Z=%f}\n", mafVector.x, mafVector.y, mafVector.z)
end

function LogUEVec(UEVec)
    Logf("{X=%f, Y=%f, Z=%f}\n", UEVec.X, UEVec.Y, UEVec.Z)
end

function UEVecToStr(UEVec)
    return string.format("{X=%f, Y=%f, Z=%f}", UEVec.X, UEVec.Y, UEVec.Z)
end

function MafVecToStr(mafVector)
    return string.format("{X=%f, Y=%f, Z=%f}", mafVector.x, mafVector.y, mafVector.z)
end

------------------------------------------------------------------------------
-- The caching code logic is taken from TheLich at nexusmods (Grounded QoL mod)
local cache = {}
cache.objects = {}
cache.names = {
    --    ["engine"] = { "Engine", false },
    --    ["kismet"] = { "/Script/Engine.Default__KismetSystemLibrary", true },
    ["map"] = { "Abyss_Map_Open_C", false },
    ["worldsettings"] = { "WorldSettings", false },
    ["ui_hud"] = { "HSTM_UI_HUD_Widget_C", false },
    ["ui_spawn"] = { "HSTM_UI_Spawn_Widget_C", false },
    ["ui_game_hud"] = { "UI_HUD_C", false }
}

cache.mt = {}
cache.mt.__index = function(obj, key)
    local newObj = obj.objects[key]
    if newObj == nil or not newObj:IsValid() then
        local className, isStatic = table.unpack(obj.names[key])
        if isStatic then
            newObj = StaticFindObject(className)
        else
            newObj = FindFirstOf(className)
        end
        if newObj == nil or not newObj:IsValid() then
            ErrLogf("Failed to find and cache object [%s][%s][%s]\n", key, className, not newObj and "nil" or "invalid")
            newObj = nil
        end
        obj.objects[key] = newObj
    end
    return newObj
end
setmetatable(cache, cache.mt)
------------------------------------------------------------------------------
function ClearCachedObjects()
    -- TODO
    cache.objects = {}
end

------------------------------------------------------------------------------
function ValidateCachedObjects()
    local map = cache.map
    local ui_hud = cache.ui_hud
    local ui_spawn = cache.ui_spawn
    -- The HUD is not loaded at the time of first check, so skipping
    -- local ui_game_hud = cache.ui_game_hud
    local worldsettings = cache.worldsettings

    if not map or not map:IsValid() then
        ErrLogf("Map not found! (%s)\n", not map and "nil" or "invalid")
        return false
    end
    if not ui_hud or not ui_hud:IsValid() then
        ErrLogf("UI HUD Widget not found! (%s)\n", not map and "nil" or "invalid")
        return false
    end
    if not ui_spawn or not ui_spawn:IsValid() then
        ErrLogf("UI Spawn Widget not found! (%s)\n", not map and "nil" or "invalid")
        return false
    end
    -- The HUD is not loaded at the time of first check, so skipping
    -- if not ui_game_hud or not ui_game_hud:IsValid() then
    --     ErrLogf("Game UI Widget not found! (%s)\n", not map and "nil" or "invalid")
    --     return false
    -- end
    if not worldsettings or not worldsettings:IsValid() then
        ErrLogf("UE WorldSettings not found! (%s)\n", not map and "nil" or "invalid")
        return false
    end
    return true
end

------------------------------------------------------------------------------
-- This is copied from UEHelpers but filtering better, for PlayerController
--- Returns the first valid PlayerController that is currently controlled by a player.
---@return APlayerController
function myGetPlayerController()
    local PlayerControllers = FindAllOf("PlayerController")
    if not PlayerControllers then
        ErrLog("No PlayerControllers exist\n")
        return nil
        --error("No PlayerController found\n")
    end
    local PlayerController = nil
    for Index, Controller in pairs(PlayerControllers) do
        if Controller.Pawn:IsValid() and Controller.Pawn:IsPlayerControlled() then
            PlayerController = Controller
            break
        else
            Log("[WARNING] Not valid or not player controlled\n")
        end
    end
    if PlayerController and PlayerController:IsValid() then
        return PlayerController
    else
        -- TODO: not sure if this is fatal or not at the moment. Error handling needs improvement
        -- error("No PlayerController found\n")
        Log("[WARNING] Returning default PlayerController from the map\n")
        local player = cache.map['Player Willie']
        if player and player:IsValid() then
            return player['Controller']
        else
            return nil
        end
    end
end

------------------------------------------------------------------------------
-- Timestamp of last invocation of InitMyMod()
local lastInitTimestamp = -1
local globalRestartCount = 0
-- This function gets added to the game restart hook below.
-- Somehow the hook gets triggered twice, so we try to have a time lock to avoid double-calling the init function,
-- but we still have to call it once if the user restarts soon, hence the miminum timeout of that 1 second.
-- So don't restart faster than once every two seconds, or this will break too.
function InitMyMod()
    -- If the restart is triggered by a resurrection, exit
    if ResurrectionWasRequested then
        ResurrectionWasRequested = false
        return
    end
    -- Otherwise, continue with the normal restart
    local curInitTimestamp = os.clock()
    local delta = curInitTimestamp - lastInitTimestamp
    if lastInitTimestamp == -1 or (delta > 1) then
        globalRestartCount = globalRestartCount + 1
        Log("Client Restart hook triggered\n")

        ClearCachedObjects()

        if not ValidateCachedObjects() then
            ErrLog("Objects not found, exiting\n")
            return
        end

        -- We retrieve the version variable from the Blueprint just to confirm that we are on the same version
        if cache.ui_hud['UI_Version'] then
            local hud_ui_version = cache.ui_hud['UI_Version']:ToString()
            if mod_version ~= hud_ui_version then
                ErrLogf("HSTM UI version mismatch: mod version [%s], HUD version [%s]\n", mod_version, hud_ui_version)
                return
            end
        end

        if cache.ui_spawn['UI_Version'] then
            local spawn_ui_version = cache.ui_spawn['UI_Version']:ToString()
            if mod_version ~= spawn_ui_version then
                ErrLogf("HSTM UI version mismatch: mod version [%s], HUD version [%s]\n", mod_version, spawn_ui_version)
                return
            end
        end

        LoadCustomLoadout()

        PopulateArmorComboBox()
        PopulateWeaponComboBox()
        PopulateNPCComboBox()
        PopulateNPCTeamComboBox()
        PopulateObjectComboBox()

        -- if intercepted_actors then
        --     intercepted_actors = {}
        -- end

        if spawned_things then
            spawned_things = {}
        end

        Frozen = false
        SlowMotionEnabled = false
        SuperStrength = false

        -- Attempt to intercept auto-spawned enemies and do something about that
        -- Don't use that, the below method works OK
        -- Somehow if we hook this, it makes the game spawn MORE enemies (faster)
        -- Needs further investigation
        --
        -- RegisterHook("/Game/Maps/Abyss_Map_Open.Abyss_Map_Open_C:Spawn NPC", function(self, SpawnTransform, WeaponLoadout, ReturnValue)
        --     local class = self:get():GetFullName()
        --     local transform = SpawnTransform:get():GetFullName()
        --     local loadout = WeaponLoadout:get()
        --     local retval = ReturnValue
        --     Logf("Spawn NPC hooked: self [%s], SpawnTransform [%s], WeaponLoadout [%s], ReturnValue [%s],\n", class, transform, loadout, retval)
        -- end)
        --

        -- This starts a thread that updates the HUD in background.
        -- It only exits if we retrn true from the lambda, which we don't
        --
        -- TODO: handle resurrection after NPC possession: the loop must still reflect the current player!
        -- TODO: we should probably cache the PlayerController at time of loop creation to detect and restart stale loops?
        --
        local myRestartCounter = globalRestartCount

        -- This loop attempts to take care of NPC autospawn in a "better" way
        -- This is still horrible but appears to work and prevent boss fights from spawning
        -- BUG when you turn autospawn back on after disabling it, a boss fight will spawn for some reason
        LoopAsync(1000, function()
            if myRestartCounter ~= globalRestartCount then
                -- This is a loop initiated from a past restart hook, exit it
                Logf("Exiting NPC Autospawn prevention update loop leftover from restart #%d\n", myRestartCounter)
                return true
            end
            if AutoSpawnEnabled ~= cache.ui_spawn['HSTM_Flag_AutospawnNPCs'] then
                AutoSpawnChangeRequested = true
            end
            AutoSpawnEnabled = cache.ui_spawn['HSTM_Flag_AutospawnNPCs']
            if AutoSpawnEnabled == true then
                if AutoSpawnChangeRequested then
                    ExecuteInGameThread(function()
                        cache.map['Score'] = OGscore
                        cache.map['Level'] = OGlevel
                        cache.map['Easy Spawn'] = true
                    end)
                    AutoSpawnChangeRequested = false
                else
                    OGlevel = cache.map['Level']
                    OGscore = cache.map['Score']
                end
            else
                cache.map['Level'] = -1
                cache.map['Score'] = 9999
                level = -1
                cache.map['Easy Spawn'] = false
                AutoSpawnChangeRequested = false
            end
            return false
        end)

        if ModUIHUDUpdateLoopEnabled then
            LoopAsync(250, function()
                if myRestartCounter ~= globalRestartCount then
                    -- This is a loop initiated from a past restart hook, exit it
                    Logf("Exiting HUD update loop leftover from restart #%d\n", myRestartCounter)
                    return true
                end
                if not ValidateCachedObjects() then
                    ErrLog("Objects not found, skipping loop\n")
                    return false
                end
                if ModUIHUDVisible then
                    HUD_UpdatePlayerStats()
                end
                return false
            end)
            Log("HUD update loop started\n")
        else
            Log("HUD update loop disabled\n")
        end
    else
        Logf("Client Restart hook skipped, too early %.3f seconds passed\n", delta)
    end
    lastInitTimestamp = curInitTimestamp
end

------------------------------------------------------------------------------
-- A very long function taking all the various stats we want from the player object
-- and writing them into the textblocks of the UI Widget that we use as a mod's HUD
-- using the bound variables of the mod's HSTM_UI blueprint, because:
-- * TextBlock does not seem to have a SetText() method we could use,
-- * and for SetText() we also need FText for an argument, the constructor of which is not in the stable UE4SS 2.5.2
--   and not yet merged into the master branch either (https://github.com/UE4SS-RE/RE-UE4SS/pull/301)
-- On the other hand, the stable UE4SS 2.5.2 crashes less with Half Sword, so all this is justified.
-- The mod is also compatible with UE4SS 3.x.x, which should have FText() now, but we use the old implementation anyway
------------------------------------------------------------------------------
function HUD_UpdatePlayerStats()
    local player = GetActivePlayer()
    -- Attempting to just skip the loop if the player wasn't found for some reasons
    if not player then
        ErrLogf("Player not found, skipping\n")
        return
    end
    PlayerTeam                              = player['Team Int']
    PlayerHealth                            = player['Health']
    Invulnerable                            = player['Invulnerable']
    cache.ui_hud['HUD_Player_Team_Value']   = PlayerTeam
    cache.ui_hud['HUD_HP_Value']            = PlayerHealth
    cache.ui_hud['HUD_Invuln_Value']        = Invulnerable
    cache.ui_hud['HUD_SuperStrength_Value'] = SuperStrength
    --
    PlayerScore                             = cache.map['Score']
    cache.ui_hud['HUD_Score_Value']         = PlayerScore

    PlayerConsciousness                     = player['Consciousness']
    cache.ui_hud['HUD_Cons_Value']          = PlayerConsciousness

    PlayerTonus                             = player['All Body Tonus']
    cache.ui_hud['HUD_Tonus_Value']         = PlayerTonus
    --
    GameSpeed                               = cache.worldsettings['TimeDilation']
    cache.ui_hud['HUD_GameSpeed_Value']     = GameSpeed
    cache.ui_hud['HUD_NPCsFrozen_Value']    = Frozen
    cache.ui_hud['HUD_SlowMotion_Value']    = SlowMotionEnabled
    --
    HH                                      = player['Head Health']
    NH                                      = player['Neck Health']
    BH                                      = player['Body Health']
    ARH                                     = player['Arm_R Health']
    ALH                                     = player['Arm_L Health']
    LRH                                     = player['Leg_R Health']
    LLH                                     = player['Leg_L Health']
    --
    cache.ui_hud['HUD_HH']                  = math.floor(HH)
    cache.ui_hud['HUD_NH']                  = math.floor(NH)
    cache.ui_hud['HUD_BH']                  = math.floor(BH)
    cache.ui_hud['HUD_ARH']                 = math.floor(ARH)
    cache.ui_hud['HUD_ALH']                 = math.floor(ALH)
    cache.ui_hud['HUD_LRH']                 = math.floor(LRH)
    cache.ui_hud['HUD_LLH']                 = math.floor(LLH)
    --
    -- Joint health logic is commented for now, as the Joint health HUD is disabled since mod v0.6
    --
    -- HJH                                     = player['Head Joint Health']
    -- TJH                                     = player['Torso Joint Health']
    -- HRJH                                    = player['Hand R Joint Health']
    -- ARJH                                    = player['Arm R Joint Health']
    -- SRJH                                    = player['Shoulder R Joint Health']
    -- HLJH                                    = player['Hand L Joint Health']
    -- ALJH                                    = player['Arm L Joint Health']
    -- SLJH                                    = player['Shoulder L Joint Health']
    -- TRJH                                    = player['Thigh R Joint Health']
    -- LRJH                                    = player['Leg R Joint Health']
    -- FRJH                                    = player['Foot R Joint Health']
    -- TLJH                                    = player['Thigh L Joint Health']
    -- LLJH                                    = player['Leg L Joint Health']
    -- FLJH                                    = player['Foot L Joint Health']
    -- --
    -- cache.ui_hud['HUD_HJH']                 = math.floor(HJH)
    -- cache.ui_hud['HUD_TJH']                 = math.floor(TJH)
    -- cache.ui_hud['HUD_HRJH']                = math.floor(HRJH)
    -- cache.ui_hud['HUD_ARJH']                = math.floor(ARJH)
    -- cache.ui_hud['HUD_SRJH']                = math.floor(SRJH)
    -- cache.ui_hud['HUD_HLJH']                = math.floor(HLJH)
    -- cache.ui_hud['HUD_ALJH']                = math.floor(ALJH)
    -- cache.ui_hud['HUD_SLJH']                = math.floor(SLJH)
    -- cache.ui_hud['HUD_TRJH']                = math.floor(TRJH)
    -- cache.ui_hud['HUD_LRJH']                = math.floor(LRJH)
    -- cache.ui_hud['HUD_FRJH']                = math.floor(FRJH)
    -- cache.ui_hud['HUD_TLJH']                = math.floor(TLJH)
    -- cache.ui_hud['HUD_LLJH']                = math.floor(LLJH)
    -- cache.ui_hud['HUD_FLJH']                = math.floor(FLJH)

    --

    HUD_CacheLevel()
    HUD_CacheProjectile()
end

------------------------------------------------------------------------------
function ToggleSuperStrength()
    -- TODO handle possession
    local player = GetActivePlayer()
    SuperStrength = not SuperStrength
    if SuperStrength then
        savedRSR = player['Running Speed Rate']
        savedMP = player['Muscle Power']
        player['Running Speed Rate'] = maxRSR
        player['Muscle Power'] = maxMP
    else
        player['Running Speed Rate'] = savedRSR
        player['Muscle Power'] = savedMP
    end
    Log("SuperStrength = " .. tostring(SuperStrength) .. "\n")
    if ModUIHUDVisible then
        cache.ui_hud['HUD_SuperStrength_Value'] = SuperStrength
    end
end

------------------------------------------------------------------------------
-- We also increase regeneration rate together with invulnerability
-- to prevent the player from dying from past wounds
function ToggleInvulnerability()
    -- TODO handle possession
    local player = GetActivePlayer()
    Invulnerable = player['Invulnerable']
    Invulnerable = not Invulnerable
    if Invulnerable then
        savedRegenRate = player['Regen Rate']
        player['Regen Rate'] = maxRegenRate
        -- Attempt to undo some of the damage done before to the player and the body model
        -- Doesn't seem work.
        player['Reset Sustained Damage']()
        player['Reset Blood Bleed']()
        player['Reset Dismemberment']()
    else
        player['Regen Rate'] = savedRegenRate
    end
    player['Invulnerable'] = Invulnerable
    Log("Invulnerable = " .. tostring(Invulnerable) .. "\n")
    if ModUIHUDVisible then
        cache.ui_hud['HUD_Invuln_Value'] = Invulnerable
    end
end

------------------------------------------------------------------------------
local Visibility_HIDDEN = 2
local Visibility_VISIBLE = 0
------------------------------------------------------------------------------
-- 99 is the z-order set in UI HUD blueprint in UE5 editor
-- 100 is the z-order set in UI Spawn blueprint in UE5 editor
-- should be high enough to be on top of everything
function ToggleModUI()
    if ModUIHUDVisible then
        cache.ui_hud:SetVisibility(Visibility_HIDDEN)
        ModUIHUDVisible = false
    else
        cache.ui_hud:SetVisibility(Visibility_VISIBLE)
        ModUIHUDVisible = true
        -- If the HUD update loop has crashed, try to update the HUD in the worst case
        HUD_UpdatePlayerStats()
    end
    if ModUISpawnVisible then
        cache.ui_spawn:SetVisibility(Visibility_HIDDEN)
        ModUISpawnVisible = false
    else
        cache.ui_spawn:SetVisibility(Visibility_VISIBLE)
        ModUISpawnVisible = true
    end
end

------------------------------------------------------------------------------
-- Just some high-tier loadout I like, all the best armor, a huge shield, long polearm and two one-armed swords.
-- The table structure is: class, {X=scale,Y=scale,Z=scale}, scale_blade_only}
local default_loadout = {
    { "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Hosen_Arming_C.BP_Armor_Hosen_Arming_C_C",                               DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Shoes_A.BP_Armor_Shoes_A_C",                                             DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Doublet_Arming.BP_Armor_Doublet_Arming_C",                               DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Cuisse_B.BP_Armor_Cuisse_B_C",                                           DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Cuirass_C.BP_Armor_Cuirass_C_C",                                         DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Vambrace_A.BP_Armor_Vambrace_A_C",                                       DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Bevor.BP_Armor_Bevor_C",                                                 DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Pauldron_A.BP_Armor_Pauldron_A_C",                                       DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Sallet_Solid_C_002.BP_Armor_Sallet_Solid_C_002_C",                       DefaultScale1x, false },
    { "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Gauntlets.BP_Armor_Gauntlets_C",                                         DefaultScale1x, false },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Pavise1.Pavise1_C",                                                           DefaultScale1x, false },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_BastardSword.ModularWeaponBP_BastardSword_C",                 DefaultScale1x, false },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_BastardSword.ModularWeaponBP_BastardSword_C",                 DefaultScale1x, false },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tiers/ModularWeaponBP_Polearm_High_Tier.ModularWeaponBP_Polearm_High_Tier_C", DefaultScale1x, false },
}

-- Read custom loadout from a text file containing class names
-- Format:
-- /foo/bar/baz/class
-- (2.0)/foo/bar/baz/class
-- (1.0,2.0,3.0)/foo/bar/baz/class
-- [BladeOnly](2.0)/foo/bar/baz/class
-- [BladeOnly](1.0,2.0,3.0)/foo/bar/baz/class

function LoadCustomLoadout()
    local file = io.open("Mods\\HalfSwordTrainerMod\\data\\custom_loadout.txt", "r");
    if file ~= nil then
        if custom_loadout then custom_loadout = {} end
        Logf("Loading custom loadout...\n")
        for line in file:lines() do
            if not line:starts_with('[BAD]') then
                local _, _, scale, class = string.find(line, "%(([%d%.]+)%)([/%w_%.]+)$")
                local blade = line:starts_with('[BladeOnly]')
                if scale and class then
                    local mult = tonumber(scale)
                    table.insert(custom_loadout, { class, { X = mult, Y = mult, Z = mult }, blade })
                else
                    local _, _, scaleX, scaleY, scaleZ, class = string.find(line,
                        "%(%s*([%d%.]+),%s*([%d%.]+),%s*([%d%.]+)%s*%)([/%w_%.]+)$")
                    if scaleX and scaleY and scaleZ and class then
                        table.insert(custom_loadout,
                            { class, { X = tonumber(scaleX), Y = tonumber(scaleY), Z = tonumber(scaleZ) }, blade })
                    else
                        table.insert(custom_loadout, { line, DefaultScale1x, false })
                    end
                end
            end
        end
        Logf("Custom loadout loaded, %d items\n", #custom_loadout)
    end
end

------------------------------------------------------------------------------
-- The function spawns any of the loaded assets by their class name and customizes a few parameters
-- A lot of them are dirty hacks and should probably be moved elsewhere
-- We are handling some special cases inside which is not optimal
-- Also as we often need the return value, this whole function has to be executed in a game thread
function SpawnActorByClassPath(FullClassPath, SpawnLocation, SpawnRotation, SpawnScale, BladeScaleOnly, AlsoScaleObjects)
    -- TODO Load missing assets!
    -- WARN Only spawns loaded assets now!
    if FullClassPath == nil or FullClassPath == "" then
        ErrLogf("Invalid ClassPath [%s] for actor, cannot spawn!\n", tostring(FullClassPath))
        return
    end
    local DefaultLocation = { X = 100.0, Y = 100.0, Z = 100.0 }
    local CurrentLocation = SpawnLocation == nil and DefaultLocation or SpawnLocation
    local DefaultScaleMultiplier = DefaultScale1x
    local SpawnScaleMultiplier = SpawnScale == nil and DefaultScaleMultiplier or SpawnScale
    local DefaultRotation = NullRotation
    local CurrentRotation = SpawnRotation == nil and DefaultRotation or SpawnRotation
    local ActorClass = StaticFindObject(FullClassPath)
    if ActorClass == nil or not ActorClass:IsValid() then error("[ERROR] ActorClass is not valid") end
    local isNPC = FullClassPath:contains("/Game/Character/Blueprints/")
    local World = myGetPlayerController():GetWorld()
    if World == nil or not World:IsValid() then error("[ERROR] World is not valid") end
    local Actor = World:SpawnActor(ActorClass, CurrentLocation, CurrentRotation)
    if Actor == nil or not Actor:IsValid() then
        Logf("[ERROR] Actor for \"%s\" is not valid\n", FullClassPath)
        return nil
    else
        if spawned_things then
            -- We try to guess if this actor was an NPC
            table.insert(spawned_things,
                { Object = Actor, IsCharacter = isNPC })
        end
        if isNPC then
            -- Try to freeze the NPC if we have spawn frozen flag set
            if SpawnFrozenNPCs then
                Actor['CustomTimeDilation'] = 0.0
            end
            -- Try to apply the chosen NPC Team
            Actor['Team Int'] = NPCTeam
        else
            -- We don't really care if this is a weapon, but we try anyway
            -- Some actors already have non-default scale, so we don't override that
            -- Yes, it is not a good idea to compare floats like this, but we do 0.1 increments so this is fine (c)
            if SpawnScale ~= nil then
                if BladeScaleOnly then
                    if FullClassPath:contains("/Built_Weapons/ModularWeaponBP") then
                        -- Actually not sure which scale we should set, relative or world?
                        Actor['head']:SetRelativeScale3D(SpawnScale)
                    end
                else
                    if AlsoScaleObjects then
                        if FullClassPath:contains("_Prop_Furniture") then
                            Actor['SM_Prop']:SetRelativeScale3D(SpawnScale)
                        elseif FullClassPath:contains("Dest_Barrel") then
                            Actor['RootComponent']:SetRelativeScale3D(SpawnScale)
                        elseif FullClassPath:contains("BP_Prop_Barrel") then
                            Actor['SM_Barrel']:SetRelativeScale3D(SpawnScale)
                        end
                    end
                    Actor:SetActorScale3D(SpawnScale)
                end
            end
        end
        Logf("Spawned Actor: %s at {X=%.3f, Y=%.3f, Z=%.3f} rotation {Pitch=%.3f, Yaw=%.3f, Roll=%.3f}\n",
            Actor:GetFullName(), CurrentLocation.X, CurrentLocation.Y, CurrentLocation.Z,
            CurrentRotation.Pitch, CurrentRotation.Yaw, CurrentRotation.Roll)
        return Actor
    end
end

-- Should also undo all spawned things if called repeatedly
function UndoLastSpawn()
    if spawned_things then
        if #spawned_things > 0 then
            local actorToDespawnRecord = spawned_things[#spawned_things]
            local actorToDespawn = actorToDespawnRecord.Object
            if actorToDespawn and actorToDespawn:IsValid() then
                Logf("Despawning actor: %s\n", actorToDespawn:GetFullName())
                --                actorToDespawn:Destroy()
                actorToDespawn:K2_DestroyActor()
                -- let's remove it for now so undo can be repeated.
                -- K2_DestroyActor() is supposed to clean up things properly
                table.remove(spawned_things, #spawned_things)
            end
        end
    end
end

-- We are iterating from the end of the array to make sure Lua does not reindex the array as we are deleting items
-- We probaly could also just set them to nil but YOLO let's try to actually remove them from the array
function UndoAllPlayerSpawnedCharacters()
    if spawned_things then
        for i = #spawned_things, 1, -1 do
            local actorToDespawnRecord = spawned_things[i]
            local actorToDespawn = actorToDespawnRecord.Object
            if actorToDespawn and actorToDespawn:IsValid() and actorToDespawnRecord.IsCharacter then
                Logf("Despawning NPC actor: %s\n", actorToDespawn:GetFullName())
                actorToDespawn:K2_DestroyActor()
                -- let's remove it for now so undo can be repeated.
                -- K2_DestroyActor() is supposed to clean up things properly
                table.remove(spawned_things, i)
            end
        end
    end
end

------------------------------------------------------------------------------
-- This takes possession into account
function GetActivePlayer()
    local FirstPlayerController = myGetPlayerController()
    -- TODO maybe this is not a great idea
    if not FirstPlayerController then
        if cache.map then
            return cache.map['Player Willie']
        end
        return nil
    end
    return FirstPlayerController.Pawn
end

------------------------------------------------------------------------------
-- The location is retrieved using a less documented approach of K2_GetActorLocation()
function GetPlayerLocation()
    local FirstPlayerController = myGetPlayerController()
    if not FirstPlayerController then
        return NullLocation
    end
    local Pawn = FirstPlayerController.Pawn
    local location = Pawn:K2_GetActorLocation()
    return location
end

function GetPlayerViewRotation()
    local FirstPlayerController = myGetPlayerController()
    if not FirstPlayerController then
        return NullRotation
    end
    local rotation = FirstPlayerController['ControlRotation']
    return rotation
end

------------------------------------------------------------------------------
-- We spawn the loadout in a circle, rotating a displacement vector a bit
-- with every item, so they all fit nicely
function SpawnLoadoutAroundPlayer()
    local PlayerLocation = GetPlayerLocation()
    local DeltaLocation = maf.vec3(300.0, 0.0, 200.0)
    local rotatedDelta = DeltaLocation
    local loadout = default_loadout
    if #custom_loadout > 0 then
        loadout = custom_loadout
        Logf("Spawning custom loadout...\n")
    end
    local rotator = maf.rotation.fromAngleAxis(((math.pi * 2) / #loadout), 0.0, 0.0, 1.0)
    for index, value in ipairs(loadout) do
        local class, scale, bladescale = table.unpack(value)
        local SpawnLocation = {
            X = PlayerLocation.X + rotatedDelta.x,
            Y = PlayerLocation.Y + rotatedDelta.y,
            Z = PlayerLocation.Z + rotatedDelta.z
        }
        ExecuteWithDelay((index - 1) * 300, function()
            ExecuteInGameThread(function()
                _ = SpawnActorByClassPath(class, SpawnLocation, NullRotation, scale, bladescale)
            end)
        end)
        rotatedDelta:rotate(rotator)
    end
end

-- Try to spawn the actor(item) in front of the player
-- Get player's rotation vector and rotate our offset by its value
function SpawnActorInFrontOfPlayer(classpath, offset, lookingAtPlayer, scale, BladeOnly, AlsoScaleObjects)
    local defaultOffset = maf.vec3(300.0, 0.0, 0.0)
    local PlayerLocation = GetPlayerLocation()
    local PlayerRotation = GetPlayerViewRotation()
    local rotator = maf.rotation.fromAngleAxis(
        math.rad(PlayerRotation.Yaw),
        0.0, -- math.rad(PlayerRotation.Pitch),
        0.0, -- math.rad(PlayerRotation.Roll),
        1.0
    )
    local DeltaLocation = offset == nil and defaultOffset or maf.vec3(offset.X, offset.Y, offset.Z)
    local rotatedDelta = DeltaLocation
    rotatedDelta:rotate(rotator)
    local SpawnLocation = {
        X = PlayerLocation.X + rotatedDelta.x,
        Y = PlayerLocation.Y + rotatedDelta.y,
        Z = PlayerLocation.Z + rotatedDelta.z
    }
    local lookingAtPlayerRotation = { Yaw = 180.0 + PlayerRotation.Yaw, Pitch = 0.0, Roll = 0.0 }
    local SpawnRotation = lookingAtPlayer and lookingAtPlayerRotation or NullRotation
    local SpawnScale = scale == nil and DefaultScale1x or scale
    ExecuteInGameThread(function()
        _ = SpawnActorByClassPath(classpath, SpawnLocation, SpawnRotation, SpawnScale, BladeOnly, AlsoScaleObjects)
    end)
end

------------------------------------------------------------------------------
function HUD_SetLevel(Level)
    cache.map['Level'] = Level
    Logf("Set Level = %d\n", Level)
    if ModUIHUDVisible then
        cache.ui_hud['HUD_Level_Value'] = Level
    end
end

function HUD_CacheLevel()
    level = cache.map['Level']
    if ModUIHUDVisible then
        cache.ui_hud['HUD_Level_Value'] = level
    end
end

-- We allow the player to use only the levels that are present in the game code
-- From 0 to 6 inclusive. Level 6 removes the music, which is also convenient.
function DecreaseLevel()
    HUD_CacheLevel()
    if level > 0 then
        level = level - 1
        HUD_SetLevel(level)
    end
end

function IncreaseLevel()
    HUD_CacheLevel()
    if level < 6 then
        level = level + 1
        HUD_SetLevel(level)
    end
end

------------------------------------------------------------------------------
function HUD_SetPlayerTeam(Team)
    local player = GetActivePlayer()
    player['Team Int'] = Team
    Logf("Set Player Team = %d\n", Team)
    if ModUIHUDVisible then
        cache.ui_hud['HUD_Player_Team_Value'] = Team
    end
end

function HUD_CachePlayerTeam()
    local player = GetActivePlayer()
    local Team = player['Team Int']
    if ModUIHUDVisible then
        cache.ui_hud['HUD_Player_Team_Value'] = Team
    end
end

-- We allow the player to choose between teams 0, 1, 2
function ChangePlayerTeamDown()
    HUD_CachePlayerTeam()
    if PlayerTeam > 0 then
        PlayerTeam = PlayerTeam - 1
        HUD_SetPlayerTeam(PlayerTeam)
    end
end

function ChangePlayerTeamUp()
    HUD_CachePlayerTeam()
    if PlayerTeam < 2 then
        PlayerTeam = PlayerTeam + 1
        HUD_SetPlayerTeam(PlayerTeam)
    end
end

------------------------------------------------------------------------------
-- Killing is actually exploding head and spilling guts
-- That is resource intensive and may lead to crashes sometimes
-- Alternative killing method below, slow animation but also cool
local silentKill = false
function KillAllNPCs()
    local player = GetActivePlayer()
    if cache.ui_spawn["HSTM_Flag_KillExplode"] then
        silentKill = false
    elseif cache.ui_spawn["HSTM_Flag_KillSlow"] then
        silentKill = true
    end
    ExecuteForAllNPCs(function(NPC)
        if UEAreObjectsEqual(player, NPC) then
            -- this is a possessed NPC, don't
        else
            if silentKill then
                NPC['Health'] = -1.0
                NPC['Death']()
            else
                NPC['Explode Head']()
                NPC['Spill Guts']()
            end
        end
    end)
end

function DespawnAllNPCs()
    local player = GetActivePlayer()
    ExecuteForAllNPCs(function(NPC)
        if UEAreObjectsEqual(player, NPC) then
            -- this is a possessed NPC, don't
        else
            NPC:K2_DestroyActor()
        end
    end)
end

-- TODO figure out how to freeze the upper half of the NPC as well.
function FreezeAllNPCs()
    Frozen = not Frozen
    local player = GetActivePlayer()

    ExecuteForAllNPCs(function(NPC)
        if UEAreObjectsEqual(player, NPC) then
            -- this is a possessed NPC, don't
        else
            NPC['CustomTimeDilation'] = Frozen and 0.0 or 1.0
        end
    end)

    if ModUIHUDVisible then
        cache.ui_hud['HUD_NPCsFrozen_Value'] = Frozen
    end
end

------------------------------------------------------------------------------
-- Does not seem to actually remove the armor stats, only the meshes
function RemoveAllArmor(player)
    -- It seems that any object inherited from BP_Armor_Master_C will work here, for some reason
    local panties = StaticFindObject("/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Panties.BP_Armor_Panties_C")
    local SpawnTransform = { Rotation = { W = 0.0, X = 0.0, Y = 0.0, Z = 0.0 }, Translation = { X = 0.0, Y = 0.0, Z = 0.0 }, Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }
    -- There are 10 values in the enum, from 0 to 9
    -- 0, Helmet
    -- 1, Neck
    -- 2, Body
    -- 3, Body 2
    -- 4, Shoulders
    -- 5, Arms
    -- 6, Hands
    -- 7, Legs
    -- 8, Legs 2
    -- 9, Feet
    for i = 0, 9, 1 do
        local key = i
        local out1 = {}
        player['Remove Armor'](
            player,
            panties,
            SpawnTransform,
            out1,
            key
        )
    end
end

function RemovePlayerArmor()
    local player = GetActivePlayer()
    RemoveAllArmor(player)
end

------------------------------------------------------------------------------
function ExecuteForAllNPCs(callback)
    if cache.map['Enemy Array'] then
        local npc = cache.map['Enemy Array']
        if npc:GetArrayNum() > 0 then
            npc:ForEach(function(Index, Elem)
                if npc:IsValid() then
                    Logf("Executing for NPC [%i]: %s\n", Index - 1, Elem:get():GetFullName())
                    callback(Elem:get())
                end
            end)
        end
    end
    -- Then freeze the boss if we are in a boss arena and the boss is alive
    if cache.map['Current Boss Arena'] and cache.map['Current Boss Arena']:IsValid() then
        if cache.map['Boss Alive'] then
            local boss = cache.map['Current Boss Arena']['Boss']
            if boss:IsValid() then
                Logf("Executing for Boss: %s\n", boss:GetFullName())
                callback(boss)
            end
        end
        local npc = cache.map['Current Boss Arena']['Spawned Enemies']
        if npc and npc:GetArrayNum() > 0 then
            npc:ForEach(function(Index, Elem)
                if npc:IsValid() then
                    Logf("Executing for Boss Spawned NPC [%i]: %s\n", Index - 1, Elem:get():GetFullName())
                    callback(Elem:get())
                end
            end)
        end
    end
    if spawned_things then
        for i = #spawned_things, 1, -1 do
            local actorToProcessRecord = spawned_things[i]
            local actorToProcess = actorToProcessRecord.Object
            if actorToProcess and actorToProcess:IsValid() and actorToProcessRecord.IsCharacter then
                Logf("Executing for NPC actor: %s\n", actorToProcess:GetFullName())
                callback(actorToProcess)
            end
        end
    end
end

------------------------------------------------------------------------------
function SpawnSelectedArmor()
    local Selected_Spawn_Armor = cache.ui_spawn['Selected_Spawn_Armor']:ToString()
    --Logf("Spawning armor key [%s]\n", Selected_Spawn_Armor)
    --    if not Selected_Spawn_Armor == nil and not Selected_Spawn_Armor == "" then
    local selected_actor = all_armor[Selected_Spawn_Armor]
    Logf("Spawning armor [%s]\n", selected_actor)
    SpawnActorInFrontOfPlayer(selected_actor)
    --    end
end

function SpawnSelectedWeapon()
    local Selected_Spawn_Weapon = cache.ui_spawn['Selected_Spawn_Weapon']:ToString()
    WeaponScaleMultiplier = cache.ui_spawn['HSTM_Slider_WeaponSize']
    WeaponScaleX = cache.ui_spawn['HSTM_Flag_ScaleX']
    WeaponScaleY = cache.ui_spawn['HSTM_Flag_ScaleY']
    WeaponScaleZ = cache.ui_spawn['HSTM_Flag_ScaleZ']
    WeaponScaleBladeOnly = cache.ui_spawn['HSTM_Flag_ScaleBladeOnly']
    --Logf("Spawning weapon key [%s]\n", Selected_Spawn_Weapon)
    --    if not Selected_Spawn_Weapon == nil and not Selected_Spawn_Weapon == "" then
    local selected_actor = all_weapons[Selected_Spawn_Weapon]
    Logf("Spawning weapon [%s]\n", selected_actor)

    if WeaponScaleMultiplier ~= 1.0 then
        local scale = {
            X = WeaponScaleX and WeaponScaleMultiplier or 1.0,
            Y = WeaponScaleY and WeaponScaleMultiplier or 1.0,
            Z = WeaponScaleZ and WeaponScaleMultiplier or 1.0
        }
        SpawnActorInFrontOfPlayer(selected_actor, nil, nil, scale, WeaponScaleBladeOnly)
    else
        SpawnActorInFrontOfPlayer(selected_actor)
    end
    --    end
end

function SpawnSelectedNPC()
    -- Update the flag from the Spawn HUD
    SpawnFrozenNPCs = cache.ui_spawn['HSTM_Flag_SpawnFrozenNPCs']
    NPCTeam = tonumber(cache.ui_spawn['Selected_Spawn_NPC_Team']:ToString())
    local Selected_Spawn_NPC = cache.ui_spawn['Selected_Spawn_NPC']:ToString()
    --Logf("Spawning NPC key [%s]\n", Selected_Spawn_NPC)
    --    if not Selected_Spawn_NPC == nil and not Selected_Spawn_NPC == "" then
    local selected_actor = all_characters[Selected_Spawn_NPC]
    Logf("Spawning NPC [%s]\n", selected_actor)
    SpawnActorInFrontOfPlayer(selected_actor, { X = 800.0, Y = 0.0, Z = 50.0 }, true)
    --    end
end

function SpawnSelectedObject()
    local Selected_Spawn_Object = cache.ui_spawn['Selected_Spawn_Object']:ToString()
    WeaponScaleMultiplier = cache.ui_spawn['HSTM_Slider_WeaponSize']
    WeaponScaleX = cache.ui_spawn['HSTM_Flag_ScaleX']
    WeaponScaleY = cache.ui_spawn['HSTM_Flag_ScaleY']
    WeaponScaleZ = cache.ui_spawn['HSTM_Flag_ScaleZ']

    ScaleObjects = cache.ui_spawn['HSTM_Flag_ScaleObjects']

    --Logf("Spawning object key [%s]\n", Selected_Spawn_Object)
    --    if not Selected_Spawn_Object == nil and not Selected_Spawn_Object == "" then
    local selected_actor = all_objects[Selected_Spawn_Object]
    Logf("Spawning object [%s]\n", selected_actor)
    if WeaponScaleMultiplier ~= 1.0 then
        local scale = {
            X = WeaponScaleX and WeaponScaleMultiplier or 1.0,
            Y = WeaponScaleY and WeaponScaleMultiplier or 1.0,
            Z = WeaponScaleZ and WeaponScaleMultiplier or 1.0
        }
        SpawnActorInFrontOfPlayer(selected_actor, { X = 300.0, Y = 0.0, Z = -60.0 }, nil, scale, nil, ScaleObjects)
    else
        SpawnActorInFrontOfPlayer(selected_actor, { X = 300.0, Y = 0.0, Z = -60.0 })
    end
    --    end
end

-- Spawns the boss arena fence around the player's location
-- No bosses will spawn, only the fence. Player is the center, rotation is ignored (aligned with X/Y axes)
function SpawnBossArena()
    local PlayerLocation = GetPlayerLocation()
    local SpawnLocation = PlayerLocation
    SpawnLocation.Z = 0
    local FullClassPath = "/Game/Blueprints/Spawner/BossFight_Arena_BP.BossFight_Arena_BP_C"
    Log("Spawning Boss Arena\n")
    local arena = SpawnActorByClassPath(FullClassPath, SpawnLocation)
end

------------------------------------------------------------------------------
-- All the functions that load spawnable items ignore the ones starting with [BAD]
-- used to mark those that are not useful (not visible, etc.)
function PopulateArmorComboBox()
    local ComboBox_Armor = cache.ui_spawn['ComboBox_Armor']
    ComboBox_Armor:ClearOptions()
    local file = io.open("Mods\\HalfSwordTrainerMod\\data\\all_armor.txt", "r");
    for line in file:lines() do
        if not line:starts_with('[BAD]') then
            local fkey = ExtractHumanReadableNameShorter(line)
            all_armor[fkey] = line
            ComboBox_Armor:AddOption(fkey)
        end
    end
    ComboBox_Armor:SetSelectedIndex(0)
end

function PopulateWeaponComboBox()
    local ComboBox_Weapon = cache.ui_spawn['ComboBox_Weapon']
    ComboBox_Weapon:ClearOptions()

    local file = io.open("Mods\\HalfSwordTrainerMod\\data\\all_weapons.txt", "r");
    for line in file:lines() do
        if not line:starts_with('[BAD]') then
            local fkey = ExtractHumanReadableNameShorter(line)
            all_weapons[fkey] = line
            ComboBox_Weapon:AddOption(fkey)
        end
    end
    ComboBox_Weapon:SetSelectedIndex(0)
end

function PopulateNPCComboBox()
    local ComboBox_NPC = cache.ui_spawn['ComboBox_NPC']
    ComboBox_NPC:ClearOptions()

    local file = io.open("Mods\\HalfSwordTrainerMod\\data\\all_characters.txt", "r");
    for line in file:lines() do
        if not line:starts_with('[BAD]') then
            local fkey = ExtractHumanReadableNameShorter(line)
            all_characters[fkey] = line
            ComboBox_NPC:AddOption(fkey)
        end
    end
    ComboBox_NPC:SetSelectedIndex(0)
end

function PopulateNPCTeamComboBox()
    local ComboBox_NPC_Team = cache.ui_spawn['ComboBox_NPC_Team']
    ComboBox_NPC_Team:ClearOptions()

    for TeamIndex = 0, 2 do
        ComboBox_NPC_Team:AddOption(tostring(TeamIndex))
    end
    ComboBox_NPC_Team:SetSelectedIndex(0)
end

function PopulateObjectComboBox()
    local ComboBox_Object = cache.ui_spawn['ComboBox_Object']
    ComboBox_Object:ClearOptions()

    local file = io.open("Mods\\HalfSwordTrainerMod\\data\\all_objects.txt", "r");
    for line in file:lines() do
        if not line:starts_with('[BAD]') then
            local fkey = ExtractHumanReadableNameShorter(line)
            all_objects[fkey] = line
            ComboBox_Object:AddOption(fkey)
        end
    end
    ComboBox_Object:SetSelectedIndex(0)
end

-- The function takes the final part of the class name, but without the _C
function ExtractHumanReadableName(BPFullClassName)
    local hname = string.match(BPFullClassName, "/([%w_]+)%.[%w_]+$")
    return hname
end

-- This attempts to clean up the item name even further by removing common prefixes
function ExtractHumanReadableNameShorter(BPFullClassName)
    local hname = ExtractHumanReadableName(BPFullClassName)
    -- this is a stupid replacement, the order matters as one filter may contain the other
    local filters = {
        "BP_Weapon_Improv_",
        "BP_Weapon_Tool_",
        "ModularWeaponBP_",
        "BP_Armor_",
        "BP_Container_",
        "BM_Prop_Furniture_",
        "BP_Prop_Furniture_",
        "BP_Prop_",
    }

    for _, filter in ipairs(filters) do
        i, j = string.find(hname, filter)
        if i ~= nil then
            hname = string.sub(hname, j + 1)
        end
    end

    return hname
end

------------------------------------------------------------------------------
function ToggleCrosshair()
    local crosshair = cache.ui_game_hud['Aim']
    if crosshair and crosshair:IsValid() then
        CrosshairVisible = crosshair:GetVisibility() == 0 and true or false
        if CrosshairVisible then
            crosshair:SetVisibility(Visibility_HIDDEN)
            CrosshairVisible = false
        else
            crosshair:SetVisibility(Visibility_VISIBLE)
            CrosshairVisible = true
        end
    end
end

------------------------------------------------------------------------------
function ToggleClassicSlowMotion()
    local worldsettings = cache.worldsettings
    local player = GetActivePlayer()
    player['Slomo Timeline']['SetTimelineLength'](1.0)
    SlowMotionEnabled = not SlowMotionEnabled
    if SlowMotionEnabled then
        player['Slomo Timeline']['PlayFromStart']()
    else
        player['Slomo Timeline']['ReverseFromEnd']()
    end
    if ModUIHUDVisible then
        cache.ui_hud['HUD_SlowMotion_Value'] = SlowMotionEnabled
    end
end

function ToggleSlowMotion()
    local worldsettings = cache.worldsettings
    SlowMotionEnabled = not SlowMotionEnabled
    if SlowMotionEnabled then
        GameSpeed = SloMoGameSpeed
    else
        GameSpeed = DefaultGameSpeed
    end
    worldsettings['TimeDilation'] = GameSpeed
    if ModUIHUDVisible then
        cache.ui_hud['HUD_GameSpeed_Value']  = GameSpeed
        cache.ui_hud['HUD_SlowMotion_Value'] = SlowMotionEnabled
    end
end

-- Game goes faster
function IncreaseGameSpeed()
    -- 5x speed is already too prone to crashes
    if SloMoGameSpeed < DefaultGameSpeed * 5 then
        SloMoGameSpeed = SloMoGameSpeed + GameSpeedDelta
    end
    if SlowMotionEnabled then
        local worldsettings = cache.worldsettings
        GameSpeed = SloMoGameSpeed
        worldsettings['TimeDilation'] = GameSpeed
        if ModUIHUDVisible then
            cache.ui_hud['HUD_GameSpeed_Value'] = GameSpeed
        end
    end
end

-- Game goes slower
function DecreaseGameSpeed()
    if SloMoGameSpeed > GameSpeedDelta then
        SloMoGameSpeed = SloMoGameSpeed - GameSpeedDelta
    end
    if SlowMotionEnabled then
        local worldsettings = cache.worldsettings
        GameSpeed = SloMoGameSpeed
        worldsettings['TimeDilation'] = GameSpeed
        if ModUIHUDVisible then
            cache.ui_hud['HUD_GameSpeed_Value'] = GameSpeed
        end
    end
end

------------------------------------------------------------------------------
-- Try to have a cooldown between jumps
local lastJumpTimestamp = -1
-- The jump cooldown/recharge delay has been selected to avoid flying into the sky
local deltaJumpCooldown = 1.0
-- The standard UE Jump() method does nothing in Half Sword due to customizations
-- player:Jump()
-- so we have to add impulse ourselves
function PlayerJump()
    local curJumpTimestamp = os.clock()
    local delta = curJumpTimestamp - lastJumpTimestamp
    -- Logf("TS = %f, LJTS = %f, delta = %f\n", curJumpTimestamp, lastJumpTimestamp, delta)
    local player = GetActivePlayer()
    local mesh = player['Mesh']

    if player['Fallen'] then
        -- TODO what if the player is laying down? Currently we do a small boost just in case
        local jumpImpulse = 1000.0 --* GameSpeed
        mesh:AddImpulse({ X = 0.0, Y = 0.0, Z = jumpImpulse }, FName("None"), true)
    else
        -- Only jump if the last jump happened long enough ago
        if delta >= deltaJumpCooldown then
            -- Update last successful jump timestamp
            lastJumpTimestamp = curJumpTimestamp
            -- The jump impulse value has been selected to jump high enough for a table or boss fence
            local jumpImpulse = 25000.0 --* GameSpeed
            mesh:AddImpulse({ X = 0.0, Y = 0.0, Z = jumpImpulse }, FName("None"), true)
        end
    end
end

------------------------------------------------------------------------------
local DASH_FORWARD = 0
local DASH_BACK = 1
local DASH_LEFT = 2
local DASH_RIGHT = 4
local lastDashTimestamp = -1
local deltaDashCooldown = 1.0
-- The dash moves the player horizontally in the selected direction
function PlayerDash(direction)
    local curDashTimestamp = os.clock()
    local delta = curDashTimestamp - lastDashTimestamp
    -- Logf("TS = %f, LJTS = %f, delta = %f\n", curJumpTimestamp, lastDashTimestamp, delta)
    local player = GetActivePlayer()
    local PlayerRotation = GetPlayerViewRotation()
    local mesh = player['Mesh']

    local angles = { [DASH_FORWARD] = 0.0, [DASH_BACK] = 2.0 * math.pi, [DASH_LEFT] = -math.pi, [DASH_RIGHT] = math.pi }
    -- The liftoff angles for the dash compensate for the ground friction and legs grappling the ground, hopefully
    local liftoffAnglesDeg = { [DASH_FORWARD] = 15.0, [DASH_BACK] = 15.0, [DASH_LEFT] = 30.0, [DASH_RIGHT] = 30.0 }
    -- The dash forces have been tuned to provide a decent movement while not tripping the player (hopefully)
    local dashForces = { [DASH_FORWARD] = 15000.0, [DASH_BACK] = 12000.0, [DASH_LEFT] = 40000.0, [DASH_RIGHT] = 40000.0 }

    local direction_rotator = maf.rotation.fromAngleAxis(
        angles[direction] / 2.0,
        0.0,
        0.0,
        1.0
    )

    local viewRotator = maf.rotation.fromAngleAxis(
        math.rad(PlayerRotation.Yaw),
        0.0,
        0.0,
        1.0
    )

    local liftoffRotator = maf.rotation.fromAngleAxis(
        -math.rad(liftoffAnglesDeg[direction]),
        0.0,
        1.0,
        0.0
    )

    if player['Fallen'] then
        -- TODO what if the player is laying down? Currently we do a small boost just in case
        local dashImpulse = 1000.0 --* GameSpeed
        local dashImpulseVector = maf.vec3(dashImpulse, 0.0, 0.0)

        dashImpulseVector:rotate(liftoffRotator)
        dashImpulseVector:rotate(viewRotator)
        dashImpulseVector:rotate(direction_rotator)
        local dashVector = maf2vec(dashImpulseVector)

        mesh:AddImpulse(dashVector, FName("None"), true)
    else
        -- Only dash if the last dash happened long enough ago
        if delta >= deltaDashCooldown then
            -- Update last successful dash timestamp
            lastDashTimestamp = curDashTimestamp
            local dashImpulse = dashForces[direction] --* GameSpeed
            local dashImpulseVector = maf.vec3(dashImpulse, 0.0, 0.0)

            dashImpulseVector:rotate(liftoffRotator)
            dashImpulseVector:rotate(viewRotator)
            dashImpulseVector:rotate(direction_rotator)
            local dashVector = maf2vec(dashImpulseVector)

            mesh:AddImpulse(dashVector, FName("None"), true)
        end
    end
end

------------------------------------------------------------------------------
local selectedProjectile = 1
local DEFAULT_PROJECTILE = "/CURRENTLY_SELECTED.CURRENTLY_SELECTED_DEFAULT"
local DEFAULT_NPC_PROJECTILE = "/CURRENTLY_SELECTED_NPC.CURRENTLY_SELECTED_NPC_DEFAULT"

-- The first and the last projectiles in this list are special cases that launch the currently selected weapon and NPC from the menus, respectively
local projectiles = {
    { DEFAULT_PROJECTILE,                                                                                            { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 100 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_Spear.ModularWeaponBP_Spear_C",                 { X = 0.5, Y = 0.5, Z = 0.5 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 100 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tools/BP_Weapon_Tool_Pitchfork_A.BP_Weapon_Tool_Pitchfork_A_C", { X = 0.5, Y = 0.5, Z = 0.5 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 150 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_Dagger.ModularWeaponBP_Dagger_C",               { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 50 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tools/BP_Weapon_Tool_Axe_D.BP_Weapon_Tool_Axe_D_C",             { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 180.0, Roll = 0.0 }, 50 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tools/BP_Weapon_Tool_Mallet_B.BP_Weapon_Tool_Mallet_B_C",       { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 100 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Improvized/BP_Weapon_Improv_Stool.BP_Weapon_Improv_Stool_C",    { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 150 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Buckler4.Buckler4_C",                                           { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 150 },
    { "/Game/Assets/Destructible/Dest_Barrel_1_BP.Dest_Barrel_1_BP_C",                                               { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },   100 },
    { "/Game/Assets/Props/Furniture/Meshes/BM_Prop_Furniture_Small_Bench_001.BM_Prop_Furniture_Small_Bench_001_C",   { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },   100 },
    { "/Game/Assets/Props/Furniture/Meshes/BP_Prop_Furniture_Small_Table_001.BP_Prop_Furniture_Small_Table_001_C",   { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },   100 },
    { DEFAULT_NPC_PROJECTILE,                                                                                        { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },   500 },
    --    { "/Game/Character/Blueprints/Willie_BP.Willie_BP_C",                                                            { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },   500 },
    --    { "/Game/Character/Blueprints/Willie_Torso_BP.Willie_Torso_BP_C",                                                { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },   500 },
    --    ,{ "/Game/Assets/Props/Barrels/Meshes/BP_Prop_Barrel_002.BP_Prop_Barrel_002_C",                                   { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },   100 }
}

-- The projectile shooting logic attempts to take into account various manual corrections
-- to try to not kill the player when spawning projectiles.
function ShootProjectile()
    local offset = { X = 40.0, Y = 0.0, Z = 0.0 }
    local baseImpulseVector = { X = 50.0, Y = 0.0, Z = 0.0 }
    local PlayerViewRotation = GetPlayerViewRotation()
    local PlayerLocation = GetPlayerLocation()

    local class, scale, baseRotation, forceMultiplier = table.unpack(projectiles[selectedProjectile])

    -- Allow to shoot a weapon from spawn menu, taking into account the scale
    if class == DEFAULT_PROJECTILE then
        local Selected_Spawn_Weapon = cache.ui_spawn['Selected_Spawn_Weapon']:ToString()
        WeaponScaleMultiplier = cache.ui_spawn['HSTM_Slider_WeaponSize']
        WeaponScaleX = cache.ui_spawn['HSTM_Flag_ScaleX']
        WeaponScaleY = cache.ui_spawn['HSTM_Flag_ScaleY']
        WeaponScaleZ = cache.ui_spawn['HSTM_Flag_ScaleZ']
        WeaponScaleBladeOnly = cache.ui_spawn['HSTM_Flag_ScaleBladeOnly']
        ScaleObjects = cache.ui_spawn['HSTM_Flag_ScaleObjects']

        local selected_actor = all_weapons[Selected_Spawn_Weapon]
        --Logf("Shooting custom weapon [%s]\n", selected_actor)

        -- Try to guess the correct rotation for various weapons
        if selected_actor:contains("Axe") then
            baseRotation = { Pitch = 0.0, Yaw = 180.0, Roll = 0.0 }
        elseif selected_actor:contains("Scythe") then
            baseRotation = { Pitch = 90.0, Yaw = 0.0, Roll = 0.0 }
            offset.X = offset.X + 120
        elseif selected_actor:contains("Pitchfork") then
            offset.X = offset.X + 20
        elseif selected_actor:contains("Sickle") then
            baseRotation = { Pitch = 0.0, Yaw = 180.0, Roll = 0.0 }
        elseif selected_actor:contains("Pavise") then
            offset.X = offset.X + 30
            baseRotation = { Pitch = 0.0, Yaw = 90.0, Roll = 90.0 }
        elseif selected_actor:contains("CandleStick") then
            -- Currently bugged
            offset.X = offset.X + 100
            baseRotation = { Pitch = 90.0, Yaw = 0.0, Roll = 0.0 }
        end

        if WeaponScaleMultiplier ~= 1.0 then
            scale = {
                X = WeaponScaleX and WeaponScaleMultiplier or 1.0,
                Y = WeaponScaleY and WeaponScaleMultiplier or 1.0,
                Z = WeaponScaleZ and WeaponScaleMultiplier or 1.0
            }
            if WeaponScaleMultiplier > 1.0 then
                -- When a long weapon spawns, it is the Z axis that is the longest
                -- Try to move the projectile away from the player to prevent sudden death
                if WeaponScaleZ then
                    offset.X = offset.X * WeaponScaleMultiplier
                end
                -- Only scale up the force if the object is scaled across all axes
                if WeaponScaleX and WeaponScaleY and WeaponScaleZ then
                    forceMultiplier = forceMultiplier * WeaponScaleMultiplier
                end
            end
        else
            -- Just to be safer against longer weapons
            offset.X = offset.X + 10
        end
        class = selected_actor
    elseif class == DEFAULT_NPC_PROJECTILE then
        SpawnFrozenNPCs = cache.ui_spawn['HSTM_Flag_SpawnFrozenNPCs']
        NPCTeam = tonumber(cache.ui_spawn['Selected_Spawn_NPC_Team']:ToString())
        local Selected_Spawn_NPC = cache.ui_spawn['Selected_Spawn_NPC']:ToString()
        local selected_actor = all_characters[Selected_Spawn_NPC]
        class = selected_actor
    end

    -- General corrections
    if class:contains("Barrel") then
        offset.X = offset.X + 50
    elseif class:contains("BM_Prop_Furniture_Small_Bench_001") then
        offset.X = offset.X + 50
    elseif class:contains("BP_Prop_Furniture_Small_Table_001") then
        offset.X = offset.X + 150
    elseif class:contains("Willie") then
        offset.X = offset.X + 60
        offset.Z = -60
    end

    -- First locate the spawn point by rotating the offset by player camera yaw (around Z axis in UE), horizontal camera position
    local rotator = maf.rotation.fromAngleAxis(
        math.rad(PlayerViewRotation.Yaw),
        0.0, -- X
        0.0, -- Y
        1.0  -- Z
    )
    local DeltaLocation = vec2maf(offset)
    local rotatedDelta = DeltaLocation
    rotatedDelta:rotate(rotator)

    -- Add the displacement vector to player location with some Z-height adjustments
    local SpawnLocation = {
        X = PlayerLocation.X + rotatedDelta.x,
        Y = PlayerLocation.Y + rotatedDelta.y,
        Z = PlayerLocation.Z + 70 + rotatedDelta.z
    }

    -- Rotate the projectile along its yaw and pitch to address horizontal and vertical camera movement

    local SpawnRotation = {
        Pitch = baseRotation.Pitch + PlayerViewRotation.Pitch,
        Yaw = baseRotation.Yaw + PlayerViewRotation.Yaw,
        Roll = baseRotation.Roll,
    }

    local ImpulseRotation = vec2maf(baseImpulseVector)

    -- Prepare the projectile impulse vector: rotate it according to vertical camera movement
    local TargetRotator = maf.rotation.fromAngleAxis(
        -math.rad(PlayerViewRotation.Pitch),
        0.0, -- X
        1.0, -- Y
        0.0  -- Z
    )

    ImpulseRotation:rotate(TargetRotator)
    -- Then address the horizonal (Yaw) camera movement around Z-axis as done above for spawn location, same for impulse
    ImpulseRotation:rotate(rotator)

    local projectile = SpawnActorByClassPath(class, SpawnLocation, baseRotation, scale, WeaponScaleBladeOnly, ScaleObjects)
    -- Correct the spawned projectile rotation by the camera-specific angles
    projectile:K2_SetActorRotation(SpawnRotation, true)

    -- We don't compensate for game speed to make projectiles a bit stronger in slow-mo
    local impulseMaf = ImpulseRotation
    local impulse = impulseMaf * forceMultiplier
    local impulseUE = maf2vec(impulse)
    -- Don't apply impulse immediately, give the player a chance to see the projectile
    ExecuteWithDelay(200, function()
        -- More dumb fixes to apply impulse to different components.
        -- We should probably be trying to find a StaticMesh inside instead of this.
        -- Ignoring mass is set to True for non-standard projectiles.
        if class:contains("_Prop_Furniture") then
            projectile['SM_Prop']:AddImpulse(impulseUE, FName("None"), true)
        elseif class:contains("Dest_Barrel") then
            projectile['RootComponent']:AddImpulse(impulseUE, FName("None"), true)
        elseif class:contains("BP_Prop_Barrel") then
            projectile['SM_Barrel']:AddImpulse(impulseUE, FName("None"), true)
        elseif class:contains("Willie") then
            projectile['Mesh']:AddImpulse(impulseUE, FName("None"), true)
        else
            projectile['BaseMesh']:AddImpulse(impulseUE, FName("None"), false)
        end
    end)
end

-- This is some truly horrible attempt to rotate through a list that I should be ashamed of
function ChangeProjectileNext()
    selectedProjectile = math.fmod(selectedProjectile, #projectiles) + 1
    HUD_CacheProjectile()
end

-- This, too, is not great but works
function ChangeProjectilePrev()
    selectedProjectile = math.fmod(#projectiles + selectedProjectile - 2, #projectiles) + 1
    HUD_CacheProjectile()
end

-- As the UI may not be on screen when we shoot the selected menu items, we try to cache them
function HUD_CacheProjectile()
    local class, _, _, _ = table.unpack(projectiles[selectedProjectile])
    local classname = class
    if class == DEFAULT_PROJECTILE then
        local selectedWeapon = cache.ui_spawn['Selected_Spawn_Weapon']:ToString()
        classname = all_weapons[selectedWeapon]
    elseif class == DEFAULT_NPC_PROJECTILE then
        local Selected_Spawn_NPC = cache.ui_spawn['Selected_Spawn_NPC']:ToString()
        classname = all_characters[Selected_Spawn_NPC]
    end
    local projectileShortName = ExtractHumanReadableNameShorter(classname)
    if class == DEFAULT_PROJECTILE then
        projectileShortName = projectileShortName .. " (Weapon menu)"
    elseif class == DEFAULT_NPC_PROJECTILE then
        projectileShortName = projectileShortName .. " (NPC menu)"
    end
    if ModUIHUDVisible then
        cache.ui_hud['HUD_Projectile_Value'] = projectileShortName
    end
end

------------------------------------------------------------------------------
-- We check equality of non-static objects by their full names,
-- which includes the unique numbered name of an instance of a class (something like My_Object_C_123456789)
-- Horrible, but a bit better than using their address (UE4SS and Lua don't help there)
function UEAreObjectsEqual(a, b)
    local aa = tostring(a:GetFullName())
    local bb = tostring(b:GetFullName())
    -- Logf("[%s] == [%s]?\n", aa, bb)
    return aa == bb
end

------------------------------------------------------------------------------
function IsPossessing()
    local player = cache.map['Player Willie']
    local playerController = myGetPlayerController()
    local possessedPawn = playerController['Pawn']
    return UEAreObjectsEqual(player, possessedPawn)
end

function IsThisNPCPossessed(NPC)
    local playerController = myGetPlayerController()
    local possessedPawn = playerController['Pawn']
    return UEAreObjectsEqual(NPC, possessedPawn)
end

function PossessNearestNPC()
    local currentLocation = GetPlayerLocation()
    local currentPawn = GetActivePlayer()
    local playerController = myGetPlayerController()

    if OGWillie == nil then
        -- cache the original Willie so that we can go back to it when repossessing
        OGWillie = cache.map['Player Willie']
        Logf("OGWillie: %s\n", OGWillie:GetFullName())
    end

    local AllNPCs = {}
    ExecuteForAllNPCs(function(NPC)
        -- Don't try to re-possess the current, already possessed NPC
        if UEAreObjectsEqual(NPC, currentPawn) then
            -- TODO process a currently possessed NPC or not?
        else
            table.insert(AllNPCs, { Pawn = NPC, Location = NPC:K2_GetActorLocation() })
        end
    end)
    -- Totally arbitrary large value, in fact a couple tiles' worth of units should be enough but YOLO
    local minDelta = 10e23
    local closestNPCidx = -1
    for idx, NPC in ipairs(AllNPCs) do
        local thisLocation = NPC.Location
        local delta = maf.vec3.distance(vec2maf(currentLocation), vec2maf(thisLocation))
        if delta < minDelta then
            minDelta = delta
            closestNPCidx = idx
        end
    end
    if closestNPCidx ~= -1 then
        local pawnToPossess = AllNPCs[closestNPCidx].Pawn
        ResurrectionWasRequested = true
        Logf("Possessing NPC: %s\n", pawnToPossess:GetFullName())
        playerController:Possess(pawnToPossess)
        -- TODO fix the player X and Y and map's link to the player character
        -- currently we use the stored one to be able to repossess it, but game progression is broken if you keep the new character
        -- we should probably fix it
        cache.map['Player Willie'] = pawnToPossess
    else
        ErrLogf("Could not find the closest NPC\n")
    end
    -- Not sure why we are doing this
    SetAllPlayerOneHUDVisibility(Visibility_HIDDEN)
end

-- Re-possession breaks AI control of previously possessed NPCs
function RepossessPlayer()
    -- ExecuteForAllNPCs(function(NPC)
    --     NPC['Controller']:UnPossess()
    -- end)
    local playerController = myGetPlayerController()
    ResurrectionWasRequested = true
    if OGWillie ~= nil and OGWillie:IsValid() then
        Logf("Possessing player Willie back: %s\n", OGWillie:GetFullName())
        playerController:Possess(OGWillie)
        cache.map['Player Willie'] = OGWillie
        SetAllPlayerOneHUDVisibility(Visibility_VISIBLE)
    else
        Logf("[ERROR]: Cannot repossess the original Willie, aborting.\n")
    end
end

------------------------------------------------------------------------------
-- Resurrection may not guarantee a complete revival, doesn't seem to work for NPCs yet
function ResurrectWillie(player, forcePlayerController)
    player['DED'] = false
    player['Consciousness'] = 100.0
    player['All Body Tonus'] = 100.0

    player['Health'] = 100.0

    player['Head Health'] = 100.0
    player['Neck Health'] = 100.0
    player['Body Health'] = 100.0
    player['Arm_R Health'] = 100.0
    player['Arm_L Health'] = 100.0
    player['Leg_R Health'] = 100.0
    player['Leg_L Health'] = 100.0

    player['Pain'] = 0.0
    player['Bleeding'] = 0.0

    -- Not sure if those functions do anything but let's call them just in case
    player['Reset Dismemberment']()
    player['Reset Sustained Damage']()
    if forcePlayerController then
        -- Possess this willie with a PlayerController instead of the last controller
        local playerController = myGetPlayerController()
        playerController:Possess(player)
    else
        -- Just reuse the last controller.
        local controller = player['Controller']
        if controller and controller:IsValid() then
            controller:Possess(player)
        else
            ErrLogf("Cannot resurrect Willie, invalid controller\n")
        end
    end
end

------------------------------------------------------------------------------
function ResurrectPlayer()
    -- TODO handle detecting and bypassing the death screen
    Logf("Resurrecting player\n")
    ResurrectionWasRequested = true
    local player = GetActivePlayer()
    ResurrectWillie(player, true)
end

function ResurrectPlayerByController()
    -- TODO handle detecting and bypassing the death screen
    Logf("Resurrecting player using default PlayerController\n")
    local PlayerController = myGetPlayerController()
    local player = PlayerController['Pawn']
    ResurrectionWasRequested = true
    ResurrectWillie(player, true)
end

------------------------------------------------------------------------------
-- This has to be called when the DED screen is triggered, not before
function RemovePlayerOneDeathScreen()
    -- We don't use the caching of those objects just in case
    local HUD = FindFirstOf("UI_HUD_C")
    if HUD and HUD:IsValid() then
        -- HUD:RemoveFromViewport()
        -- It is better to hide the black death screen on the HUD
        -- Damage HUD and crosshair are still visible
        HUD['Black']:SetVisibility(Visibility_HIDDEN)
        HUD['Vignette']:SetVisibility(Visibility_HIDDEN)
        HUD['Vignette_WakeUp']:SetVisibility(Visibility_HIDDEN)
        HUD['Vignette_Pain']:SetVisibility(Visibility_HIDDEN)
        Logf("Removing HUD Black screen\n")
    end
    local DED = FindFirstOf("UI_DED_C")
    if DED and DED:IsValid() then
        -- It is better to remove the DED screen as it blocks the menu UI with it (cannot restart otherwise)
        DED:RemoveFromViewport()
        -- DED:SetVisibility(Visibility_HIDDEN)
        Logf("Removing Death screen\n")
        if GetGameplayStatics():IsGamePaused(GetWorldContextObject()) then
            GetGameplayStatics():SetGamePaused(GetWorldContextObject(), false)
            Logf("Unpausing game after death screen\n")
        end
    end
end

function SetAllPlayerOneHUDVisibility(NewVisibility)
    -- We don't use the caching of those objects just in case
    local HUD = FindFirstOf("UI_HUD_C")
    if HUD and HUD:IsValid() then
        -- crosshair
        HUD['Aim']:SetVisibility(NewVisibility)
        -- damage HUD
        HUD['ArmLDmg']:SetVisibility(NewVisibility)
        HUD['ArmRDmg']:SetVisibility(NewVisibility)
        HUD['HeadDmg']:SetVisibility(NewVisibility)
        HUD['HPDmg1']:SetVisibility(NewVisibility)
        HUD['HPDmg2']:SetVisibility(NewVisibility)
        HUD['HPDmg3']:SetVisibility(NewVisibility)
        HUD['LegLDmg']:SetVisibility(NewVisibility)
        HUD['LegRDmg']:SetVisibility(NewVisibility)
        -- shock/death vignette
        HUD['Black']:SetVisibility(NewVisibility)
        HUD['Vignette']:SetVisibility(NewVisibility)
        HUD['Vignette_WakeUp']:SetVisibility(NewVisibility)
        HUD['Vignette_Pain']:SetVisibility(NewVisibility)

        Logf("Toggling visibility for Player one HUD\n")
    end
end

-- function RemoveUIHints()
--     local hint1 = FindFirstOf("UI_Hint_Move_C")
--     local hint2 = FindFirstOf("UI_Hint_Interact_C")
--     if hint1 and hint2 then
--         hint1:RemoveFromViewport()
--         hint2:RemoveFromViewport()
--         Logf("Removing hints UI\n")
--     end
-- end

------------------------------------------------------------------------------
-- This is intended to be used mostly to get free camera from PhotoMode
-- But can be used to unpause from death screen as well
-- The function is trying to be smart and hide the HUD with blood when in free camera mode, and bring it back when you exit it from PhotoMode.
-- Note that if you just exit the photomode with ESC, the HUD will probably stay disabled.
function ToggleGamePaused()
    local UI_PhotoMode_C = FindFirstOf("UI_PhotoMode_C")
    if GetGameplayStatics():IsGamePaused(GetWorldContextObject()) then
        if UI_PhotoMode_C ~= nil and UI_PhotoMode_C:IsValid() and UI_PhotoMode_C['bUsingFreeCamera'] == true then
            -- Let the camera fly further away, default is 1000
            UI_PhotoMode_C['FreeCameraActor']['MaximumDistance'] = 5000
            SetAllPlayerOneHUDVisibility(Visibility_HIDDEN)
        end
        GetGameplayStatics():SetGamePaused(GetWorldContextObject(), false)
        Logf("Unpausing game\n")
    else
        if UI_PhotoMode_C ~= nil and UI_PhotoMode_C:IsValid() and UI_PhotoMode_C['bUsingFreeCamera'] == true then
            SetAllPlayerOneHUDVisibility(Visibility_VISIBLE)
        end
        GetGameplayStatics():SetGamePaused(GetWorldContextObject(), true)
        Logf("Pausing game\n")
    end
end

------------------------------------------------------------------------------
-- The code below is commented as a better free camera implementation above can be enabled straight from PhotoMode by unpausing the game
--
-- local freeCameraMode = false
-- -- set freezePlayerFreeCamera to false if you need the player to move with free camera (e.g. to keep fighting)
-- local freezePlayerFreeCamera = true
-- -- This attempts to reuse the built-in photo mode's "free camera" and gives control to the player in game
-- -- The player will be frozen or not, depending on freezePlayerFreeCamera
-- function ToggleFreeCamera()
--     local UI_PhotoMode_C = FindFirstOf("UI_PhotoMode_C")
--     local controller = myGetPlayerController()
--     local player = GetActivePlayer()
--     if UI_PhotoMode_C ~= nil then
--         if freeCameraMode == false then
--             -- enable Free Camera
--             UI_PhotoMode_C:ChangeFreeCameraFOV(100)
--             UI_PhotoMode_C:OpenFreeCamera()
--             freeCameraMode = true
--             -- prevent the player character from moving
--             if freezePlayerFreeCamera then
--                 player:DisableInput(controller)
--             end
--             -- hide the on-screen pain/blood UI
--             SetAllPlayerOneHUDVisibility(Visibility_HIDDEN)
--         else
--             -- disable Free Camera
--             UI_PhotoMode_C:CloseFreeCamera()
--             freeCameraMode = false
--             -- re-enable the player character movement
--             if freezePlayerFreeCamera then
--                 player:EnableInput(controller)
--             end
--             -- restore the on-screen pain/blood UI
--             SetAllPlayerOneHUDVisibility(Visibility_VISIBLE)
--         end
--     end
-- end
------------------------------------------------------------------------------
-- The code below is based on UE4SS LineTraceMod
-- It uses UKismetSystemLibrary::LineTraceSingle() to find the actor under cursor (center of screen)
-- No actual line is ever drawn on screen as the game is in a shipping build, not debug one
function TraceObjectFromPlayerCamera()
    local PlayerController = myGetPlayerController()
    local PlayerPawn = PlayerController.Pawn
    local CameraManager = PlayerController.PlayerCameraManager
    local StartVector = CameraManager:GetCameraLocation()
    local AddValue = GetKismetMathLibrary():Multiply_VectorInt(
        GetKismetMathLibrary():GetForwardVector(CameraManager:GetCameraRotation()), 50000.0)
    local EndVector = GetKismetMathLibrary():Add_VectorVector(StartVector, AddValue)
    local TraceColor = {
        ["R"] = 0,
        ["G"] = 0,
        ["B"] = 0,
        ["A"] = 0,
    }
    local TraceHitColor = TraceColor
    local EDrawDebugTrace_Type_None = 0
    local ETraceTypeQuery_TraceTypeQuery1 = 0
    local ActorsToIgnore = {}
    local HitResult = {}
    local WasHit = GetKismetSystemLibrary():LineTraceSingle(
        PlayerPawn,
        StartVector,
        EndVector,
        ETraceTypeQuery_TraceTypeQuery1,
        false,
        ActorsToIgnore,
        EDrawDebugTrace_Type_None,
        HitResult,
        true,
        TraceColor,
        TraceHitColor,
        0.0
    )

    if WasHit then
        HitActor = HitResult.HitObjectHandle.Actor:Get()
        return HitActor
    else
        return nil
    end
end

-- We find the actor under cursor (center of screen) and despawn it with K2_DestroyActor
function DespawnObjectFromPlayerCamera()
    local actor = TraceObjectFromPlayerCamera()
    if actor then
        local actorName = actor:GetFullName()
        -- Refuse to despawn the floor or the player for obvious reasons
        if not UEAreObjectsEqual(actor, GetActivePlayer()) and not actorName:contains("BP_Floor_Tile") then
            Logf("Despawning actor: %s\n", actor:GetFullName())
            actor:K2_DestroyActor()
        end
    end
end

-- Attempt to command all the NPCs on the same team to move to the player
-- TODO should we do something about Team 0 which are hostile to each other?
function GoToMe()
    ExecuteForAllNPCs(function(NPC)
        if NPC and NPC:IsValid() and NPC['Team Int'] == PlayerTeam then
            local npcController = NPC['Controller']
            if npcController and npcController:IsValid() then
                npcController['MoveToActor'](npcController,
                    GetActivePlayer(),
                    200.0,
                    true,
                    true,
                    true,
                    nil,
                    true
                )
            end
        end
    end)
end

-- We find the actor under cursor (center of screen) and try to scale it
function ScaleObjectUnderCamera()
    WeaponScaleMultiplier = cache.ui_spawn['HSTM_Slider_WeaponSize']
    WeaponScaleX = cache.ui_spawn['HSTM_Flag_ScaleX']
    WeaponScaleY = cache.ui_spawn['HSTM_Flag_ScaleY']
    WeaponScaleZ = cache.ui_spawn['HSTM_Flag_ScaleZ']
    WeaponScaleBladeOnly = cache.ui_spawn['HSTM_Flag_ScaleBladeOnly']

    if WeaponScaleMultiplier ~= 1.0 then
        local scale = {
            X = WeaponScaleX and WeaponScaleMultiplier or 1.0,
            Y = WeaponScaleY and WeaponScaleMultiplier or 1.0,
            Z = WeaponScaleZ and WeaponScaleMultiplier or 1.0
        }
        local Actor = TraceObjectFromPlayerCamera()
        if Actor then
            local actorName = Actor:GetFullName()
            -- Refuse to scale the floor or the player for obvious reasons
            if not UEAreObjectsEqual(Actor, GetActivePlayer()) and not actorName:contains("BP_Floor_Tile") then
                Logf("Scaling actor: %s to %s\n", actorName, UEVecToStr(scale))
                if actorName:contains("/Built_Weapons/ModularWeaponBP") then
                    if WeaponScaleBladeOnly then
                        -- Actually not sure which scale we should set, relative or world?
                        Actor['head']:SetRelativeScale3D(scale)
                    else
                        Actor:SetActorScale3D(scale)
                    end
                elseif actorName:contains("_Prop_Furniture") then
                    Actor['SM_Prop']:SetRelativeScale3D(scale)
                elseif actorName:contains("Dest_Barrel") then
                    Actor['RootComponent']:SetRelativeScale3D(scale)
                elseif actorName:contains("BP_Prop_Barrel") then
                    Actor['SM_Barrel']:SetRelativeScale3D(scale)
                elseif actorName:contains("BP_Container") then
                    Actor['Box']:SetRelativeScale3D(scale)
                else
                    Actor:SetActorScale3D(scale)
                end
            end
        end
    end
end

------------------------------------------------------------------------------
function AllHooks()
    CriticalHooks()
    AllCustomEventHooks()
    AllKeybindHooks()
end

------------------------------------------------------------------------------
function CriticalHooks()
    ------------------------------------------------------------------------------
    -- We hook the restart event, which somehow fires twice per restart
    -- We take care of that in the InitMyMod() function above
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", InitMyMod)
    --    RegisterLoadMapPostHook(function(Engine, World)
    --        InitMyMod()
    --    end)
    Log("Critical hooks registered\n")
end

------------------------------------------------------------------------------
function DangerousHooks()
    ------------------------------------------------------------------------------
    -- We hook the creation of Character class objects, those are NPCs usually
    -- WARN for some reason, this crashes the game on restart
    -- TODO intercept and set CustomTimeDilation if we want to freeze all NPCs
    -- Maybe it is the Lua GC doing this to a table of actors somehow?
    -- NotifyOnNewObject("/Script/Engine.Character", function(ConstructedObject)
    --     if intercepted_actors then
    --         table.insert(intercepted_actors, ConstructedObject)
    --     end
    --     Logf("Hook Character spawned: %s\n", ConstructedObject:GetFullName())
    -- end)
    ------------------------------------------------------------------------------
    -- Damage hooks are commented for now, not sure which is the correct one to intercept and how to interpret the variables
    -- TODO Needs a proper investigation
    -- RegisterHook("/Script/Engine.Actor:ReceiveAnyDamage", function(self, Damage, DamageType, InstigatedBy, DamageCauser)
    --     Logf("Damage %f\n", Damage:get())
    -- end)
    -- RegisterHook("/Game/Character/Blueprints/Willie_BP.Willie_BP_C:Get Damage", function(self,
    --         Impulse,Velocity,Location,Normal,bone,Raw_Damage,Cutting_Power,Inside,Damaged_Mesh,Dism_Blunt,Lower_Threshold,Shockwave,Hit_By_Component,Damage_Out
    --     )
    --     Logf("Damage %f %f\n", Raw_Damage:get(), Damage_Out:get())
    -- end)
end

------------------------------------------------------------------------------
-- Trying to hook the button click functions of the HSTM_UI blueprint:
-- * HSTM_SpawnArmor
-- * HSTM_SpawnWeapon
-- * HSTM_SpawnNPC
-- * HSTM_SpawnObject
-- * HSTM_UndoSpawn
-- * HSTM_ToggleSlowMotion
-- * HSTM_KillAllNPCs
-- * HSTM_FreezeAllNPCs
-- Those are defined as custom functions in the spawn widget of the HSTM_UI blueprint itself.
function AllCustomEventHooks()
    RegisterCustomEvent("HSTM_SpawnArmor", function(ParamContext, ParamMessage)
        SpawnSelectedArmor()
    end)

    RegisterCustomEvent("HSTM_SpawnWeapon", function(ParamContext, ParamMessage)
        SpawnSelectedWeapon()
    end)

    RegisterCustomEvent("HSTM_SpawnNPC", function(ParamContext, ParamMessage)
        SpawnSelectedNPC()
    end)

    RegisterCustomEvent("HSTM_SpawnObject", function(ParamContext, ParamMessage)
        SpawnSelectedObject()
    end)

    -- Buttons below
    RegisterCustomEvent("HSTM_UndoSpawn", function(ParamContext, ParamMessage)
        UndoLastSpawn()
    end)

    RegisterCustomEvent("HSTM_DespawnNPCs", function(ParamContext, ParamMessage)
        UndoLastSpawn()
    end)

    RegisterCustomEvent("HSTM_ToggleSlowMotion", function(ParamContext, ParamMessage)
        ToggleSlowMotion()
    end)

    RegisterCustomEvent("HSTM_KillAllNPCs", function(ParamContext, ParamMessage)
        KillAllNPCs()
    end)

    RegisterCustomEvent("HSTM_FreezeAllNPCs", function(ParamContext, ParamMessage)
        FreezeAllNPCs()
    end)

    Log("Custom events registered\n")
end

------------------------------------------------------------------------------
-- The user-facing key bindings are below.
-- Most are wrapped in a ExecuteInGameThread() call to not crash,
-- the others have that wrapper inside them around the critical sections like spawning
function AllKeybindHooks()
    RegisterKeyBind(Key.I, function()
        ExecuteInGameThread(function()
            ToggleInvulnerability()
        end)
    end)

    RegisterKeyBind(Key.T, function()
        ExecuteInGameThread(function()
            ToggleSuperStrength()
        end)
    end)

    RegisterKeyBind(Key.L, function()
        SpawnLoadoutAroundPlayer()
    end)

    RegisterKeyBind(Key.OEM_MINUS, function()
        ExecuteInGameThread(function()
            DecreaseLevel()
        end)
    end)

    RegisterKeyBind(Key.OEM_PLUS, function()
        ExecuteInGameThread(function()
            IncreaseLevel()
        end)
    end)

    RegisterKeyBind(Key.U, function()
        ExecuteInGameThread(function()
            ToggleModUI()
        end)
    end)

    RegisterKeyBind(Key.F1, function()
        SpawnSelectedArmor()
    end)

    RegisterKeyBind(Key.F2, function()
        SpawnSelectedWeapon()
    end)

    RegisterKeyBind(Key.F3, function()
        SpawnSelectedNPC()
    end)

    RegisterKeyBind(Key.F4, function()
        SpawnSelectedObject()
    end)

    RegisterKeyBind(Key.F5, function()
        UndoLastSpawn()
    end)

    RegisterKeyBind(Key.F6, function()
        DespawnAllNPCs()
    end)

    RegisterKeyBind(Key.K, function()
        ExecuteInGameThread(function()
            KillAllNPCs()
        end)
    end)

    RegisterKeyBind(Key.Z, function()
        ExecuteInGameThread(function()
            FreezeAllNPCs()
        end)
    end)

    RegisterKeyBind(Key.B, function()
        ExecuteInGameThread(function()
            SpawnBossArena()
        end)
    end)

    RegisterKeyBind(Key.M, function()
        ExecuteInGameThread(function()
            ToggleSlowMotion()
        end)
    end)

    RegisterKeyBind(Key.M, { ModifierKey.SHIFT }, function()
        ExecuteInGameThread(function()
            ToggleSlowMotion()
        end)
    end)

    -- OEM_FOUR == [
    RegisterKeyBind(Key.OEM_FOUR, function()
        ExecuteInGameThread(function()
            DecreaseGameSpeed()
        end)
    end)
    -- OEM_SIX == ]
    RegisterKeyBind(Key.OEM_SIX, function()
        ExecuteInGameThread(function()
            IncreaseGameSpeed()
        end)
    end)

    -- OEM_FOUR == [
    RegisterKeyBind(Key.OEM_FOUR, { ModifierKey.SHIFT }, function()
        ExecuteInGameThread(function()
            DecreaseGameSpeed()
        end)
    end)
    -- OEM_SIX == ]
    RegisterKeyBind(Key.OEM_SIX, { ModifierKey.SHIFT }, function()
        ExecuteInGameThread(function()
            IncreaseGameSpeed()
        end)
    end)

    RegisterKeyBind(Key.OEM_PERIOD, function()
        ExecuteInGameThread(function()
            ToggleCrosshair()
        end)
    end)

    RegisterKeyBind(Key.SPACE, function()
        ExecuteInGameThread(function()
            PlayerJump()
        end)
    end)
    -- Also make sure we can still jump while sprinting with Shift held down
    RegisterKeyBind(Key.SPACE, { ModifierKey.SHIFT }, function()
        ExecuteInGameThread(function()
            PlayerJump()
        end)
    end)

    RegisterKeyBind(Key.SPACE, { ModifierKey.CONTROL }, function()
        ExecuteInGameThread(function()
            PlayerJump()
        end)
    end)

    RegisterKeyBind(Key.MIDDLE_MOUSE_BUTTON, function()
        ExecuteInGameThread(function()
            ShootProjectile()
        end)
    end)

    RegisterKeyBind(Key.MIDDLE_MOUSE_BUTTON, { ModifierKey.CONTROL }, function()
        ExecuteInGameThread(function()
            ShootProjectile()
        end)
    end)

    -- RegisterKeyBind(Key.J, function()
    --     ExecuteInGameThread(function()
    --         RemovePlayerArmor()
    --     end)
    -- end)

    -- Not sure why, but holding down SHIFT still triggers the other hooks, so let's not double things up
    -- RegisterKeyBind(Key.MIDDLE_MOUSE_BUTTON, { ModifierKey.SHIFT }, function()
    --     ExecuteInGameThread(function()
    --         ShootProjectile()
    --     end)
    -- end)

    RegisterKeyBind(Key.TAB, function()
        ChangeProjectileNext()
    end)

    -- Also make sure we can still shoot while sprinting with Shift held down
    RegisterKeyBind(Key.MIDDLE_MOUSE_BUTTON, { ModifierKey.SHIFT }, function()
        ExecuteInGameThread(function()
            ShootProjectile()
        end)
    end)

    RegisterKeyBind(Key.TAB, { ModifierKey.SHIFT }, function()
        ChangeProjectilePrev()
    end)

    RegisterKeyBind(Key.U, { ModifierKey.ALT }, function()
        RemovePlayerOneDeathScreen()
    end)

    RegisterKeyBind(Key.J, { ModifierKey.CONTROL }, function()
        ExecuteInGameThread(function()
            --ResurrectPlayer()
            -- Attempt to resurrect the Willie that is currently possessed by the Player, not the OG Willie
            ResurrectPlayerByController()
        end)
    end)

    RegisterKeyBind(Key.END, { ModifierKey.CONTROL }, function()
        PossessNearestNPC()
    end)

    RegisterKeyBind(Key.HOME, { ModifierKey.CONTROL }, function()
        RepossessPlayer()
    end)

    RegisterKeyBind(Key.NUM_EIGHT, function()
        ExecuteInGameThread(function()
            PlayerDash(DASH_FORWARD)
        end)
    end)

    RegisterKeyBind(Key.NUM_TWO, function()
        ExecuteInGameThread(function()
            PlayerDash(DASH_BACK)
        end)
    end)

    RegisterKeyBind(Key.NUM_FOUR, function()
        ExecuteInGameThread(function()
            PlayerDash(DASH_LEFT)
        end)
    end)

    RegisterKeyBind(Key.NUM_SIX, function()
        ExecuteInGameThread(function()
            PlayerDash(DASH_RIGHT)
        end)
    end)

    RegisterKeyBind(Key.MULTIPLY, function()
        ExecuteInGameThread(function()
            ToggleGamePaused()
            --ToggleFreeCamera()
        end)
    end)

    RegisterKeyBind(Key.ADD, function()
        ExecuteInGameThread(function()
            ChangePlayerTeamUp()
        end)
    end)

    RegisterKeyBind(Key.SUBTRACT, function()
        ExecuteInGameThread(function()
            ChangePlayerTeamDown()
        end)
    end)

    RegisterKeyBind(Key.F, { ModifierKey.CONTROL }, function()
        ExecuteInGameThread(function()
            GoToMe()
        end)
    end)

    RegisterKeyBind(Key.DEL, function()
        ExecuteInGameThread(function()
            DespawnObjectFromPlayerCamera()
        end)
    end)

    RegisterKeyBind(Key.DECIMAL, function()
        ExecuteInGameThread(function()
            ScaleObjectUnderCamera()
        end)
    end)

    Log("Keybinds registered\n")
end

------------------------------------------------------------------------------
-- The logic below attempts to check if the environment is OK to run in
function SanityCheckAndInit()
    local UE4SS_Major, UE4SS_Minor, UE4SS_Hotfix = UE4SS.GetVersion()
    local UE4SS_Version_String = string.format("%d.%d.%d", UE4SS_Major, UE4SS_Minor, UE4SS_Hotfix)

    if UE4SS_Major == 2 and UE4SS_Minor == 5 and (UE4SS_Hotfix == 2 or UE4SS_Hotfix == 1) then
        AllHooks()
    elseif UE4SS_Major == 3 then -- and UE4SS_Minor == 0 and UE4SS_Hotfix == 0 then
        -- We are on UE4SS 3.x.x
        -- TODO special handling of BPModLoaderMod
        -- Currently the best course of action is to copy BPModLoaderMod from UE4SS 2.5.2
        -- We will check if the BPModLoaderMod is our patched one or not
        local bpml_file_path = "Mods\\BPModLoaderMod\\Scripts\\main.lua"
        local bpml_file = io.open(bpml_file_path, "r")
        if bpml_file then
            local file_size = bpml_file:seek("end")
            --            Logf("BMPL size: %d\n", file_size)
            -- Yes, this is horrible.
            -- The file contains 203 lines
            -- 7819 is the size of that file with CRLF (Windows style) endings and
            -- 7616 is the size of that file with LF (unix style) endings (7616 + 203 = 7819)
            -- If you download the master branch from github you get the LF, otherwise CRLF.
            if file_size ~= 7819 and file_size ~= 7616 then
                error("You are using UE4SS 3.x.x, please copy Mods\\BPModLoaderMod\\Scripts\\main.lua from UE4SS 2.5.2!")
            end
        else
            error("BPModLoaderMod not found!")
        end
        AllHooks()
    else
        -- Unsupported UE4SS version
        error("Unsupported UE4SS version: " .. UE4SS_Version_String)
    end

    -- Half Sword steam demo is on UE 5.1 currently.
    -- If UE4SS didn't detect the correct UE version, we bail out.
    assert(UnrealVersion.IsEqual(5, 1))

    Logf("Sanity check passed!\n")
end

------------------------------------------------------------------------------
SanityCheckAndInit()
------------------------------------------------------------------------------
-- EOF
