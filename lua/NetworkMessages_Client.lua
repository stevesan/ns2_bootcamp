// ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
//
// lua\NetworkMessages_Client.lua
//
//    Created by:   Charlie Cleveland (charlie@unknownworlds.com) and
//                  Max McGuire (max@unknownworlds.com)
//
// See the Messages section of the Networking docs in Spark Engine scripting docs for details.
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/InsightNetworkMessages_Client.lua")

function OnCommandPing(pingTable)

    local playerId, ping = ParsePingMessage(pingTable)    
    Scoreboard_SetPing(playerId, ping)
    
end

function OnCommandHitEffect(hitEffectTable)

    local position, doer, surface, target, showtracer, altMode = ParseHitEffectMessage(hitEffectTable)

    local tableParams = {}
    tableParams[kEffectHostCoords] = Coords.GetTranslation(position)
    if doer then
        tableParams[kEffectFilterDoerName] = doer:GetClassName()
    end
    tableParams[kEffectSurface] = surface
    tableParams[kEffectFilterInAltMode] = altMode
    
    if target then
    
        tableParams[kEffectFilterClassName] = target:GetClassName()
        
        if target.GetTeamType then
            tableParams[kEffectFilterIsMarine] = target:GetTeamType() == kMarineTeamType
            tableParams[kEffectFilterIsAlien] = target:GetTeamType() == kAlienTeamType
        end
        
    else
            tableParams[kEffectFilterIsMarine] = false
            tableParams[kEffectFilterIsAlien] = false
    end
    
    // don't play the hit cinematic, those are made for third person
    if target ~= Client.GetLocalPlayer() then
        GetEffectManager():TriggerEffects("damage", tableParams)
    end
    
    // always play sound effect
    GetEffectManager():TriggerEffects("damage_sound", tableParams)
    
    if showtracer == true and doer then
    
        
        local tracerStart = (doer.GetBarrelPoint and doer:GetBarrelPoint()) or (doer.GetEyePos and doer:GetEyePos()) or doer:GetOrigin()
    
        local tracerVelocity = GetNormalizedVector(position - tracerStart) * kTracerSpeed
        CreateTracer(tracerStart, position, tracerVelocity, doer)
    
    end
    
    if target and target.OnTakeDamageClient then
        // Damage not available here
        target:OnTakeDamageClient(nil, doer, position)
    end

end

// Show damage numbers for players
function OnCommandDamage(damageTable)

    local target, amount, hitpos = ParseDamageMessage(damageTable)
    if target then
        Client.AddWorldMessage(kWorldTextMessageType.Damage, ToString(math.round(amount)), hitpos, target:GetId())
    end
    
end

function OnCommandAbilityResult(msg)

    // The server will send us this message to tell us an ability succeded.
    player = Client.GetLocalPlayer()
    if player:GetIsCommander() then
        player:OnAbilityResultMessage(msg.techId, msg.success, msg.castTime)
    end

end

function OnCommandScores(scoreTable)

    local status = kPlayerStatus[scoreTable.status]
    if scoreTable.status == kPlayerStatus.Hidden then
        status = "-"
    elseif scoreTable.status == kPlayerStatus.Dead then
        status = Locale.ResolveString("STATUS_DEAD")
    elseif scoreTable.status == kPlayerStatus.Evolving then
        status = Locale.ResolveString("STATUS_EVOLVING")
    elseif scoreTable.status == kPlayerStatus.Embryo then
        status = Locale.ResolveString("STATUS_EMBRYO")
    elseif scoreTable.status == kPlayerStatus.Commander then
        status = Locale.ResolveString("STATUS_COMMANDER")
    elseif scoreTable.status == kPlayerStatus.Exo then
        status = Locale.ResolveString("STATUS_EXO")
    elseif scoreTable.status == kPlayerStatus.GrenadeLauncher then
        status = Locale.ResolveString("STATUS_GRENADE_LAUNCHER")
    elseif scoreTable.status == kPlayerStatus.Rifle then
        status = Locale.ResolveString("STATUS_RIFLE")
    elseif scoreTable.status == kPlayerStatus.Shotgun then
        status = Locale.ResolveString("STATUS_SHOTGUN")
    elseif scoreTable.status == kPlayerStatus.Flamethrower then
        status = Locale.ResolveString("STATUS_FLAMETHROWER")
    elseif scoreTable.status == kPlayerStatus.Void then
        status = Locale.ResolveString("STATUS_VOID")
    elseif scoreTable.status == kPlayerStatus.Spectator then
        status = Locale.ResolveString("STATUS_SPECTATOR")
    elseif scoreTable.status == kPlayerStatus.Skulk then
        status = Locale.ResolveString("STATUS_SKULK")
    elseif scoreTable.status == kPlayerStatus.Gorge then
        status = Locale.ResolveString("STATUS_GORGE")
    elseif scoreTable.status == kPlayerStatus.Fade then
        status = Locale.ResolveString("STATUS_FADE")
    elseif scoreTable.status == kPlayerStatus.Lerk then
        status = Locale.ResolveString("STATUS_LERK")
    elseif scoreTable.status == kPlayerStatus.Onos then
        status = Locale.ResolveString("STATUS_ONOS")
    end
    
    Scoreboard_SetPlayerData(scoreTable.clientId, scoreTable.entityId, scoreTable.playerName, scoreTable.teamNumber, scoreTable.score,
                             scoreTable.kills, scoreTable.deaths, math.floor(scoreTable.resources), scoreTable.isCommander, scoreTable.isRookie,
                             status, scoreTable.isSpectator)
    
