// ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
//
// lua\Hive_Server.lua
//
//    Created by:   Charlie Cleveland (charlie@unknownworlds.com) and
//                  Max McGuire (max@unknownworlds.com)
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

// Send out an impulse to maintain infestations every 10 seconds.
local kImpulseInterval = 10

local kHiveDyingThreshold = 0.4

local kCheckLowHealthRate = 12

// A little bigger than we might expect because the hive origin isn't on the ground
local kEggMinRange = 4
local kEggMaxRange = 22

function Hive:OnResearchComplete(researchId)

    local success = false
    local hiveTypeChosen = false
    
    local newTechId = kTechId.Hive
    
    if researchId == kTechId.UpgradeToCragHive then
    
        success = self:UpgradeToTechId(kTechId.CragHive)
        newTechId = kTechId.CragHive
        hiveTypeChosen = true
        
    elseif researchId == kTechId.UpgradeToShadeHive then
    
        success = self:UpgradeToTechId(kTechId.ShadeHive)
        newTechId = kTechId.ShadeHive
        hiveTypeChosen = true
        
    elseif researchId == kTechId.UpgradeToShiftHive then
    
        success = self:UpgradeToTechId(kTechId.ShiftHive)
        newTechId = kTechId.ShiftHive
        hiveTypeChosen = true
        
    end
    
    if success then
    
        if hiveTypeChosen then
        
            // Let gamerules know for stat tracking.
            GetGamerules():SetHiveTechIdChosen(self, newTechId)
            
        end
        
    end   
    
end

function Hive:SetFirstLogin()
    self.isFirstLogin = true
end

function Hive:OnCommanderLogin()

    if self.isFirstLogin then
        for i = 1, kInitialDrifters do
            self:CreateManufactureEntity(kTechId.Drifter)
        end
        
        self.isFirstLogin = false
    end
    
end

function Hive:OnDestroy()

    local team = self:GetTeam()
    
    if team then
        team:OnHiveDestroyed(self)
    end
    
    CommandStructure.OnDestroy(self)
    
end

function Hive:GetTeamType()
    return kAlienTeamType
end

// Aliens log in to hive instantly
function Hive:GetWaitForCloseToLogin()
    return false
end

// Hives building can't be sped up
function Hive:GetCanConstructOverride(player)
    return false
end

local function UpdateHealing(self)

    if self:GetIsBuilt() then
    
        if self.timeOfLastHeal == nil or Shared.GetTime() > (self.timeOfLastHeal + Hive.kHealthUpdateTime) then
            
            local players = GetEntitiesForTeam("Player", self:GetTeamNumber())
            
            for index, player in ipairs(players) do
            
                if player:GetIsAlive() and ((player:GetOrigin() - self:GetOrigin()):GetLength() < Hive.kHealRadius) then                
                    player:AddHealth(Clamp(player:GetMaxHealth() * Hive.kHealthPercentage, kAlienMinRegeneration, kAlienMaxRegeneration), true )                
                end
                
            end
            
            self.timeOfLastHeal = Shared.GetTime()
            
        end
        
    end
    
end

local function GetNumEggs(self)

    local numEggs = 0
    local eggs = GetEntitiesForTeam("Egg", self:GetTeamNumber())
    
    for index, egg in ipairs(eggs) do
    
        if egg:GetLocationName() == self:GetLocationName() and egg:GetIsAlive() and egg:GetIsFree() then
            numEggs = numEggs + 1
        end
        
    end
    
    return numEggs
    
end

local function GetEggSpawnTime(self)

    if Shared.GetDevMode() then
        return 3
    end
    
    local numPlayers = Clamp(self:GetTeam():GetNumPlayers(), 1, kMaxPlayers)
    local numDeadPlayers = self:GetTeam():GetNumDeadPlayers()
    
    local eggSpawnTime = CalcEggSpawnTime(numPlayers, GetNumEggs(self) + 1, numDeadPlayers)    
    return eggSpawnTime
    
end

local function GetCanSpawnEgg(self)

    local canSpawnEgg = false
    
    if self:GetIsBuilt() then
    
        if Shared.GetTime() > (self.timeOfLastEgg + GetEggSpawnTime(self)) then    
            canSpawnEgg = true
        end
        
    end
    
    return canSpawnEgg
    
end

local function SpawnEgg(self)

    if self.eggSpawnPoints == nil or #self.eggSpawnPoints == 0 then
    
        Print("Can't spawn egg. No spawn points!")
        return nil
        
    end
    
    local position = table.random(self.eggSpawnPoints)
    
    // Need to check if this spawn is valid for an Egg and for a Skulk because
    // the Skulk spawns from the Egg.
    local validForEgg = GetIsPlacementForTechId(position, true, kTechId.Egg)
    local validForSkulk = GetIsPlacementForTechId(position, true, kTechId.Skulk)
    
    // Prevent an Egg from spawning on top of a Resource Point.
    local notNearResourcePoint = #GetEntitiesWithinRange("ResourcePoint", position, 2) == 0
    
    if validForEgg and validForSkulk and notNearResourcePoint then
    
        local egg = CreateEntity(Egg.kMapName, position, self:GetTeamNumber())
        egg:SetHive(self)
        
        if egg ~= nil then
        
            // Randomize starting angles
            local angles = self:GetAngles()
            angles.yaw = math.random() * math.pi * 2
            egg:SetAngles(angles)
            
            // To make sure physics model is updated without waiting a tick
            egg:UpdatePhysicsModel()
            
            self.timeOfLastEgg = Shared.GetTime()
            
            return egg
            
        end
        
    end
    
    return nil
    
