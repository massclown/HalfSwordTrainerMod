-- Half Sword Trainer Mod by massclown

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
local ModUIVisible = true
local ModUIWidgetInstance = nil
-- Instances of classes we need
---@type AWillie_BP_C
local PlayerInstance = nil
---@class AAbyss_Map_Open_C
local WorldMapInstance = nil
-- A flag to prevent the ClientRestart hook to fire twice
local waitingAfterRestartLock = false
-- If restarting, attempt to exit asyc loops
local restarting = false

local VerboseLogging = true
function Log(Message, AlwaysLog)
    if not VerboseLogging and not AlwaysLog then return end
    print("[HalfSwordTrainerMod] " .. Message)
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

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
    restarting = true
    Log("Client Restart hook triggered\n")
    -- Somehow ClientRestart hook always triggers twice on each start or restart.
    -- No idea why, so we just lock and wait, and only do what we need once.
    if not waitingAfterRestartLock then
        waitingAfterRestartLock = not waitingAfterRestartLock
        ExecuteWithDelay(1000, function()
            Log("Delayed caching\n")
            ExecuteInGameThread(function ()
                CacheModUIWidget()
                CacheMapInstance()
                CachePlayerInstance()
                CachePlayerStats()
                CacheLevel()
            end)
            -- Update HP meter forever 5 times per second
            LoopAsync(200, function()
                CachePlayerStats()
                if restarting and not waitingAfterRestartLock then
                    Log("Terminating async loop\n")
                    return true
                end
                return false -- Loops forever
            end)

            waitingAfterRestartLock = false
        end)
    else
        Log("Not caching, lock active\n")
    end
    restarting = false
end)

-- We hook the creation of Character class objects, those are NPCs usually
NotifyOnNewObject("/Script/Engine.Character", function(ConstructedObject)
    Log(string.format("Hook Character spawned: %s\n", ConstructedObject:GetFullName()))
end)

-- Damage hooks are commented for now, not sure which is the correct one to intercept
-- RegisterHook("/Script/Engine.Actor:ReceiveAnyDamage", function(self, Damage, DamageType, InstigatedBy, DamageCauser)
--     Log(string.format("Damage %f\n", Damage:get()))
--     --CachePlayerStats()
-- end)

-- RegisterHook("/Game/Character/Blueprints/Willie_BP.Willie_BP_C:Get Damage", function(self,
--         Impulse,Velocity,Location,Normal,bone,Raw_Damage,Cutting_Power,Inside,Damaged_Mesh,Dism_Blunt,Lower_Threshold,Shockwave,Hit_By_Component,Damage_Out
--     )
--     Log(string.format("Damage %f %f\n", Raw_Damage:get(), Damage_Out:get()))
--     CachePlayerStats()
-- end)

function CacheMapInstance()
    ---@class AAbyss_Map_Open_C
    local Map = FindFirstOf("Abyss_Map_Open_C")
    if Map then
        WorldMapInstance = Map
        --Log("World isntance cached\n")
    end
end

function CachePlayerInstance()
    if WorldMapInstance then
        ---@type AWillie_BP_C
        PlayerInstance = WorldMapInstance['Player Willie']
        --Log("Player instance cached\n")
    end
end

function CacheModUIWidget()
    ModUIWidgetInstance = FindFirstOf("HSTM_UI_Widget_C")
    Log("Mod UI isntance cached\n")
    SetTextBoxText("TextBox_SuperStrength", string.format("Super Strength : %s", SuperStrength and "ON" or "OFF"))
    SetTextBoxText("TextBox_Invulnerability",
        string.format("Invulnerability : %s", Invulnerable and "ON" or "OFF"))
end

