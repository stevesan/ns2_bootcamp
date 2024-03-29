// ======= Copyright (c) 2003-2012, Unknown Worlds Entertainment, Inc. All rights reserved. =======
//
// lua\Player_Client.lua
//
//    Created by:   Charlie Cleveland (charlie@unknownworlds.com) and
//                  Max McGuire (max@unknownworlds.com)
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/Chat.lua")
Script.Load("lua/HudTooltips.lua")
Script.Load("lua/tweener/Tweener.lua")
Script.Load("lua/Player_Rumble.lua")
Script.Load("lua/TechTreeConstants.lua")
Script.Load("lua/GUICommunicationStatusIcons.lua")

// These screen effects are only used on the local player so create them statically.
Player.screenEffects = { }
Player.screenEffects.fadeBlink = Client.CreateScreenEffect("shaders/FadeBlink.screenfx")
Player.screenEffects.fadeBlink:SetActive(false)
Player.screenEffects.lowHealth = Client.CreateScreenEffect("shaders/LowHealth.screenfx")
Player.screenEffects.lowHealth:SetActive(false)
Player.screenEffects.darkVision = Client.CreateScreenEffect("shaders/DarkVision.screenfx")
Player.screenEffects.darkVision:SetActive(false)
Player.screenEffects.blur = Client.CreateScreenEffect("shaders/Blur.screenfx")
Player.screenEffects.blur:SetActive(false)
Player.screenEffects.phase = Client.CreateScreenEffect("shaders/Phase.screenfx")
Player.screenEffects.phase:SetActive(false)
Player.screenEffects.cloaked = Client.CreateScreenEffect("shaders/Cloaked.screenfx")
Player.screenEffects.cloaked:SetActive(false)
Player.screenEffects.disorient = Client.CreateScreenEffect("shaders/Disorient.screenfx")
Player.screenEffects.disorient:SetActive(false)
Player.screenEffects.celerityFX = Client.CreateScreenEffect("shaders/Celerity.screenfx")
Player.screenEffects.celerityFX:SetActive(false)

local kDefaultPingSound = PrecacheAsset("sound/NS2.fev/common/ping")
local kMarinePingSound = PrecacheAsset("sound/NS2.fev/marine/commander/ping")
local kAlienPingSound = PrecacheAsset("sound/NS2.fev/alien/commander/ping")

local kDefaultFirstPersonEffectName = PrecacheAsset("cinematics/marine/hit_1p.cinematic")

Client.PrecacheLocalSound(kDefaultPingSound)
Client.PrecacheLocalSound(kMarinePingSound)
Client.PrecacheLocalSound(kAlienPingSound)

Player.kMeleeHitCameraShakeAmount = 0.05
Player.kMeleeHitCameraShakeSpeed = 5
Player.kMeleeHitCameraShakeTime = 0.25

Player.kRangeFinderDistance = 20

// The amount of health left before the low health warning
// screen effect is active
local kLowHealthWarning = 0.35
local kLowHealthPulseSpeed = 10

Player.kShowGiveDamageTime = 1

local kPhaseEffectActiveTime = 2

gHUDMapEnabled = true

Player.kFirstPersonHealthCircle = PrecacheAsset("models/misc/marine-build/marine-build.model")
Player.kFirstPersonMarineHealthCircle = PrecacheAsset("models/misc/marine-build/marine-build.model")
Player.kFirstPersonAlienHealthCircle = PrecacheAsset("models/misc/marine-build/marine-build.model")

Player.kFirstPersonDeathEffect = PrecacheAsset("cinematics/death_1p.cinematic")

local kVortexed2DStart = "sound/NS2.fev/alien/fade/vortex_start_2D"
Client.PrecacheLocalSound(kVortexed2DStart)
local kVortexed2DEnd = "sound/NS2.fev/alien/fade/vortex_end_2D"
Client.PrecacheLocalSound(kVortexed2DEnd)

local kDeadSound = PrecacheAsset("sound/NS2.fev/common/dead")
Client.PrecacheLocalSound(kDeadSound)
gPlayingDeadMontage = nil

local kHealthCircleFadeOutTime = 1

local function GetHealthCircleName(self)

    if self:GetTeamNumber() == kMarineTeamType then
        return Player.kFirstPersonMarineHealthCircle
    elseif self:GetTeamNumber() == kAlienTeamType then
        return Player.kFirstPersonAlienHealthCircle
    end
    
    return Player.kFirstPersonHealthCircle

end

function Player:GetShowUnitStatusForOverride(forEntity)
    return not GetAreEnemies(self, forEntity) or (forEntity:GetOrigin() - self:GetOrigin()):GetLength() < 8
end

function PlayerUI_GetWorldMessages()

    local messageTable = {}
    local player = Client.GetLocalPlayer()
    
    if player then
            
        for _, worldMessage in ipairs(Client.GetWorldMessages()) do
            
            local tableEntry = {}
            
            tableEntry.position = worldMessage.position
            tableEntry.messageType = worldMessage.messageType
            tableEntry.previousNumber = worldMessage.previousNumber
            tableEntry.text = worldMessage.message
            tableEntry.animationFraction = worldMessage.animationFraction
            tableEntry.distance = (worldMessage.position - player:GetOrigin()):GetLength()
            tableEntry.minimumAnimationFraction = worldMessage.minimumAnimationFraction
            tableEntry.entityId = worldMessage.entityId
            
            local direction = GetNormalizedVector(worldMessage.position - player:GetViewCoords().origin)
            tableEntry.inFront = player:GetViewCoords().zAxis:DotProduct(direction) > 0
            
            table.insert(messageTable, tableEntry)
            
        end
    
    end
    
    return messageTable

end

function PlayerUI_GetIsFeinting()

    local player = Client.GetLocalPlayer()
    local isFeinting = false
    
    if player then
    
        if HasMixin(player, "Feint") then
            isFeinting = player:GetIsFeinting()
        end
        
    end
    
    return isFeinting
end

function PlayerUI_GetIsDead()

    local player = Client.GetLocalPlayer()
    local isDead = false
    
    if player then
    
        if HasMixin(player, "Live") then
            isDead = not player:GetIsAlive()
        end
        
    end
    
    return isDead
    
end

function PlayerUI_GetIsSpecating()

    local player = Client.GetLocalPlayer()
    return player ~= nil and (player:isa("Spectator") or player:isa("FilmSpectator"))
    
end

function PlayerUI_GetHUDMapEnabled()
    return gHUDMapEnabled
end

function PlayerUI_GetCurrentOrderType()

    local player = Client.GetLocalPlayer()
    
    if player and HasMixin(player, "Orders")  and player:GetCurrentOrder() then
        return player:GetCurrentOrder():GetType()
    end
    
    return kTechId.None
    
end

function PlayerUI_GetOrderInfo()

    local orderInfo = { }
    
    // Hard-coded for testing
    local player = Client.GetLocalPlayer()
    if player then
    
        for index, order in ientitylist(Shared.GetEntitiesWithClassname("Order")) do
        
            table.insert(orderInfo, order.orderType)
            table.insert(orderInfo, order.orderParam)
            table.insert(orderInfo, order.orderLocation)
            table.insert(orderInfo, order.orderOrientation)
            table.insert(orderInfo, order.orderSource)
            
        end
        
    end
    
    return orderInfo
    
end

local gLastOrderId = 0
local gLastOrderTime = 0
local kNewOrderDuration = 3
function PlayerUI_GetHasNewOrder()

    local hasNewOrder = false
    local player = Client.GetLocalPlayer()
    
    if player then

        local order = player:GetCurrentOrder()
        if order and order:GetId() ~= gLastOrderId then

            gLastOrderId = order:GetId()
            gLastOrderTime = Client.GetTime()
        
        end
        
        hasNewOrder = gLastOrderTime + kNewOrderDuration > Client.GetTime()
        
    end

    return hasNewOrder

end

local function GetMostRelevantPheromone(toOrigin)

    local pheromones = GetEntitiesWithinRange("Pheromone", toOrigin, 100)
    local bestPheromone = nil
    local bestDistSq = math.huge
    for p = 1, #pheromones do
    
        local currentPheromone = pheromones[p]
        local currentDistSq = currentPheromone:GetDistanceSquared(toOrigin)

        if currentDistSq < bestDistSq then
        
            bestDistSq = currentDistSq
            bestPheromone = currentPheromone
            
        end
        
    end
    
    return bestPheromone
    
end

function PlayerUI_GetOrderPath()

    local player = Client.GetLocalPlayer()
    if player then
    
        if player:isa("Alien") then
        
            local playerOrigin = player:GetOrigin()
            local pheromone = GetMostRelevantPheromone(playerOrigin)
            if pheromone then
            
                local points = { }
                local isReachable = Pathing.GetPathPoints(playerOrigin, pheromone:GetOrigin(), points)
                if isReachable then
                    return points
                end
                
            end
            
        elseif HasMixin(player, "Orders") then
        
            local currentOrder = player:GetCurrentOrder()
            if currentOrder then
            
                local targetLocation = currentOrder:GetLocation()
                local points = { }
                local isReachable = Pathing.GetPathPoints(player:GetOrigin(), targetLocation, points)
                if isReachable then
                    return points
                end
                
            end
            
        end
        
    end
    
    return nil
    
end

function PlayerUI_GetCanDisplayRequestMenu()

    local player = Client.GetLocalPlayer()
    return player ~= nil and (player:GetIsAlive() or player:isa("Spectator")) and not player:GetBuyMenuIsDisplaying() and not MainMenu_GetIsOpened()
    
end

function Player:GetBuyMenuIsDisplaying()
    return self.buyMenu ~= nil
end

function PlayerUI_GetBuyMenuDisplaying()

    local isDisplaying = false
    
    local player = Client.GetLocalPlayer()
    
    if player then
        isDisplaying = player:GetBuyMenuIsDisplaying()
    end
    
    return isDisplaying
    
end

local function LocalIsFriendlyMarineComm(player, unit)
    return player:isa("MarineCommander") and unit:isa("Player")
end

local kUnitStatusDisplayRange = 13
local kUnitStatusCommanderDisplayRange = 50
local kDefaultHealthOffset = Vector(0, 1.2, 0)

function PlayerUI_GetUnitStatusInfo()

    local unitStates = { }
    
    local player = Client.GetLocalPlayer()
    
    if player and not player:GetBuyMenuIsDisplaying() and (not player.GetDisplayUnitStates or player:GetDisplayUnitStates()) then
    
        local eyePos = player:GetEyePos()
        local crossHairTarget = player:GetCrossHairTarget()
        
        local range = kUnitStatusDisplayRange
         
        if player:isa("Commander") then
            range = kUnitStatusCommanderDisplayRange
        end
    
        for index, unit in ipairs(GetEntitiesWithMixinWithinRange("UnitStatus", eyePos, range)) do
        
            // checks here if the model was rendered previous frame as well
            local status = unit:GetUnitStatus(player)
            if unit:GetShowUnitStatusFor(player) and (unit:isa("Player") or status ~= kUnitStatus.None or unit == crossHairTarget) then       

                // Get direction to blip. If off-screen, don't render. Bad values are generated if 
                // Client.WorldToScreen is called on a point behind the camera.
                local origin = nil
                local getEngagementPoint = unit.GetEngagementPoint
                if getEngagementPoint then
                    origin = getEngagementPoint(unit)
                else
                    origin = unit:GetOrigin()
                end
                
                local normToEntityVec = GetNormalizedVector(origin - eyePos)
                local normViewVec = player:GetViewAngles():GetCoords().zAxis
               
                local dotProduct = normToEntityVec:DotProduct(normViewVec)
                
                if dotProduct > 0 then

                    local statusFraction = unit:GetUnitStatusFraction(player)
                    local description = unit:GetUnitName(player)
                    local action = unit:GetActionName(player)
                    local hint = unit:GetUnitHint(player)
                    
                    local healthBarOrigin = origin + kDefaultHealthOffset
                    local getHealthbarOffset = unit.GetHealthbarOffset
                    if getHealthbarOffset then
                        healthBarOrigin = origin + getHealthbarOffset(unit)
                    end
                    
                    local worldOrigin = Vector(origin)
                    origin = Client.WorldToScreen(origin)
                    healthBarOrigin = Client.WorldToScreen(healthBarOrigin)
                    
                    if unit == crossHairTarget then
                        healthBarOrigin.y = math.max(GUIScale(180), healthBarOrigin.y)
                    end

                    local health = 0
                    local armor = 0

                    local visibleToPlayer = true                        
                    if HasMixin(unit, "Cloakable") and unit:GetIsCloaked() and GetAreEnemies(player, unit) then
                        visibleToPlayer = false
                    end
                    
                    // Don't show tech points or nozzles if they are attached
                    if (unit:GetMapName() == TechPoint.kMapName or unit:GetMapName() == ResourcePoint.kPointMapName) and unit.GetAttached and (unit:GetAttached() ~= nil) then
                        visibleToPlayer = false
                    end
                    
                    if HasMixin(unit, "Live") and (not unit.GetShowHealthFor or unit:GetShowHealthFor(player)) then
                    
                        health = unit:GetHealthFraction()                
                        if unit:GetArmor() == 0 then
                            armor = 0
                        else 
                            armor = unit:GetArmorScalar()
                        end

                    end
                    
                    local badge = ""
                    
                    if HasMixin(unit, "Badge") then
                        badge = unit:GetBadgeIcon() or ""
                    end
                    
                    local unitState = {
                        
                        Position = origin,
                        WorldOrigin = worldOrigin,
                        HealthBarPosition = healthBarOrigin,
                        Status = status,
                        Name = description,
                        Action = action,
                        Hint = hint,
                        StatusFraction = statusFraction,
                        HealthFraction = health,
                        ArmorFraction = armor,
                        IsCrossHairTarget = (unit == crossHairTarget and visibleToPlayer) or LocalIsFriendlyMarineComm(player, unit),
                        TeamType = kNeutralTeamType,
                        ForceName = unit:isa("Player") and not GetAreEnemies(player, unit),
                        OnScreen = onScreen,
                        BadgeTexture = badge
                    
                    }
                    
                    if unit.GetTeamNumber then
                        unitState.IsFriend = (unit:GetTeamNumber() == player:GetTeamNumber())
                    end
                    
                    if unit.GetTeamType then
                        unitState.TeamType = unit:GetTeamType()
                    end
                    
                    table.insert(unitStates, unitState)
                
                end
                
            end
         
         end
        
    end
    
    return unitStates

