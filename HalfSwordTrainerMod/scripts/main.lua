-- Half Sword Trainer Mod v0.7 by massclown
-- https://github.com/massclown/HalfSwordTrainerMod
-- Requirements: UE4SS 2.5.2 (or newer) and a Blueprint mod HSTM_UI (see repo)
------------------------------------------------------------------------------
local mod_version = "0.7"
------------------------------------------------------------------------------
local maf = require 'maf'
--local UEHelpers = require("UEHelpers")
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
local AutoSpawnEnabled = true -- this is the default, UI is 'HSTM_Flag_AutospawnNPCs'
local SpawnFrozenNPCs = false -- we can change it, UI flag is 'HSTM_Flag_SpawnFrozenNPCs'

local SlowMotionEnabled = false
local Frozen = false
local SuperStrength = false
-- Those are copies of player's (or level's) object properties
local GameSpeed = 1.0
local Invulnerable = false
local level = 0
local PlayerScore = 0
local PlayerHealth = 0
local PlayerConsciousness = 0
local PlayerTonus = 0
-- Cached from the spawn UI (HSTM_Slider_WeaponSize)
local WeaponScaleMultiplier = 1.0
local WeaponScaleX = true
local WeaponScaleY = true
local WeaponScaleZ = true

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

-- Various UI-related stuff
local ModUIHUDVisible = true
local ModUISpawnVisible = true
local CrosshairVisible = true
local ModUIHUDUpdateLoopEnabled = true
-- everything that we spawned
local spawned_things = {}

-- The actors from the hook
--local intercepted_actors = {}

-- Item/NPC tables for the spawn menus in the UI
local all_armor = {}
local all_weapons = {}
local all_characters = {}
local all_objects = {}

local custom_loadout = {}
------------------------------------------------------------------------------
function Log(Message)
    print("[HalfSwordTrainerMod] " .. Message)
end

function Logf(...)
    print("[HalfSwordTrainerMod] " .. string.format(...))
end

function ErrLog(Message)
    print("[HalfSwordTrainerMod] [ERROR] " .. Message)
end

function ErrLogf(...)
    print("[HalfSwordTrainerMod] [ERROR] " .. string.format(...))
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

function mafrotator2rot(vector)
    return { Pitch = vector.y, Yaw = vector.x, Roll = vector.z }
end

function rot2mafrotator(vector)
    return maf.rotation.fromAngleAxis(
        math.rad(vector.Yaw),
        math.rad(vector.Pitch),
        math.rad(vector.Roll),
        1.0
    )
end

------------------------------------------------------------------------------
-- Just some high-tier loadout I like, all the best armor, a huge shield, long polearm and two one-armed swords.
local default_loadout = {
    "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Hosen_Arming_C.BP_Armor_Hosen_Arming_C_C",
    "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Shoes_A.BP_Armor_Shoes_A_C",
    "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Doublet_Arming.BP_Armor_Doublet_Arming_C",
    "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Cuisse_B.BP_Armor_Cuisse_B_C",
    "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Cuirass_C.BP_Armor_Cuirass_C_C",
    "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Vambrace_A.BP_Armor_Vambrace_A_C",
    "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Bevor.BP_Armor_Bevor_C",
    "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Pauldron_A.BP_Armor_Pauldron_A_C",
    "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Sallet_Solid_C_002.BP_Armor_Sallet_Solid_C_002_C",
    "/Game/Assets/Armor/Blueprints/Built_Armor/BP_Armor_Gauntlets.BP_Armor_Gauntlets_C",
    "/Game/Assets/Weapons/Blueprints/Built_Weapons/Pavise1.Pavise1_C",
    "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_BastardSword.ModularWeaponBP_BastardSword_C",
    "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_BastardSword.ModularWeaponBP_BastardSword_C",
    "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tiers/ModularWeaponBP_Polearm_High_Tier.ModularWeaponBP_Polearm_High_Tier_C"
}

