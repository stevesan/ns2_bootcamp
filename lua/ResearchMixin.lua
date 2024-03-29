// ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======    
//    
// lua\ResearchMixin.lua    
//    
//    Created by:   Andreas Urwalek (andi@unknownworlds.com)
//    
// ========= For more information, visit us at http://www.unknownworlds.com =====================    

Script.Load("lua/FunctionContracts.lua")

ResearchMixin = CreateMixin( ResearchMixin )
ResearchMixin.type = "Research"

local gResearchTimeScale = 0.1

ResearchMixin.networkVars =
{
    // Tech id of research this building is currently researching
    researchingId           = "enum kTechId",
    // 0 to 1 scalar of progress
    researchProgress        = "float (0 to 1 by 0.01)",
}

ResearchMixin.expectedMixins =
{
    //TechAction = "Required to display buttons."
}

ResearchMixin.expectedCallbacks = 
{
}

ResearchMixin.optionalCallbacks = 
{
    GetCanResearchOverride = "Return custom conditions when researching should be allowed.",
    OnResearch = "Called whenever a research is triggered.",
    OverrideCreateManufactureEntity = "Custom creation method",
    OnManufactured = "Called after successful creation" 
}

function ResearchMixin:__initmixin()

    self.researchingId = kTechId.None
    self.researchProgress = 0
    self.timeResearchStarted = 0
    self.researchingPlayerId = Entity.invalidId
    
end

function ResearchMixin:UpdateResearch(deltaTime)

    local researchNode = self:GetTeam():GetTechTree():GetTechNode(self.researchingId)
    if researchNode then
    
        local researchDuration = gResearchTimeScale * LookupTechData(researchNode:GetTechId(), kTechDataResearchTimeKey, 0.01)
        
        if GetGamerules():GetAutobuild() then
            researchDuration = math.min(0.5, researchDuration)
        end
        
        researchDuration = researchDuration * kResearchMod
        
        // avoid division with 0
        researchDuration = math.max(researchDuration, 0.01)
        
        local progress = self.researchProgress + deltaTime / researchDuration
        progress = math.min(progress, 1)

        if progress ~= self.researchProgress then
        
            self.researchProgress = progress

            researchNode:SetResearchProgress(self.researchProgress)
            
            local techTree = self:GetTeam():GetTechTree()
            techTree:SetTechNodeChanged(researchNode, string.format("researchProgress = %.2f", self.researchProgress))
            
            // Update research progress
            if self.researchProgress == 1 then

                // Mark this tech node as researched
                researchNode:SetResearched(true)
                
                techTree:QueueOnResearchComplete(self.researchingId, self)
                
            end
        
        end
        
    end 

end

local function SharedUpdate(self, deltaTime)

    if Server then
   
        if self.researchingId ~= kTechId.None and ( GetIsUnitActive(self) or ( HasMixin(self, "Recycle") and self.researchingId == kTechId.Recycle ) ) then
            self:UpdateResearch(deltaTime)
        end

    end
    
end

function ResearchMixin:OnUpdate(deltaTime)
    SharedUpdate(self, deltaTime)
end
AddFunctionContract(ResearchMixin.OnUpdate, { Arguments = { "Entity", "number" }, Returns = { } })

function ResearchMixin:OnProcessMove(input)
    SharedUpdate(self, input.time)
end
AddFunctionContract(ResearchMixin.OnProcessMove, { Arguments = { "Entity", "Move" }, Returns = { } })

function ResearchMixin:OnUpdateAnimationInput(modelMixin)

    PROFILE("ResearchMixin:OnUpdateAnimationInput")
    
end

function ResearchMixin:GetResearchingId()
    return self.researchingId
end

function ResearchMixin:GetResearchProgress()
    return self.researchProgress
end

function ResearchMixin:GetResearchTechAllowed(techNode)

    // Return true unless it's it's specified that it can only be triggered for specific tech id (ie, an upgraded version of a structure)
    local addOnRequirementMet = true
    local addOnTechId = techNode:GetAddOnTechId()
    if addOnTechId ~= kTechId.None then        
        addOnRequirementMet = (self:GetTechId() == addOnTechId)
    end

    // Return false if we're researching, or if tech is being researched
    return not (self.researchingId ~= kTechId.None or techNode.researched or techNode.researching or not addOnRequirementMet)
    
end

function ResearchMixin:OnKill()
    self:AbortResearch()
end 

function ResearchMixin:ClearResearch()

    self.researchingId = kTechId.None
    self.researchingPlayerId = Entity.invalidId
    self.researchTime = 0
    self.timeResearchStarted = 0
    self.timeResearchComplete = 0
    self.researchProgress = 0

end

function ResearchMixin:GetIsResearching()
    return self:GetResearchProgress() ~= 0