end

function OnCommandClearTechTree()
    ClearTechTree()
end

function OnCommandTechNodeBase(techNodeBaseTable)
    GetTechTree():CreateTechNodeFromNetwork(techNodeBaseTable)
end

function OnCommandTechNodeUpdate(techNodeUpdateTable)
    GetTechTree():UpdateTechNodeFromNetwork(techNodeUpdateTable)
end

function OnCommandResetMouse()

    Client.SetYaw(0)
    Client.SetPitch(0)
    
end

function OnCommandOnResetGame()

    Scoreboard_OnResetGame()
    ResetLights()
    
end

function OnCommandDebugLine(debugLineMessage)
    DebugLine(ParseDebugLineMessage(debugLineMessage))
end

function OnCommandDebugCapsule(debugCapsuleMessage)
    DebugCapsule(ParseDebugCapsuleMessage(debugCapsuleMessage))
end

function OnCommandMinimapAlert(message)

    local player = Client.GetLocalPlayer()
    if player then
        player:AddAlert(message.techId, message.worldX, message.worldZ, message.entityId, message.entityTechId)
    end
    
end

function OnCommandCommanderNotification(message)

    local player = Client.GetLocalPlayer()
    if player:isa("Marine") then
        player:AddNotification(message.locationId, message.techId)
    end
    
end

kWorldTextResolveStrings = { }
kWorldTextResolveStrings[kWorldTextMessageType.Resources] = "RESOURCES_ADDED"
kWorldTextResolveStrings[kWorldTextMessageType.Resource] = "RESOURCE_ADDED"
kWorldTextResolveStrings[kWorldTextMessageType.Damage] = "DAMAGE_TAKEN"
function OnCommandWorldText(message)

    local messageStr = string.format(Locale.ResolveString(kWorldTextResolveStrings[message.messageType]), message.data)
    Client.AddWorldMessage(message.messageType, messageStr, message.position)
    
end

function OnCommandCommanderError(message)

    local messageStr = Locale.ResolveString(message.data)
    Client.AddWorldMessage(kWorldTextMessageType.CommanderError, messageStr, message.position)
    
end

function OnCommandJoinError(message)
    ChatUI_AddSystemMessage( Locale.ResolveString("JOIN_ERROR_TOO_MANY") )
end

Client.HookNetworkMessage("Ping", OnCommandPing)
Client.HookNetworkMessage("HitEffect", OnCommandHitEffect)
Client.HookNetworkMessage("Damage", OnCommandDamage)
Client.HookNetworkMessage("AbilityResult", OnCommandAbilityResult)
Client.HookNetworkMessage("JoinError", OnCommandJoinError)
Client.HookNetworkMessage("Scores", OnCommandScores)

Client.HookNetworkMessage("ClearTechTree", OnCommandClearTechTree)
Client.HookNetworkMessage("TechNodeBase", OnCommandTechNodeBase)
Client.HookNetworkMessage("TechNodeUpdate", OnCommandTechNodeUpdate)

Client.HookNetworkMessage("MinimapAlert", OnCommandMinimapAlert)
Client.HookNetworkMessage("CommanderNotification", OnCommandCommanderNotification)

Client.HookNetworkMessage("ResetMouse", OnCommandResetMouse)
Client.HookNetworkMessage("ResetGame", OnCommandOnResetGame)

Client.HookNetworkMessage("DebugLine", OnCommandDebugLine)
Client.HookNetworkMessage("DebugCapsule", OnCommandDebugCapsule)

Client.HookNetworkMessage("WorldText", OnCommandWorldText)
Client.HookNetworkMessage("CommanderError", OnCommandCommanderError)