-- Read custom loadout from a text file containing class names
function LoadCustomLoadout()
    local file = io.open("Mods\\HalfSwordTrainerMod\\data\\custom_loadout.txt", "r");
    if file ~= nil then
        if custom_loadout then custom_loadout = {} end
        Logf("Loading custom loadout...\n")
        for line in file:lines() do
            if not line:starts_with('[BAD]') then
                table.insert(custom_loadout, line)
            end
        end
        Logf("Custom loadout loaded, %d items\n", #custom_loadout)
    end
end

------------------------------------------------------------------------------
-- This is copied from UEHelpers but filtering better, for PlayerController
--- Returns the first valid PlayerController that is currently controlled by a player.
---@return APlayerController
function myGetPlayerController()
    local PlayerControllers = FindAllOf("PlayerController")
    if not PlayerControllers then error("No PlayerController found\n") end
    local PlayerController = nil
    for Index, Controller in pairs(PlayerControllers) do
        if Controller.Pawn:IsValid() and Controller.Pawn:IsPlayerControlled() then
            PlayerController = Controller
        else
            Log("Not valid or not player controlled\n")
        end
    end
    if PlayerController and PlayerController:IsValid() then
        return PlayerController
    else
        error("No PlayerController found\n")
    end
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
    local ui_game_hud = cache.ui_game_hud
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
-- Timestamp of last invocation of InitMyMod()
local lastInitTimestamp = -1
local globalRestartCount = 0
-- This function gets added to the game restart hook below.
-- Somehow the hook gets triggered twice, so we try to have a time lock to avoid double-calling the init function,
-- but we still have to call it once if the user restarts soon, hence the miminum timeout of that 1 second.
-- So don't restart faster than once every two seconds, or this will break too.
function InitMyMod()
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

        -- This starts a thread that updates the HUD in background.
        -- It only exits if we retrn true from the lambda, which we don't
        local myRestartCounter = globalRestartCount
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
function HUD_UpdatePlayerStats()
    local player                            = cache.map['Player Willie']
    PlayerHealth                            = player['Health']
    Invulnerable                            = player['Invulnerable']
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
end

------------------------------------------------------------------------------
function ToggleSuperStrength()
    local player = cache.map['Player Willie']
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
    local player = cache.map['Player Willie']
    Invulnerable = player['Invulnerable']
    Invulnerable = not Invulnerable
    if Invulnerable then
        savedRegenRate = player['Regen Rate']
        player['Regen Rate'] = maxRegenRate
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
-- 99 is the z-order set in UI HUD blueprint in UE5 editor
-- 100 is the z-order set in UI Spawn blueprint in UE5 editor
-- should be high enough to be on top of everything
function ToggleModUI()
    if ModUIHUDVisible then
        cache.ui_hud:RemoveFromParent()
        ModUIHUDVisible = false
    else
        cache.ui_hud:AddToViewport(99)
        ModUIHUDVisible = true
    end
    if ModUISpawnVisible then
        cache.ui_spawn:RemoveFromParent()
        ModUISpawnVisible = false
    else
        cache.ui_spawn:AddToViewport(100)
        ModUISpawnVisible = true
    end
end

------------------------------------------------------------------------------
function SpawnActorByClassPath(FullClassPath, SpawnLocation, SpawnRotation, SpawnScale)
    -- TODO Load missing assets!
    -- WARN Only spawns loaded assets now!
    if FullClassPath == nil or FullClassPath == "" then
        ErrLogf("Invalid ClassPath [%s] for actor, cannot spawn!\n", tostring(FullClassPath))
        return
    end
    local DefaultScaleMultiplier = { X = 1.0, Y = 1.0, Z = 1.0 }
    local SpawnScaleMultiplier = SpawnScale == nil and DefaultScaleMultiplier or SpawnScale
    local DefaultRotation = { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }
    local CurrentRotation = SpawnRotation == nil and DefaultRotation or SpawnRotation
    local ActorClass = StaticFindObject(FullClassPath)
    if ActorClass == nil or not ActorClass:IsValid() then error("[ERROR] ActorClass is not valid") end
    local isNPC = FullClassPath:contains("/Game/Character/Blueprints/")
    local World = myGetPlayerController():GetWorld()
    if World == nil or not World:IsValid() then error("[ERROR] World is not valid") end
    local Actor = World:SpawnActor(ActorClass, SpawnLocation, CurrentRotation)
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
        else
            -- We don't really care if this is a weapon, but we try anyway
            -- Some actors already have non-default scale, so we don't override that
            -- Yes, it is not a good idea to compare floats like this, but we do 0.1 increments so this is fine (c)
            if SpawnScale ~= nil then
                Actor:SetActorScale3D(SpawnScale)
            end
        end
        Logf("Spawned Actor: %s at {X=%.3f, Y=%.3f, Z=%.3f} rotation {Pitch=%.3f, Yaw=%.3f, Roll=%.3f}\n",
            Actor:GetFullName(), SpawnLocation.X, SpawnLocation.Y, SpawnLocation.Z,
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
-- The location is retrieved using a less documented approach of K2_GetActorLocation()
function GetPlayerLocation()
    local FirstPlayerController = myGetPlayerController()
    if not FirstPlayerController then
        return { X = 0.0, Y = 0.0, Z = 0.0 }
    end
    local Pawn = FirstPlayerController.Pawn
    local location = Pawn:K2_GetActorLocation()
    return location
end

function GetPlayerViewRotation()
    local FirstPlayerController = myGetPlayerController()
    if not FirstPlayerController then
        return { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }
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
        local SpawnLocation = {
            X = PlayerLocation.X + rotatedDelta.x,
            Y = PlayerLocation.Y + rotatedDelta.y,
            Z = PlayerLocation.Z + rotatedDelta.z
        }
        ExecuteWithDelay((index - 1) * 300, function()
            ExecuteInGameThread(function()
                _ = SpawnActorByClassPath(value, SpawnLocation)
            end)
        end)
        rotatedDelta:rotate(rotator)
    end
end

-- Try to spawn the actor(item) in front of the player
-- Get player's rotation vector and rotate our offset by its value
function SpawnActorInFrontOfPlayer(classpath, offset, lookingAtPlayer, scale)
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
    local SpawnRotation = lookingAtPlayer and lookingAtPlayerRotation or { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }
    local SpawnScale = scale == nil and { X = 1.0, Y = 1.0, Z = 1.0 } or scale
    ExecuteInGameThread(function()
        _ = SpawnActorByClassPath(classpath, SpawnLocation, SpawnRotation, SpawnScale)
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
-- Killing is actually despawning for now
-- That is OK as the weapons get dropped on the ground
function KillAllNPCs()
    -- First the ones spawned by player
    UndoAllPlayerSpawnedCharacters()
    -- Then the ones spawned by the game
    if cache.map['Enemy Array'] then
        local npc = cache.map['Enemy Array']
        -- Logf("Enemy Array: %s\n", tostring(npc))
        -- Logf("Enemy Array size: %d\n", npc:GetArrayNum())
        if npc:GetArrayNum() > 0 then
            npc:ForEach(function(Index, Elem)
                if npc:IsValid() then
                    Logf("Destroying NPC [%i]: %s\n", Index - 1, Elem:get():GetFullName())
                    Elem:get():K2_DestroyActor()
                end
            end)
        end
    end
    -- Then the boss if we are in a boss arena and the boss is alive
    -- The killing of the boss will not count as a player kill, though
    if cache.map['Current Boss Arena'] then
        if cache.map['Boss Alive'] then
            local boss = cache.map['Current Boss Arena']['Boss']
            if boss:IsValid() then
                Logf("Destroying Boss: %s\n", boss:GetFullName())
                boss:K2_DestroyActor()
            end
        end
    end
end

function FreezeAllNPCs()
    Frozen = not Frozen
    if cache.map['Enemy Array'] then
        local npc = cache.map['Enemy Array']
        if npc:GetArrayNum() > 0 then
            npc:ForEach(function(Index, Elem)
                if npc:IsValid() then
                    Logf("Freezing/Unfreezing NPC [%i]: %s\n", Index - 1, Elem:get():GetFullName())
                    Elem:get()['CustomTimeDilation'] = Frozen and 0.0 or 1.0
                end
            end)
        end
    end
    -- Then freeze the boss if we are in a boss arena and the boss is alive
    if cache.map['Current Boss Arena'] then
        if cache.map['Boss Alive'] then
            local boss = cache.map['Current Boss Arena']['Boss']
            if boss:IsValid() then
                Logf("Freezing Boss: %s\n", boss:GetFullName())
                boss['CustomTimeDilation'] = Frozen and 0.0 or 1.0
            end
        end
    end
    if spawned_things then
        for i = #spawned_things, 1, -1 do
            local actorToFreezeRecord = spawned_things[i]
            local actorToFreeze = actorToFreezeRecord.Object
            if actorToFreeze and actorToFreeze:IsValid() and actorToFreezeRecord.IsCharacter then
                Logf("Despawning NPC actor: %s\n", actorToFreeze:GetFullName())
                actorToFreeze['CustomTimeDilation'] = Frozen and 0.0 or 1.0
            end
        end
    end
    if ModUIHUDVisible then
        cache.ui_hud['HUD_NPCsFrozen_Value'] = Frozen
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
        SpawnActorInFrontOfPlayer(selected_actor, nil, nil, scale)
    else
        SpawnActorInFrontOfPlayer(selected_actor)
    end
    --    end
end

function SpawnSelectedNPC()
    -- Update the flag from the Spawn HUD
    SpawnFrozenNPCs = cache.ui_spawn['HSTM_Flag_SpawnFrozenNPCs']
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
    --Logf("Spawning object key [%s]\n", Selected_Spawn_Object)
    --    if not Selected_Spawn_Object == nil and not Selected_Spawn_Object == "" then
    local selected_actor = all_objects[Selected_Spawn_Object]
    Logf("Spawning object [%s]\n", selected_actor)
    SpawnActorInFrontOfPlayer(selected_actor, { X = 300.0, Y = 0.0, Z = -60.0 })
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

    local file = io.open("Mods\\HalfSwordTrainerMod\\data\\all_armor.txt", "r");
    for line in file:lines() do
        if not line:starts_with('[BAD]') then
            local fkey = ExtractHumanReadableName(line)
            all_armor[fkey] = line
            ComboBox_Armor:AddOption(fkey)
        end
    end
    ComboBox_Armor:SetSelectedIndex(0)
end

function PopulateWeaponComboBox()
    local ComboBox_Weapon = cache.ui_spawn['ComboBox_Weapon']

    local file = io.open("Mods\\HalfSwordTrainerMod\\data\\all_weapons.txt", "r");
    for line in file:lines() do
        if not line:starts_with('[BAD]') then
            local fkey = ExtractHumanReadableName(line)
            all_weapons[fkey] = line
            ComboBox_Weapon:AddOption(fkey)
        end
    end
    ComboBox_Weapon:SetSelectedIndex(0)
end

function PopulateNPCComboBox()
    local ComboBox_NPC = cache.ui_spawn['ComboBox_NPC']

    local file = io.open("Mods\\HalfSwordTrainerMod\\data\\all_characters.txt", "r");
    for line in file:lines() do
        if not line:starts_with('[BAD]') then
            local fkey = ExtractHumanReadableName(line)
            all_characters[fkey] = line
            ComboBox_NPC:AddOption(fkey)
        end
    end
    ComboBox_NPC:SetSelectedIndex(0)
end

function PopulateObjectComboBox()
    local ComboBox_Object = cache.ui_spawn['ComboBox_Object']

    local file = io.open("Mods\\HalfSwordTrainerMod\\data\\all_objects.txt", "r");
    for line in file:lines() do
        if not line:starts_with('[BAD]') then
            local fkey = ExtractHumanReadableName(line)
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

------------------------------------------------------------------------------
function ToggleCrosshair()
    local crosshair = cache.ui_game_hud['Aim']
    if crosshair and crosshair:IsValid() then
        CrosshairVisible = crosshair:GetVisibility() == 0 and true or false
        if CrosshairVisible then
            crosshair:SetVisibility(2)
            CrosshairVisible = false
        else
            crosshair:SetVisibility(0)
            CrosshairVisible = true
        end
    end
end

------------------------------------------------------------------------------
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
    local player = cache.map['Player Willie']
    if player['Fallen'] then
        -- TODO what if the player is laying down? Currently we do nothing
    else
        -- Only jump if the last jump happened long enough ago
        if delta >= deltaJumpCooldown then
            -- Update last successful jump timestamp
            lastJumpTimestamp = curJumpTimestamp
            local mesh = player['Mesh']
            -- The jump impulse value has been selected to jump high enough for a table or boss fence
            -- We also compensate for the current game speed linearly, by decreasing the impulse (otherwise slomo means jump into space)
            local jumpImpulse = 25000.0 * GameSpeed
            mesh:AddImpulse({ X = 0.0, Y = 0.0, Z = jumpImpulse }, FName("None"), true)
        end
    end
end

------------------------------------------------------------------------------
local selectedProjectile = 1
local projectiles = {
    { "CURRENTLY_SELECTED",                                                                                          { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 100 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_Spear.ModularWeaponBP_Spear_C",                 { X = 0.5, Y = 0.5, Z = 0.5 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 100 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tools/BP_Weapon_Tool_Pitchfork_A.BP_Weapon_Tool_Pitchfork_A_C", { X = 0.5, Y = 0.5, Z = 0.5 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 150 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/ModularWeaponBP_Dagger.ModularWeaponBP_Dagger_C",               { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 50 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tools/BP_Weapon_Tool_Axe_C.BP_Weapon_Tool_Axe_C_C",             { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = 0.0, Yaw = 180.0, Roll = 0.0 }, 50 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Tools/BP_Weapon_Tool_Mallet_B.BP_Weapon_Tool_Mallet_B_C",       { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 100 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Improvized/BP_Weapon_Improv_Stool.BP_Weapon_Improv_Stool_C",    { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 150 },
    { "/Game/Assets/Weapons/Blueprints/Built_Weapons/Buckler4.Buckler4_C",                                           { X = 1.0, Y = 1.0, Z = 1.0 }, { Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, 150 },
}

function ShootProjectile()
    local offset = { X = 40.0, Y = 0.0, Z = 0.0 }
    local baseImpulseVector = { X = 50.0, Y = 0.0, Z = 0.0 }
    local PlayerViewRotation = GetPlayerViewRotation()
    local PlayerLocation = GetPlayerLocation()

    local class, scale, baseRotation, forceMultiplier = table.unpack(projectiles[selectedProjectile])

    -- Allow to shoot a weapon from spawn menu, taking into account the scale
    if class == "CURRENTLY_SELECTED" then
        local Selected_Spawn_Weapon = cache.ui_spawn['Selected_Spawn_Weapon']:ToString()
        WeaponScaleMultiplier = cache.ui_spawn['HSTM_Slider_WeaponSize']
        WeaponScaleX = cache.ui_spawn['HSTM_Flag_ScaleX']
        WeaponScaleY = cache.ui_spawn['HSTM_Flag_ScaleY']
        WeaponScaleZ = cache.ui_spawn['HSTM_Flag_ScaleZ']
        local selected_actor = all_weapons[Selected_Spawn_Weapon]
        Logf("Shooting custom weapon [%s]\n", selected_actor)

        if WeaponScaleMultiplier ~= 1.0 then
            scale = {
                X = WeaponScaleX and WeaponScaleMultiplier or 1.0,
                Y = WeaponScaleY and WeaponScaleMultiplier or 1.0,
                Z = WeaponScaleZ and WeaponScaleMultiplier or 1.0
            }
            offset.X = offset.X * WeaponScaleMultiplier
            if WeaponScaleMultiplier > 1.0 then
                forceMultiplier = forceMultiplier * WeaponScaleMultiplier
            end
        else
            -- Just to be safer against longer weapons
            offset.X = offset.X + 10
        end
        class = selected_actor
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
    -- Then address horizonal camera movement as above for spawn location, same for impulse
    ImpulseRotation:rotate(rotator)

    local projectile = SpawnActorByClassPath(class, SpawnLocation, baseRotation, scale)
    -- Correct the spawned projectile rotation by the camera-specific angles
    projectile:K2_SetActorRotation(SpawnRotation, true)

    local impulseMaf = ImpulseRotation
    local impulse = impulseMaf * forceMultiplier
    local impulseUE = maf2vec(impulse)
    -- Don't apply impulse immediately, give the player a chance to see the projectile
    ExecuteWithDelay(200, function()
        projectile['BaseMesh']:AddImpulse(impulseUE, FName("None"), false)
    end)
end

function ChangeProjectile()
    selectedProjectile = math.fmod(selectedProjectile, #projectiles) + 1
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

    RegisterKeyBind(Key.H, function()
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

    RegisterKeyBind(Key.MIDDLE_MOUSE_BUTTON, function()
        ExecuteInGameThread(function()
            ShootProjectile()
        end)
    end)

    RegisterKeyBind(Key.TAB, function()
        ChangeProjectile()
    end)

    -- Also make sure we can still shoot while sprinting with Shift held down
    RegisterKeyBind(Key.MIDDLE_MOUSE_BUTTON, { ModifierKey.SHIFT }, function()
        ExecuteInGameThread(function()
            ShootProjectile()
        end)
    end)

    RegisterKeyBind(Key.TAB, { ModifierKey.SHIFT }, function()
        ChangeProjectile()
    end)


    Log("Keybinds registered\n")
end

------------------------------------------------------------------------------
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
            -- Yes, this is horrible
            if file_size ~= 7819 then
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
