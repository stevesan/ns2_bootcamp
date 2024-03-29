// ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
//
// lua\SoundEffect.lua
//
//    Created by:   Brain Cronin (brianc@unknownworlds.com)
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/Mixins/SignalListenerMixin.lua")

// Utility functions below.
if Server then

    function StartSoundEffectAtOrigin(soundEffectName, atOrigin, optionalRelevantFunction)
    
        local soundEffectEntity = Server.CreateEntity(SoundEffect.kMapName)
        soundEffectEntity:SetOrigin(atOrigin)
        soundEffectEntity:SetAsset(soundEffectName)
        soundEffectEntity:Start()
        if optionalRelevantFunction then
        
            soundEffectEntity:SetPropagate(Entity.Propagate_Callback)
            soundEffectEntity.OnGetIsRelevant = optionalRelevantFunction
            
        end
        
    end
    
    function StartSoundEffectOnEntity(soundEffectName, onEntity)
    
        local soundEffectEntity = Server.CreateEntity(SoundEffect.kMapName)
        soundEffectEntity:SetParent(onEntity)
        soundEffectEntity:SetAsset(soundEffectName)
        soundEffectEntity:Start()
        
    end
    
    /**
     * Starts a sound effect which only 1 player will hear.
     */
    function StartSoundEffectForPlayer(soundEffectName, forPlayer)
    
        local soundEffectEntity = Server.CreateEntity(SoundEffect.kMapName)
        soundEffectEntity:SetParent(forPlayer)
        soundEffectEntity:SetAsset(soundEffectName)
        soundEffectEntity:SetPropagate(Entity.Propagate_Callback)
        function soundEffectEntity:OnGetIsRelevant(player)
            return player == forPlayer
        end
        soundEffectEntity:Start()
        
    end
    
end

if Client then

    function StartSoundEffectAtOrigin(soundEffectName, atOrigin)
        // TODO: implement to allow prediction
    end
    
    function StartSoundEffectOnEntity(soundEffectName, onEntity)
        // TODO: implement to allow prediction
    end

    function StartSoundEffectForPlayer(soundEffectName, forPlayer)
        Shared.PlayPrivateSound(forPlayer, soundEffectName, forPlayer, 1, forPlayer:GetOrigin())
    end
    
end


if Predict then

    function StartSoundEffectAtOrigin(soundEffectName, atOrigin)
    end
    
    function StartSoundEffectOnEntity(soundEffectName, onEntity)
    end

    function StartSoundEffectForPlayer(soundEffectName, forPlayer)
    end
    
end

local kDefaultMaxAudibleDistance = 50
local kSoundEndBufferTime = 0.5

class 'SoundEffect' (Entity)

SoundEffect.kMapName = "sound_effect"

local networkVars =
{
    playing = "boolean",
    assetIndex = "resource",
    startTime = "time"
}

function SoundEffect:OnCreate()

    Entity.OnCreate(self)
    
    InitMixin(self, SignalListenerMixin)
    
    self.playing = false
    self.assetIndex = 0
    
    self:SetPropagate(Entity.Propagate_Mask)
    self:SetRelevancyDistance(kDefaultMaxAudibleDistance)
    
    if Server then
    
        self.assetLength = 0
        self.startTime = 0
        
    end
    
    if Client then
    
        self.clientPlaying = false
        self.clientAssetIndex = 0
        self.soundEffectInstance = nil
        
    end
    
    self:SetUpdates(true)
    
end

function SoundEffect:GetIsPlaying()
    return self.playing
end

function GetSoundEffectLength(soundName)

    local fevStart, fevEnd = string.find(soundName, ".fev")
    local fixedAssetPath = string.sub(soundName, fevEnd + 1)
    return Server.GetSoundLength(fixedAssetPath)

end