end

local kObjectiveOffset = Vector(0, 0.0, 0)
local kObjectiveDistance = 40
local function AddObjectives(objectives, className)

    local player = Client.GetLocalPlayer()
    
    if player then

        for index, objective in ientitylist(Shared.GetEntitiesWithClassname(className)) do
        
            if objective.showObjective and objective.occupiedTeam ~= player:GetTeamNumber() then
            
                local origin = objective:GetOrigin() + kObjectiveOffset
                            
                local cameraCoords = GetRenderCameraCoords()
                local screenPosition = Vector(0,0,0)

                local toPosition = GetNormalizedVector(cameraCoords.origin - objective:GetOrigin())
                local distanceFraction = 1 - Clamp((cameraCoords.origin - objective:GetOrigin()):GetLength() / kObjectiveDistance, 0, 1)
                local dotProduct = cameraCoords.zAxis:DotProduct(toPosition)
                
                if dotProduct < 0 then
                
                    // Display higher then the origin (world units above the origin)
                    local yOffset = ConditionalValue(player:GetTeamType() == kAlienTeamType, .75, 3)
        
                    VectorCopy(Client.WorldToScreen(objective:GetOrigin() + Vector(0, yOffset, 0)), screenPosition) 
                    table.insert(objectives, { Position = screenPosition, TechId = objective:GetTechId(), DistanceFraction = distanceFraction })                    
                end
                
            end    

        end
    
    end

end

function PlayerUI_GetObjectives()

    local objectives = { }
    //AddObjectives(objectives, "ResourcePoint")    
    AddObjectives(objectives, "TechPoint") 

    return objectives
    
end

function PlayerUI_GetWaypointType()

    local player = Client.GetLocalPlayer()
    
    local type = kTechId.Move
    
    if player then
    
        local currentOrder = player:GetCurrentOrder()
        if currentOrder then
            type = currentOrder:GetType()
        end
    
    end
    
    return type

end

/**
 * Gives the UI the screen space coordinates of where to display
 * the final waypoint for when players have an order location.
 */
function PlayerUI_GetFinalWaypointInScreenspace()

    local player = Client.GetLocalPlayer()
    
    if not player then
        return nil
    end
    
    local isCommander = player:isa("Commander")
    local currentOrder = nil
    
    if isCommander then
    
        local orders = Shared.GetEntitiesWithClassname("Order")
        if orders:GetSize() < 1 then
            return nil
        end
        
        currentOrder = orders:GetEntityAtIndex(0)
        
    else
    
        if player:isa("Alien") then
            currentOrder = GetMostRelevantPheromone(player:GetOrigin())
        elseif HasMixin(player, "Orders") then
            currentOrder = player:GetCurrentOrder()
        end
        
    end
    
    if not currentOrder then
        return nil
    end
    
    local orderTypeName = GetDisplayNameForTechId(currentOrder:GetType(), "<no display name>")
    local orderType = currentOrder:GetType()
    local orderId = currentOrder:GetId()
    
    local playerEyePos = Vector(player:GetCameraViewCoords().origin)
    local playerForwardNorm = Vector(player:GetCameraViewCoords().zAxis)
    
    // This method needs to use the previous updates player info.
    if player.lastPlayerEyePos == nil then
    
        player.lastPlayerEyePos = Vector(playerEyePos)
        player.lastPlayerForwardNorm = Vector(playerForwardNorm)
        
    end
    
    local orderWayPoint = nil
    if currentOrder:isa("Pheromone") then
        orderWayPoint = currentOrder:GetOrigin()
    else
        orderWayPoint = currentOrder:GetLocation()
    end
    
    if not isCommander then
        orderWayPoint = orderWayPoint + Vector(0, 1.5, 0)
    end
    
    local screenPos = Client.WorldToScreen(orderWayPoint)
    
    local isInScreenSpace = false
    local nextWPDir = orderWayPoint - player.lastPlayerEyePos
    local normToEntityVec = GetNormalizedVectorXZ(nextWPDir)
    local normViewVec = GetNormalizedVectorXZ(player.lastPlayerForwardNorm)
    local dotProduct = Math.DotProduct(normToEntityVec, normViewVec)
    
    // Distance is used for scaling.
    local nextWPDist = nextWPDir:GetLength()
    local nextWPMaxDist = 25
    local nextWPScale = isCommander and 0.3 or math.max(0.5, 1 - (nextWPDist / nextWPMaxDist))
    local entriesPerWaypoint = 7
    
    if isCommander then
        nextWPDist = 0
    end
    
    if player.nextWPInScreenSpace == nil then
    
        player.nextWPInScreenSpace = true
        player.nextWPDoingTrans = false
        player.nextWPLastVal = { }
        
        for i = 1, entriesPerWaypoint do
            player.nextWPLastVal[i] = 0
        end
        
        player.nextWPCurrWP = Vector(orderWayPoint)
        
    end
    
    // If the waypoint has changed, do a smooth transition.
    if player.nextWPCurrWP ~= orderWayPoint then
    
        player.nextWPDoingTrans = true
        VectorCopy(orderWayPoint, player.nextWPCurrWP)
        
    end
    
    local returnTable = nil
    local spaceToBorder = ConditionalValue(isCommander, 0, 0.18)
    
    // If offscreen, fallback on compass method.
    local minWidthBuff = Client.GetScreenWidth() * spaceToBorder
    local minHeightBuff = Client.GetScreenHeight() * spaceToBorder
    local maxWidthBuff = Client.GetScreenWidth() * (1 - spaceToBorder)
    local maxHeightBuff = Client.GetScreenHeight() * (1 - spaceToBorder)
    
    if screenPos.x < minWidthBuff or screenPos.x > maxWidthBuff or
       screenPos.y < minHeightBuff or screenPos.y > maxHeightBuff or dotProduct < 0 then
       
        if player.nextWPInScreenSpace then
            player.nextWPDoingTrans = true
        end
        player.nextWPInScreenSpace = false
        
        local eyeForwardPos = player.lastPlayerEyePos + (player.lastPlayerForwardNorm * 5)
        local eyeForwardToWP = orderWayPoint - eyeForwardPos
        eyeForwardToWP:Normalize()
        local eyeForwardToWPScreen = Client.WorldToScreen(eyeForwardPos + eyeForwardToWP)
        local middleOfScreen = Vector(Client.GetScreenWidth() / 2, Client.GetScreenHeight() / 2, 0)
        local screenSpaceDir = eyeForwardToWPScreen - middleOfScreen
        screenSpaceDir:Normalize()
        local finalScreenPos = middleOfScreen + Vector(screenSpaceDir.x * (Client.GetScreenWidth() / 2), screenSpaceDir.y * (Client.GetScreenHeight() / 2), 0)
        
        local showArrow = not isCommander and (finalScreenPos.x < minWidthBuff or finalScreenPos.x > maxWidthBuff or finalScreenPos.y < minHeightBuff or finalScreenPos.y > maxHeightBuff)
        
        // Clamp to edge of screen with buffer
        finalScreenPos.x = Clamp(finalScreenPos.x, minWidthBuff, maxWidthBuff)
        finalScreenPos.y = Clamp(finalScreenPos.y, minHeightBuff, maxHeightBuff)
        
        returnTable = { finalScreenPos.x, finalScreenPos.y, nextWPScale, orderTypeName, nextWPDist, orderType, orderId, showArrow }
        
    else
    
        isInScreenSpace = true
        
        if not player.nextWPInScreenSpace then
            player.nextWPDoingTrans = true
        end
        player.nextWPInScreenSpace = true
        
        local bounceY = screenPos.y + (math.sin(Shared.GetTime() * 3) * (10 * nextWPScale))
        
        returnTable = { screenPos.x, bounceY, nextWPScale, orderTypeName, nextWPDist, orderType, orderId }
        
    end
    
    if player.nextWPDoingTrans then
    
        local replaceTable = { }
        local allEqual = true
        for i = 1, entriesPerWaypoint do
        
            if type(returnTable[i]) == "number" then
            
                replaceTable[i] = Slerp(player.nextWPLastVal[i], returnTable[i], 50)
                allEqual = allEqual and replaceTable[i] == returnTable[i]
                
            else
                replaceTable[i] = returnTable[i]
            end
            
        end
        
        if allEqual then
            player.nextWPDoingTrans = false
        end
        
        returnTable = replaceTable
        
    end
    
    for i = 1, entriesPerWaypoint do
        player.nextWPLastVal[i] = returnTable[i]
    end
    
    // Save current for next update.
    VectorCopy(playerEyePos, player.lastPlayerEyePos)
    VectorCopy(playerForwardNorm, player.lastPlayerForwardNorm)
    
    return returnTable
    
end

/**
 * Get the X position of the crosshair image in the atlas. 
 */
function PlayerUI_GetCrosshairX()
    return 0
end

/**
 * Get the Y position of the crosshair image in the atlas.
 * Listed in this order:
 *   Rifle, Pistol, Axe, Shotgun, Minigun, Rifle with GL, Flamethrower
 */
function PlayerUI_GetCrosshairY()

    local player = Client.GetLocalPlayer()

    if(player and not player:GetIsThirdPerson()) then  
      
        local weapon = player:GetActiveWeapon()
        if(weapon ~= nil) then
        
            // Get class name and use to return index
            local index 
            local mapname = weapon:GetMapName()
            
            if mapname == Rifle.kMapName then 
                index = 0
            elseif mapname == Pistol.kMapName then
                index = 1
            elseif mapname == Shotgun.kMapName then
                index = 3
            elseif mapname == Minigun.kMapName then
                index = 4
            elseif mapname == Flamethrower.kMapName then
                index = 5
            // All alien crosshairs are the same for now
            elseif mapname == LerkBite.kMapName or mapname == Spores.kMapName or mapname == LerkUmbra.kMapName or mapname == Parasite.kMapName then
                index = 6
            elseif(mapname == SpitSpray.kMapName) then
                index = 7
            // Blanks (with default damage indicator)
            else
                index = 8
            end
        
            return index * 64
            
        end
        
    end

end

function PlayerUI_GetCrosshairDamageIndicatorY()

    return 8 * 64
    
end

/**
 * Returns the player name under the crosshair for display (return "" to not display anything).
 */
function PlayerUI_GetCrosshairText()
    
    local player = Client.GetLocalPlayer()
    if player then
        if player.GetCrossHairText then
            return player:GetCrossHairText()
        else
            return player.crossHairText
        end
    end
    return nil
    
end

function Player:GetDisplayUnitStates()
    return self:GetIsAlive()
end

function PlayerUI_GetProgressText()

    local player = Client.GetLocalPlayer()
    if player then
        return player.progressText
    end
    return nil

end

function PlayerUI_GetProgressFraction()

    local player = Client.GetLocalPlayer()
    if player then
        return player.progressFraction
    end
    return nil

end

