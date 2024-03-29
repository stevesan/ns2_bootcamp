// ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
//
// lua\Weapons\Marine\Welder.lua
//
//    Created by:   Andreas Urwalek (a_urwa@sbox.tugraz.at)
//
//    Weapon used for repairing structures and armor of friendly players (marines, exosuits, jetpackers).
//    Uses hud slot 3 (replaces axe)
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/Weapons/Weapon.lua")
Script.Load("lua/PickupableWeaponMixin.lua")

class 'Welder' (Weapon)

Welder.kMapName = "welder"

Welder.kModelName = PrecacheAsset("models/marine/welder/welder.model")
local kViewModelName = PrecacheAsset("models/marine/welder/welder_view.model")
local kAnimationGraph = PrecacheAsset("models/marine/welder/welder_view.animation_graph")

kWelderHUDSlot = 3

local kWelderTraceExtents = Vector(0.4, 0.4, 0.4)

local networkVars =
{
    welding = "boolean",
    loopingSoundEntId = "entityid"
}

local kWeldRange = 2.4
local kWelderEffectRate = 0.45

local kFireLoopingSound = PrecacheAsset("sound/NS2.fev/marine/welder/weld")

function Welder:OnCreate() 

    Weapon.OnCreate(self)
    
    self.welding = false
    
    InitMixin(self, PickupableWeaponMixin)
    
    self.loopingSoundEntId = Entity.invalidId
    
    if Server then
    
        self.loopingFireSound = Server.CreateEntity(SoundEffect.kMapName)
        self.loopingFireSound:SetAsset(kFireLoopingSound)
        // SoundEffect will automatically be destroyed when the parent is destroyed (the Welder).
        self.loopingFireSound:SetParent(self)
        self.loopingSoundEntId = self.loopingFireSound:GetId()
        
    end
    
end

function Welder:OnInitialized()

    self:SetModel(Welder.kModelName)
    
    Weapon.OnInitialized(self)
    
    self.timeWeldStarted = 0
    self.timeLastWeld = 0
    
end

function Welder:GetIsValidRecipient(recipient)

    if self:GetParent() == nil and recipient and not GetIsVortexed(recipient) and recipient:isa("Marine") then
    
        local welder = recipient:GetWeapon(Welder.kMapName)
        return welder == nil
        
    end
    
    return false
    
end

function Welder:GetViewModelName()
    return kViewModelName
end

function Welder:GetAnimationGraphName()
    return kAnimationGraph
end

function Welder:GetHUDSlot()
    return kWelderHUDSlot
end

function Welder:GetIsDroppable()
    return true
end

function Welder:OnHolster(player)

    Weapon.OnHolster(self, player)
    
    self.welding = false
    // cancel muzzle effect
    self:TriggerEffects("welder_holster")
    
end

function Welder:OnDraw(player, previousWeaponMapName)

    Weapon.OnDraw(self, player, previousWeaponMapName)
    
    self:SetAttachPoint(Weapon.kHumanAttachPoint)
    self.welding = false
    
end

// for marine third person model pose, "builder" fits perfectly for this.
function Welder:OverrideWeaponName()
    return "builder"
end

// don't play 'welder_attack' and 'welder_attack_end' too often, would become annoying with the sound effects and also client fps
function Welder:OnPrimaryAttack(player)

    if GetIsVortexed(player) then
        return
    end
    
    PROFILE("Welder:OnPrimaryAttack")
    
    if not self.welding then
    
        self:TriggerEffects("welder_start")
        self.timeWeldStarted = Shared.GetTime()
        
        if Server then
            self.loopingFireSound:Start()
        end
        
    end
    
    self.welding = true
    local hitPoint = nil
    
    if self.timeLastWeld + kWelderFireDelay < Shared.GetTime () then
    
        hitPoint = self:PerformWeld(player)
        self.timeLastWeld = Shared.GetTime()
        
    end
    
    if not self.timeLastWeldEffect or self.timeLastWeldEffect + kWelderEffectRate < Shared.GetTime() then
    
        self:TriggerEffects("welder_muzzle")
        self.timeLastWeldEffect = Shared.GetTime()
        
    end
    
end