end

function ResearchMixin:GetIsManufacturing()

    if self:GetIsResearching() then
    
        local researchNode = GetTechTree(self:GetTeamNumber()):GetTechNode(self.researchingId)
        return researchNode ~= nil and (researchNode:GetIsManufacture() or researchNode:GetIsEnergyManufacture() or researchNode:GetIsPlasmaManufacture())
    
    end
    
    return false

end

function ResearchMixin:GetIsUpgrading()

    if self:GetIsResearching() then
    
        local researchNode = GetTechTree(self:GetTeamNumber()):GetTechNode(self.researchingId)
        return researchNode ~= nil and researchNode:GetIsUpgrade()
    
    end
    
    return false

end

// Could be for research or upgrade
function ResearchMixin:SetResearching(techNode, player)

    self.researchingId = techNode.techId
    assert(self.researchingId ~= 0)
    self.researchTime = techNode.time
    self.researchingPlayerId = player:GetId()
    
    self.timeResearchStarted = Shared.GetTime()
    self.timeResearchComplete = techNode.time
    self.researchProgress = 0
    
    if self.OnResearch then
        self:OnResearch(self.researchingId)
    end
    
end

function ResearchMixin:AbortResearch(refundCost)

    if self.researchProgress > 0 then
    
        local team = self:GetTeam()
        // Team is not always available due to order of destruction during map change.
        if team then
        
            local researchNode = team:GetTechTree():GetTechNode(self.researchingId)
            if researchNode ~= nil then
            
                // Give money back if refundCost is true
                if refundCost then
                    team:SetTeamResources(team:GetTeamResources() + researchNode:GetCost())
                end
                
                ASSERT(researchNode:GetResearching() or researchNode:GetIsUpgrade())
                
                researchNode:ClearResearching()
                
                if self.OnResearchCancel then
                    self:OnResearchCancel(self.researchingId)
                end
                
                self:ClearResearch()
                
                team:GetTechTree():SetTechChanged()
                
            end
            
        end
        
    end
    
end

function ResearchMixin:OnUpdateAnimationInput(modelMixin)

    PROFILE("ResearchMixin:OnUpdateAnimationInput")
    modelMixin:SetAnimationInput("researching", self:GetIsResearching())
    
end

function ResearchMixin:PerformAction(techNode, position)

    // Process Cancel of research or upgrade
    if techNode.techId == kTechId.Cancel then
    
        if self:GetIsResearching() then        
            self:AbortResearch(true)            
        end       

    end
    
end

function ResearchMixin:OnEntityChange(oldId, newId)

    if oldId == self.researchingPlayerId and self.researchingPlayerId ~= Entity.invalidId then
        self.researchingPlayerId = newId
    end
    
end

function ResearchMixin:GetCanResearch(techId)

    if self:GetIsResearching() then
        return false
    end    

    if techId == kTechId.Recycle and HasMixin(self, "Recycle") then
        return true
    end

    if self.GetCanResearchOverride then
        return self:GetCanResearchOverride(techId)
    end

    return GetIsUnitActive(self)
    
end

function ResearchMixin:GetIssuedCommander()

    local issuedCommander = Shared.GetEntity(self.researchingPlayerId)
    
    if not issuedCommander then
        local commanders = GetEntitiesForTeam("Commander", self:GetTeamNumber())
        issuedCommander = commanders[1]
    end
    
    return issuedCommander
    
end

function ResearchMixin:CreateManufactureEntity(techId)

    local entity = nil

    if self.OverrideCreateManufactureEntity then
        entity = self:OverrideCreateManufactureEntity(techId)
    else

        local mapName = LookupTechData(techId, kTechDataMapName)
        entity = CreateEntity(mapName, self:GetOrigin(), self:GetTeamNumber())
        entity:SetOwner(self:GetIssuedCommander())
        
        if entity.ProcessRallyOrder then
            entity:ProcessRallyOrder(self)
        end
        
    end    
    
    if entity and self.OnManufactured then
        self:OnManufactured(entity)
    end
    
    return entity

end

function ResearchMixin:TechResearched(structure, researchId)

    if structure and structure:GetId() == self:GetId() then
    
        local researchNode = self:GetTeam():GetTechTree():GetTechNode(researchId)
        if researchNode and (researchNode:GetIsEnergyManufacture() or researchNode:GetIsManufacture() or researchNode:GetIsPlasmaManufacture()) then        

            // Handle manufacture actions        
            self:CreateManufactureEntity(researchId)
            
        elseif self.OnResearchComplete then
            self:OnResearchComplete(researchId)
        end
    
        self:ClearResearch()
        
    end

end

function ResearchMixin:OnPowerOff()

    if self:GetIsResearching() then        
        self:AbortResearch(true)            
    end       

end