local kEnemyObjectiveRange = 30
function PlayerUI_GetObjectiveInfo()

    local player = Client.GetLocalPlayer()
    
    if player then
    
        if player.crossHairHealth and player.crossHairText then  
        
            player.showingObjective = true
            return player.crossHairHealth / 100, player.crossHairText .. " " .. ToString(player.crossHairHealth) .. "%", player.crossHairTeamType
            
        end
        
        // check command structures in range (enemy or friend) and return health % and name
        local objectiveInfoEnts = EntityListToTable( Shared.GetEntitiesWithClassname("ObjectiveInfo") )
        local playersTeam = player:GetTeamNumber()
        
        local function SortByHealthAndTeam(ent1, ent2)
            return ent1:GetHealthScalar() < ent2:GetHealthScalar() and ent1.teamNumber == playersTeam
        end
        
        table.sort(objectiveInfoEnts, SortByHealthAndTeam)
        
        for _, objectiveInfoEnt in ipairs(objectiveInfoEnts) do
        
            if objectiveInfoEnt:GetIsInCombat() and ( playersTeam == objectiveInfoEnt:GetTeamNumber() or (player:GetOrigin() - objectiveInfoEnt:GetOrigin()):GetLength() < kEnemyObjectiveRange ) then

                local healthFraction = math.max(0.01, objectiveInfoEnt:GetHealthScalar())

                player.showingObjective = true
                
                local text = StringReformat(Locale.ResolveString("OBJECTIVE_PROGRESS"),
                                            { location = objectiveInfoEnt:GetLocationName(),
                                              name = GetDisplayNameForTechId(objectiveInfoEnt:GetTechId()),
                                              health = math.ceil(healthFraction * 100) })
                
                return healthFraction, text, objectiveInfoEnt:GetTeamType()
                
            end
            
        end
        
        player.showingObjective = false
        
    end
    
end

function PlayerUI_GetShowsObjective()

    local player = Client.GetLocalPlayer()
    if player then
        return player.showingObjective == true
    end
    
    return false

end

function PlayerUI_GetCrosshairHealth()

    local player = Client.GetLocalPlayer()
    if player then
        if player.GetCrossHairHealth then
            return player:GetCrossHairHealth()
        else
            return player.crossHairHealth
        end
    end
    return nil

end

function PlayerUI_GetCrosshairMaturity()

    local player = Client.GetLocalPlayer()
    if player then
        if player.GetCrossHairMaturity then
            return player:GetCrossHairMaturity()
        else
            return player.crossHairMaturity
        end
    end
    return nil

end

function PlayerUI_GetCrosshairBuildStatus()

    local player = Client.GetLocalPlayer()
    if player then
        if player.GetCrossHairBuildStatus then
            return player:GetCrossHairBuildStatus()
        else
            return player.crossHairBuildStatus
        end
    end
    return nil

end

// Returns the int color to draw the results of PlayerUI_GetCrosshairText() in. 
function PlayerUI_GetCrosshairTextColor()
    local player = Client.GetLocalPlayer()
    if player then
        return player.crossHairTextColor
    end
    return kFriendlyColor
end

/**
 * Get the width of the crosshair image in the atlas, return 0 to hide
 */
function PlayerUI_GetCrosshairWidth()

    local player = Client.GetLocalPlayer()
    if player then

        local weapon = player:GetActiveWeapon()
    
        //if (weapon ~= nil and player:isa("Marine") and not player:GetIsThirdPerson()) then
    if (weapon ~= nil and not player:GetIsThirdPerson()) then
            return 64
        end
    end
    
    return 0
    
end

function PlayerUI_GetTooltipDataFromTechId(techId, hotkeyIndex)

    local techTree = GetTechTree()

    if techTree then
    
        local tooltipData = {}
        local techNode = techTree:GetTechNode(techId)

        tooltipData.text = GetDisplayNameForTechId(techId, "TIP")
        tooltipData.info = GetTooltipInfoText(techId)
        if target and target.GetTooltipText then
            tooltipData.info = target:GetTooltipText()
        end
        tooltipData.costNumber = LookupTechData(techId, kTechDataCostKey, 0)                
        tooltipData.requires = techTree:GetRequiresText(techId)
        tooltipData.enabled = techTree:GetEnablesText(techId)          
        tooltipData.techNode = techTree:GetTechNode(techId)
        
        tooltipData.resourceType = 0
        
        if techNode then
            tooltipData.resourceType = techNode:GetResourceType()
        end

        if hotkeyIndex then
        
            tooltipData.hotKey = kGridHotkeys[hotkeyIndex]
            
            if tooltipData.hotKey ~= "" then
                tooltipData.hotKey = gHotkeyDescriptions[tooltipData.hotKey]
            end
        
        end
        
        tooltipData.hotKey = tooltipData.hotKey or ""
    
        return tooltipData
    
    end

end


/**
 * Get the height of the crosshair image in the atlas, return 0 to hide
 */
function PlayerUI_GetCrosshairHeight()

    local player = Client.GetLocalPlayer()
    if(player ~= nil) then

        local weapon = player:GetActiveWeapon()    
        //if(weapon ~= nil and player:isa("Marine") and not player:GetIsThirdPerson()) then
    if (weapon ~= nil and not player:GetIsThirdPerson()) then
            return 64
        end
    
    end
    
    return 0

end

/**
 * Returns nil or the commander name.
 */
function PlayerUI_GetCommanderName()

    local player = Client.GetLocalPlayer()
    local commanderName = nil
    
    if player then
    
        // we simply use the scoreboard ui here, since it holds all informations required client side
        local commTable = ScoreboardUI_GetOrderedCommanderNames(player:GetTeamNumber())
        
        if table.count(commTable) > 0 then
            commanderName = commTable[1]
        end    
        
    end
    
    return commanderName
    
end

function PlayerUI_GetWeapon()
-- TODO : Return actual weapon name
    local player = Client.GetLocalPlayer()
    if player then
        return player:GetActiveWeapon()
    end
    return nil

end

/**
 * Returns a list of techIds (weapons) the player is carrying.
 */
function PlayerUI_GetInventoryTechIds()

    PROFILE("PlayerUI_GetInventoryTechIds")
    
    local player = Client.GetLocalPlayer()
    if player and HasMixin(player, "WeaponOwner") then
    
        local inventoryTechIds = table.array(5)
        local weaponList = player:GetHUDOrderedWeaponList()
        
        for w = 1, #weaponList do
        
            local weapon = weaponList[w]
            table.insert(inventoryTechIds, { TechId = weapon:GetTechId(), HUDSlot = weapon:GetHUDSlot() })
            
        end
        
        return inventoryTechIds
        
    end
    return { }
    
end

function PlayerUI_IsCameraAnimated()

    local player = Client.GetLocalPlayer()
    if player ~= nil then
        return player:IsAnimated()
    end
    
    return false
    
end

/**
 * Returns the techId of the active weapon.
 */
function PlayerUI_GetActiveWeaponTechId()

    PROFILE("PlayerUI_GetActiveWeaponTechId")
    
    local player = Client.GetLocalPlayer()
    if player then
    
        local activeWeapon = player:GetActiveWeapon()
        if activeWeapon then
            return activeWeapon:GetTechId()
        end
        
    end
    
end

function PlayerUI_GetPlayerClassName()

    local player = Client.GetLocalPlayer()
    if player then
        return player:GetClassName()
    end

end

function PlayerUI_GetPlayerClass()
    
    /*
    local player = Client.GetLocalPlayer()
    if player then
        return player:GetClassName()
    end
    */
    return "Player"

end

function PlayerUI_GetMinimapPlayerDirection()

    local player = Client.GetLocalPlayer()
    if player then
        local coords = player:GetViewAngles():GetCoords().zAxis
        return math.atan2(coords.x, coords.z)
    end
    return 0

end

function PlayerUI_GetReadyRoomOrders()

    local readyRoomOrders = { }
    
    for _, teamjoinEnt in ientitylist(Shared.GetEntitiesWithClassname("TeamJoin")) do
    
        if teamjoinEnt.teamNumber == kTeam1Index or teamjoinEnt.teamNumber == kTeam2Index then
        
            local order = { }
            order.TeamNumber = teamjoinEnt.teamNumber
            order.Position = teamjoinEnt:GetOrigin() + Vector(0, 1, 0)
            order.IsFull = teamjoinEnt.teamIsFull
            
            order.PlayerCount = teamjoinEnt.playerCount
            
            table.insert(readyRoomOrders, order)
            
        end
        
    end
    
    return readyRoomOrders
    
end

function PlayerUI_GetWeaponAmmo()

    local player = Client.GetLocalPlayer()
    
    if player then
        return player:GetWeaponAmmo()
    end
    
    return 0
    
end

function PlayerUI_GetWeaponClip()

    local player = Client.GetLocalPlayer()
    
    if player then
        return player:GetWeaponClip()
    end
    
    return 0
    
end

function PlayerUI_GetAuxWeaponClip()

    local player = Client.GetLocalPlayer()
    
    if player then
        return player:GetAuxWeaponClip()
    end
    
    return 0
    
end

function PlayerUI_GetWeldPercentage()

    local player = Client.GetLocalPlayer()
    
    if player and player.GetCurrentWeldPercentage then
        return player:GetCurrentWeldPercentage()
    end
    
    return 0
    
end

function PlayerUI_GetUnitStatusPercentage()

    local player = Client.GetLocalPlayer()
    
    if player and player.UnitStatusPercentage then
        return player:UnitStatusPercentage()
    end
    
    return 0
    
end

/**
 * Returns the amount of team resources.
 */
function PlayerUI_GetTeamResources()

    PROFILE("PlayerUI_GetTeamResources")
    
    local player = Client.GetLocalPlayer()
    if player then
        return player:GetDisplayTeamResources()
    end
    
    return 0
    
end

// TODO: 
function PlayerUI_MarineAbilityIconsImage()
end

function PlayerUI_GetGameStartTime()

    local entityList = Shared.GetEntitiesWithClassname("GameInfo")
    if entityList:GetSize() > 0 then
    
        local gameInfo = entityList:GetEntityAtIndex(0)
        local state = gameInfo:GetState()
        
        if state ~= kGameState.NotStarted and
           state ~= kGameState.PreGame and
           state ~= kGameState.Countdown then
            return gameInfo:GetStartTime()
        end
        
    end
    
    return 0
    
end

function PlayerUI_GetNumCommandStructures()

    local player = Client.GetLocalPlayer()
    if player ~= nil then
    
        local teamInfo = GetEntitiesForTeam("TeamInfo", player:GetTeamNumber())
        if table.count(teamInfo) > 0 then
            return teamInfo[1]:GetNumCapturedTechPoints()
        end
        
    end
    
    return 0
    
end

/**
 * Called by Flash to get the value to display for the personal resources on
 * the HUD.
 */
function PlayerUI_GetPlayerResources()

    local player = Client.GetLocalPlayer()
    if player then
        return player:GetDisplayResources()
    end
    
    return 0
    
end

/**
 * Returns a float instead of integer to define a change of the value.
 */
function PlayerUI_GetPersonalResources()

    PROFILE("PlayerUI_GetPersonalResources")
    
    local player = Client.GetLocalPlayer()
    if player then
        return player:GetPersonalResources()
    end
    
    return 0
    
end

function PlayerUI_GetPlayerHealth()

    local player = Client.GetLocalPlayer()
    if player then
    
        local health = math.ceil(player:GetHealth())
        // When alive, enforce at least 1 health for display.
        if player:GetIsAlive() then
            health = math.max(1, health)
        end
        return health
        
    end
    
    return 0
    
end

function PlayerUI_GetPlayerMaxHealth()

    local player = Client.GetLocalPlayer()
    if player then
        return player:GetMaxHealth()
    end
    
    return 0
    
end

function PlayerUI_GetPlayerArmor()

    local player = Client.GetLocalPlayer()
    if player then
        return player:GetArmor()
    end
    
    return 0
    
end

function PlayerUI_GetPlayerMaxArmor()

    local player = Client.GetLocalPlayer()
    if player then
        return player:GetMaxArmor()
    end
    
    return 0
    
end

function PlayerUI_GetPlayerIsParasited()

    local player = Client.GetLocalPlayer()
    if player then
        return player:GetGameEffectMask(kGameEffect.Parasite)
    end
    
    return false
    
end

function PlayerUI_GetPlayerJetpackFuel()

    local player = Client.GetLocalPlayer()
    
    if player:isa("JetpackMarine") then
        return player:GetFuel()
    end
    
    return 0
    
end

function PlayerUI_GetIsNanoShielded()

    local player = Client.GetLocalPlayer()
    
    if player and HasMixin(player, "NanoShieldAble") then
        
        return player:GetIsNanoShielded()
    
    end
    
    return false

end

function PlayerUI_GetPlayerParasiteState()

    local playerParasiteState = 1
    if PlayerUI_GetPlayerIsParasited() then
        playerParasiteState = 2
    end
    /*    
    elseif PlayerUI_GetPlayerOnInfestation() then
        playerParasiteState = 3
    end
    */
    
    return playerParasiteState

end
function PlayerUI_GetIsBeaconing()

    local player = Client.GetLocalPlayer()
    if player then
        return player:GetGameEffectMask(kGameEffect.Beacon)
    end
    return false

end

function PlayerUI_GetPlayerOnInfestation()

    local player = Client.GetLocalPlayer()
    if player then
        return player:GetGameEffectMask(kGameEffect.OnInfestation)
    end
    return false

