-- Half Sword Trainer Mod v0.3 by massclown
-- Needs UE4SS to work and a Blueprint mod HSTM_UI (see repo)

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

function Log(Message)
    print("[HalfSwordTrainerMod] " .. Message)
end

function Logf(...)
    print("[HalfSwordTrainerMod] " .. string.format(...))
end

function ErrLog(Message)
    print("[HalfSwordTrainerMod] [ERROR]" .. Message)
end

function ErrLogf(...)
    print("[HalfSwordTrainerMod] [ERROR]" .. string.format(...))
end

-- Just some high-tier loadout I like, all the best armor, a huge shield, long polearm and two one-armed swords.
local loadout = {
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
            newObj = nil
            ErrLogf("Failed to find and cache object [%s][%s], retrying...\n", key, className)
        end
        obj.objects[key] = newObj
    end
    return newObj
end
setmetatable(cache, cache.mt)
-----------------------------

local lastInitTimestamp = -1
-- This gets added to the hook later
function InitMyMod()
    local curInitTimestamp = os.clock()
    local delta = curInitTimestamp - lastInitTimestamp
    if lastInitTimestamp == -1 or (delta > 1) then
        Log("Client Restart hook triggered\n")
        local map = cache.map
        local ui_hud = cache.ui_hud
        local ui_spawn = cache.ui_spawn
        if not map or not map:IsValid() then
            ErrLog("Map not found!\n")
            return
        end
        if not ui_hud or not ui_hud:IsValid() then
            ErrLog("UI HUD Widget not found!\n")
            return
        end
        if not ui_spawn or not ui_spawn:IsValid() then
            ErrLog("UI Spawn Widget not found!\n")
            return
        end
        LoopAsync(250, function()
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
-- and writing them into the textboxes of the UI Widget that we use as a mod's HUD
function HUD_UpdatePlayerStats()
    local player = cache.map['Player Willie']
    PlayerHealth = player['Health']
    SetTextBoxText(cache.ui_hud, "TextBox_HP", string.format("HP : %.2f", PlayerHealth))
    Invulnerable = player['Invulnerable']
    SetTextBoxText(cache.ui_hud, "TextBox_Invulnerability",
        string.format("Invulnerability : %s", Invulnerable and "ON" or "OFF"))

    SetTextBoxText(cache.ui_hud, "TextBox_SuperStrength",
        string.format("Super Strength : %s", SuperStrength and "ON" or "OFF"))

    --
    PlayerScore = cache.map['Score']
    SetTextBoxText(cache.ui_hud, "TextBox_Score", string.format("Score : %d", PlayerScore))
    PlayerConsciousness = player['Consciousness']
    SetTextBoxText(cache.ui_hud, "TextBox_Cons", string.format("Consciousness : %.2f", PlayerConsciousness))

    --
    HH  = player['Head Health']
    NH  = player['Neck Health']
    BH  = player['Body Health']
    ARH = player['Arm_R Health']
    ALH = player['Arm_L Health']
    LRH = player['Leg_R Health']
    LLH = player['Leg_L Health']
    --
    SetTextBoxText(cache.ui_hud, "TextBox_HH", string.format("%.0f", HH))
    SetTextBoxText(cache.ui_hud, "TextBox_NH", string.format("%.0f", NH))
    SetTextBoxText(cache.ui_hud, "TextBox_BH", string.format("%.0f", BH))
    SetTextBoxText(cache.ui_hud, "TextBox_ARH", string.format("%.0f", ARH))
    SetTextBoxText(cache.ui_hud, "TextBox_ALH", string.format("%.0f", ALH))
    SetTextBoxText(cache.ui_hud, "TextBox_LRH", string.format("%.0f", LRH))
    SetTextBoxText(cache.ui_hud, "TextBox_LLH", string.format("%.0f", LLH))
    --
    HJH  = player['Head Joint Health']
    TJH  = player['Torso Joint Health']
    HRJH = player['Hand R Joint Health']
    ARJH = player['Arm R Joint Health']
    SRJH = player['Shoulder R Joint Health']
    HLJH = player['Hand L Joint Health']
    ALJH = player['Arm L Joint Health']
    SLJH = player['Shoulder L Joint Health']
    TRJH = player['Thigh R Joint Health']
    LRJH = player['Leg R Joint Health']
    FRJH = player['Foot R Joint Health']
    TLJH = player['Thigh L Joint Health']
    LLJH = player['Leg L Joint Health']
    FLJH = player['Foot L Joint Health']
    --
    SetTextBoxText(cache.ui_hud, "TextBox_HJH", string.format("%.0f", HJH))
    SetTextBoxText(cache.ui_hud, "TextBox_TJH", string.format("%.0f", TJH))
    SetTextBoxText(cache.ui_hud, "TextBox_HRJH", string.format("%.0f", HRJH))
    SetTextBoxText(cache.ui_hud, "TextBox_ARJH", string.format("%.0f", ARJH))
    SetTextBoxText(cache.ui_hud, "TextBox_SRJH", string.format("%.0f", SRJH))
    SetTextBoxText(cache.ui_hud, "TextBox_HLJH", string.format("%.0f", HLJH))
    SetTextBoxText(cache.ui_hud, "TextBox_ALJH", string.format("%.0f", ALJH))
    SetTextBoxText(cache.ui_hud, "TextBox_SLJH", string.format("%.0f", SLJH))
    SetTextBoxText(cache.ui_hud, "TextBox_TRJH", string.format("%.0f", TRJH))
    SetTextBoxText(cache.ui_hud, "TextBox_LRJH", string.format("%.0f", LRJH))
    SetTextBoxText(cache.ui_hud, "TextBox_FRJH", string.format("%.0f", FRJH))
    SetTextBoxText(cache.ui_hud, "TextBox_TLJH", string.format("%.0f", TLJH))
    SetTextBoxText(cache.ui_hud, "TextBox_LLJH", string.format("%.0f", LLJH))
    SetTextBoxText(cache.ui_hud, "TextBox_FLJH", string.format("%.0f", FLJH))
    --
    HUD_CacheLevel()
end

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
    SetTextBoxText(cache.ui_hud, "TextBox_SuperStrength",
        string.format("Super Strength : %s", SuperStrength and "ON" or "OFF"))
end

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
    SetTextBoxText(cache.ui_hud, "TextBox_Invulnerability",
        string.format("Invulnerability : %s", Invulnerable and "ON" or "OFF"))
end

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

--[[
    TextBox_HP
    TextBox_Level
    TextBox_Invulnerability
    TextBox_SuperStrength
]]
function SetTextBoxText(Widget, TextBoxName, TextString)
    local textbox = Widget[TextBoxName]
    if textbox then
        textbox:SetText(FText(TextString))
    else
        Log(string.format("[ERROR] TextBox %s not found\n", TextBoxName))
    end
end

function SpawnActorByClassPath(FullClassPath, SpawnLocation)
    -- TODO Load missing assets
    -- WARN only spawns loaded assets now!
    --
    local ActorClass = StaticFindObject(FullClassPath)
    if not ActorClass:IsValid() then error("[ERROR] ActorClass is not valid") end

    local World = UEHelpers:GetWorld()
    if not World:IsValid() then error("[ERROR] World is not valid") end
    local Actor = World:SpawnActor(ActorClass, SpawnLocation, {})
    if not Actor:IsValid() then
        Log(string.format("[ERROR] Actor for \"%s\" is not valid\n", FullClassPath))
    else
        Log(string.format("Spawned Actor: %s at {X=%.3f, Y=%.3f, Z=%.3f}\n",
            Actor:GetFullName(), SpawnLocation.X, SpawnLocation.Y, SpawnLocation.Z))
    end
end

function GetPlayerLocation()
    local FirstPlayerController = UEHelpers:GetPlayerController()
    if not FirstPlayerController then
        return { X = 0.0, Y = 0.0, Z = 0.0 }
    end
    local Pawn = FirstPlayerController.Pawn
    local location = Pawn:K2_GetActorLocation()
    return location
end

-- We spawn the loadout in a circle, rotating a displacement vector a bit
-- with every item
function SpawnLoadoutAroundPlayer()
    local PlayerLocation = GetPlayerLocation()
    local DeltaLocation = maf.vec3(300.0, 0.0, 200.0)
    local rotatedDelta = DeltaLocation
    local rotator = maf.rotation.fromAngleAxis(0.45, 0.0, 0.0, 1.0)
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

function HUD_SetLevel(Level)
    cache.map['Level'] = Level
    Log(string.format("Set Level = %d\n", Level))
    SetTextBoxText(cache.ui_hud, "TextBox_Level", string.format("Level : %d", level))
end

function HUD_CacheLevel()
    level = cache.map['Level']
    SetTextBoxText(cache.ui_hud, "TextBox_Level", string.format("Level : %d", level))
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
function PopulateArmorComboBox()

end

function PopulateWeaponComboBox()

end

function PopulateNPCComboBox()

end

function PopulateObjectComboBox()

end

------------------------------------------------------------------------------
-- We hook the restart event, which somehow fires twice per restart
RegisterHook("/Script/Engine.PlayerController:ClientRestart", InitMyMod)

-- We hook the creation of Character class objects, those are NPCs usually
NotifyOnNewObject("/Script/Engine.Character", function(ConstructedObject)
    Log(string.format("Hook Character spawned: %s\n", ConstructedObject:GetFullName()))
end)

-- Damage hooks are commented for now, not sure which is the correct one to intercept
-- RegisterHook("/Script/Engine.Actor:ReceiveAnyDamage", function(self, Damage, DamageType, InstigatedBy, DamageCauser)
--     Log(string.format("Damage %f\n", Damage:get()))
-- end)

-- RegisterHook("/Game/Character/Blueprints/Willie_BP.Willie_BP_C:Get Damage", function(self,
--         Impulse,Velocity,Location,Normal,bone,Raw_Damage,Cutting_Power,Inside,Damaged_Mesh,Dism_Blunt,Lower_Threshold,Shockwave,Hit_By_Component,Damage_Out
--     )
--     Log(string.format("Damage %f %f\n", Raw_Damage:get(), Damage_Out:get()))
-- end)

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
