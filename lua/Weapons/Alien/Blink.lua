// ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
//
// lua\Weapons\Alien\Blink.lua
//
//    Created by:   Charlie Cleveland (charlie@unknownworlds.com) and
//                  Max McGuire (max@unknownworlds.com)
//
// Blink - Attacking many times in a row will create a cool visual "chain" of attacks, 
// showing the more flavorful animations in sequence. Base class for swipe and vortex, available at tier 2.
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================
Script.Load("lua/Weapons/Alien/Ability.lua")

class 'Blink' (Ability)
Blink.kMapName = "blink"

// initial force added when starting blink
local kEtherealForce = 4

// Delay before you can blink again after a blink
Blink.kMinEnterEtherealTime = 0.4

local networkVars =
{
}

function Blink:OnInitialized()

    Ability.OnInitialized(self)

    self.secondaryAttacking = false
    self.timeBlinkStarted = 0
    
end

function Blink:OnHolster(player)

    Ability.OnHolster(self, player)
    
    self:SetEthereal(player, false)
    
end

function Blink:GetHasSecondary(player)
    return player:GetHasTwoHives()
end

function Blink:GetSecondaryAttackRequiresPress()
    return true
end

function Blink:TriggerBlinkOutEffects(player)

    // Play particle effect at vanishing position
    if not Shared.GetIsRunningPrediction() then
    
        self:TriggerEffects("blink_out", {effecthostcoords = Coords.GetTranslation(player:GetOrigin())})
        
        if Client and Client.GetLocalPlayer():GetId() == player:GetId() then
            self:TriggerEffects("blink_out_local", {effecthostcoords = Coords.GetTranslation(player:GetOrigin())})
        end
        
    end

end

function Blink:TriggerBlinkInEffects(player)

    if not Shared.GetIsRunningPrediction() then
        self:TriggerEffects("blink_in", {effecthostcoords = Coords.GetTranslation(player:GetOrigin())})
    end
    
end

function Blink:GetIsBlinking()

    local player = self:GetParent()
    
    if player then
        return player:GetIsBlinking()
    end
    
    return false
    
end

// Cannot attack while blinking.
function Blink:GetPrimaryAttackAllowed()
    return not self:GetIsBlinking()
end

function Blink:GetSecondaryEnergyCost(player)
    return kStartBlinkEnergyCost
end

function Blink:OnSecondaryAttack(player)

    local minTimePassed = not player:GetRecentlyBlinked()
    local hasEnoughEnergy = player:GetEnergy() > kStartBlinkEnergyCost
    if not player.etherealStartTime or minTimePassed and hasEnoughEnergy and self:GetBlinkAllowed() then
    
        // Enter "ether" fast movement mode, but don't keep going ethereal when button still held down after
        // running out of energy
        if not self.secondaryAttacking then
        
            self:SetEthereal(player, true)
            
            self.timeBlinkStarted = Shared.GetTime()
            
            self.secondaryAttacking = true
            
            TEST_EVENT("Blink started")
            
        end
        
    end
    
    Ability.OnSecondaryAttack(self, player)
    
end

function Blink:OnSecondaryAttackEnd(player)

    if player.ethereal then
    
        self:SetEthereal(player, false)
        TEST_EVENT("Blink ended, button released")
        
    end
    
    Ability.OnSecondaryAttackEnd(self, player)
    
    self.secondaryAttacking = false
    
end

function Blink:SetEthereal(player, state)

    // Enter or leave invulnerable invisible fast-moving mode
    if player.ethereal ~= state then
    
        if state then

            player.etherealStartTime = Shared.GetTime()
            self:TriggerBlinkOutEffects(player)
            player:AddHealth(kHealthOnBlink)
            
            local newVelocity = player:GetViewCoords().zAxis * kEtherealForce * player:GetMovementSpeedModifier() + player:GetVelocity()
            player:SetVelocity(newVelocity)
            
        else
            self:TriggerBlinkInEffects(player)     
            player.etherealEndTime = Shared.GetTime() 
        end
        
        player.ethereal = state
        player:SetGravityEnabled(not player.ethereal)
        
        player:SetEthereal(state)
        
        // Give player initial velocity in direction we're pressing, or forward if not pressing anything.
        if player.ethereal then
            
            // Deduct blink start energy amount.
            player:DeductAbilityEnergy(kStartBlinkEnergyCost)
            player:TriggerBlink()
        
        else
            
            player:OnBlinkEnd()
            
        end
        
    end
    
end

function Blink:ProcessMoveOnWeapon(player, input)
 
    if self:GetIsActive() and player.ethereal then
    
        // Decrease energy while in blink mode
        // Don't deduct energy for blink for a short time to make sure that when we blink
        // we always get at least a short blink out of it
        if Shared.GetTime() > (self.timeBlinkStarted + .08) then

            local energyCost = input.time * kBlinkEnergyCost
            player:DeductAbilityEnergy(energyCost)
            
        end
        
    end
    
    // End blink mode if out of energy
    if player:GetEnergy() == 0 and player.ethereal then
    
        self:SetEthereal(player, false)
        TEST_EVENT("Blink ended, out of energy")
        
    end
    
end

function Blink:OnUpdateAnimationInput(modelMixin)

    local player = self:GetParent()
    if self:GetIsBlinking() then
        modelMixin:SetAnimationInput("move", "blink")
    end
    
end

Shared.LinkClassToMap("Blink", Blink.kMapName, networkVars)