end

// For drawing health circles
function GameUI_GetHealthStatus(entityId)

    local entity = Shared.GetEntity(entityId)
    if entity ~= nil then
    
        if HasMixin(entity, "Live") then
            return entity:GetHealth() / entity:GetMaxHealth()
        else
            Print("GameUI_GetHealthStatus(%d) - Entity type %s is not alive.", entityId, entity:GetMapName())
        end
        
    end
    
    return 0
    
end

function Player:GetName(forEntity)

    // There are cases where the player name will be nil such as right before
    // this Player is destroyed on the Client (due to the scoreboard removal message
    // being received on the Client before the entity removed message). Play it safe.
    return Scoreboard_GetPlayerData(self:GetClientIndex(), "Name") or "No Name"
    
end

function PlayerUI_GetPlayerName()

    local player = Client.GetLocalPlayer()
    if player then
        return player:GetName()
    end

    return ""    

end

function PlayerUI_GetEnergizeLevel()

    local energizeLevel = 0
    
    local player = Client.GetLocalPlayer()
    if player and HasMixin(player, "Energize") then
        energizeLevel = player:GetEnergizeLevel()
    end
    
    return energizeLevel
    
end

function Player:GetIsLocalPlayer()
    return self == Client.GetLocalPlayer()
end

function Player:GetDrawResourceDisplay()
    return false
end

function Player:GetShowHealthFor(player)
    return player:isa("Spectator") or ( not GetAreEnemies(self, player) and self:GetIsAlive() )
end

function Player:GetCrossHairTarget()

    local viewAngles = self:GetViewAngles()    
    local viewCoords = viewAngles:GetCoords()    
    local startPoint = self:GetEyePos()
    local endPoint = startPoint + viewCoords.zAxis * Player.kRangeFinderDistance
    
    local trace = Shared.TraceRay(startPoint, endPoint, CollisionRep.Damage, PhysicsMask.AllButPCsAndRagdolls, EntityFilterOne(self))
    return trace.entity
    
end

function Player:GetShowCrossHairText()
    return self:GetTeamNumber() == kMarineTeamType or self:GetTeamNumber() == kAlienTeamType
end

function Player:UpdateCrossHairText(entity)

    if self.buyMenu ~= nil then
        self.crossHairText = nil
        self.crossHairHealth = 0
        self.crossHairMaturity = 0
        self.crossHairBuildStatus = 0
        return
    end

    if not entity or ( entity.GetShowCrossHairText and not entity:GetShowCrossHairText(self) ) then
        self.crossHairText = nil
        return
    end    
    
    if HasMixin(entity, "Cloakable") and GetAreEnemies(self, entity) and entity:GetIsCloaked() then
        self.crossHairText = nil
        return
    end
    
    if entity:isa("Player") and GetAreEnemies(self, entity) then
        self.crossHairText = nil
        return
    end    
    
    if HasMixin(entity, "Tech") and HasMixin(entity, "Live") and (entity:GetIsAlive() or (entity.GetShowHealthFor and entity:GetShowHealthFor(self))) then
    
        if self:isa("Marine") and entity:isa("Marine") and self:GetActiveWeapon() and self:GetActiveWeapon():isa("Welder") then
            self.crossHairHealth = math.ceil(math.max(0.00, entity:GetArmor() / entity:GetMaxArmor() ) * 100)
        else
            self.crossHairHealth = math.ceil(math.max(0.00, entity:GetHealthScalar()) * 100)
        end
        
        if entity:isa("Player") then        
            self.crossHairText = entity:GetName()    
        else 
            self.crossHairText = Locale.ResolveString(LookupTechData(entity:GetTechId(), kTechDataDisplayName, ""))
            
            if entity:isa("CommandStructure") then
              self.crossHairText = entity:GetLocationName() .. " " .. self.crossHairText          
            end
            
        end    
            
        // add maturity % 
        /*
        if HasMixin(entity, "Maturity") then
        
            self.crossHairMaturity = 0
        
            if entity:GetMaturityLevel() == kMaturityLevel.Mature then
                self.crossHairText = "Mature " .. self.crossHairText
                //self.crossHairMaturity = 100
            else
                //self.crossHairMaturity = math.ceil(entity:GetMaturityFraction() * 100)
                
                if entity:GetMaturityLevel() == kMaturityLevel.Newborn then
                    self.crossHairText = "Newborn " .. self.crossHairText
                end
                
            end
            
        else
            self.crossHairMaturity = 0
        end
        
        */
        
        // add build %
        if HasMixin(entity, "Construct") then
        
            if entity:GetIsBuilt() then
                self.crossHairBuildStatus = 100
            else
                self.crossHairBuildStatus = math.floor(entity:GetBuiltFraction() * 100)
            end
        
        else
            self.crossHairBuildStatus = 0
        end
        
        if HasMixin(entity, "Team") then
            self.crossHairTeamType = entity:GetTeamType()        
        end
        
    else
    
        self.crossHairText = nil
        self.crossHairHealth = 0
        
        if entity:isa("Player") then
            self.crossHairText = entity:GetName()
        end
        
    end
        
    if GetAreEnemies(self, entity) then
        self.crossHairTextColor = kEnemyColor
    elseif HasMixin(entity, "GameEffects") and entity:GetGameEffectMask(kGameEffect.Parasite) then
        self.crossHairTextColor = kParasitedTextColor
    elseif HasMixin(entity, "Team") and self:GetTeamNumber() == entity:GetTeamNumber() then
        self.crossHairTextColor = kFriendlyColor
    else
        self.crossHairTextColor = kNeutralColor
    end

end

// Updates visibilty, status and position of health circle when aiming at an entity with live mixin
function Player:UpdateCrossHairTarget()
 
    //local entity = self:GetCrossHairTarget()
    
    if GetShowHealthRings() == false then
        entity = nil
    end    
    
    self:UpdateCrossHairText(entity)
    
end

// use only client side (for bringing up menus for example). Key events, and their consequences, are not send to the server
function Player:SendKeyEvent(key, down)

    // When exit hit, bring up menu
    if down and key == InputKey.Escape and (Shared.GetTime() > (self.timeLastMenu + 0.3) and not ChatUI_EnteringChatMessage()) then
    
        ExitPressed()
        self.timeLastMenu = Shared.GetTime()
        return true
        
    end
    
    if GetIsBinding(key, "RequestHealth") then
        self.timeOfLastHealRequest = Shared.GetTime()
    end
    
    return false

end

// For debugging. Cheats only.
function Player:ToggleTraceReticle()
    self.traceReticle = not self.traceReticle
end

function Player:UpdateMisc(input)

    PROFILE("Player:UpdateMisc")

    if not Shared.GetIsRunningPrediction() then
    
        self:UpdateCrossHairTarget()
        self:UpdateDamageIndicators()
        self:UpdateDeadSound()
        
    end
    
end

function Player:SetBlurEnabled(blurEnabled)

    if self:GetIsLocalPlayer() and Player.screenEffects.blur then
        Player.screenEffects.blur:SetActive(blurEnabled)
    end
    
end

local function CreatePhaseTweener()

    local phaseTweener = Tweener("forward")
    phaseTweener.add(0, { amount = 1 }, Easing.linear)
    local amplitude = 0.01
    local period = kPhaseEffectActiveTime * 0.75
    phaseTweener.add(kPhaseEffectActiveTime, { amount = 0 }, Easing.outElastic, { amplitude, period })
    return phaseTweener
    
end

function Player:UpdateScreenEffects(deltaTime)

    // Show low health warning if below the threshold and not a spectator and not a commander.
    local isSpectator = self:isa("Spectator") or self:isa("FilmSpectator")
    local isCommander = self:isa("Commander")
    local isEmbryo = self:isa("Embryo")
    local isExo = self:isa("Exo")
    if self:GetHealthScalar() <= kLowHealthWarning and not isSpectator and
       not isCommander and not isEmbryo and not isExo then
    
        Player.screenEffects.lowHealth:SetActive(true)
        local healthWeight = 1 - (self:GetHealthScalar() / kLowHealthWarning)
        local pulseSpeed = kLowHealthPulseSpeed / 2 + (kLowHealthPulseSpeed / 2 * healthWeight)
        local pulseScalar = (math.sin(Shared.GetTime() * pulseSpeed) + 1) / 2
        healthWeight = 0.5 + (0.5 * (healthWeight * pulseScalar))
        Player.screenEffects.lowHealth:SetParameter("healthWeight", healthWeight *.65)
        
    else
        Player.screenEffects.lowHealth:SetActive(false)
    end
    
    if Player.screenEffects.phase then
    
        self.clientTimeOfLastPhase = self.clientTimeOfLastPhase or 0
        self.clientStartPhaseEffectTime = self.clientStartPhaseEffectTime or 0
        if self.timeOfLastPhase and self.clientTimeOfLastPhase ~= self.timeOfLastPhase then
        
            self.clientTimeOfLastPhase = self.timeOfLastPhase
            self.clientStartPhaseEffectTime = Shared.GetTime()
            self.phaseTweener = CreatePhaseTweener()
            
        end
        
        if self.clientStartPhaseEffectTime ~= 0 and (Shared.GetTime() - self.clientStartPhaseEffectTime <= kPhaseEffectActiveTime) then
        
            Player.screenEffects.phase:SetActive(true)
            self.phaseTweener.update(deltaTime)
            Player.screenEffects.phase:SetParameter("amount", self.phaseTweener.getCurrentProperties().amount)
            
        else
            Player.screenEffects.phase:SetActive(false)
        end
        
    end
    
    // If we're cloaked, change screen effect
    local cloakScreenEffectState = HasMixin(self, "Cloakable") and self:GetIsCloaked()    
    self:SetCloakShaderState(cloakScreenEffectState)    
    self:UpdateCloakSoundLoop(cloakScreenEffectState)
    
    // Play disorient screen effect to show we're near a shade
    self:UpdateDisorientFX()
    
end

function Player:UpdateIdleSound()

    // Set idle sound parameter if playing
    if self.idleSoundInstance then
    
        // 1 means inactive, 0 means active   
        local value = ConditionalValue(Shared.GetTime() < self.timeOfIdleActive, 1, 0)
        self.idleSoundInstance:SetParameter("idle", value, 5)
        
        // Set speed parameter also
        local speedScalar = Clamp(self:GetSpeedScalar(), 0, 1)
        self.idleSoundInstance:SetParameter("speed", speedScalar, 5)
        
    end
    
end

function Player:GetDrawWorld(isLocal)
    return not self:GetIsLocalPlayer() or self:GetIsThirdPerson() or ((self.countingDown and not Shared.GetCheatsEnabled()) and self:GetTeamNumber() ~= kNeutralTeamType)
end

local kDangerCheckEndDistance = 25
local kDangerCheckStartDistance = 15
assert(kDangerCheckEndDistance > kDangerCheckStartDistance)
local kDangerHealthEndAmount = 0.6
local kDangerHealthStartAmount = 0.5
assert(kDangerHealthEndAmount > kDangerHealthStartAmount)
local function UpdateDangerEffects(self)

    if self:GetGameStarted() then
    
        local now = Shared.GetTime()
        self.lastDangerCheckTime = self.lastDangerCheckTime or now
        if now - self.lastDangerCheckTime > 1 then
        
            local playerOrigin = self:GetOrigin()
            // Check to see if there are any nearby Command Structures that are close to death.
            local commandStructures = GetEntitiesWithinRange("CommandStructure", playerOrigin, kDangerCheckEndDistance)
            Shared.SortEntitiesByDistance(playerOrigin, commandStructures)
            
            // Check if danger needs to be enabled or disabled
            if not self.dangerEnabled then
            
                if #commandStructures > 0 then
                
                    local commandStructure = commandStructures[1]
                    if commandStructure:GetIsBuilt() and commandStructure:GetIsAlive() and
                       commandStructure:GetIsInCombat() and
                       commandStructure:GetHealthScalar() <= kDangerHealthStartAmount and
                       commandStructure:GetDistance(playerOrigin) <= kDangerCheckStartDistance then
                    
                        self.dangerEnabled = true
                        self.dangerOrigin = commandStructure:GetOrigin()
                        Client.PlayMusic("danger")
                        
                    end
                    
                end
                
            else
            
                local commandStructure = commandStructures[1]
                if not commandStructure or not commandStructure:GetIsAlive() or
                   commandStructure:GetHealthScalar() >= kDangerHealthEndAmount or
                   not commandStructure:GetIsInCombat() or
                   self.dangerOrigin:GetDistanceTo(playerOrigin) > kDangerCheckEndDistance then
                
                    Client.PlayMusic("no_danger")
                    self.dangerEnabled = false
                    self.dangerOrigin = nil
                    
                end
                
            end
            
            self.lastDangerCheckTime = now
            
        end
        
    end
    
end