function Welder:GetDeathIconIndex()
    return kDeathMessageIcon.Welder
end

function Welder:OnPrimaryAttackEnd(player)

    if self.welding then
        self:TriggerEffects("welder_end")
    end
    
    self.welding = false
    
    if Server then
        self.loopingFireSound:Stop()
    end
    
end

function Welder:Dropped(prevOwner)

    Weapon.Dropped(self, prevOwner)
    
    if Server then
        self.loopingFireSound:Stop()
    end
    
end

function Welder:GetRange()
    return kWeldRange
end

// repair rate increases over time
function Welder:GetRepairRate(repairedEntity)

    local repairRate = kPlayerWeldRate
    if repairedEntity.GetReceivesStructuralDamage and repairedEntity:GetReceivesStructuralDamage() then
        repairRate = kStructureWeldRate
    end
    
    return repairRate
    
end

function Welder:GetMeleeBase()
    return 2, 2
end

local function PrioritizeDamagedFriends(weapon, player, newTarget, oldTarget)
    return not oldTarget or (HasMixin(newTarget, "Team") and newTarget:GetTeamNumber() == player:GetTeamNumber() and (HasMixin(newTarget, "Weldable") and newTarget:GetCanBeWelded(weapon)))
end

function Welder:PerformWeld(player)

    local attackDirection = player:GetViewCoords().zAxis
    local success = false
    // prioritize friendlies
    local didHit, target, endPoint, direction, surface = CheckMeleeCapsule(self, player, 0, self:GetRange(), nil, true, 1, PrioritizeDamagedFriends)
    
    if didHit and target and HasMixin(target, "Live") then
        
        if GetAreEnemies(player, target) then
            self:DoDamage(kWelderDamagePerSecond * kWelderFireDelay, target, endPoint, attackDirection)
            success = true     
        elseif player:GetTeamNumber() == target:GetTeamNumber() and HasMixin(target, "Weldable") then
        
            if target:GetHealthScalar() < 1 then
                
                local prevHealthScalar = target:GetHealthScalar()
                target:OnWeld(self, kWelderFireDelay, player)
                success = prevHealthScalar ~= target:GetHealthScalar()
            
            end
            
            if HasMixin(target, "Construct") and target:GetCanConstruct(player) then
                target:Construct(kWelderFireDelay, player)
            end
            
        end
        
    end
    
    if success then    
        return endPoint
    end
    
end

function Welder:GetShowDamageIndicator()
    return true
end

function Welder:GetReplacementWeaponMapName()
    return Axe.kMapName
end

function Welder:OnUpdateAnimationInput(modelMixin)

    PROFILE("Welder:OnUpdateAnimationInput")
    
    modelMixin:SetAnimationInput("activity", ConditionalValue(self.welding, "primary", "none"))
    modelMixin:SetAnimationInput("welder", true)
    
end

function Welder:UpdateViewModelPoseParameters(viewModel)
    viewModel:SetPoseParam("welder", 1)    
end

function Welder:OnUpdatePoseParameters(viewModel)

    PROFILE("Welder:OnUpdatePoseParameters")
    self:SetPoseParam("welder", 1)
    
end

function Welder:OnUpdateRender()

    local parent = self:GetParent()
    if parent and self.welding then

        if (not self.timeLastWeldHitEffect or self.timeLastWeldHitEffect + 0.06 < Shared.GetTime()) then
        
            local viewCoords = parent:GetViewCoords()
        
            local trace = Shared.TraceRay(viewCoords.origin, viewCoords.origin + viewCoords.zAxis * self:GetRange(), CollisionRep.Damage, PhysicsMask.Bullets, EntityFilterTwo(self, parent))
            if trace.fraction ~= 1 then
            
                local coords = Coords.GetTranslation(trace.endPoint - viewCoords.zAxis * .1)
                
                local className = nil
                if trace.entity then
                    className = trace.entity:GetClassName()
                end
                
                self:TriggerEffects("welder_hit", { classname = className, effecthostcoords = coords})
                
            end

            self.timeLastWeldHitEffect = Shared.GetTime()
            
        end
    
    end

end

Shared.LinkClassToMap("Welder", Welder.kMapName, networkVars)