function CachePlayerStats()
    CachePlayerInstance()
    if PlayerInstance then
        PlayerHealth = PlayerInstance['Health']
        if PlayerHealth then
            SetTextBoxText("TextBox_HP", string.format("HP : %.2f", PlayerHealth))
        else
            Log("[ERROR] Bad PlayerHealth received\n")
        end
        Invulnerable = PlayerInstance['Invulnerable']
        SetTextBoxText("TextBox_Invulnerability",
            string.format("Invulnerability : %s", Invulnerable and "ON" or "OFF"))
        --
        PlayerScore = WorldMapInstance['Score']
        SetTextBoxText("TextBox_Score", string.format("Score : %d", PlayerScore))
        PlayerConsciousness = PlayerInstance['Consciousness']
        SetTextBoxText("TextBox_Cons", string.format("Consciousness : %.2f", PlayerConsciousness))

        --
        HH  = PlayerInstance['Head Health']
        NH  = PlayerInstance['Neck Health']
        BH  = PlayerInstance['Body Health']
        ARH = PlayerInstance['Arm_R Health']
        ALH = PlayerInstance['Arm_L Health']
        LRH = PlayerInstance['Leg_R Health']
        LLH = PlayerInstance['Leg_L Health']
        --
        SetTextBoxText("TextBox_HH", string.format("%.0f", HH))
        SetTextBoxText("TextBox_NH", string.format("%.0f", NH))
        SetTextBoxText("TextBox_BH", string.format("%.0f", BH))
        SetTextBoxText("TextBox_ARH", string.format("%.0f", ARH))
        SetTextBoxText("TextBox_ALH", string.format("%.0f", ALH))
        SetTextBoxText("TextBox_LRH", string.format("%.0f", LRH))
        SetTextBoxText("TextBox_LLH", string.format("%.0f", LLH))
        --
        HJH  = PlayerInstance['Head Joint Health']
        TJH  = PlayerInstance['Torso Joint Health']
        HRJH = PlayerInstance['Hand R Joint Health']
        ARJH = PlayerInstance['Arm R Joint Health']
        SRJH = PlayerInstance['Shoulder R Joint Health']
        HLJH = PlayerInstance['Hand L Joint Health']
        ALJH = PlayerInstance['Arm L Joint Health']
        SLJH = PlayerInstance['Shoulder L Joint Health']
        TRJH = PlayerInstance['Thigh R Joint Health']
        LRJH = PlayerInstance['Leg R Joint Health']
        FRJH = PlayerInstance['Foot R Joint Health']
        TLJH = PlayerInstance['Thigh L Joint Health']
        LLJH = PlayerInstance['Leg L Joint Health']
        FLJH = PlayerInstance['Foot L Joint Health']
        --
        SetTextBoxText("TextBox_HJH", string.format("%.0f", HJH))
        SetTextBoxText("TextBox_TJH", string.format("%.0f", TJH))
        SetTextBoxText("TextBox_HRJH", string.format("%.0f", HRJH))
        SetTextBoxText("TextBox_ARJH", string.format("%.0f", ARJH))
        SetTextBoxText("TextBox_SRJH", string.format("%.0f", SRJH))
        SetTextBoxText("TextBox_HLJH", string.format("%.0f", HLJH))
        SetTextBoxText("TextBox_ALJH", string.format("%.0f", ALJH))
        SetTextBoxText("TextBox_SLJH", string.format("%.0f", SLJH))
        SetTextBoxText("TextBox_TRJH", string.format("%.0f", TRJH))
        SetTextBoxText("TextBox_LRJH", string.format("%.0f", LRJH))
        SetTextBoxText("TextBox_FRJH", string.format("%.0f", FRJH))
        SetTextBoxText("TextBox_TLJH", string.format("%.0f", TLJH))
        SetTextBoxText("TextBox_LLJH", string.format("%.0f", LLJH))
        SetTextBoxText("TextBox_FLJH", string.format("%.0f", FLJH))
        --
    end
    CacheLevel()
end

function ToggleSuperStrength()
    CachePlayerInstance()
    if PlayerInstance then
        SuperStrength = not SuperStrength
        if SuperStrength then
            savedRSR = PlayerInstance['Running Speed Rate']
            savedMP = PlayerInstance['Muscle Power']
            PlayerInstance['Running Speed Rate'] = maxRSR
            PlayerInstance['Muscle Power'] = maxMP
        else
            PlayerInstance['Running Speed Rate'] = savedRSR
            PlayerInstance['Muscle Power'] = savedMP
        end
        Log("SuperStrength = " .. tostring(SuperStrength) .. "\n")
        SetTextBoxText("TextBox_SuperStrength", string.format("Super Strength : %s", SuperStrength and "ON" or "OFF"))
    end
end

function ToggleInvulnerability()
    CachePlayerInstance()
    if PlayerInstance then
        ---@type boolean
        Invulnerable = PlayerInstance['Invulnerable']
        Invulnerable = not Invulnerable
        if Invulnerable then
            savedRegenRate = PlayerInstance['Regen Rate']
            PlayerInstance['Regen Rate'] = maxRegenRate
        else
            PlayerInstance['Regen Rate'] = savedRegenRate
        end
        PlayerInstance['Invulnerable'] = Invulnerable
        Log("Invulnerable = " .. tostring(Invulnerable) .. "\n")
        SetTextBoxText("TextBox_Invulnerability",
            string.format("Invulnerability : %s", Invulnerable and "ON" or "OFF"))
    end
end

function ToggleModUI()
    if ModUIWidgetInstance then
        if ModUIVisible then
            ModUIWidgetInstance:RemoveFromParent()
            ModUIVisible = false
        else
            ModUIWidgetInstance:AddToViewport(99)
            ModUIVisible = true
        end
    end
end

--[[
    TextBox_HP
    TextBox_Level
    TextBox_Invulnerability
    TextBox_SuperStrength
]]
function SetTextBoxText(TextBoxName, TextString)
    if ModUIWidgetInstance then
        local textbox = ModUIWidgetInstance[TextBoxName]
        if textbox then
            textbox:SetText(FText(TextString))
        else
            Log(string.format("[ERROR] TextBox %s not found\n", TextBoxName))
        end
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

function SetLevel(Level)
    if WorldMapInstance then
        WorldMapInstance['Level'] = Level
        Log(string.format("Set Level = %d\n", Level))
        SetTextBoxText("TextBox_Level", string.format("Level : %d", level))
    else
        Log("[ERROR] No Map found")
    end
end

function CacheLevel()
    if WorldMapInstance then
        level = WorldMapInstance['Level']
        SetTextBoxText("TextBox_Level", string.format("Level : %d", level))
    else
        Log("[ERROR] No Map found")
    end
end

function DecreaseLevel()
    CacheLevel()
    if level > 0 then
        level = level - 1
        SetLevel(level)
    end
end

function IncreaseLevel()
    CacheLevel()
    if level < 6 then
        level = level + 1
        SetLevel(level)
    end
end

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