// Only called when not running prediction
function Player:UpdateClientEffects(deltaTime, isLocal)

    if isLocal then
    
        self:UpdateIdleSound()
        self:UpdateCommanderPingSound()
        UpdateDangerEffects(self)
        
    end
    
    // Rumbling effects due to Onos
    self:UpdateShakingLights(deltaTime)
    self:UpdateDirtFalling(deltaTime)
    //self:UpdateOnosRumble(deltaTime)
    
end

function Player:UpdateCommanderPingSound()

    local teamInfoEnts = GetEntitiesForTeam("TeamInfo", self:GetTeamNumber())
    local teamInfo = #teamInfoEnts > 0 and teamInfoEnts[1]
    
    if teamInfo then

        local pingTime = teamInfo:GetPingTime()
        if self.timeLastCommanderPing ~= nil and pingTime > self.timeLastCommanderPing then

            local pingSound = kDefaultPingSound
            if self:GetTeamType() == kMarineTeamType then
                pingSound = kMarinePingSound
            elseif self:GetTeamType() == kAlienTeamType then
                pingSound = kAlienPingSound
            end    
         
            Shared.PlaySound(nil, pingSound)
            
        end
        
        self.timeLastCommanderPing = pingTime
        
    end

end

function PlayerUI_GetCommanderPingInfo(onMiniMap)

    local timeSincePing = kCommanderPingDuration
    local position = Vector(0,0,0)
    local distance = 0
    local player = Client.GetLocalPlayer()
    local locationName = nil
    
    if player then
    
        for _, teamInfo in ipairs(GetEntitiesForTeam("TeamInfo", player:GetTeamNumber())) do
        
            local pingPos = teamInfo:GetPingPosition()
            
            local location = GetLocationForPoint(pingPos)
            locationName = location and location:GetName() or ""
        
            if not onMiniMap then            
                position = GetClampedScreenPosition(pingPos, 40)                
            else
                position = pingPos
            end
            
            timeSincePing = Shared.GetTime() - teamInfo:GetPingTime()
            distance = (player:GetEyePos() - pingPos):GetLength()
            
            break 

        end
    
    end
    
    return timeSincePing, position, distance, locationName

end

function PlayerUI_GetCrossHairVerticalOffset()

    local vOffset = 0
    local player = Client.GetLocalPlayer()
    
    if player and player.pitchDiff then
    
        vOffset = math.sin(player.pitchDiff) * Client.GetScreenWidth() / 2
    
    end
    
    return vOffset

end

function Player:SetDesiredName()

    // Set default player name to one set in Steam, or one we've used and saved previously
    local playerName = Client.GetOptionString( kNicknameOptionsKey, Client.GetUserName() )
   
    Shared.ConsoleCommand(string.format("name \"%s\"", playerName))

end

function Player:AddAlert(techId, worldX, worldZ, entityId, entityTechId)
    
    assert(worldX)
    assert(worldZ)
    
    // Create alert blip
    local alertType = LookupTechData(techId, kTechDataAlertType, kAlertType.Info)

    table.insert(self.alertBlips, worldX)
    table.insert(self.alertBlips, worldZ)
    table.insert(self.alertBlips, alertType - 1)
    
    // Create alert message => {text, icon x offset, icon y offset, -1, entity id}
    local alertText = GetDisplayNameForAlert(techId, "")
    
    local xOffset, yOffset = GetMaterialXYOffset(entityTechId, GetIsMarineUnit(self))
    if not xOffset or not yOffset then
        Print("Warning: Missing texture offsets for alert: %s techId %s", alertText, EnumToString(kTechId, entityTechId))
        xOffset = 0
        yOffset = 0
    end
    
    table.insert(self.alertMessages, alertText)
    table.insert(self.alertMessages, xOffset)
    table.insert(self.alertMessages, yOffset)
    table.insert(self.alertMessages, entityId)
    table.insert(self.alertMessages, worldX)
    table.insert(self.alertMessages, worldZ)
    
end

function Player:GetAlertBlips()

    local alertBlips = {}
    table.copy(self.alertBlips, alertBlips)
    return alertBlips
    
end

function Player:ClearAlertBlips()
    table.clear(self.alertBlips)    
end

function Player:OnGUIUpdated()
    self:ClearAlertBlips()
end

local function DisableDanger(self)

    // Stop looping music.
    if self:GetIsLocalPlayer() then
        Client.StopMusic("danger")
    end
    
end

local function DisableScreenEffects(self)

    if self:GetIsLocalPlayer() then
    
        for _, effect in pairs(Player.screenEffects) do
            effect:SetActive(false)
        end
        
    end
    
end

// Called on the Client only, after OnInitialized(), for a ScriptActor that is controlled by the local player.
// Ie, the local player is controlling this Marine and wants to intialize local UI, flash, etc.
function Player:OnInitLocalClient()

    self.minimapVisible = false
    
    self.alertBlips = { }
    self.alertMessages = { }
    
    // Initialize offsets used for drawing tech ids as buttons
    InitTechTreeMaterialOffsets()

    // Only create base HUDs the first time a player is created.
    // We only ever want one of these.
    GetGUIManager():CreateGUIScriptSingle("GUICrosshair")
    GetGUIManager():CreateGUIScriptSingle("GUIScoreboard")
    GetGUIManager():CreateGUIScriptSingle("GUINotifications")
    GetGUIManager():CreateGUIScriptSingle("GUIDamageIndicators")
    GetGUIManager():CreateGUIScriptSingle("GUIDeathMessages")
    GetGUIManager():CreateGUIScriptSingle("GUIChat")
    GetGUIManager():CreateGUIScriptSingle("GUIVoiceChat")
    self.minimapScript = GetGUIManager():CreateGUIScriptSingle("GUIMinimapFrame")
    GetGUIManager():CreateGUIScriptSingle("GUIMapAnnotations")
    //GetGUIManager():CreateGUIScriptSingle("GUIPlayerNameTags")
    GetGUIManager():CreateGUIScriptSingle("GUIGameEnd")
    GetGUIManager():CreateGUIScriptSingle("GUIWorldText")
    GetGUIManager():CreateGUIScriptSingle("GUIPing")
    GetGUIManager():CreateGUIScriptSingle("GUICommunicationStatusIcons")
    
    if self.unitStatusDisplay == nil then
    
        self.unitStatusDisplay = GetGUIManager():CreateGUIScript("GUIUnitStatus")
        self.unitStatusDisplay:EnableAlienStyle()
        
    end
    
    DisableScreenEffects(self)

    // Re-enable skybox rendering after commanding
    SetSkyboxDrawState(true)
    
    // Show props normally
    SetCommanderPropState(false)
    
    // Turn on sound occlusion for non-commanders
    Client.SetSoundGeometryEnabled(true)
    
    // Setup materials, etc. for death messages
    InitDeathMessages(self)
    
    // Fix after Main/Client issue resolved
    self:SetDesiredName()
    
    self.traceReticle = false
    
    self.damageIndicators = { }
    
    // Set commander geometry visible
    Client.SetGroupIsVisible(kCommanderInvisibleGroupName, true)
    
    Client.SetEnableFog(true)
    
    local loopingIdleSound = self:GetIdleSoundName()
    if loopingIdleSound then
        
        local soundIndex = Shared.GetSoundIndex(loopingIdleSound)
        self.idleSoundInstance = Client.CreateSoundEffect(soundIndex)
        self.idleSoundInstance:SetParent(self:GetId())
        self.idleSoundInstance:Start()
        
        self.timeOfIdleActive = Shared.GetTime()
        
    end
    
    self.crossHairText = nil
    self.crossHairTextColor = kFriendlyColor
    
    // reset mouse sens in case it hase been forgotten somewhere else
    Client.SetMouseSensitivityScalar(1)
    
    // Just in case the danger music wasn't stopped already for some reason.
    DisableDanger(self)
    
end

function Player:OnVortexClient()

    self:SetEthereal(true)
    if self:GetIsLocalPlayer() then
    
        StartSoundEffectForPlayer(kVortexed2DStart, self)
        TEST_EVENT("Player Vortex start sound played")
        
    end
    
end

function Player:OnVortexEndClient()

    self:SetEthereal(false)
    if self:GetIsLocalPlayer() then
    
        StartSoundEffectForPlayer(kVortexed2DEnd, self)
        TEST_EVENT("Player Vortex end sound played")
        
    end
    
end

function Player:SetCloakShaderState(state)

    if self:GetIsLocalPlayer() and Player.screenEffects.cloaked then
        Player.screenEffects.cloaked:SetActive(state)
    end
    
end

function Player:UpdateDisorientSoundLoop(state)

    // Start or stop sound effects
    if state ~= self.playerDisorientSoundLoopPlaying then
        
        self:TriggerEffects("disorient_loop", {active = state})
        self.playerDisorientSoundLoopPlaying = state
        
    end

end

function Player:UpdateCloakSoundLoop(state)

    // Start or stop sound effects
    if state ~= self.playerCloakSoundLoopPlaying then
    
        self:TriggerEffects("cloak_loop", {active = state})
        self.playerCloakSoundLoopPlaying = state
        
    end
    
end

function Player:UpdateDisorientFX()

    if Player.screenEffects.disorient then
    
        local amount = 0
        if HasMixin(self, "Disorientable") then
            amount = self:GetDisorientedAmount()
        end
        
        local state = (amount > 0)
        if not self:GetIsThirdPerson() or not state then
            Player.screenEffects.disorient:SetActive(state)
        end
        
        Player.screenEffects.disorient:SetParameter("amount", amount)
        
    end
    
    self:UpdateDisorientSoundLoop(state)
    
end

/**
 * Called when the player entity is destroyed.
 */
function Player:OnDestroy()

    ScriptActor.OnDestroy(self)
    
    if self.viewModel ~= nil then
    
        Client.DestroyRenderViewModel(self.viewModel)
        self.viewModel = nil
        
    end
    
    self:UpdateCloakSoundLoop(false)
    self:UpdateDisorientSoundLoop(false)
    
    self:CloseMenu()
    
    if self.idleSoundInstance then
        Client.DestroySoundEffect(self.idleSoundInstance)
    end
    
    if self.guiCountDownDisplay then
    
        GetGUIManager():DestroyGUIScript(self.guiCountDownDisplay)
        self.guiCountDownDisplay = nil
        
    end
    
    if self.unitStatusDisplay then
    
        GetGUIManager():DestroyGUIScript(self.unitStatusDisplay)
        self.unitStatusDisplay = nil
        
    end
    
    DisableDanger(self)
    
end

/**
 * Clear screen effects on the player immediately upon being killed so
 * they don't have them enabled while spectating. This is required now
 * that the dead player entity exists alongside the new spectator player.
 */
function Player:OnKillClient()

    DisableScreenEffects(self)
    DisableDanger(self)
    
end

function Player:DrawGameStatusMessage()

    local time = Shared.GetTime()
    local fraction = 1 - (time - math.floor(time))
    Client.DrawSetColor(255, 0, 0, fraction*200)

    if(self.countingDown) then
    
        Client.DrawSetTextPos(.42*Client.GetScreenWidth(), .95*Client.GetScreenHeight())
        Client.DrawString("Game is starting")
        
    else
    
        Client.DrawSetTextPos(.25*Client.GetScreenWidth(), .95*Client.GetScreenHeight())
        Client.DrawString("Game will start when both sides have players")
        
    end

end

function entityIdInList(entityId, entityList, useParentId)

    for index, entity in ipairs(entityList) do
    
        local id = entity:GetId()
        if(useParentId) then id = entity:GetParentId() end
        
        if(id == entityId) then
        
            return true
            
        end
        
    end
    
    return false
    
end

function Player:DebugVisibility()

    // For each visible entity on other team
    local entities = GetEntitiesMatchAnyTypesForTeam({"Player", "ScriptActor"}, GetEnemyTeamNumber(self:GetTeamNumber()))
    
    for entIndex, entity in ipairs(entities) do
    
        // If so, remember that it's seen and break
        local seen = GetCanSeeEntity(self, entity)            
        
        // Draw red or green depending
        DebugLine(self:GetEyePos(), entity:GetOrigin(), 1, ConditionalValue(seen, 0, 1), ConditionalValue(seen, 1, 0), 0, 1)
        
    end

end

function Player:CloseMenu()
    return false    
end

function Player:ShowMap(showMap, showBig, forceReset)

    self.minimapVisible = showMap and showBig
    
    self.minimapScript:ShowMap(showMap)
    self.minimapScript:SetBackgroundMode((showBig and GUIMinimapFrame.kModeBig) or GUIMinimapFrame.kModeMini, forceReset)

end

function Player:GetWeaponAmmo()

    // We could do some checks to make sure we have a non-nil ClipWeapon,
    // but this should never be called unless we do.
    local weapon = self:GetActiveWeapon()
    
    if(weapon ~= nil and weapon:isa("ClipWeapon")) then
        return weapon:GetAmmo()
    end
    
    return 0
    
end

