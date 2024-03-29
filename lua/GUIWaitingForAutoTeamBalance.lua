// ======= Copyright (c) 2003-2012, Unknown Worlds Entertainment, Inc. All rights reserved. =====
//
// lua\GUIWaitingForAutoTeamBalance.lua
//
// Created by: Brian Cronin (brianc@unknownworlds.com)
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

class 'GUIWaitingForAutoTeamBalance' (GUIScript)

local kFontName = "fonts/AgencyFB_large.fnt"
local kFontColor = Color(0.8, 0.8, 0.8, 1)

function GUIWaitingForAutoTeamBalance:Initialize()

    self.waitingText = GUIManager:CreateTextItem()
    self.waitingText:SetFontName(kFontName)
    self.waitingText:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.waitingText:SetPosition(Vector(0, 120, 0))
    self.waitingText:SetTextAlignmentX(GUIItem.Align_Center)
    self.waitingText:SetTextAlignmentY(GUIItem.Align_Center)
    self.waitingText:SetColor(kFontColor)
    self.waitingText:SetText(Locale.ResolveString("AUTO_TEAM_BALANCE_TOOLTIP"))
    self.waitingText:SetIsVisible(true)
    
end

function GUIWaitingForAutoTeamBalance:Uninitialize()

    assert(self.waitingText)
    
    GUI.DestroyItem(self.waitingText)
    self.waitingText = nil
    
end

function GUIWaitingForAutoTeamBalance:SetIsVisible(visible)
    self.waitingText:SetIsVisible(visible)
end