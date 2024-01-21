-- Half Sword Trainer Mod v0.4 by massclown
-- https://github.com/massclown/HalfSwordTrainerMod
-- Requirements: UE4SS 2.5.2 (or newer) a Blueprint mod HSTM_UI (see repo)

local maf = require 'maf'
local UEHelpers = require("UEHelpers")

-- Saved copies of player stats before buffs
local savedRSR = 0
local savedMP = 0
local savedRegenRate = 0
-- Our buffed stats that we set
local maxRSR = 1000
local maxMP = 200
local maxRegenRate = 10000

-- Variables tracking things we change or want to observe and display in HUD
local SuperStrength = false
local Invulnerable = false
local level = 0
local PlayerScore = 0
local PlayerHealth = 0
local PlayerConsciousness = 0

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

local spawnedThings = {}

-- The actors from the hook
local intercepted_actors = {}
-- The NPC actors that we spawned
local spawned_actors = {}

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
-- The caching code logic is taken from TheLich at nexusmods (Grounded QoL mod)
local cache = {}
cache.objects = {}
cache.names = {
    --    ["engine"] = { "Engine", false },
    --    ["kismet"] = { "/Script/Engine.Default__KismetSystemLibrary", true },
    ["map"] = { "Abyss_Map_Open_C", false },
    ["ui_hud"] = { "HSTM_UI_HUD_Widget_C", false },
    ["ui_spawn"] = { "HSTM_UI_Spawn_Widget_C", false }
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
function ValidateCachedObjects()
    local map = cache.map
    local ui_hud = cache.ui_hud
    local ui_spawn = cache.ui_spawn
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
    return true
end

-- Timestamp of last invocation of InitMyMod()
local lastInitTimestamp = -1
-- This function gets added to the game restart hook below.
-- Somehow the hook gets triggered twice, so we try to have a time lock to avoid double-calling the init function,
-- but we still have to call it once if the user restarts soon, hence the miminum timeout of that 1 second.
-- So don't restart faster than once every two seconds, or this will break too.
function InitMyMod()
    local curInitTimestamp = os.clock()
    local delta = curInitTimestamp - lastInitTimestamp
    if lastInitTimestamp == -1 or (delta > 1) then
        Log("Client Restart hook triggered\n")

        if not ValidateCachedObjects() then
            ErrLog("Objects not found, exiting\n")
            return
        end

        LoadCustomLoadout()

        PopulateArmorComboBox()
        PopulateWeaponComboBox()
        PopulateNPCComboBox()
        PopulateObjectComboBox()

        if intercepted_actors then
            intercepted_actors = {}
        end

        if spawnedThings then
            spawnedThings = {}
        end

        if spawned_actors then
            spawned_actors = {}
        end

        -- This starts a thread that updates the HUD in background.
        -- It only exits if we retrn true from the lambda, which we don't
        LoopAsync(250, function()
            if not ValidateCachedObjects() then
                ErrLog("Objects not found, skipping loop\n")
                return false
            end
            HUD_UpdatePlayerStats()
            return false
        end)
        Log("HUD update loop started\n")
    else
        Logf("Client Restart hook skipped, too early %.3f seconds passed\n", delta)
    end
    lastInitTimestamp = curInitTimestamp
end

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
    HJH                                     = player['Head Joint Health']
    TJH                                     = player['Torso Joint Health']
    HRJH                                    = player['Hand R Joint Health']
    ARJH                                    = player['Arm R Joint Health']
    SRJH                                    = player['Shoulder R Joint Health']
    HLJH                                    = player['Hand L Joint Health']
    ALJH                                    = player['Arm L Joint Health']
    SLJH                                    = player['Shoulder L Joint Health']
    TRJH                                    = player['Thigh R Joint Health']
    LRJH                                    = player['Leg R Joint Health']
    FRJH                                    = player['Foot R Joint Health']
    TLJH                                    = player['Thigh L Joint Health']
    LLJH                                    = player['Leg L Joint Health']
    FLJH                                    = player['Foot L Joint Health']
    --
    cache.ui_hud['HUD_HJH']                 = math.floor(HJH)
    cache.ui_hud['HUD_TJH']                 = math.floor(TJH)
    cache.ui_hud['HUD_HRJH']                = math.floor(HRJH)
    cache.ui_hud['HUD_ARJH']                = math.floor(ARJH)
    cache.ui_hud['HUD_SRJH']                = math.floor(SRJH)
    cache.ui_hud['HUD_HLJH']                = math.floor(HLJH)
    cache.ui_hud['HUD_ALJH']                = math.floor(ALJH)
    cache.ui_hud['HUD_SLJH']                = math.floor(SLJH)
    cache.ui_hud['HUD_TRJH']                = math.floor(TRJH)
    cache.ui_hud['HUD_LRJH']                = math.floor(LRJH)
    cache.ui_hud['HUD_FRJH']                = math.floor(FRJH)
    cache.ui_hud['HUD_TLJH']                = math.floor(TLJH)
    cache.ui_hud['HUD_LLJH']                = math.floor(LLJH)
    cache.ui_hud['HUD_FLJH']                = math.floor(FLJH)

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
    cache.ui_hud['HUD_SuperStrength_Value'] = SuperStrength
end

------------------------------------------------------------------------------
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
    cache.ui_hud['HUD_Invuln_Value'] = Invulnerable
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
function SpawnActorByClassPath(FullClassPath, SpawnLocation, SpawnRotation)
    -- TODO Load missing assets!
    -- WARN Only spawns loaded assets now!
    local DefaultRotation = {Pitch = 0.0, Yaw = 0.0, Roll = 0.0}
    local CurrentRotation = SpawnRotation == nil and DefaultRotation or SpawnRotation
    local ActorClass = StaticFindObject(FullClassPath)
    if ActorClass == nil or not ActorClass:IsValid() then error("[ERROR] ActorClass is not valid") end

    local World = UEHelpers:GetWorld()
    if World == nil or not World:IsValid() then error("[ERROR] World is not valid") end
    local Actor = World:SpawnActor(ActorClass, SpawnLocation, CurrentRotation)
    if Actor == nil or not Actor:IsValid() then
        Logf("[ERROR] Actor for \"%s\" is not valid\n", FullClassPath)
    else
        if spawnedThings then
            table.insert(spawnedThings, Actor)
        end
        Logf("Spawned Actor: %s at {X=%.3f, Y=%.3f, Z=%.3f} rotation {Pitch=%.3f, Yaw=%.3f, Roll=%.3f}\n",
            Actor:GetFullName(), SpawnLocation.X, SpawnLocation.Y, SpawnLocation.Z,
            CurrentRotation.Pitch, CurrentRotation.Yaw, CurrentRotation.Roll)
    end
end

-- Should also undo all spawned things if called repeatedly
function UndoLastSpawn()
    if spawnedThings then
        if #spawnedThings > 0 then
            local actorToDespawn = spawnedThings[#spawnedThings]
            if actorToDespawn and actorToDespawn:IsValid() then
                Logf("Despawning actor: %s\n", actorToDespawn:GetFullName())
                --                actorToDespawn:Destroy()
                actorToDespawn:K2_DestroyActor()
                -- let's remove it for now so undo can be repeated.
                -- K2_DestroyActor() is supposed to clean up things properly
                table.remove(spawnedThings, #spawnedThings)
            end
        end
    end
end

-- The location is retrieved using a less documented approach of K2_GetActorLocation()
function GetPlayerLocation()
    local FirstPlayerController = UEHelpers:GetPlayerController()
    if not FirstPlayerController then
        return { X = 0.0, Y = 0.0, Z = 0.0 }
    end
    local Pawn = FirstPlayerController.Pawn
    local location = Pawn:K2_GetActorLocation()
    return location
end

function GetPlayerViewRotation()
    local FirstPlayerController = UEHelpers:GetPlayerController()
    if not FirstPlayerController then
        return { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }
    end
    local rotation = FirstPlayerController['ControlRotation']
    return rotation
end

-- We spawn the loadout in a circle, rotating a displacement vector a bit
-- with every item, so they all fit nicely
-- (loadout is 14 items so 0.4 radian is OK for 14*angle < 2*pi radians total)
function SpawnLoadoutAroundPlayer()
    local PlayerLocation = GetPlayerLocation()
    local DeltaLocation = maf.vec3(300.0, 0.0, 200.0)
    local rotatedDelta = DeltaLocation
    local rotator = maf.rotation.fromAngleAxis(0.45, 0.0, 0.0, 1.0)
    local loadout = default_loadout
    if #custom_loadout > 0 then
        loadout = custom_loadout
        Logf("Spawning custom loadout...\n")
    end
    for index, value in ipairs(loadout) do
        local SpawnLocation = {
            X = PlayerLocation.X + rotatedDelta.x,
            Y = PlayerLocation.Y + rotatedDelta.y,
            Z = PlayerLocation.Z + rotatedDelta.z
        }
        ExecuteWithDelay((index - 1) * 300, function()
            ExecuteInGameThread(function()
                SpawnActorByClassPath(value, SpawnLocation)
            end)
        end)
        rotatedDelta:rotate(rotator)
    end
end

-- Try to spawn the actor(item) in front of the player
-- Get player's rotation vector and rotate our offset by its value
function SpawnActorInFrontOfPlayer(classpath, offset, lookingAtPlayer)
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
    local lookingAtPlayerRotation = {Yaw = 180 + PlayerRotation.Yaw, Pitch = 0, Roll = 0}
    local SpawnRotation = lookingAtPlayer and lookingAtPlayerRotation or {}
    ExecuteInGameThread(function()
        SpawnActorByClassPath(classpath, SpawnLocation, SpawnRotation)
    end)
end

------------------------------------------------------------------------------
function HUD_SetLevel(Level)
    cache.map['Level'] = Level
    Logf("Set Level = %d\n", Level)
    cache.ui_hud['HUD_Level_Value'] = Level
end

function HUD_CacheLevel()
    level = cache.map['Level']
    cache.ui_hud['HUD_Level_Value'] = level
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
function KillAllNPCs()
    if intercepted_actors then
        for index, actor in ipairs(intercepted_actors) do
            -- Very crude hack: ignore the earliest N spawned actors
            -- up to N == the number of despawned NPC
            -- We should probably look at map['Enemy Array'] instead?
            if actor ~= nil and actor:IsValid() and index > cache.map['Enemies Despawned'] then
                Logf("Destroying actor [%s]\n", actor:GetFullName())
                actor:K2_DestroyActor()
            end
        end
    end
end

function FreezeAllNPCs()
    -- TODO
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
    --Logf("Spawning weapon key [%s]\n", Selected_Spawn_Weapon)
    --    if not Selected_Spawn_Weapon == nil and not Selected_Spawn_Weapon == "" then
    local selected_actor = all_weapons[Selected_Spawn_Weapon]
    Logf("Spawning weapon [%s]\n", selected_actor)
    SpawnActorInFrontOfPlayer(selected_actor)
    --    end
end

function SpawnSelectedNPC()
    local Selected_Spawn_NPC = cache.ui_spawn['Selected_Spawn_NPC']:ToString()
    --Logf("Spawning NPC key [%s]\n", Selected_Spawn_NPC)
    --    if not Selected_Spawn_NPC == nil and not Selected_Spawn_NPC == "" then
    local selected_actor = all_characters[Selected_Spawn_NPC]
    Logf("Spawning NPC [%s]\n", selected_actor)
    SpawnActorInFrontOfPlayer(selected_actor, { X = 800.0, Y = 0.0, Z = 50.0 }, true)
    -- The last spawned actor is probably the NPC we just spawned
    table.insert(spawned_actors, spawnedThings[#spawnedThings])
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
function SpawnBossArena()
    local PlayerLocation = GetPlayerLocation()
    local SpawnLocation = PlayerLocation
    SpawnLocation.Z = 0
    local FullClassPath = "/Game/Blueprints/Spawner/BossFight_Arena_BP.BossFight_Arena_BP_C"
    Log("Spawning Boss Arena\n")
    local arena = SpawnActorByClassPath(FullClassPath, SpawnLocation)
end

------------------------------------------------------------------------------
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
-- We hook the restart event, which somehow fires twice per restart
-- We take care of that in the InitMyMod() function above
RegisterHook("/Script/Engine.PlayerController:ClientRestart", InitMyMod)
------------------------------------------------------------------------------

-- We hook the creation of Character class objects, those are NPCs usually
NotifyOnNewObject("/Script/Engine.Character", function(ConstructedObject)
    if intercepted_actors then
        table.insert(intercepted_actors, ConstructedObject)
    end
    Logf("Hook Character spawned: %s\n", ConstructedObject:GetFullName())
end)
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
------------------------------------------------------------------------------

-- Trying to hook the button click functions of the HSTM_UI blueprint:
-- * HSTM_SpawnArmor
-- * HSTM_SpawnWeapon
-- * HSTM_SpawnNPC
-- * HSTM_SpawnObject
-- * HSTM_UndoSpawn
-- * HSTM_KillAllNPCs
-- Those are defined as custom functions in the blueprint itself.
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

RegisterCustomEvent("HSTM_UndoSpawn", function(ParamContext, ParamMessage)
    UndoLastSpawn()
end)

RegisterCustomEvent("HSTM_KillAllNPCs", function(ParamContext, ParamMessage)
    KillAllNPCs()
end)
------------------------------------------------------------------------------
-- The user-facing key bindings are below.
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

-- Does not work yet
RegisterKeyBind(Key.Z, function()
    FreezeAllNPCs()
end)

RegisterKeyBind(Key.B, function()
    SpawnBossArena()
end)

-- EOF