function Player:GetWeaponClip()

    // We could do some checks to make sure we have a non-nil ClipWeapon,
    // but this should never be called unless we do.
    local weapon = self:GetActiveWeapon()
    
    if weapon ~= nil then
        if weapon:isa("ClipWeapon") then
            return weapon:GetClip()
        elseif weapon:isa("LayMines") then
            return weapon:GetMinesLeft()
        end
    end
    
    return 0
    
end

function Player:GetAuxWeaponClip()

    // We could do some checks to make sure we have a non-nil ClipWeapon,
    // but this should never be called unless we do.
    local weapon = self:GetActiveWeapon()
    
    if(weapon ~= nil and weapon:isa("ClipWeapon")) then
        return weapon:GetAuxClip()
    end
    
    return 0
    
end   

function Player:OnConstructTarget(target)

    if self:GetIsLocalPlayer() and HasMixin(target, "Construct") then
        self.timeLastConstructed = Shared.GetTime()
    end

end

function Player:GetHeadAttachpointName()
    return "Head"
end

function Player:GetCameraViewCoordsOverride(cameraCoords)

    local initialAngles = Angles()
    initialAngles:BuildFromCoords(cameraCoords)

    local continue = true

    if not self:GetIsAlive() and self:GetAnimateDeathCamera() then

        local attachCoords = self:GetAttachPointCoords(self:GetHeadAttachpointName())

        local animationIntensity = 0.2
        local movementIntensity = 0.5
        
        cameraCoords.yAxis = GetNormalizedVector(cameraCoords.yAxis + attachCoords.yAxis * animationIntensity)
        cameraCoords.xAxis = cameraCoords.yAxis:CrossProduct(cameraCoords.zAxis)
        cameraCoords.zAxis = cameraCoords.xAxis:CrossProduct(cameraCoords.yAxis)        
        
        cameraCoords.origin.x = cameraCoords.origin.x + (attachCoords.origin.x - cameraCoords.origin.x) * movementIntensity
        cameraCoords.origin.y = attachCoords.origin.y
        cameraCoords.origin.z = cameraCoords.origin.z + (attachCoords.origin.z - cameraCoords.origin.z) * movementIntensity
        
        return cameraCoords
    
    end

    if self.countingDown and not Shared.GetCheatsEnabled() then
    
        if HasMixin(self, "Team") and (self:GetTeamNumber() == kMarineTeamType or self:GetTeamNumber() == kAlienTeamType) then
            cameraCoords = self:GetCameraViewCoordsCountdown(cameraCoords)
            Client.SetYaw(self.viewYaw)
            Client.SetPitch(self.viewPitch)
            continue = false
        end
        
        if not self.clientCountingDown then

            self.clientCountingDown = true    
            if self.OnCountDown then
                self:OnCountDown()
            end  
  
        end
        
    end
        
    if continue then
    
         if self.clientCountingDown then
            self.clientCountingDown = false
            
            if self.OnCountDownEnd then
                self:OnCountDownEnd()
            end 
        end
        
        local activeWeapon = self:GetActiveWeapon()
        local animateCamera = activeWeapon and (not activeWeapon.GetPreventCameraAnimation or not activeWeapon:GetPreventCameraAnimation(self))
    
        // clamp the yaw value to prevent sudden camera flip    
        local cameraAngles = Angles()
        cameraAngles:BuildFromCoords(cameraCoords)
        cameraAngles.pitch = Clamp(cameraAngles.pitch, -kMaxPitch, kMaxPitch)

        cameraCoords = cameraAngles:GetCoords(cameraCoords.origin)

        // Add in camera movement from view model animation
        if self:GetCameraDistance() == 0 then    
        
            local viewModel = self:GetViewModelEntity()
            if viewModel and animateCamera then
            
                local success, viewModelCameraCoords = viewModel:GetCameraCoords()
                if success then
                
                    // If the view model coords has scaling in it that can affect
                    // our later calculations, so remove it.
                    viewModelCameraCoords.xAxis:Normalize()
                    viewModelCameraCoords.yAxis:Normalize()
                    viewModelCameraCoords.zAxis:Normalize()

                    cameraCoords = cameraCoords * viewModelCameraCoords
                    
                end
                
            end
        
        end

        // Allow weapon or ability to override camera (needed for Blink)
        if activeWeapon then
        
            local override, newCoords = activeWeapon:GetCameraCoords()
            
            if override then
                cameraCoords = newCoords
            end
            
        end

        // Add in camera shake effect if any
        if(Shared.GetTime() < self.cameraShakeTime) then
        
            // Camera shake knocks view up and down a bit
            local shakeAmount = math.sin( Shared.GetTime() * self.cameraShakeSpeed * 2 * math.pi ) * self.cameraShakeAmount
            local origin = Vector(cameraCoords.origin)
            
            //cameraCoords.origin = cameraCoords.origin + self.shakeVec*shakeAmount
            local yaw = GetYawFromVector(cameraCoords.zAxis)
            local pitch = GetPitchFromVector(cameraCoords.zAxis) + shakeAmount
            
            local angles = Angles(Clamp(pitch, -kMaxPitch, kMaxPitch), yaw, 0)
            cameraCoords = angles:GetCoords(origin)
            
        end
        
        cameraCoords = self:PlayerCameraCoordsAdjustment(cameraCoords)
    
    end

    local resultingAngles = Angles()
    resultingAngles:BuildFromCoords(cameraCoords)
    /*
    local fovScale = 1
    
    if self:GetNumModelCameras() > 0 then
        local camera = self:GetModelCamera(0)
        fovScale = camera:GetFov() / math.rad(self:GetFov())
    else
        fovScale = 65 / self:GetFov()
    end

    self.pitchDiff = GetAnglesDifference(resultingAngles.pitch, initialAngles.pitch) * fovScale*/
  
    return cameraCoords
    
end

function Player:GetCountDownFraction()

    if not self.clientTimeCountDownStarted then
        self.clientTimeCountDownStarted = Shared.GetTime()
    end
    
    return Clamp((Shared.GetTime() - self.clientTimeCountDownStarted) / Player.kCountDownLength, 0, 1)

end

function Player:GetCountDownTime()

    if self.clientTimeCountDownStarted then
        return Player.kCountDownLength - (Shared.GetTime() - self.clientTimeCountDownStarted)
    end
    
    return Player.kCountDownLength

end

function Player:GetCountDownCamerStartCoords()

    local coords = nil
    
    // find the closest command structure and a random start position, look at it at start
    local commandStructures = GetEntitiesForTeam("CommandStructure", self:GetTeamNumber())
    
    if #commandStructures > 0 then
    
        local extents = LookupTechData(kTechDataMaxExtents, self:GetTechId(), Vector(Player.kXZExtents, Player.kYExtents, Player.kXZExtents))
        local randomSpawn = GetRandomSpawnForCapsule(extents.y, extents.x, commandStructures[1]:GetOrigin(), 4, 7, EntityFilterAll())
    
        if randomSpawn then
        
            randomSpawn = randomSpawn + Vector(0, 2, 0)
            local directionToPlayer = self:GetEyePos() - randomSpawn  
            directionToPlayer.y = 0
            directionToPlayer:Normalize()  
            coords =  Coords.GetLookIn(randomSpawn, directionToPlayer)
            
        end    

    end
    
    return coords

end  

function Player:OnCountDown()

    if not Shared.GetCheatsEnabled() then
    
        if not self.guiCountDownDisplay and HasMixin(self, "Team") and (self:GetTeamNumber() == kMarineTeamType or self:GetTeamNumber() == kAlienTeamType) then
            self.guiCountDownDisplay = GetGUIManager():CreateGUIScript("GUICountDownDisplay")
        end
        
    end

end

function Player:OnCountDownEnd()

    if self.guiCountDownDisplay then
    
        GetGUIManager():DestroyGUIScript(self.guiCountDownDisplay)
        self.guiCountDownDisplay = nil
        
    end
    
    Client.PlayMusic("round_start")
    
end

function Player:GetCameraViewCoordsCountdown(cameraCoords)

    if not Shared.GetCheatsEnabled() then
    
        if not self.countDownStartCameraCoords then
            self.countDownStartCameraCoords = self:GetCountDownCamerStartCoords()
        end
        
        if not self.countDownEndCameraCoords then
            self.countDownEndCameraCoords = self:GetViewCoords()
        end

        if self.countDownStartCameraCoords then
        
            local originDiff = self.countDownEndCameraCoords.origin - self.countDownStartCameraCoords.origin        
            local zAxisDiff = self.countDownEndCameraCoords.zAxis - self.countDownStartCameraCoords.zAxis
            zAxisDiff.y = 0
            local animationFraction = self:GetCountDownFraction()
            
            //local viewDirection = self.countDownStartCameraCoords.zAxis + zAxisDiff * animationFraction
            local viewDirection = self.countDownStartCameraCoords.zAxis + zAxisDiff * ( math.cos((animationFraction * (math.pi / 2)) + math.pi ) + 1)

            viewDirection:Normalize()
            
            cameraCoords = Coords.GetLookIn(self.countDownStartCameraCoords.origin + originDiff * animationFraction, viewDirection)
            
            // correct the yAxis to prevent camera flipping
            if cameraCoords.yAxis:DotProduct(Vector(0, 1, 0)) < 0 then
                cameraCoords.yAxis = cameraCoords.zAxis:CrossProduct(-cameraCoords.xAxis)
                cameraCoords.xAxis = viewDirection:CrossProduct(cameraCoords.yAxis)
            end
            
        end
        
    end

    return cameraCoords

end

function Player:PlayerCameraCoordsAdjustment(cameraCoords)

    // No adjustment by default. This function can be overridden to modify the camera
    // coordinates right before rendering.
    return cameraCoords

end

// Ignore camera shaking when done quickly in a row
function Player:SetCameraShake(amount, speed, time)

    // Overrides existing shake if it has elapsed or if new shake amount is larger
    local success = false
    
    local currentTime = Shared.GetTime()
    
    if self.cameraShakeLastTime ~= nil and (currentTime > (self.cameraShakeLastTime + .5)) then
    
        if currentTime > self.cameraShakeTime or amount > self.cameraShakeAmount then
        
            self.cameraShakeAmount = amount

            // "bumps" per second
            self.cameraShakeSpeed = speed 
            
            self.cameraShakeTime = currentTime + time
            
            self.cameraShakeLastTime = currentTime
            
            success = true
            
        end
        
    end
    
    return success
    
end

function PlayerUI_GetIsWaitingForTeamBalance()

    local player = Client.GetLocalPlayer()
    if player then
        return player:GetIsWaitingForTeamBalance()
    end
    
    return false
    
end

function PlayerUI_GetIsRepairing()

    local player = Client.GetLocalPlayer()
    if player then
        return player.timeLastRepaired ~= nil and player.timeLastRepaired + 1 > Shared.GetTime()
    end    
    
    return false
    
end

function PlayerUI_GetIsConstructing()

    local player = Client.GetLocalPlayer()
    if player then
        return player.timeLastConstructed ~= nil and player.timeLastConstructed + 1 > Shared.GetTime()
    end
    
    return false
    
end

function PlayerUI_GetLocationPower()

    local player = Client.GetLocalPlayer()
    local isPowered = false
    local powerSource = nil
    local lightMode = nil
    
    if player then
    
        local powerPoint = GetPowerPointForLocation(player:GetLocationName())
        powerSource = powerPoint
        if powerPoint then
        
            isPowered = powerPoint:GetIsPowering()
            lightMode = powerPoint:GetLightMode()
            
        end
        
    end
    
    return { isPowered, powerSource, lightMode }
    
end

// fetch the oldest notification
function PlayerUI_GetRecentNotification()

    if gDebugNotifications then
        if math.random() < 0.2 then
            return { LocationName = "Test Location" , TechId = math.random(1, 80) }
        end
    end

    local notification = nil
    
    local player = Client.GetLocalPlayer()
    if player and player.GetAndClearNotification then
        notification = player:GetAndClearNotification()
    end

    return notification
end

function PlayerUI_GetHasItem(techId)

    local hasItem = false

    if techId and techId ~= kTechId.None then
    
        local player = Client.GetLocalPlayer()
        if player then
        
            local items = GetChildEntities(player, "ScriptActor")

            for index, item in ipairs(items) do
            
                if item:GetTechId() == techId then
                
                    hasItem = true
                    break
                    
                end

            end
        
        end
    
    end
    
    return hasItem

end

local gPreviousTechId = kTechId.None
function PlayerUI_GetRecentPurchaseable()

    local player = Client.GetLocalPlayer()
    if player ~= nil then
        local teamInfo = GetEntitiesForTeam("TeamInfo", player:GetTeamNumber())
        if table.count(teamInfo) > 0 then
        
            local newTechId = teamInfo[1]:GetLatestResearchedTech()
            local playSound = newTechId ~= gPreviousTechId
            
            gPreviousTechId = newTechId
            return newTechId, playSound
            
        end
    end
    return 0, false

end