if Server then

    function SoundEffect:SetAsset(assetPath)
    
        if string.len(assetPath) == 0 then
            return
        end
        
        local assetIndex = Shared.GetSoundIndex(assetPath)
        if assetIndex == 0 then
        
            Shared.Message("Effect " .. assetPath .. " wasn't precached")
            return
            
        end
        
        self.assetIndex = assetIndex
        self.assetLength = GetSoundEffectLength(assetPath)
        
    end
    
    function SoundEffect:Start()
    
        // Asset must be assigned before playing.
        assert(self.assetIndex ~= 0)
        
        self.playing = true
        self.startTime = Shared.GetTime()
        
    end
    
    function SoundEffect:Stop()
    
        self.playing = false
        self.startTime = 0
        
    end
    
    function SoundEffect:GetIsPlaying()
        return self.playing
    end
    
    local function SharedUpdate(self)
    
        PROFILE("SoundEffect:SharedUpdate")
        
        // If the assetLength is < 0, it is a looping sound and needs to be manually destroyed.
        if self.playing and self.assetLength >= 0 then
        
            // Add in a bit of time to make sure the Client has had enough time to fully play.
            local endTime = self.startTime + self.assetLength + kSoundEndBufferTime
            if Shared.GetTime() > endTime then
                DestroyEntity(self)
            end
            
        end
        
    end
    
    function SoundEffect:OnProcessMove()
        SharedUpdate(self)
    end
    
    function SoundEffect:OnUpdate(deltaTime)
        SharedUpdate(self)
    end
    
end

if Client then

    local function DestroySoundEffect(self)
    
        if self.soundEffectInstance then
        
            Client.DestroySoundEffect(self.soundEffectInstance)
            self.soundEffectInstance = nil
            
        end
        
    end
    
    function SoundEffect:OnDestroy()
        DestroySoundEffect(self)
    end
    
    local function SharedUpdate(self)
    
        PROFILE("SoundEffect:SharedUpdate")
       
        if self.clientAssetIndex ~= self.assetIndex then
        
            DestroySoundEffect(self)
            
            self.clientAssetIndex = self.assetIndex
            
            if self.assetIndex ~= 0 then
            
                self.soundEffectInstance = Client.CreateSoundEffect(self.assetIndex)
                self.soundEffectInstance:SetParent(self:GetId())
                
            end
        
        end
        
        // Only attempt to play if the index seems valid.
        if self.assetIndex ~= 0 then
        
            if self.clientPlaying ~= self.playing or self.clientStartTime ~= self.startTime then
            
                self.clientPlaying = self.playing
                self.clientStartTime = self.startTime
                
                if self.playing then
                    self.soundEffectInstance:Start()
                else
                    self.soundEffectInstance:Stop()
                end
                
            end
            
        end    
    end
    
    function SoundEffect:OnUpdate(deltaTime)
        SharedUpdate(self)
    end
    
    function SoundEffect:OnProcessMove()
        SharedUpdate(self)
    end
    
    function SoundEffect:SetParameter(paramName, paramValue, paramSpeed)
    
        ASSERT(type(paramName) == "string")
        ASSERT(type(paramValue) == "number")
        ASSERT(type(paramSpeed) == "number")
        
        local success = false
        
        if self.soundEffectInstance and self.playing then
            success = self.soundEffectInstance:SetParameter(paramName, paramValue, paramSpeed)
        end
        
        return success
        
    end
    
    // will create a sound effect instance
    function CreateLoopingSoundForEntity(entity, localSoundName, worldSoundName)
    
        local soundEffectInstance = nil
    
        if entity then
        
            if entity == Client.GetLocalPlayer() and localSoundName then
                soundName = localSoundName
            else
                soundName = worldSoundName
            end
            
            if soundName then
            
                soundEffectInstance = Client.CreateSoundEffect(Shared.GetSoundIndex(soundName))
                soundEffectInstance:SetParent(entity:GetId())
        
            end
        
        end
        
        return soundEffectInstance
    
    end

end

Shared.LinkClassToMap("SoundEffect", SoundEffect.kMapName, networkVars)