end

// Spawn a new egg around the hive if needed. Returns true if it did.
local function UpdateEggs(self)

    local createdEgg = false
    
    // Count number of eggs nearby and see if we need to create more, but only every so often
    local eggCount = GetNumEggs(self)
    if GetCanSpawnEgg(self) and eggCount < kAlienEggsPerHive then
        createdEgg = SpawnEgg(self) ~= nil
    end 
    
    return createdEgg
    
end

local function FireImpulses(self) 

    local now = Shared.GetTime()
    
    if not self.lastImpulseFireTime then
        self.lastImpulseFireTime = now
    end    
    
    if now - self.lastImpulseFireTime > kImpulseInterval then
    
        local removals = {}
        for key, id in pairs(self.cystChildren) do
        
            local child = Shared.GetEntity(id)
            if child == nil then
                removals[key] = true
            else
                if child.TriggerImpulse and child:isa("Cyst") then
                    child:TriggerImpulse(now)
                else
                    Print("Hive.cystChildren contained a: %s", ToString(child))
                    removals[key] = true
                end
            end
            
        end
        
        for key,_ in pairs(removals) do
            self.cystChildren[key] = nil
        end
        
        self.lastImpulseFireTime = now
        
    end
    
end

local function CheckLowHealth(self)

    if not self:GetIsAlive() then
        return
    end
    
    local inCombat = self:GetIsInCombat()
    if inCombat and (self:GetHealth() / self:GetMaxHealth() < kHiveDyingThreshold) then
    
        // Don't send too often.
        self.lastLowHealthCheckTime = self.lastLowHealthCheckTime or 0
        if Shared.GetTime() - self.lastLowHealthCheckTime >= kCheckLowHealthRate then
        
            self.lastLowHealthCheckTime = Shared.GetTime()
            
            // Notify the teams that this Hive is close to death.
            SendGlobalMessage(kTeamMessageTypes.HiveLowHealth, self:GetLocationId())
            
        end
        
    end
    
end

function Hive:OnEntityChange(oldId, newId)

    CommandStructure.OnEntityChange(self, oldId, newId)
    
end

function Hive:OnUpdate(deltaTime)

    PROFILE("Hive:OnUpdate")
    
    CommandStructure.OnUpdate(self, deltaTime)
    
    UpdateEggs(self)
    
    UpdateHealing(self)
    
    FireImpulses(self)
    
    CheckLowHealth(self)
    
end

function Hive:OnKill(attacker, doer, point, direction)

    CommandStructure.OnKill(self, attacker, doer, point, direction)
    
    // Notify the teams that this Hive was destroyed.
    SendGlobalMessage(kTeamMessageTypes.HiveKilled, self:GetLocationId())
    
end

function Hive:GenerateEggSpawns(hiveLocationName)

    PROFILE("Hive:GenerateEggSpawns")
    
    self.eggSpawnPoints = { }
    
    local minNeighbourDistance = 1.5
    local maxEggSpawns = 20
    local maxAttempts = maxEggSpawns * 10
    // pre-generate maxEggSpawns, trying at most maxAttempts times
    for index = 1, maxAttempts do
    
        // Note: We use kTechId.Skulk here instead of kTechId.Egg because they do not share the same extents.
        // The Skulk is a bit bigger so there are cases where it would find a location big enough for an Egg
        // but too small for a Skulk and the Skulk would be stuck when spawned.
        local extents = LookupTechData(kTechId.Skulk, kTechDataMaxExtents, nil)
        local capsuleHeight, capsuleRadius = GetTraceCapsuleFromExtents(extents)  
        local spawnPoint = GetRandomSpawnForCapsule(capsuleHeight, capsuleRadius, self:GetModelOrigin(), kEggMinRange, kEggMaxRange, EntityFilterAll())
        
        if spawnPoint ~= nil then
            spawnPoint = GetGroundAtPosition(spawnPoint, nil, PhysicsMask.AllButPCs, extents)
        end
        
        local location = spawnPoint and GetLocationForPoint(spawnPoint)
        local locationName = location and location:GetName() or ""
        
        local sameLocation = spawnPoint ~= nil and locationName == hiveLocationName
        
        if spawnPoint ~= nil and sameLocation then
        
            local tooCloseToNeighbor = false
            for _, point in ipairs(self.eggSpawnPoints) do
            
                if (point - spawnPoint):GetLengthSquared() < (minNeighbourDistance * minNeighbourDistance) then
                
                    tooCloseToNeighbor = true
                    break
                    
                end
                
            end
            
            if not tooCloseToNeighbor then
            
                table.insert(self.eggSpawnPoints, spawnPoint)
                if #self.eggSpawnPoints >= maxEggSpawns then
                    break
                end
                
            end
            
        end
        
    end
    
    if #self.eggSpawnPoints < kAlienEggsPerHive then
        Print("Hive in location \"%s\" only generated %d egg spawns (needs %d). Make room more open.", hiveLocationName, table.count(self.eggSpawnPoints), kAlienEggsPerHive)
    end
    