// returns 0 - 3
function PlayerUI_GetArmorLevel()
    local armorLevel = 0
    
    if Client.GetLocalPlayer().gameStarted then
    
        local techTree = GetTechTree()
    
        if techTree then
        
            local armor3Node = techTree:GetTechNode(kTechId.Armor3)
            local armor2Node = techTree:GetTechNode(kTechId.Armor2)
            local armor1Node = techTree:GetTechNode(kTechId.Armor1)
        
            if armor3Node and armor3Node:GetResearched() then
                armorLevel = 3
            elseif armor2Node and armor2Node:GetResearched()  then
                armorLevel = 2
            elseif armor1Node and armor1Node:GetResearched()  then
                armorLevel = 1
            end
            
        end
    
    end

    return armorLevel
end

function PlayerUI_GetWeaponLevel()
    local weaponLevel = 0
    
    if Client.GetLocalPlayer().gameStarted then
    
        local techTree = GetTechTree()
    
        if techTree then
        
            local weapon3Node = techTree:GetTechNode(kTechId.Weapons3)
            local weapon2Node = techTree:GetTechNode(kTechId.Weapons2)
            local weapon1Node = techTree:GetTechNode(kTechId.Weapons1)
        
            if weapon3Node and weapon3Node:GetResearched() then
                weaponLevel = 3
            elseif weapon2Node and weapon2Node:GetResearched()  then
                weaponLevel = 2
            elseif weapon1Node and weapon1Node:GetResearched()  then
                weaponLevel = 1
            end
            
        end  
    
    end
    
    return weaponLevel
end

// Draw the current location on the HUD ("Marine Start", "Processing", etc.)
function PlayerUI_GetLocationName()

    local locationName = ""
    
    local player = Client.GetLocalPlayer()
    if player ~= nil and player:GetIsPlaying() then
        locationName = player:GetLocationName()
    end
    
    return locationName
    
end

function PlayerUI_GetOrigin()

    local player = Client.GetLocalPlayer()    
    if player ~= nil then
        return player:GetOrigin()
    end
    
    return Vector(0, 0, 0)
    
end

function PlayerUI_GetYaw()

    local player = Client.GetLocalPlayer()    
    if player ~= nil then
        return player:GetAngles().yaw
    end
    
    return 0
    
end

function PlayerUI_GetEyePos()

    local player = Client.GetLocalPlayer()    
    if player ~= nil then
        return player:GetEyePos()
    end
    
    return Vector(0, 0, 0)
    
end

function PlayerUI_GetCountDownFraction()

    local player = Client.GetLocalPlayer()
    
    if player and player.GetCountDownFraction then
        return player:GetCountDownFraction()
    end
    
    return 0
    
end

function PlayerUI_GetRemainingCountdown()

    local player = Client.GetLocalPlayer()
    
    if player and player.GetCountDownFraction then
        return player:GetCountDownTime()
    end
    
    return 0
    
end

function PlayerUI_GetIsThirdperson()

    local player = Client.GetLocalPlayer()
    
    if player then
    
        return player:GetIsThirdPerson()
    
    end
    
    return false

end

function PlayerUI_GetIsPlaying()

    local player = Client.GetLocalPlayer()
    
    if player then
        return player:GetIsPlaying()
    end
    
    return false
    
end

function PlayerUI_GetForwardNormal()

    local player = Client.GetLocalPlayer()
    if player ~= nil then
        return player:GetCameraViewCoords().zAxis
    end
    return Vector(0, 0, 1)
    
end

function PlayerUI_IsACommander()

    local player = Client.GetLocalPlayer()
    if player ~= nil then
        return player:isa("Commander")
    end
    
    return false
    
end

function PlayerUI_IsASpectator()

    local player = Client.GetLocalPlayer()
    if player ~= nil then
        return player:isa("Spectator")
    end
    
    return false
    
end

function PlayerUI_IsOverhead()

    local player = Client.GetLocalPlayer()
    if player ~= nil then
        return player:isa("Commander") or (player:isa("Spectator") and player:GetIsOverhead())
    end
    
    return false
    
end

function PlayerUI_IsOnMarineTeam()

    local player = Client.GetLocalPlayer()
    if player and HasMixin(player, "Team") then
        return player:GetTeamNumber() == kMarineTeamType
    end
    
    return false    
    
end

function PlayerUI_IsOnAlienTeam()

    local player = Client.GetLocalPlayer()
    if player and HasMixin(player, "Team") then
        return player:GetTeamNumber() == kAlienTeamType
    end
    
    return false  
    
end

function PlayerUI_IsAReadyRoomPlayer()

    local player = Client.GetLocalPlayer()
    if player ~= nil then
        return player:GetTeamNumber() == kTeamReadyRoom
    end
    
    return false
    
end

function PlayerUI_GetTeamNumber()

    local player = Client.GetLocalPlayer()
    
    if player and HasMixin(player, "Team") then    
        return player:GetTeamNumber()    
    end
    
    return 0

end

function PlayerUI_GetRequests()

    local player = Client.GetLocalPlayer()
    local requests = {}
    
    if player and player.GetRequests then

        for _, techId in ipairs() do
        
            local name = GetDisplayNameForTechId(techId)
            
            table.insert(requests, { Name = name, TechId = techId } )
        
        end
 
    end
    
    return requests

end

function PlayerUI_GetTimeDamageTaken()

    local player = Client.GetLocalPlayer()
    if player then
    
        if HasMixin(player, "Combat") then
            return player:GetTimeLastDamageTaken()
        end
    
    end
    
    return 0

end

function PlayerUI_GetTeamType()

    local player = Client.GetLocalPlayer()
    
    if player and HasMixin(player, "Team") then    
        return player:GetTeamType()    
    end
    
    return kNeutralTeamType

end

function PlayerUI_GetHasGameStarted()

     local player = Client.GetLocalPlayer()
     return player and player:GetGameStarted()
     
end

function PlayerUI_GetTeamColor(teamNumber)

    if teamNumber then
        return ColorIntToColor(GetColorForTeamNumber(teamNumber))
    else
        local player = Client.GetLocalPlayer()
        return ColorIntToColor(GetColorForPlayer(player))
    end
    
end

/**
 * Returns all locations as a name and origin.
 */
function PlayerUI_GetLocationData()

    local returnData = { }
    local locationEnts = GetLocations()
    for i, location in ipairs(locationEnts) do
        if location:GetShowOnMinimap() then
            table.insert(returnData, { Name = location:GetName(), Origin = location:GetOrigin() })
        end
    end
    return returnData

end

/**
 * Converts world coordinates into normalized map coordinates.
 */
function PlayerUI_GetMapXY(worldX, worldZ)

    local player = Client.GetLocalPlayer()
    if player then
        local success, mapX, mapY = player:GetMapXY(worldX, worldZ)
        return mapX, mapY
    end
    return 0, 0

end

/**
 * Returns a linear array of static blip data
 * X position, Y position, rotation, X texture offset, Y texture offset, kMinimapBlipType, kMinimapBlipTeam
 *
 * Eg {0.5, 0.5, 1.32, 0, 0, 3, 1}
 */
function PlayerUI_GetStaticMapBlips()

    PROFILE("PlayerUI_GetStaticMapBlips")

    local player = Client.GetLocalPlayer()
    local blipsData = {}
    local numBlips = 0
    
    local minimapBlipTeamAlien    = kMinimapBlipTeam.Alien
    local minimapBlipTeamMarine   = kMinimapBlipTeam.Alien
    local minimapBlipTeamFriendly = kMinimapBlipTeam.Friendly
    local minimapBlipTeamEnemy    = kMinimapBlipTeam.Enemy
    local minimapBlipTeamNeutral  = kMinimapBlipTeam.Neutral
    
    if player then
    
        local playerTeam      = player:GetTeamNumber()
        local playerNoTeam    = playerTeam == kRandomTeamType or playerTeam == kNeutralTeamType
        local playerEnemyTeam = GetEnemyTeamNumber(playerTeam)
        local playerId        = player:GetId()
      
        local mapBlipList = Shared.GetEntitiesWithClassname("MapBlip")
        local GetEntityAtIndex = mapBlipList.GetEntityAtIndex
        
        for index = 0, mapBlipList:GetSize() - 1 do
        
            local blip = GetEntityAtIndex(mapBlipList, index)
            if blip ~= nil and blip.ownerEntityId ~= playerId then
            
                local blipTeam = minimapBlipTeamNeutral
                local blipTeamNumber = blip:GetTeamNumber()        
            
                if playerNoTeam then
                    if blipTeamNumber == kMarineTeamType then
                        blipTeam = minimapBlipTeamMarine
                    elseif blipTeamNumber== kAlienTeamType then
                        blipTeam = minimapBlipTeamAlien
                    end
                else
                    if blipTeamNumber == playerTeam then
                        blipTeam = minimapBlipTeamFriendly
                    elseif blipTeamNumber == playerEnemyTeam then
                        blipTeam = minimapBlipTeamEnemy
                    end
                end    
              
                local i = numBlips * 8
                local blipOrig = blip:GetOrigin()
                blipsData[i + 1] = blipOrig.x
                blipsData[i + 2] = blipOrig.z
                blipsData[i + 3] = blip:GetRotation()
                blipsData[i + 4] = 0
                blipsData[i + 5] = 0
                blipsData[i + 6] = blip:GetType()
                blipsData[i + 7] = blipTeam
                blipsData[i + 8] = blip:GetIsInCombat() // change to "GetIsAttacked" maybe
                
                numBlips = numBlips + 1
                
            end            
            
        end
        
        for index, blip in ientitylist(Shared.GetEntitiesWithClassname("SensorBlip")) do
        
            local blipOrigin = blip:GetOrigin()
         
            local i = numBlips * 8
         
            blipsData[i + 1] = blipOrigin.x
            blipsData[i + 2] = blipOrigin.z
            blipsData[i + 3] = 0
            blipsData[i + 4] = 0
            blipsData[i + 5] = 0
            blipsData[i + 6] = kMinimapBlipType.SensorBlip
            blipsData[i + 7] = kMinimapBlipTeam.Enemy
            blipsData[i + 8] = false
            
            numBlips = numBlips + 1
            
        end
        
        for index, order in ientitylist(Shared.GetEntitiesWithClassname("Order")) do
         
            local blipOrigin = order:GetLocation()
            
            local blipType = kMinimapBlipType.MoveOrder
            local orderType = order:GetType()
            if orderType == kTechId.Construct then
                blipType = kMinimapBlipType.BuildOrder
            elseif orderType == kTechId.Attack then
                blipType = kMinimapBlipType.AttackOrder
            end
        
            local i = numBlips * 8
              
            blipsData[i + 1] = blipOrigin.x
            blipsData[i + 2] = blipOrigin.z
            blipsData[i + 3] = 0
            blipsData[i + 4] = 0
            blipsData[i + 5] = 0
            blipsData[i + 6] = blipType
            blipsData[i + 7] = kMinimapBlipTeam.Friendly
            blipsData[i + 8] = false
            
            numBlips = numBlips + 1
            
        end     
        
    end
    
    return blipsData
    
end

/**
 * Damage indicators. Returns a array of damage indicators which are used to draw red arrows pointing towards
 * recent damage. Each damage indicator pair will consist of an alpha and a direction. The alpha is 0-1 and the
 * direction in radians is the angle at which to display it. 0 should face forward (top of the screen), pi 
 * should be behind us (bottom of the screen), pi/2 is to our left, 3*pi/2 is right.
 * 
 * For two damage indicators, perhaps:
 *  {alpha1, directionRadians1, alpha2, directonRadius2}
 *
 * It returns an empty table if the player has taken no damage recently. 
 */
function PlayerUI_GetDamageIndicators()

    local drawIndicators = {}
    
    local player = Client.GetLocalPlayer()
    if player then
    
        for index, indicatorTriple in ipairs(player.damageIndicators) do
            
            local alpha = Clamp(1 - ((Shared.GetTime() - indicatorTriple[3])/Player.kDamageIndicatorDrawTime), 0, 1)
            table.insert(drawIndicators, alpha)

            local worldX = indicatorTriple[1]
            local worldZ = indicatorTriple[2]
            
            local normDirToDamage = GetNormalizedVector(Vector(player:GetOrigin().x, 0, player:GetOrigin().z) - Vector(worldX, 0, worldZ))
            local worldToView = player:GetViewAngles():GetCoords():GetInverse()
            
            local damageDirInView = worldToView:TransformVector(normDirToDamage)
            
            local directionRadians = math.atan2(damageDirInView.x, damageDirInView.z)
            if directionRadians < 0 then
                directionRadians = directionRadians + 2 * math.pi
            end
            
            table.insert(drawIndicators, directionRadians)
            
        end
        
    end
    
    return drawIndicators
    
end

// Displays an image around the crosshair when the local player has given damage to something else.
// Returns true if the indicator should be displayed and the time that has passed as a percentage.
function PlayerUI_GetShowGiveDamageIndicator()

    local player = Client.GetLocalPlayer()
    if player and player.GetDamageIndicatorTime and player:GetIsPlaying() then
    
        local timePassed = Shared.GetTime() - player:GetDamageIndicatorTime()
        return timePassed <= Player.kShowGiveDamageTime, math.min(timePassed / Player.kShowGiveDamageTime, 1)
        
    end
    
    return false, 0
    
end

local function GetDamageEffectType(self)

    if self:isa("Marine") then
        return kDamageEffectType.Blood
    elseif self:isa("Alien") then
        return kDamageEffectType.AlienBlood
    elseif self:isa("Exo") then
        return kDamageEffectType.Sparks
    end

end

function Player:GetShowDamageArrows()
    return true
end

function Player:AddTakeDamageIndicator(damagePosition)

    if self:GetShowDamageArrows() then
    
        // Insert triple indicating when damage was taken and from where it came 
        local triple = {damagePosition.x, damagePosition.z, Shared.GetTime()}
        table.insert(self.damageIndicators, triple)
        
    end
    
    if not self:GetIsAlive() and not self.deathTriggered then
        self:TriggerFirstPersonDeathEffects()
        self.deathTriggered = true
    end
    
    local damageIndicatorScript = GetGUIManager():GetGUIScriptSingle("GUIDamageIndicators")
    local hitEffectType = GetDamageEffectType(self)
    
    if damageIndicatorScript and hitEffectType then
    
        local position = Vector(0,0,0)
        local viewCoords = self:GetViewCoords()
        
        local hitDirection = GetNormalizedVector( viewCoords.origin - damagePosition )
        position.x = viewCoords.xAxis:DotProduct(hitDirection)
        position.y = viewCoords.zAxis:DotProduct(hitDirection)
        
        if position:GetLength() > 0 then
        
            position:Normalize()
            position:Scale(0.95)
            
            local screenPos = Vector()
            
            screenPos.y = position.y * Client.GetScreenHeight() *.5 + Client.GetScreenHeight() *.5
            screenPos.x = position.x * Client.GetScreenWidth() * .5 + Client.GetScreenWidth() * .5
            
            local rotation = math.atan2(position.x, position.y) + .5 * math.pi
            if rotation < 0 then
                rotation = rotation + 2 * math.pi
            end
            
            damageIndicatorScript:OnTakeDamage(screenPos, rotation, hitEffectType)
        
        end
        
    end
    
end

// child classes can override this
function Player:GetShowDamageIndicator()

    local weapon = self:GetActiveWeapon()
    if weapon then
        return weapon:GetShowDamageIndicator()
    end    
    return true
    
end

// child classes should override this
function Player:OnGiveDamage()
end

function Player:UpdateDamageIndicators()

    local indicesToRemove = {}
    
    // Expire old damage indicators
    for index, indicatorTriple in ipairs(self.damageIndicators) do
    
        if Shared.GetTime() > (indicatorTriple[3] + Player.kDamageIndicatorDrawTime) then
        
            table.insert(indicesToRemove, index)
            
        end
        
    end
    
    for i, index in ipairs(indicesToRemove) do
        table.remove(self.damageIndicators, index)
    end
    
    // update damage given
    if self.giveDamageTimeClientCheck ~= self.giveDamageTime then
    
        self.giveDamageTimeClientCheck = self.giveDamageTime
        // Must factor in ping time as this value is delayed.
        self.giveDamageTimeClient = self.giveDamageTime + Client.GetPing()
        self.showDamage = self:GetShowDamageIndicator()
        if self.showDamage then
            self:OnGiveDamage()
        end
        
    end
    
end

    
function Player:UpdateDeadSound()

    if self:GetIsLocalPlayer() then
    
        // If we're dead and not playing montage, play deathly sound montage
        if (self:GetTeamNumber() ~= kSpectatorIndex) and not self:GetIsAlive() and not gPlayingDeadMontage then
        
            Shared.PlaySound(nil, kDeadSound)
            gPlayingDeadMontage = true
            
        // If we're alive and playing montage, stop it
        elseif self:GetIsAlive() and gPlayingDeadMontage then
        
            Shared.StopSound(nil, kDeadSound)
            gPlayingDeadMontage = nil

        end
        
    end
    
end

function Player:GetDamageIndicatorTime()

    if self.showDamage then
        return self.giveDamageTimeClient
    end
    
    return 0
    
end

// Set after hotgroup updated over the network
function Player:SetHotgroup(number, entityList)

    if(number >= 1 and number <= Player.kMaxHotkeyGroups) then
        //table.copy(entityList, self.hotkeyGroups[number])
        self.hotkeyGroups[number] = entityList
    end
    
end

local function OnJumpLandClient(self)

    if not Shared.GetIsRunningPrediction() then
    
        local landSurface = GetSurfaceAndNormalUnderEntity(self)
        self:TriggerEffects("land", { surface = landSurface, enemy = GetAreEnemies(self, Client.GetLocalPlayer()) })
        
    end
    
end

function Player:OnJumpLandLocalClient()
    OnJumpLandClient(self)
end

function Player:OnJumpLandNonLocalClient()
    OnJumpLandClient(self)
end

// Call OnJumpLandNonLocalClient for other players to avoid network traffic
function Player:CheckClientJumpLandOnSynch()

    if not self:GetIsLocalPlayer() then
    
        if self.clientOnSurface == false and self:GetIsOnSurface() then
            self:OnJumpLandNonLocalClient()
        end
        
        self.clientOnSurface = self:GetIsOnSurface()
        
    end
    
end


function Player:OnPreUpdate()

    PROFILE("Player:OnPreUpdate")

    self:CheckClientJumpLandOnSynch()
    
    if self.locationId ~= self.lastLocationId then
    
        self:OnLocationChange(Shared.GetString(self.locationId))
        
        self.lastLocationId = self.locationId
        
    end
    
end

function Player:OnUpdatePlayer(deltaTime)

    if not Shared.GetIsRunningPrediction() then
    
        if self.UpdateClientHelp then
            self:UpdateClientHelp()
        end
        
        self:UpdateClientEffects(deltaTime, self:GetIsLocalPlayer())
        
        self:UpdateRookieMode()
        
        self:UpdateCommunicationStatus()
        
    end
    
end

// The client is authoritative over our rookie state. It could be changed because
// we've been playing long enough, or because the user changed it in their options.
function Player:UpdateRookieMode()

    // Only update for local player
    if self:GetIsLocalPlayer() then

        local time = Client.GetTime()
        
        // Doesn't need to be updated too often, and don't want to resend message multiple times while waiting for update
        if self.timeLastRookieModeUpdate == nil or (time > self.timeLastRookieModeUpdate + kRookieNetworkCheckInterval) then
        
            local name = self:GetName()
            local isRookie = ScoreboardUI_IsPlayerRookie(self:GetName())
            local optionsRookieMode = Client.GetOptionBoolean(kRookieOptionsKey, true)
            
            if isRookie ~= optionsRookieMode then

                Client.SendNetworkMessage("SetRookieMode", BuildRookieMessage(optionsRookieMode), true)
                
                // Set scoreboard for instant change
                Scoreboard_SetRookieMode(self:GetName(), optionsRookieMode)
                
            end
            
            self.timeLastRookieModeUpdate = time    
            
        end
        
    end
    
end

function Player:UpdateCommunicationStatus()

    if self:GetIsLocalPlayer() then

        local time = Client.GetTime()
        
        if self.timeLastCommStatusUpdate == nil or (time > self.timeLastCommStatusUpdate + 0.5) then
        
            local newCommStatus = kPlayerCommunicationStatus.None

            // If voice comm being used
            if Client.IsVoiceRecordingActive() then
                newCommStatus = kPlayerCommunicationStatus.Voice
            // If we're typing
            elseif ChatUI_EnteringChatMessage() then
                newCommStatus = kPlayerCommunicationStatus.Typing
            // In menu
            elseif MainMenu_GetIsOpened() then
                newCommStatus = kPlayerCommunicationStatus.Menu
            end
            
            if newCommStatus ~= self:GetCommunicationStatus() then
            
                Client.SendNetworkMessage("SetCommunicationStatus", BuildCommunicationStatus(newCommStatus), true)
                self:SetCommunicationStatus(newCommStatus)
                
            end
        
            self.timeLastCommStatusUpdate = time
            
        end
        
    end
    
end

function Player:OnGetIsVisible(visibleTable)

    visibleTable.Visible = self:GetDrawWorld()
    
    if not self:GetIsAlive() and not HasMixin(self, "Ragdoll") then
        visibleTable.Visible = false
    end
    
end

function Player:OnUpdateRender()

    PROFILE("Player:OnUpdateRender")
    
    if self:GetIsLocalPlayer() then
    
        local blurEnabled = self.minimapVisible
        self:SetBlurEnabled(blurEnabled)
        
        self.lastOnUpdateRenderTime = self.lastOnUpdateRenderTime or Shared.GetTime()
        local now = Shared.GetTime()
        self:UpdateScreenEffects(now - self.lastOnUpdateRenderTime)
        self.lastOnUpdateRenderTime = now
        
    end
    
end

function Player:UpdateChat(input)

    if not Shared.GetIsRunningPrediction() then
    
        // Enter chat message
        if (bit.band(input.commands, Move.TextChat) ~= 0) then
            ChatUI_EnterChatMessage(false)
        end

        // Enter chat message
        if (bit.band(input.commands, Move.TeamChat) ~= 0) then
            ChatUI_EnterChatMessage(true)
        end
        
    end
    
end

function Player:GetCustomSelectionText()
    return string.format("%s kills\n%s deaths\n%s score",
            ToString(Scoreboard_GetPlayerData(self:GetClientIndex(), "Kills")),
            ToString(Scoreboard_GetPlayerData(self:GetClientIndex(), "Deaths")),
            ToString(Scoreboard_GetPlayerData(self:GetClientIndex(), "Score")))
end

function Player:GetIdleSoundName()
    return nil
end

function Player:SetIdleSoundInactive()
    self.timeOfIdleActive = Shared.GetTime() + 3
end

// Set light shake amount due to nearby roaming Onos
function Player:SetLightShakeAmount(amount, duration, scalar)

    if scalar == nil then
        scalar = 1
    end
    
    // So lights start moving in time with footsteps
    self:ResetShakingLights()

    self.lightShakeAmount = Clamp(amount, 0, 1)
    
    // Save off original amount so we can have it fall off nicely
    self.savedLightShakeAmount = self.lightShakeAmount
    
    self.lightShakeEndTime = Shared.GetTime() + duration
    
    self.lightShakeScalar = scalar
    
end

function Player:AddBindingHint(bindingString, entId, localizableText, priority)

    assert(type(bindingString) == "string")
    assert(type(entId) == "number")
    assert(type(localizableText) == "string")
    assert(type(priority) == "number")

    if self.hints then
    
        local key = BindingsUI_GetInputValue(bindingString)
        local localizedText = string.format(Locale.ResolveString(localizableText), ToString(key))
        self.hints:AddHint(entId, localizedText, priority)
        
    end
    
end

function Player:AddHint(entId, localizableText, priority)

    assert(type(entId) == "number")
    assert(type(localizableText) == "string")
    assert(type(priority) == "number")
    
    if self.hints then    
        self.hints:AddHint(entId, Locale.ResolveString(localizableText), priority)        
    end    
end

// Put a small information sign in the world
/*
function Player:AddInfoHint(entId, localizableText, priority)

    assert(type(entId) == "number")
    assert(type(localizableText) == "string")
    assert(type(priority) == "number")
    
    if self.hints then    
        self.hints:AddInfoHint(entId, Locale.ResolveString(localizableText), priority)        
    end    

end
*/

function Player:AddGlobalHint(localizableText, priority)

    assert(type(localizableText) == "string")
    assert(type(priority) == "number")

    if self.hints then
    
        local text = TranslateHintText(Locale.ResolveString(localizableText))
        self.hints:AddGlobalHint(text, priority)
        
    end
end

function Player:GetFirstPersonDeathEffect()
    return Player.kFirstPersonDeathEffect
end

function Player:TriggerFirstPersonDeathEffects()

    local cinematic = Client.CreateCinematic(RenderScene.Zone_ViewModel)
    cinematic:SetCinematic(self:GetFirstPersonDeathEffect())
    
end

local function GetFirstPersonHitEffectName(doer)

    local effectName = kDefaultFirstPersonEffectName
    
    local player = Client.GetLocalPlayer()
    
    if player and player.GetFirstPersonHitEffectName then    
        effectName = player:GetFirstPersonHitEffectName(doer)    
    end
    
    return effectName

end

/**
 * This is called from BaseModelMixin. This will force all player animations to process so we
 * get animation tags on the Client for other player models. These tags are needed to trigger
 * footstep sound effects.
 */
function Player:GetClientSideAnimationEnabled()
    return true
end

function Player:GetShowAtmosphericLight()
    return true
end