end

function Hive:OnLocationChange(locationName)

    CommandStructure.OnLocationChange(self, locationName)
    self:GenerateEggSpawns(locationName)

end

function Hive:OnOverrideSpawnInfestation(infestation)

    infestation.hostAlive = true
    infestation:SetMaxRadius(kHiveInfestationRadius)
    
end

function Hive:GetDamagedAlertId()

    // Trigger "hive dying" on less than 40% health, otherwise trigger "hive under attack" alert every so often
    if self:GetHealth() / self:GetMaxHealth() < kHiveDyingThreshold then
        return kTechId.AlienAlertHiveDying
    else
        return kTechId.AlienAlertHiveUnderAttack
    end
    
end

function Hive:OnTakeDamage(damage, attacker, doer, point)

    local time = Shared.GetTime()
    if self:GetIsAlive() and self.lastHiveFlinchEffectTime == nil or (time > (self.lastHiveFlinchEffectTime + 1)) then

        // Play freaky sound for team mates
        local team = self:GetTeam()
        team:PlayPrivateTeamSound(Hive.kWoundAlienSound, self:GetModelOrigin())
        
        // ...and a different sound for enemies
        local enemyTeamNumber = GetEnemyTeamNumber(team:GetTeamNumber())
        local enemyTeam = GetGamerules():GetTeam(enemyTeamNumber)
        if enemyTeam ~= nil then
            enemyTeam:PlayPrivateTeamSound(Hive.kWoundSound, self:GetModelOrigin())
        end
        
        // Trigger alert for Commander
        team:TriggerAlert(kTechId.AlienAlertHiveUnderAttack, self)
        
        self.lastHiveFlinchEffectTime = time
        
    end
    
    // Update objective markers because OnSighted isn't always called
    local attached = self:GetAttached()
    if attached then
        attached.showObjective = true
    end
    
end

function Hive:OnTeleportEnd()
    
    local attachedTechPoint = self:GetAttached()
    if attachedTechPoint then
        attachedTechPoint:SetIsSmashed(true)
    end
    
    // lets the old infestation die and creates a new one
    self:SpawnInfestation()
    
    local commander = self:GetCommander()
    
    if commander then
    
        // we assume onos extents for now, save lastExtents in commander
        local extents = LookupTechData(kTechId.Onos, kTechDataMaxExtents, nil)
        local randomSpawn = GetRandomSpawnForCapsule(extents.y, extents.x, self:GetOrigin(), 2, 4, EntityFilterAll())
        commander.lastGroundOrigin = randomSpawn
    
    end
    
    for key,id in pairs(self.cystChildren) do
    
        local child = Shared.GetEntity(id)
        if child == nil then
            removals[key] = true
        else
            child.parentId = Entity.invalidId
        end
        
    end
    
    self.cystChildren = {}
    
end

function Hive:GetCompleteAlertId()
    return kTechId.AlienAlertHiveComplete
end

function Hive:SetAttached(structure)

    CommandStructure.SetAttached(self, structure)
    
    if self:GetIsBuilt() and structure:isa("TechPoint") then
        structure:SetIsSmashed(true)
    end

end

function Hive:OnConstructionComplete()

    // Play special tech point animation at same time so it appears that we bash through it
    local attachedTechPoint = self:GetAttached()
    if attachedTechPoint then
        attachedTechPoint:SetIsSmashed(true)
    else
        Print("Hive not attached to tech point")
    end
    
    local team = self:GetTeam()
    
    if team then    
        team:OnHiveConstructed(self)        
    end
    
    if self.hiveType == 1 then
        self:OnResearchComplete(kTechId.UpgradeToCragHive)
    elseif self.hiveType == 2 then
        self:OnResearchComplete(kTechId.UpgradeToShadeHive)
    elseif self.hiveType == 3 then
        self:OnResearchComplete(kTechId.UpgradeToShiftHive)
    end
    
end

function Hive:GetIsPlayerValidForCommander(player)
    return player ~= nil and player:isa("Alien") and CommandStructure.GetIsPlayerValidForCommander(self, player)
end

function Hive:GetCommanderClassName()
    return AlienCommander.kMapName   
end

function Hive:AddChildCyst(child)
    self.cystChildren["" .. child:GetId()] = child:GetId()
end