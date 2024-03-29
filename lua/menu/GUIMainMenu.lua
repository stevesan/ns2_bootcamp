// ======= Copyright (c) 2003-2012, Unknown Worlds Entertainment, Inc. All rights reserved. =====
//
// lua\menu\GUIMainMenu.lua
//
//    Created by:   Andreas Urwalek (a_urwa@sbox.tugraz.at) and
//                  Brian Cronin (brianc@unknownworlds.com)
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/menu/WindowManager.lua")
Script.Load("lua/GUIAnimatedScript.lua")
Script.Load("lua/menu/MenuMixin.lua")
Script.Load("lua/menu/Link.lua")
Script.Load("lua/menu/SlideBar.lua")
Script.Load("lua/menu/ContentBox.lua")
Script.Load("lua/menu/Image.lua")
Script.Load("lua/menu/Table.lua")
Script.Load("lua/menu/Ticker.lua")
Script.Load("lua/ServerBrowser.lua")
Script.Load("lua/menu/Form.lua")
Script.Load("lua/menu/ServerList.lua")
Script.Load("lua/dkjson.lua")

local kMainMenuLinkColor = Color(137 / 255, 137 / 255, 137 / 255, 1)

class 'GUIMainMenu' (GUIAnimatedScript)

Script.Load("lua/menu/GUIMainMenu_FindPeople.lua")
Script.Load("lua/menu/GUIMainMenu_PlayNow.lua")
Script.Load("lua/menu/GUIMainMenu_Mods.lua")
Script.Load("lua/menu/GUIMainMenu_Tutorial.lua")

// Min and maximum values for the mouse sensitivity slider
local kMinSensitivity = 1
local kMaxSensitivity = 20

local kMinAcceleration = 1
local kMaxAcceleration = 1.4

local kDisplayModes = { "windowed", "fullscreen", "fullscreen-windowed" }
local kAmbientOcclusionModes = { "off", "medium", "high" }
local kInfestationModes = { "minimal", "rich" }
    
local kLocales =
    {
        { name = "enUS", label = "English" },
        { name = "frFR", label = "French" },
        { name = "deDE", label = "German" },
        { name = "koKR", label = "Korean" },
        { name = "plPL", label = "Polish" },
        { name = "esES", label = "Spanish" },
        { name = "seSW", label = "Swedish" },
    }

function GUIMainMenu:Initialize()

    GUIAnimatedScript.Initialize(self)
    
    Shared.Message("Main Menu Initialized at Version: " .. Shared.GetBuildNumber())
    Shared.Message("Steam Id: " .. Client.GetSteamId())
    
    // provides a set of functions required for window handling
    AddMenuMixin(self)
    self:SetCursor("ui/Cursor_MenuDefault.dds")
    self:SetWindowLayer(kWindowLayerMainMenu)
    
    LoadCSSFile("lua/menu/main_menu.css")
    
    self.mainWindow = self:CreateWindow()
    self.mainWindow:SetCSSClass("main_frame")
    
    self.tvGlareImage = CreateMenuElement(self.mainWindow, "Image")
    
    if MainMenu_IsInGame() then
        self.tvGlareImage:SetCSSClass("tvglare_dark")
    else
        self.tvGlareImage:SetCSSClass("tvglare")
    end    
    
    self.mainWindow:DisableTitleBar()
    self.mainWindow:DisableResizeTile()
    self.mainWindow:DisableCanSetActive()
    self.mainWindow:DisableContentBox()
    self.mainWindow:DisableSlideBar()
    
    self.showWindowAnimation = CreateMenuElement(self.mainWindow, "Font", false)
    self.showWindowAnimation:SetCSSClass("showwindow_hidden")
    
    self.openedWindows = 0
    self.numMods = 0
    
    local eventCallbacks =
    {
        OnEscape = function (self)
        
            if MainMenu_IsInGame() then
                self.scriptHandle:SetIsVisible(false)
            end
            
        end,
        
        OnShow = function (self)
            MainMenu_Open()
        end,
        
        OnHide = function (self)
        
            if MainMenu_IsInGame() then
            
                MainMenu_ReturnToGame()
                return true
                
            else
                return false
            end
            
        end
    }
    
    self.mainWindow:AddEventCallbacks(eventCallbacks)
    
    self:CreatePlayWindow()
    self:CreateTutorialWindow()
    self:CreateOptionWindow()
    self:CreateModsWindow()
    self:CreatePasswordPromptWindow()
    self:CreateAutoJoinWindow()
    self:CreateAlertWindow()
    
    local TriggerOpenAnimation = function(window)
    
        if not window:GetIsVisible() then
        
            window.scriptHandle.windowToOpen = window
            window.scriptHandle:SetShowWindowName(window:GetWindowName())
            
        end
        
    end
    
    self.scanLine = CreateMenuElement(self.mainWindow, "Image")
    self.scanLine:SetCSSClass("scanline")

    self.tweetText = CreateMenuElement(self.mainWindow, "Ticker")
    
    self.logo = CreateMenuElement(self.mainWindow, "Image")
    self.logo:SetCSSClass("logo")
    
    self:CreateMenuBackground()
    self:CreateProfile()
    
    if MainMenu_IsInGame() then
    
        // Create "resume playing" button
        self.resumeLink = self:CreateMainLink("RESUME GAME", "resume_ingame", "01")
        self.resumeLink:AddEventCallbacks(
        {
            OnClick = function(self)
                self.scriptHandle:SetIsVisible(not self.scriptHandle:GetIsVisible())
            end
        })
        
        // Create "go to ready room" button
        self.readyRoomLink = self:CreateMainLink("GO TO READY ROOM", "readyroom_ingame", "02")
        self.readyRoomLink:AddEventCallbacks(
        {
            OnClick = function(self)
                self.scriptHandle:SetIsVisible(not self.scriptHandle:GetIsVisible())
                Shared.ConsoleCommand("rr")
            end
        })
        
        self.playLink = self:CreateMainLink("PLAY", "play_ingame", "03")
        self.playLink:AddEventCallbacks(
        {
            OnClick = function(self)
            
                TriggerOpenAnimation(self.scriptHandle.playWindow)
                self.scriptHandle:HideMenu()
                
            end
        })
        
        self.optionLink = self:CreateMainLink("OPTIONS", "options_ingame", "04")
        self.optionLink:AddEventCallbacks(
        {
            OnClick = function(self)
            
                TriggerOpenAnimation(self.scriptHandle.optionWindow)
                self.scriptHandle:HideMenu()
                
            end
        })
        
        self.tutorialLink = self:CreateMainLink("TRAINING", "tutorial_ingame", "05")
        self.tutorialLink:AddEventCallbacks(
        {
            OnClick = function(self)
            
                TriggerOpenAnimation(self.scriptHandle.tutorialWindow)
                self.scriptHandle:HideMenu()
                
            end
        })
        
        // Create "disconnect" button
        self.disconnectLink = self:CreateMainLink("DISCONNECT", "disconnect_ingame", "06")
        self.disconnectLink:AddEventCallbacks(
        {
            OnClick = function(self)
            
                self.scriptHandle:HideMenu()
                
                Shared.ConsoleCommand("disconnect")

                self.scriptHandle:ShowMenu()
                
            end
        })
        
    else
    
        self.playLink = self:CreateMainLink("PLAY", "play", "01")
        self.playLink:AddEventCallbacks(
        {
            OnClick = function(self)
            
                TriggerOpenAnimation(self.scriptHandle.playWindow)
                self.scriptHandle:HideMenu()
                
            end
        })
        
        self.tutorialLink = self:CreateMainLink("TRAINING", "tutorial", "02")
        self.tutorialLink:AddEventCallbacks(
        {
            OnClick = function(self)
            
                TriggerOpenAnimation(self.scriptHandle.tutorialWindow)
                self.scriptHandle:HideMenu()
                
            end
        })
        
        self.optionLink = self:CreateMainLink("OPTIONS", "options", "03")
        self.optionLink:AddEventCallbacks(
        {
            OnClick = function(self)
            
                TriggerOpenAnimation(self.scriptHandle.optionWindow)
                self.scriptHandle:HideMenu()
                
            end
        })
        
        self.modsLink = self:CreateMainLink("MODS", "mods", "04")
        self.modsLink:AddEventCallbacks(
        {
            OnClick = function(self)
            
                TriggerOpenAnimation(self.scriptHandle.modsWindow)
                self.scriptHandle:HideMenu()
                
            end
        })
        
        self.quitLink = self:CreateMainLink("EXIT", "exit", "05")
        self.quitLink:AddEventCallbacks(
        {
            OnClick = function(self)
                Client.Exit()
            end
        })
        
    end
    
end

function GUIMainMenu:SetShowWindowName(name)

    self.showWindowAnimation:SetText(ToString(name))
    self.showWindowAnimation:GetBackground():DestroyAnimations()
    self.showWindowAnimation:SetIsVisible(true)
    self.showWindowAnimation:SetCSSClass("showwindow_hidden")
    self.showWindowAnimation:SetCSSClass("showwindow_animation1")
    
end

function GUIMainMenu:CreateMainLink(text, className, linkNum)

    local mainLink = CreateMenuElement(self.menuBackground, "Link")
    mainLink:SetText(text)
    mainLink:SetCSSClass(className)
    mainLink:SetTextColor(kMainMenuLinkColor)
    mainLink:SetBackgroundColor(Color(1,1,1,0))
    mainLink:EnableHighlighting()
    
    mainLink.linkIcon = CreateMenuElement(mainLink, "Font")
    mainLink.linkIcon:SetText(linkNum)
    mainLink.linkIcon:SetCSSClass(className)
    mainLink.linkIcon:SetTextColor(Color(1,1,1,0))
    mainLink.linkIcon:EnableHighlighting()
    mainLink.linkIcon:SetBackgroundColor(Color(1,1,1,0))
    
    local eventCallbacks =
    {
        OnMouseIn = function (self, buttonPressed)
            MainMenu_OnMouseIn()
        end,
        
        OnMouseOver = function (self, buttonPressed)        
            self.linkIcon:OnMouseOver(buttonPressed)
        end,
        
        OnMouseOut = function (self, buttonPressed)
            self.linkIcon:OnMouseOut(buttonPressed) 
            MainMenu_OnMouseOut()
        end
    }
    
    mainLink:AddEventCallbacks(eventCallbacks)
    
    return mainLink
    
end

function GUIMainMenu:Uninitialize()

    self:DestroyAllWindows()
    GUIAnimatedScript.Uninitialize(self)
    
end

function GUIMainMenu:CreateMenuBackground()

    self.menuBackground = CreateMenuElement(self.mainWindow, "Image")
    self.menuBackground:SetCSSClass("menu_bg_show")
    
end

function GUIMainMenu:CreateProfile()

    self.profileBackground = CreateMenuElement(self.menuBackground, "Image")
    self.profileBackground:SetCSSClass("profile")


    local eventCallbacks =
    {
        // Trigger initial animation
        OnShow = function(self)
        
            // Passing updateChildren == false to prevent updating of children
            self:SetCSSClass("profile", false)
            
        end,
        
        // Destroy all animation and reset state
        OnHide = function(self) end
    }
    
    self.profileBackground:AddEventCallbacks(eventCallbacks)
    
    // create avatar icon.
    self.avatar = CreateMenuElement(self.profileBackground, "Image")
    self.avatar:SetCSSClass("avatar")
    self.avatar:SetBackgroundTexture("*avatar")

    // Remove icons until we can get proper artwork in for them
        
    // create SE and dev tools icons, TODO: set correct CSS class
    /*
    self.seIcon = CreateMenuElement(self.profileBackground, "Image")
    self.seIcon:SetCSSClass("se_enabled")
    self.seIcon:EnableHighlighting()
    
    self.devToolsIcon = CreateMenuElement(self.profileBackground, "Image")
    self.devToolsIcon:SetCSSClass("devtoolsicon")  
    self.devToolsIcon:EnableHighlighting()  
    
    // create dlc icons    
    self.dlcIcons = {}
    for _, dlc in ipairs(MainMenu_GetDLCs()) do
    
        local dlcIcon = CreateMenuElement(self.profileBackground, "Image")
        dlcIcon:SetCSSClass(dlc)
        dlcIcon:EnableHighlighting() 
        table.insert(self.dlcIcons, dlcIcon)
    
    end
    */
    self.playerName = CreateMenuElement(self.profileBackground, "Font")
    self.playerName:SetCSSClass("profile")
    
end  

local function FinishWindowAnimations(self)
    self:GetBackground():EndAnimations()
end    

local function UpdateServerList(self)

    self.numServers = 0
    Client.RebuildServerList()
    self.playWindow.updateButton:SetText("UPDATING...")
    self.playWindow:ResetSlideBar()
    self.timeUpdateButtonPressed = Shared.GetTime()
    self.selectServer:SetIsVisible(false)
    self.serverList:ClearChildren()
    // Needs to be done here because the server IDs will change.
    self:ResetServerSelection()
    
end

local function RefreshServerList(self)

    
    
end

function GUIMainMenu:ProcessJoinServer()

    if MainMenu_GetSelectedServer() ~= nil then
    
        if MainMenu_GetSelectedRequiresPassword() then
            self.passwordPromptWindow:SetIsVisible(true)
        else
            self:JoinServer()
        end
        
    end
    
end

function GUIMainMenu:JoinServer()

    if MainMenu_GetSelectedIsFull() then
        self.autoJoinWindow:SetIsVisible(true)
        self.autoJoinText:SetText(ToString(MainMenu_GetSelectedServerName()))
    else
        MainMenu_JoinSelected()
    end

end

function GUIMainMenu:CreateAlertWindow()

    self.alertWindow = self:CreateWindow()    
    self.alertWindow:SetWindowName("ALERT")
    self.alertWindow:SetInitialVisible(false)
    self.alertWindow:SetIsVisible(false)
    self.alertWindow:DisableResizeTile()
    self.alertWindow:DisableSlideBar()
    self.alertWindow:DisableContentBox()
    self.alertWindow:SetCSSClass("alert_window")
    self.alertWindow:DisableCloseButton()
    self.alertWindow:AddEventCallbacks( { OnBlur = function(self) self:SetIsVisible(false) end } )
    
    self.alertText = CreateMenuElement(self.alertWindow, "Font")
    self.alertText:SetCSSClass("alerttext")
    
    self.alertText:SetTextClipped(true, 350, 100)
    
    local okButton = CreateMenuElement(self.alertWindow, "MenuButton")
    okButton:SetCSSClass("bottomcenter")
    okButton:SetText("OK")
    
    okButton:AddEventCallbacks({ OnClick = function (self)

        self.scriptHandle.alertWindow:SetIsVisible(false)

    end  })
    
end 

function GUIMainMenu:CreateAutoJoinWindow()

    self.autoJoinWindow = self:CreateWindow()    
    self.autoJoinWindow:SetWindowName("WAITING FOR SLOT ...")
    self.autoJoinWindow:SetInitialVisible(false)
    self.autoJoinWindow:SetIsVisible(false)
    self.autoJoinWindow:DisableTitleBar()
    self.autoJoinWindow:DisableResizeTile()
    self.autoJoinWindow:DisableSlideBar()
    self.autoJoinWindow:DisableContentBox()
    self.autoJoinWindow:SetCSSClass("autojoin_window")
    self.autoJoinWindow:DisableCloseButton()
    
    local cancel = CreateMenuElement(self.autoJoinWindow, "MenuButton")
    cancel:SetCSSClass("bottomcenter")
    cancel:SetText("CANCEL")
    
    local text = CreateMenuElement(self.autoJoinWindow, "Font")
    text:SetCSSClass("auto_join_text")
    text:SetText("WAITING FOR SLOT...")
    
    self.autoJoinText = CreateMenuElement(self.autoJoinWindow, "Font")
    self.autoJoinText:SetCSSClass("auto_join_text_servername")
    self.autoJoinText:SetText("")
    
    self.blinkingArrowTwo = CreateMenuElement(self.autoJoinWindow, "Image")
    self.blinkingArrowTwo:SetCSSClass("blinking_arrow_two")

    cancel:AddEventCallbacks({ OnClick =
    function (self)    
        self:GetParent():SetIsVisible(false)        
    end })
    
    local eventCallbacks =
    {
        OnShow = function(self)
            self.scriptHandle.updateAutoJoin = true
        end,
        OnHide = function(self)
            self.scriptHandle.updateAutoJoin = false
        end,
        OnBlur = function(self)
            self:SetIsVisible(false)
        end
    }
    
    self.autoJoinWindow:AddEventCallbacks(eventCallbacks)

end

function GUIMainMenu:CreatePasswordPromptWindow()

    self.passwordPromptWindow = self:CreateWindow()    
    self.passwordPromptWindow:SetWindowName("ENTER PASSWORD")
    self.passwordPromptWindow:SetInitialVisible(false)
    self.passwordPromptWindow:SetIsVisible(false)
    self.passwordPromptWindow:DisableResizeTile()
    self.passwordPromptWindow:DisableSlideBar()
    self.passwordPromptWindow:DisableContentBox()
    self.passwordPromptWindow:SetCSSClass("passwordprompt_window")
    self.passwordPromptWindow:DisableCloseButton()
    
    self.passwordPromptWindow:AddEventCallbacks( { OnBlur = function(self) self:SetIsVisible(false) end } )
    
    self.passwordForm = CreateMenuElement(self.passwordPromptWindow, "Form", false)
    self.passwordForm:SetCSSClass("passwordprompt")

    // Password entry
    local textinput = self.passwordForm:CreateFormElement(Form.kElementType.TextInput, "PASSWORD", Client.GetOptionString("serverPassword", ""))
    textinput:SetCSSClass("serverpassword")
    
    
    local descriptionText = CreateMenuElement(self.passwordPromptWindow.titleBar, "Font", false)
    descriptionText:SetCSSClass("passwordprompt_title")
    descriptionText:SetText("ENTER PASSWORD")

    local joinServer = CreateMenuElement(self.passwordPromptWindow, "MenuButton")
    joinServer:SetCSSClass("bottomcenter")
    joinServer:SetText("JOIN")
    
    joinServer:AddEventCallbacks({ OnClick =
    function (self)
    
        local formData = self.scriptHandle.passwordForm:GetFormData()
        MainMenu_SetSelectedServerPassword(formData.PASSWORD)
        self.scriptHandle:JoinServer()
        
    end })
    
end

local function GetFiltersAllowCommunityContent(self)
    return self.filterModded:GetValue() == false
end

local kMaxPingDesciption = "MAX PING: %s"
local kTickrateDescription = "PERFORMANCE: %s%%"

local function CreateFilterForm(self)

    self.filterForm = CreateMenuElement(self.playWindow, "Form", false)
    self.filterForm:SetCSSClass("filter_form")

    self.filterGameMode = self.filterForm:CreateFormElement(Form.kElementType.TextInput, "GAME MODE")
    self.filterGameMode:SetCSSClass("filter_gamemode")
    self.filterGameMode:AddSetValueCallback( function(self)
    
        local value = self:GetValue()
        self.scriptHandle.serverList:SetFilter(1, FilterServerMode(value))   
        self.scriptHandle.filterCustomContentHint:SetIsVisible(GetFiltersAllowCommunityContent(self.scriptHandle))
        
        Client.SetOptionString("filter_gamemode", value)
     
    end )
    
    self.filterCustomContentHint = CreateMenuElement(self.filterForm, "Font")
    self.filterCustomContentHint:SetText(Locale.ResolveString("SERVERBROWSER_SHOWING_MODDED_HINT"))
    self.filterCustomContentHint:SetCSSClass("filter_custom_content_hint")
    self.filterCustomContentHint:SetIsVisible(false)

    local description = CreateMenuElement(self.filterGameMode, "Font")
    description:SetText("GAME")
    description:SetCSSClass("filter_description")
    
    self.filterMapName = self.filterForm:CreateFormElement(Form.kElementType.TextInput, "MAP NAME")
    self.filterMapName:SetCSSClass("filter_mapname")
    self.filterMapName:AddSetValueCallback( function(self)
    
        self.scriptHandle.serverList:SetFilter(2, FilterMapName(self:GetValue()))
        Client.SetOptionString("filter_mapname", self.scriptHandle.filterMapName:GetValue())
        
    end )

    local description = CreateMenuElement(self.filterMapName, "Font")
    description:SetText("MAP")
    description:SetCSSClass("filter_description")
    
    self.filterTickrate = self.filterForm:CreateFormElement(Form.kElementType.SlideBar, "TICK RATE")
    self.filterTickrate:SetCSSClass("filter_tickrate")
    self.filterTickrate:AddSetValueCallback( function(self)
    
        local value = self:GetValue()
        self.scriptHandle.serverList:SetFilter(3, FilterMinRate(value))
        Client.SetOptionString("filter_tickrate", ToString(value))
        
        self.scriptHandle.tickrateDescription:SetText(string.format(kTickrateDescription, ToString(math.round(value * 100)))) 
        
    end )

    self.tickrateDescription = CreateMenuElement(self.filterTickrate, "Font")
    self.tickrateDescription:SetCSSClass("filter_description")
    
    self.filterMaxPing = self.filterForm:CreateFormElement(Form.kElementType.SlideBar, "MAX PING")
    self.filterMaxPing:SetCSSClass("filter_maxping")
    self.filterMaxPing:AddSetValueCallback( function(self)
        
        local value = self.scriptHandle.filterMaxPing:GetValue()
        self.scriptHandle.serverList:SetFilter(4, FilterMaxPing(math.round(value * kFilterMaxPing)))
        Client.SetOptionString("filter_maxping", ToString(value))
        
        local textValue = ""
        if value == 1.0 then
            textValue = "unlimited"
        else        
            textValue = ToString(math.round(value * kFilterMaxPing))
        end

        self.scriptHandle.pingDescription:SetText(string.format(kMaxPingDesciption, textValue))    
        
    end )

    self.pingDescription = CreateMenuElement(self.filterMaxPing, "Font")
    self.pingDescription:SetCSSClass("filter_description")
    
    self.filterHasPlayers = self.filterForm:CreateFormElement(Form.kElementType.Checkbox, "FILTER EMPTY")
    self.filterHasPlayers:SetCSSClass("filter_hasplayers")
    self.filterHasPlayers:AddSetValueCallback( function(self)
    
        self.scriptHandle.serverList:SetFilter(5, FilterEmpty(self:GetValue()))
        Client.SetOptionString("filter_hasplayers", ToString(self.scriptHandle.filterHasPlayers:GetValue()))
        
    end )

    local description = CreateMenuElement(self.filterHasPlayers, "Font")
    description:SetText("FILTER EMPTY")
    description:SetCSSClass("filter_description")
    
    self.filterFull = self.filterForm:CreateFormElement(Form.kElementType.Checkbox, "FILTER FULL")
    self.filterFull:SetCSSClass("filter_full")
    self.filterFull:AddSetValueCallback( function(self)
    
        self.scriptHandle.serverList:SetFilter(6, FilterFull(self:GetValue()))
        Client.SetOptionString("filter_full", ToString(self.scriptHandle.filterFull:GetValue()))
        
    end )
    
    local description = CreateMenuElement(self.filterFull, "Font")
    description:SetText("FILTER FULL")
    description:SetCSSClass("filter_description")
    
    self.filterModded = self.filterForm:CreateFormElement(Form.kElementType.Checkbox, "FILTER MODDED")
    self.filterModded:SetCSSClass("filter_modded")
    self.filterModded:AddSetValueCallback( function(self)
    
        self.scriptHandle.serverList:SetFilter(7, FilterModded(self:GetValue()))
        self.scriptHandle.filterCustomContentHint:SetIsVisible(GetFiltersAllowCommunityContent(self.scriptHandle))
        Client.SetOptionString("filter_modded", ToString(self:GetValue()))
        
    end )
    
    local description = CreateMenuElement(self.filterModded, "Font")
    description:SetText("FILTER MODDED")
    description:SetCSSClass("filter_description")
    
    self.filterFavorites = self.filterForm:CreateFormElement(Form.kElementType.Checkbox, "FAVORITES")
    self.filterFavorites:SetCSSClass("filter_favorites")
    self.filterFavorites:AddSetValueCallback( function(self)
    
        self.scriptHandle.serverList:SetFilter(7, FilterFavoriteOnly(self:GetValue()))
        Client.SetOptionString("filter_favorites", ToString(self.scriptHandle.filterFavorites:GetValue()))
        
    end )
    
    local description = CreateMenuElement(self.filterFavorites, "Font")
    description:SetText("FAVORITES")
    description:SetCSSClass("filter_description")
    
    
    self.filterRookie = self.filterForm:CreateFormElement(Form.kElementType.Checkbox, "FILTER ROOKIE")
    self.filterRookie:SetCSSClass("filter_rookie")
    self.filterRookie:AddSetValueCallback( function(self)
    
        self.scriptHandle.serverList:SetFilter(8, FilterRookie(self:GetValue()))
        Client.SetOptionString("filter_rookie", ToString(self.scriptHandle.filterRookie:GetValue()))
        
    end )
    
    local description = CreateMenuElement(self.filterRookie, "Font")
    description:SetText("FILTER ROOKIE")
    description:SetCSSClass("filter_description")
    
    self.filterGameMode:SetValue(Client.GetOptionString("filter_gamemode", ""))
    self.filterMapName:SetValue(Client.GetOptionString("filter_mapname", ""))
    self.filterTickrate:SetValue(tonumber(Client.GetOptionString("filter_tickrate", "0")) or 0)
    self.filterHasPlayers:SetValue(Client.GetOptionString("filter_hasplayers", "false"))
    self.filterFull:SetValue(Client.GetOptionString("filter_full", "false"))
    self.filterMaxPing:SetValue(tonumber(Client.GetOptionString("filter_maxping", "1")) or 1)
    self.filterModded:SetValue(Client.GetOptionString("filter_modded", "false"))
    self.filterRookie:SetValue(Client.GetOptionString("filter_rookie", "false"))
    self.filterFavorites:SetValue(Client.GetOptionString("filter_favorites", "false"))
    
end

function GUIMainMenu:CreateServerListWindow()

    local update = CreateMenuElement(self.playWindow, "MenuButton")
    update:SetCSSClass("update")
    update:SetText("UPDATE")
    self.playWindow.updateButton = update
    update:AddEventCallbacks({
        OnClick = function()
            UpdateServerList(self)
        end
    })
    
    local refresh = CreateMenuElement(self.playWindow, "MenuButton")
    refresh:SetCSSClass("refresh")
    refresh:SetText("REFRESH")
    self.playWindow.refreshButton = refresh
    refresh:AddEventCallbacks({
        OnClick = function()
            RefreshServerList(self)
        end
    })
    refresh:SetIsVisible(false)
    
    self.joinServerButton = CreateMenuElement(self.playWindow, "MenuButton")
    self.joinServerButton:SetCSSClass("apply")
    self.joinServerButton:SetText("JOIN")
    self.joinServerButton:AddEventCallbacks( {OnClick = function(self) self.scriptHandle:ProcessJoinServer() end } )
    
    self.highlightServer = CreateMenuElement(self.playWindow:GetContentBox(), "Image")
    self.highlightServer:SetCSSClass("highlight_server")
    self.highlightServer:SetIgnoreEvents(true)
    self.highlightServer:SetIsVisible(false)
    
    self.blinkingArrow = CreateMenuElement(self.highlightServer, "Image")
    self.blinkingArrow:SetCSSClass("blinking_arrow")
    self.blinkingArrow:GetBackground():SetInheritsParentStencilSettings(false)
    self.blinkingArrow:GetBackground():SetStencilFunc(GUIItem.Always)
    
    self.selectServer = CreateMenuElement(self.playWindow:GetContentBox(), "Image")
    self.selectServer:SetCSSClass("select_server")
    self.selectServer:SetIsVisible(false)
    self.selectServer:SetIgnoreEvents(true)
    
    self.serverRowNames = CreateMenuElement(self.playWindow, "Table")
    self.serverList = CreateMenuElement(self.playWindow:GetContentBox(), "ServerList")
    
    local columnClassNames =
    {
        "favorite",
        "private",
        "servername",
        "game",
        "map",
        "players",
        "rate",
        "ping"
    }
    
    local rowNames = { { "FAVORITE", "PRIVATE", "NAME", "GAME", "MAP", "PLAYERS", "PERF.", "PING" } }
    
    local serverList = self.serverList
    
    local entryCallbacks = {
        { OnClick = function() UpdateSortOrder(1) serverList:SetComparator( SortByFavorite ) end },
        { OnClick = function() UpdateSortOrder(2) serverList:SetComparator( SortByPrivate ) end },
        { OnClick = function() UpdateSortOrder(3) serverList:SetComparator( SortByName ) end },
        { OnClick = function() UpdateSortOrder(4) serverList:SetComparator( SortByMode ) end },
        { OnClick = function() UpdateSortOrder(5) serverList:SetComparator( SortByMap ) end },
        { OnClick = function() UpdateSortOrder(6) serverList:SetComparator( SortByPlayers ) end },
        { OnClick = function() UpdateSortOrder(7) serverList:SetComparator( SortByTickrate ) end },
        { OnClick = function() UpdateSortOrder(8) serverList:SetComparator( SortByPing ) end },
    }
    
    self.serverRowNames:SetCSSClass("server_list_row_names")
    self.serverRowNames:AddCSSClass("server_list_names")
    self.serverRowNames:SetColumnClassNames(columnClassNames)
    self.serverRowNames:SetEntryCallbacks(entryCallbacks)
    self.serverRowNames:SetRowPattern( { RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, } )
    self.serverRowNames:SetTableData(rowNames)
    
    self.playWindow:AddEventCallbacks({
        OnShow = function()
        
            // Default to no sorting.
            sortedColumn = nil
            entryCallbacks[6].OnClick()
            self.playWindow:ResetSlideBar()
            UpdateServerList(self)
            
        end
    })
    
    CreateFilterForm(self)
    
end

function GUIMainMenu:ResetServerSelection()
    
    self.selectServer:SetIsVisible(false)
    MainMenu_SelectServer(nil)
    
end

local function SaveServerSettings(self)

    local formData = self.createServerForm:GetFormData()
    Client.SetOptionString("serverName", formData.ServerName)
    Client.SetOptionString("mapName", formData.Map)
    Client.SetOptionString("lastServerMapName", formData.Map)
    Client.SetOptionString("gameMod", formData.GameMode)
    Client.SetOptionInteger("playerLimit", formData.PlayerLimit)
    Client.SetOptionString("serverPassword", formData.Password)
    
end

local function CreateExploreServer(self)

    local formData = self.createExploreServerForm:GetFormData()
    
    local modIndex      = Client.GetLocalModId("explore")
    
    if modIndex == -1 then
        Shared.Message("Explore mode does not exist!")
        return
    end
    
    local password      = formData.Password
    local port          = 27015
    local maxPlayers    = formData.PlayerLimit
    local serverName    = formData.ServerName
    local mapName       = "ns2_" .. string.lower(formData.Map)
    Client.SetOptionString("lastServerMapName", mapName)
    
    if Client.StartServer(modIndex, mapName, serverName, password, port, maxPlayers) then
        LeaveMenu()
    end
    
end

local function CreateServer(self)

    SaveServerSettings(self)
    local formData = self.createServerForm:GetFormData()
    
    local modIndex      = self.createServerForm.modIds[formData.Map_index]
    local password      = formData.Password
    local port          = 27015
    local maxPlayers    = formData.PlayerLimit
    local serverName    = formData.ServerName
    
    if modIndex == 0 then
        local mapName = formData.GameMode .. "_" .. string.lower(formData.Map)
        if Client.StartServer(mapName, serverName, password, port, maxPlayers) then
            LeaveMenu()
        end
    else
        if Client.StartServer(modIndex, serverName, password, port, maxPlayers) then
            LeaveMenu()
        end
    end
    
end

function GUIMainMenu:CreateServerDetailWindow()

    self.serverDetailWindow = self:CreateWindow()
    self:SetupWindow(self.hostGameWindow, "SERVER DETAIL")
    self.serverDetailWindow:DisableSlideBar()
    self.serverDetailWindow:AddEventCallbacks({ OnShow = function() LoadServerDetails(self) end })

end
 
local function GetMaps()

    Client.RefreshModList()
    
    local mapNames = { }
    local modIds   = { }
    
    // First add all of the maps that ship with the game into the list.
    // These maps don't have corresponding mod ids since they are loaded
    // directly from the main game.
    local shippedMaps = MainMenu_GetMapNameList()
    for i = 1, #shippedMaps do
        mapNames[i] = shippedMaps[i]
        modIds[i]   = 0
    end
    
    // TODO: Add levels from mods we have installed
    
    return mapNames, modIds

end

GUIMainMenu.CreateOptionsForm = function(mainMenu, content, options)

    local form = CreateMenuElement(content, "Form", false)
    
    local rowHeight = 50
    
    for i = 1, #options do
    
        local option = options[i]
        local input
        
        if option.type == "select" then
            input = form:CreateFormElement(Form.kElementType.DropDown, option.name, option.value)
            if option.values then
                input:SetOptions(option.values)
            end                
        elseif option.type == "slider" then
            input = form:CreateFormElement(Form.kElementType.SlideBar, option.name, option.value)
            // HACK: Really should use input:AddSetValueCallback, but the slider bar bypasses that.
            if option.sliderCallback then
                input:Register(
                    {OnSlide =
                        function(value, interest)
                            option.sliderCallback(mainMenu)
                        end
                    }, SLIDE_HORIZONTAL)
            end
        else
            input = form:CreateFormElement(Form.kElementType.TextInput, option.name, option.value)
        end
        
        if option.callback then
            input:AddSetValueCallback(option.callback)
        end
        
        local y = rowHeight * (i - 1)
        
        input:SetCSSClass("option_input")
        input:SetTopOffset(y)
        
        local label = CreateMenuElement(form, "Font", false)
        label:SetCSSClass("option_label")
        label:SetText(option.label .. ":")
        label:SetTopOffset(y)
        label:SetIgnoreEvents(true)

        mainMenu.optionElements[option.name] = input
        
    end
    
    form:SetCSSClass("options")
    return form

end

function GUIMainMenu:CreateExploreWindow()

    local minPlayers            = 2
    local maxPlayers            = 32
    local playerLimitOptions    = { }
    
    for i = minPlayers, maxPlayers do
        table.insert(playerLimitOptions, i)
    end

    local gameModes = CreateServerUI_GetGameModes()

    local hostOptions = 
        {
            {   
                name   = "ServerName",            
                label  = "SERVER NAME",
                value  = "Explore Mode"
            },
            {   
                name   = "Password",            
                label  = "PASSWORD [OPTIONAL]",
            },
            {
                name    = "Map",
                label   = "MAP",
                type    = "select",
                value  = "Summit",
            },

            {
                name    = "PlayerLimit",
                label   = "PLAYER LIMIT",
                type    = "select",
                values  = playerLimitOptions,
                value   = 4
            },
        }
        
    self.optionElements = { }
    
    local content = self.explore
    local createServerForm = GUIMainMenu.CreateOptionsForm(self, content, hostOptions)
    
    self.createExploreServerForm = createServerForm
    self.createExploreServerForm:SetCSSClass("createserver")
    
    local mapList = self.optionElements.Map
    
    self.exploreButton = CreateMenuElement(self.tutorialWindow, "MenuButton")
    self.exploreButton:SetCSSClass("apply")
    self.exploreButton:SetText("EXPLORE")
    
    self.exploreButton:AddEventCallbacks({
             OnClick = function (self) CreateExploreServer(self.scriptHandle) end
        })

    self.explore:AddEventCallbacks({
             OnShow = function (self)
                local mapNames = { "Summit" }
                mapList:SetOptions( mapNames )
            end
        })
    
end

function GUIMainMenu:CreateHostGameWindow()

    self.createGame:AddEventCallbacks({ OnHide = function() SaveServerSettings(self) end })

    local minPlayers            = 2
    local maxPlayers            = 32
    local playerLimitOptions    = { }
    
    for i = minPlayers, maxPlayers do
        table.insert(playerLimitOptions, i)
    end

    local gameModes = CreateServerUI_GetGameModes()

    local hostOptions = 
        {
            {   
                name   = "ServerName",            
                label  = "SERVER NAME",
                value  = Client.GetOptionString("serverName", "NS2 Listen Server")
            },
            {   
                name   = "Password",            
                label  = "PASSWORD [OPTIONAL]",
                value  = Client.GetOptionString("serverPassword", "")
            },
            {
                name    = "Map",
                label   = "MAP",
                type    = "select",
                value  = Client.GetOptionString("mapName", "Summit")
            },
            {
                name    = "GameMode",
                label   = "GAME MODE",
                type    = "select",
                values  = gameModes,
                value   = gameModes[CreateServerUI_GetGameModesIndex()]
            },
            {
                name    = "PlayerLimit",
                label   = "PLAYER LIMIT",
                type    = "select",
                values  = playerLimitOptions,
                value   = Client.GetOptionInteger("playerLimit", 16)
            },
        }
        
    self.optionElements = { }
    
    local content = self.createGame
    local createServerForm = GUIMainMenu.CreateOptionsForm(self, content, hostOptions)
    
    self.createServerForm = createServerForm
    self.createServerForm:SetCSSClass("createserver")
    
    local mapList = self.optionElements.Map
    
    self.hostGameButton = CreateMenuElement(self.playWindow, "MenuButton")
    self.hostGameButton:SetCSSClass("apply")
    self.hostGameButton:SetText("CREATE")
    
    self.hostGameButton:AddEventCallbacks({
             OnClick = function (self) CreateServer(self.scriptHandle) end
        })

    self.createGame:AddEventCallbacks({
             OnShow = function (self)
                local mapNames
                mapNames, createServerForm.modIds = GetMaps()
                mapList:SetOptions( mapNames )
            end
        })
    
end

local function InitKeyBindings(keyInputs)

    local bindingsTable = BindingsUI_GetBindingsTable()
    for b = 1, #bindingsTable do
        keyInputs[b]:SetValue(bindingsTable[b].current)
    end
    
end

local function CheckForConflictedKeys(keyInputs)

    // Reset back to non-conflicted state.
    for k = 1, #keyInputs do
        keyInputs[k]:SetCSSClass("option_input")
    end
    
    // Check for conflicts.
    for k1 = 1, #keyInputs do
    
        for k2 = 1, #keyInputs do
        
            if k1 ~= k2 then
            
                local boundKey1 = Client.GetOptionString("input/" .. keyInputs[k1].inputName, "")
                local boundKey2 = Client.GetOptionString("input/" .. keyInputs[k2].inputName, "")
                if boundKey1 == boundKey2 then
                
                    keyInputs[k1]:SetCSSClass("option_input_conflict")
                    keyInputs[k2]:SetCSSClass("option_input_conflict")
                    
                end
                
            end
            
        end
        
    end
    
end

local function CreateKeyBindingsForm(mainMenu, content)

    local keyBindingsForm = CreateMenuElement(content, "Form", false)
    
    local bindingsTable = BindingsUI_GetBindingsTable()
    
    mainMenu.keyInputs = { }
    
    local rowHeight = 50
    
    for b = 1, #bindingsTable do
    
        local binding = bindingsTable[b]
        
        local keyInput = keyBindingsForm:CreateFormElement(Form.kElementType.FormButton, "INPUT" .. b, binding.current)
        keyInput:SetCSSClass("option_input")
        keyInput:AddEventCallbacks( { OnBlur = function(self) keyInput.ignoreFirstKey = nil end } )
        
        function keyInput:OnSendKey(key, down)
        
            if not down then
            
                // We want to ignore the click that gave this input focus.
                if keyInput.ignoreFirstKey == true then
                
                    local keyString = Client.ConvertKeyCodeToString(key)
                    keyInput:SetValue(keyString)
                    
                    Client.SetOptionString("input/" .. keyInput.inputName, keyString)
                    
                    CheckForConflictedKeys(mainMenu.keyInputs)
                    
                end
                keyInput.ignoreFirstKey = true
                
            end
            
        end
        
        local keyInputText = CreateMenuElement(keyBindingsForm, "Font", false)
        keyInputText:SetText(string.upper(binding.detail) ..  ":")
        keyInputText:SetCSSClass("option_label")
        
        local y = rowHeight * (b  - 1)
        
        keyInput:SetTopOffset(y)
        keyInputText:SetTopOffset(y)
        
        keyInput.inputName = binding.name
        table.insert(mainMenu.keyInputs, keyInput)
        
    end
    
    InitKeyBindings(mainMenu.keyInputs)
    
    CheckForConflictedKeys(mainMenu.keyInputs)
    
    keyBindingsForm:SetCSSClass("keybindings")
    
    return keyBindingsForm
    
end

local function InitOptions(optionElements)
        
    local function BoolToIndex(value)
        if value then
            return 2
        end
        return 1
    end

    local nickName              = OptionsDialogUI_GetNickname()
    local mouseSens             = (OptionsDialogUI_GetMouseSensitivity() - kMinSensitivity) / (kMaxSensitivity - kMinSensitivity)
    local mouseAcceleration     = Client.GetOptionBoolean("input/mouse/acceleration", false)
    local accelerationAmount    = (Client.GetOptionFloat("input/mouse/acceleration-amount", 1) - kMinAcceleration) / (kMaxAcceleration -kMinAcceleration)
    local invMouse              = OptionsDialogUI_GetMouseInverted()
    local rawInput              = Client.GetOptionBoolean("input/mouse/rawinput", false)
    local locale                = Client.GetOptionString( "locale", "enUS" )
    local showHints             = Client.GetOptionBoolean( "showHints", true )
    local showCommanderHelp     = Client.GetOptionBoolean( "commanderHelp", true )
    local drawDamage            = Client.GetOptionBoolean( "drawDamage", true )
    local rookieMode            = Client.GetOptionBoolean( kRookieOptionsKey, true )

    local screenResIdx = OptionsDialogUI_GetScreenResolutionsIndex()
    local visualDetailIdx = OptionsDialogUI_GetVisualDetailSettingsIndex()
    local displayMode = table.find(kDisplayModes, OptionsDialogUI_GetWindowMode())
    local displayBuffering = Client.GetOptionInteger("graphics/display/display-buffering", 0)
    local multicoreRendering = Client.GetOptionBoolean("graphics/multithreaded", true)
    local textureStreaming = Client.GetOptionBoolean("graphics/texture-streaming", false)
    local ambientOcclusion = Client.GetOptionString("graphics/display/ambient-occlusion", kAmbientOcclusionModes[1])
    local infestation = Client.GetOptionString("graphics/infestation", "rich")
    local fovAdjustment = Client.GetOptionFloat("graphics/display/fov-adjustment", 0)
    local cameraAnimation       = Client.GetOptionBoolean("CameraAnimation", false) and "ON" or "OFF"
    
    local minimapZoom = Client.GetOptionFloat( "minimap-zoom", 0.75 )
    local armorType = Client.GetOptionString( "armorType", "" )
    
    if string.len(armorType) == 0 then
    
        if GetHasBlackArmor() then
            armorType = "Black"
        elseif GetHasDeluxeEdition() then
            armorType = "Deluxe"
        else
            armorType = "Green"
        end
        
    end
    
    Client.SetOptionString("armorType", armorType)
    
    // support legacy values    
    if ambientOcclusion == "false" then
        ambientOcclusion = "off"
    elseif ambientOcclusion == "true" then
        ambientOcclusion = "high"
    end
    
    local shadows = OptionsDialogUI_GetShadows()
    local bloom = OptionsDialogUI_GetBloom()
    local atmospherics = OptionsDialogUI_GetAtmospherics()
    local anisotropicFiltering = OptionsDialogUI_GetAnisotropicFiltering()
    local antiAliasing = OptionsDialogUI_GetAntiAliasing()
    
    local soundVol = Client.GetOptionInteger("soundVolume", 90) / 100
    local musicVol = Client.GetOptionInteger("musicVolume", 90) / 100
    local voiceVol = Client.GetOptionInteger("voiceVolume", 90) / 100
    
    for i = 1, #kLocales do
    
        if kLocales[i].name == locale then
            optionElements.Language:SetOptionActive(i)
        end
        
    end
    
    optionElements.NickName:SetValue( nickName )
    optionElements.Sensitivity:SetValue( mouseSens )
    optionElements.AccelerationAmount:SetValue( accelerationAmount )
    optionElements.MouseAcceleration:SetOptionActive( BoolToIndex(mouseAcceleration) )
    optionElements.InvertedMouse:SetOptionActive( BoolToIndex(invMouse) )
    optionElements.RawInput:SetOptionActive( BoolToIndex(rawInput) )
    optionElements.ShowHints:SetOptionActive( BoolToIndex(showHints) )
    optionElements.ShowCommanderHelp:SetOptionActive( BoolToIndex(showCommanderHelp) )
    optionElements.DrawDamage:SetOptionActive( BoolToIndex(drawDamage) )
    optionElements.RookieMode:SetOptionActive( BoolToIndex(rookieMode) )

    optionElements.DisplayMode:SetOptionActive( displayMode )
    optionElements.DisplayBuffering:SetOptionActive( displayBuffering + 1 )
    optionElements.Resolution:SetOptionActive( screenResIdx )
    optionElements.Shadows:SetOptionActive( BoolToIndex(shadows) )
    optionElements.Infestation:SetOptionActive( table.find(kInfestationModes, infestation) )
    optionElements.Bloom:SetOptionActive( BoolToIndex(bloom) )
    optionElements.Atmospherics:SetOptionActive( BoolToIndex(atmospherics) )
    optionElements.AnisotropicFiltering:SetOptionActive( BoolToIndex(anisotropicFiltering) )
    optionElements.AntiAliasing:SetOptionActive( BoolToIndex(antiAliasing) )
    optionElements.Detail:SetOptionActive(visualDetailIdx)
    optionElements.MulticoreRendering:SetOptionActive( BoolToIndex(multicoreRendering) )
    optionElements.TextureStreaming:SetOptionActive( BoolToIndex(textureStreaming) )
    optionElements.AmbientOcclusion:SetOptionActive( table.find(kAmbientOcclusionModes, ambientOcclusion) )
    optionElements.FOVAdjustment:SetValue(fovAdjustment)
    optionElements.MinimapZoom:SetValue(minimapZoom)
    optionElements.ArmorType:SetValue(armorType)
    optionElements.CameraAnimation:SetValue(cameraAnimation)
    
    
    optionElements.SoundVolume:SetValue(soundVol)
    optionElements.MusicVolume:SetValue(musicVol)
    optionElements.VoiceVolume:SetValue(voiceVol)
    
end

local function SaveSecondaryGraphicsOptions(mainMenu)
    // These are options that are pretty quick to change, unlike screen resolution etc.
    // Have this separate, since graphics options are auto-applied
        
    local multicoreRendering    = mainMenu.optionElements.MulticoreRendering:GetActiveOptionIndex() > 1
    local textureStreaming      = mainMenu.optionElements.TextureStreaming:GetActiveOptionIndex() > 1
    local ambientOcclusionIdx   = mainMenu.optionElements.AmbientOcclusion:GetActiveOptionIndex()
    local visualDetailIdx       = mainMenu.optionElements.Detail:GetActiveOptionIndex()
    local infestationIdx        = mainMenu.optionElements.Infestation:GetActiveOptionIndex()
    local shadows               = mainMenu.optionElements.Shadows:GetActiveOptionIndex() > 1
    local bloom                 = mainMenu.optionElements.Bloom:GetActiveOptionIndex() > 1
    local atmospherics          = mainMenu.optionElements.Atmospherics:GetActiveOptionIndex() > 1
    local anisotropicFiltering  = mainMenu.optionElements.AnisotropicFiltering:GetActiveOptionIndex() > 1
    local antiAliasing          = mainMenu.optionElements.AntiAliasing:GetActiveOptionIndex() > 1
    
    Client.SetOptionBoolean("graphics/multithreaded", multicoreRendering)
    Client.SetOptionBoolean("graphics/texture-streaming", textureStreaming)
    Client.SetOptionString("graphics/display/ambient-occlusion", kAmbientOcclusionModes[ambientOcclusionIdx] )
    Client.SetOptionString("graphics/infestation", kInfestationModes[infestationIdx] )
    Client.SetOptionInteger( kDisplayQualityOptionsKey, visualDetailIdx - 1 )
    Client.SetOptionBoolean ( kShadowsOptionsKey, shadows )
    Client.SetOptionBoolean ( kBloomOptionsKey, bloom )
    Client.SetOptionBoolean ( kAtmosphericsOptionsKey, atmospherics )
    Client.SetOptionBoolean ( kAnisotropicFilteringOptionsKey, anisotropicFiltering )
    Client.SetOptionBoolean ( kAntiAliasingOptionsKey, antiAliasing )
    
end

local function SyncSecondaryGraphicsOptions()
    Render_SyncRenderOptions() 
    if Infestation_SyncOptions then
        Infestation_SyncOptions()
    end
end

local function OnGraphicsOptionsChanged(mainMenu)
    SaveSecondaryGraphicsOptions(mainMenu)
    Client.ReloadGraphicsOptions()
    SyncSecondaryGraphicsOptions()
end

local function OnSoundVolumeChanged(mainMenu)
    local soundVol = mainMenu.optionElements.SoundVolume:GetValue() * 100
    OptionsDialogUI_SetSoundVolume( soundVol )
end
local function OnMusicVolumeChanged(mainMenu)
    local musicVol = mainMenu.optionElements.MusicVolume:GetValue() * 100
    OptionsDialogUI_SetMusicVolume( musicVol )
end
local function OnVoiceVolumeChanged(mainMenu)
    local voiceVol = mainMenu.optionElements.VoiceVolume:GetValue() * 100
    OptionsDialogUI_SetVoiceVolume( voiceVol )
end

local function OnFOVAdjustChanged(mainMenu)
    local value = mainMenu.optionElements.FOVAdjustment:GetValue()
    Client.SetOptionFloat("graphics/display/fov-adjustment", value)
end

local function OnMinimapZoomChanged(mainMenu)

    local value = mainMenu.optionElements.MinimapZoom:GetValue()
    Client.SetOptionFloat("minimap-zoom", value)

    if SafeRefreshMinimapZoom then
        SafeRefreshMinimapZoom()
    end

end

local function SaveOptions(mainMenu)

    local nickName              = mainMenu.optionElements.NickName:GetValue()
    local mouseSens             = mainMenu.optionElements.Sensitivity:GetValue() * (kMaxSensitivity - kMinSensitivity) + kMinSensitivity
    local mouseAcceleration     = mainMenu.optionElements.MouseAcceleration:GetActiveOptionIndex() > 1
    local accelerationAmount    = mainMenu.optionElements.AccelerationAmount:GetValue() * (kMaxAcceleration - kMinAcceleration) + kMinAcceleration
    local invMouse              = mainMenu.optionElements.InvertedMouse:GetActiveOptionIndex() > 1
    local rawInput              = mainMenu.optionElements.RawInput:GetActiveOptionIndex() > 1
    local locale                = kLocales[mainMenu.optionElements.Language:GetActiveOptionIndex()].name
    local showHints             = mainMenu.optionElements.ShowHints:GetActiveOptionIndex() > 1
    local showCommanderHelp     = mainMenu.optionElements.ShowCommanderHelp:GetActiveOptionIndex() > 1
    local drawDamage            = mainMenu.optionElements.DrawDamage:GetActiveOptionIndex() > 1
    local rookieMode            = mainMenu.optionElements.RookieMode:GetActiveOptionIndex() > 1
    
    local screenResIdx          = mainMenu.optionElements.Resolution:GetActiveOptionIndex()
    local visualDetailIdx       = mainMenu.optionElements.Detail:GetActiveOptionIndex()
    local displayBuffering      = mainMenu.optionElements.DisplayBuffering:GetActiveOptionIndex() - 1
    local displayMode           = mainMenu.optionElements.DisplayMode:GetActiveOptionIndex()
    local shadows               = mainMenu.optionElements.Shadows:GetActiveOptionIndex() > 1
    local bloom                 = mainMenu.optionElements.Bloom:GetActiveOptionIndex() > 1
    local atmospherics          = mainMenu.optionElements.Atmospherics:GetActiveOptionIndex() > 1
    local anisotropicFiltering  = mainMenu.optionElements.AnisotropicFiltering:GetActiveOptionIndex() > 1
    local antiAliasing          = mainMenu.optionElements.AntiAliasing:GetActiveOptionIndex() > 1
    
    local soundVol              = mainMenu.optionElements.SoundVolume:GetValue() * 100
    local musicVol              = mainMenu.optionElements.MusicVolume:GetValue() * 100
    local voiceVol              = mainMenu.optionElements.VoiceVolume:GetValue() * 100
    
    local armorType             = mainMenu.optionElements.ArmorType:GetValue()
    local cameraAnimation       = mainMenu.optionElements.CameraAnimation:GetActiveOptionIndex() > 1
    
    Client.SetOptionString( "locale", locale )

    Client.SetOptionBoolean("input/mouse/rawinput", rawInput)
    Client.SetOptionBoolean("input/mouse/acceleration", mouseAcceleration)
    Client.SetOptionBoolean( "showHints", showHints )
    Client.SetOptionBoolean( "commanderHelp", showCommanderHelp )
    Client.SetOptionBoolean( "drawDamage", drawDamage)
    Client.SetOptionBoolean( kRookieOptionsKey, rookieMode)
    Client.SetOptionBoolean( "CameraAnimation", cameraAnimation)
    Client.SetOptionString( "armorType", armorType )

    Client.SetOptionFloat("input/mouse/acceleration-amount", accelerationAmount)
    
    // Some redundancy with ApplySecondaryGraphicsOptions here, no harm.
    OptionsDialogUI_SetValues(
        nickName,
        mouseSens,
        screenResIdx,
        visualDetailIdx,
        soundVol,
        musicVol,
        kDisplayModes[displayMode],
        shadows,
        bloom,
        atmospherics,
        anisotropicFiltering,
        antiAliasing,
        invMouse,
        voiceVol)
    SaveSecondaryGraphicsOptions(mainMenu)
    Client.SetOptionInteger("graphics/display/display-buffering", displayBuffering)
    
    // This will reload the first three graphics settings
    OptionsDialogUI_ExitDialog()

    SyncSecondaryGraphicsOptions()
    
    for k = 1, #mainMenu.keyInputs do
    
        local keyInput = mainMenu.keyInputs[k]
        Client.SetOptionString("input/" .. keyInput.inputName, keyInput:GetValue())
        
    end
    Client.ReloadKeyOptions()
    

end

local function StoreCameraAnimationOption(formElement)
    Client.SetOptionBoolean("CameraAnimation", formElement:GetActiveOptionIndex() > 1)
end

function GUIMainMenu:CreateOptionWindow()

    self.optionWindow = self:CreateWindow()
    self.optionWindow:DisableCloseButton()
    self.optionWindow:SetCSSClass("option_window")
    
    self:SetupWindow(self.optionWindow, "OPTIONS")
    local function InitOptionWindow()
    
        InitOptions(self.optionElements)
        InitKeyBindings(self.keyInputs)
        
    end
    self.optionWindow:AddEventCallbacks({ OnHide = InitOptionWindow })
    
    local content = self.optionWindow:GetContentBox()
    
    local back = CreateMenuElement(self.optionWindow, "MenuButton")
    back:SetCSSClass("back")
    back:SetText("BACK")
    back:AddEventCallbacks( { OnClick = function() self.optionWindow:SetIsVisible(false) end } )
    
    local apply = CreateMenuElement(self.optionWindow, "MenuButton")
    apply:SetCSSClass("apply")
    apply:SetText("APPLY")
    apply:AddEventCallbacks( { OnClick = function() SaveOptions(self) end } )

    self.fpsDisplay = CreateMenuElement( self.optionWindow, "MenuButton" )
    self.fpsDisplay:SetCSSClass("fps")
    
    local screenResolutions = OptionsDialogUI_GetScreenResolutions()
    
    local languages = { }
    for i = 1,#kLocales do
        languages[i] = kLocales[i].label
    end
    
    local armorTypes = {
        "Green"
    }
    
    if GetHasBlackArmor() then
        table.insert(armorTypes, "Black")
    end
    
    if GetHasDeluxeEdition() then
        table.insert(armorTypes, "Deluxe")
    end

    local generalOptions =
        {
            { 
                name    = "NickName",
                label   = "NICKNAME",
            },
            {
                name    = "Language",
                label   = "LANGUAGE",
                type    = "select",
                values  = languages,
            },
            { 
                name    = "Sensitivity",
                label   = "MOUSE SENSITIVITY",
                type    = "slider",
            },
            {
                name    = "InvertedMouse",
                label   = "REVERSE MOUSE",
                type    = "select",
                values  = { "NO", "YES" }
            },
            {
                name    = "MouseAcceleration",
                label   = "MOUSE ACCELERATION",
                type    = "select",
                values  = { "OFF", "ON" }
            },
            {
                name    = "AccelerationAmount",
                label   = "ACCELERATION AMOUNT",
                type    = "slider",
            },
            {
                name    = "RawInput",
                label   = "RAW INPUT",
                type    = "select",
                values  = { "OFF", "ON" }
            },
            {
                name    = "ShowHints",
                label   = "SHOW HINTS",
                type    = "select",
                values  = { "NO", "YES" }
            },  
            {
                name    = "ShowCommanderHelp",
                label   = "COMMANDER HELP",
                type    = "select",
                values  = { "OFF", "ON" }
            },  
            {
                name    = "DrawDamage",
                label   = "DRAW DAMAGE",
                type    = "select",
                values  = { "NO", "YES" }
            },  
            {
                name    = "RookieMode",
                label   = "ROOKIE MODE",
                type    = "select",
                values  = { "NO", "YES" }
            },          
            { 
                name    = "FOVAdjustment",
                label   = "FOV ADJUSTMENT",
                type    = "slider",
                sliderCallback = OnFOVAdjustChanged,
            },
            { 
                name    = "MinimapZoom",
                label   = "MINIMAP ZOOM",
                type    = "slider",
                sliderCallback = OnMinimapZoomChanged,
            },
            
            {
                name    = "ArmorType",
                label   = "ARMOR TYPE",
                type    = "select",
                values  = armorTypes
            },
            
            {
                name    = "CameraAnimation",
                label   = "CAMERA ANIMATION",
                type    = "select",
                values  = { "OFF", "ON" },
                callback = StoreCameraAnimationOption
            }, 
        }

    local soundOptions =
        {
            { 
                name    = "SoundVolume",
                label   = "SOUND VOLUME",
                type    = "slider",
                sliderCallback = OnSoundVolumeChanged,
            },
            { 
                name    = "MusicVolume",
                label   = "MUSIC VOLUME",
                type    = "slider",
                sliderCallback = OnMusicVolumeChanged,
            },
            { 
                name    = "VoiceVolume",
                label   = "VOICE VOLUME",
                type    = "slider",
                sliderCallback = OnVoiceVolumeChanged,
            },
        }        
        
    local autoApplyCallback = function(formElement) OnGraphicsOptionsChanged(self) end
    
    local graphicsOptions = 
        {
            {   
                name   = "Resolution",
                label  = "RESOLUTION",
                type   = "select",
                values = screenResolutions,
            },
            {   
                name   = "DisplayMode",            
                label  = "DISPLAY MODE",
                type   = "select",
                values = { "WINDOWED", "FULLSCREEN", "FULLSCREEN WINDOWED" }
            },
            {   
                name   = "DisplayBuffering",            
                label  = "WAIT FOR VERTICAL SYNC",
                type   = "select",
                values = { "DISABLED", "DOUBLE BUFFERED", "TRIPLE BUFFERED" }
            },
            {
                name    = "Detail",
                label   = "TEXTURE QUALITY",
                type    = "select",
                values  = { "LOW", "MEDIUM", "HIGH" },
                callback = autoApplyCallback
            },
            {
                name    = "Infestation",
                label   = "INFESTATION",
                type    = "select",
                values  = { "MINIMAL", "RICH" },
                callback = autoApplyCallback
            },
            {
                name    = "AntiAliasing",
                label   = "ANTI-ALIASING",
                type    = "select",
                values  = { "OFF", "ON" },
                callback = autoApplyCallback
            },
            {
                name    = "Bloom",
                label   = "BLOOM",
                type    = "select",
                values  = { "OFF", "ON" },
                callback = autoApplyCallback
            },
            {
                name    = "Atmospherics",
                label   = "ATMOSPHERICS",
                type    = "select",
                values  = { "OFF", "ON" },
                callback = autoApplyCallback
            },
            {   
                name    = "AnisotropicFiltering",
                label   = "ANISOTROPIC FILTERING",
                type    = "select",
                values  = { "OFF", "ON" },
                callback = autoApplyCallback
            },
            {
                name    = "AmbientOcclusion",
                label   = "AMBIENT OCCLUSION",
                type    = "select",
                values  = { "OFF", "MEDIUM", "HIGH" },
                callback = autoApplyCallback
            },    
            {
                name    = "Shadows",
                label   = "SHADOWS",
                type    = "select",
                values  = { "OFF", "ON" },
                callback = autoApplyCallback
            },
            {
                name    = "TextureStreaming",
                label   = "TEXTURE STREAMING (EXPERIMENTAL)",
                type    = "select",
                values  = { "OFF", "ON" },
                callback = autoApplyCallback
            },
            {
                name    = "MulticoreRendering",
                label   = "MULTICORE RENDERING",
                type    = "select",
                values  = { "OFF", "ON" },
                callback = autoApplyCallback
            }, 
        }
        
    self.optionElements = { }
    
    local generalForm     = GUIMainMenu.CreateOptionsForm(self, content, generalOptions)
    local keyBindingsForm = CreateKeyBindingsForm(self, content)
    local graphicsForm    = GUIMainMenu.CreateOptionsForm(self, content, graphicsOptions)
    local soundForm       = GUIMainMenu.CreateOptionsForm(self, content, soundOptions)
    
    local tabs = 
        {
            { label = "GENERAL",  form = generalForm, scroll=true  },
            { label = "BINDINGS", form = keyBindingsForm, scroll=true },
            { label = "GRAPHICS", form = graphicsForm },
            { label = "SOUND",    form = soundForm },
        }
        
    local xTabWidth = 256

    local tabBackground = CreateMenuElement(self.optionWindow, "Image")
    tabBackground:SetCSSClass("tab_background")
    tabBackground:SetIgnoreEvents(true)
    
    local tabAnimateTime = 0.1
        
    for i = 1,#tabs do
    
        local tab = tabs[i]
        local tabButton = CreateMenuElement(self.optionWindow, "MenuButton")
        
        local function ShowTab()
            for j =1,#tabs do
                tabs[j].form:SetIsVisible(i == j)
                self.optionWindow:ResetSlideBar()
                self.optionWindow:SetSlideBarVisible(tab.scroll == true)
                local tabPosition = tabButton.background:GetPosition()
                tabBackground:SetBackgroundPosition( tabPosition, false, tabAnimateTime ) 
            end
        end
    
        tabButton:SetCSSClass("tab")
        tabButton:SetText(tab.label)
        tabButton:AddEventCallbacks({ OnClick = ShowTab })
        
        local tabWidth = tabButton:GetWidth()
        tabButton:SetBackgroundPosition( Vector(tabWidth * (i - 1), 0, 0) )
        
        // Make the first tab visible.
        if i==1 then
            tabBackground:SetBackgroundPosition( Vector(tabWidth * (i - 1), 0, 0) )
            ShowTab()
        end
        
    end        
    
    InitOptionWindow()
  
end

local function BuildServerEntry(serverIndex)

    local mods = Client.GetServerKeyValue(serverIndex, "mods")
    
    local serverEntry = { }
    serverEntry.name = Client.GetServerName(serverIndex)
    serverEntry.mode = Client.GetServerGameMode(serverIndex)
    serverEntry.map = GetTrimmedMapName(Client.GetServerMapName(serverIndex))
    serverEntry.numPlayers = Client.GetServerNumPlayers(serverIndex)
    serverEntry.maxPlayers = Client.GetServerMaxPlayers(serverIndex)
    serverEntry.ping = Client.GetServerPing(serverIndex)
    serverEntry.address = Client.GetServerAddress(serverIndex)
    serverEntry.requiresPassword = Client.GetServerRequiresPassword(serverIndex)
    serverEntry.rookieFriendly = Client.GetServerHasTag(serverIndex, "rookie")
    serverEntry.friendsOnServer = false
    serverEntry.lanServer = false
    serverEntry.tickrate = Client.GetServerTickRate(serverIndex)
    serverEntry.serverId = serverIndex
    serverEntry.modded = Client.GetServerIsModded(serverIndex)
    serverEntry.favorite = GetIsServerFavorite(serverEntry.address)
    
    // Change name to display "rookie friendly" at the end of the line.
    if serverEntry.rookieFriendly then
    
        local maxLen = 34
        local separator = ConditionalValue(string.len(serverEntry.name) > maxLen, "... ", " ")
        serverEntry.name = serverEntry.name:sub(0, maxLen) .. separator  .. Locale.ResolveString("ROOKIE_FRIENDLY")
        
    else
    
        local maxLen = 50
        local separator = ConditionalValue(string.len(serverEntry.name) > maxLen, "... ", " ")
        serverEntry.name = serverEntry.name:sub(0, maxLen) .. separator
        
    end
    
    return serverEntry
    
end

function GUIMainMenu:Update(deltaTime)

    PROFILE("GUIMainMenu:Update")
    
    if self:GetIsVisible() then

        local currentTime = Client.GetTime();
        
        // Refresh the mod list once every 5 seconds
        self.timeOfLastRefresh = self.timeOfLastRefresh or currentTime
        if self.modsWindow:GetIsVisible() and currentTime - self.timeOfLastRefresh >= 5 then
            self:RefreshModsList()
            self.timeOfLastRefresh = currentTime;
        end

        self.tweetText:Update(deltaTime)
    
        local alertText = MainMenu_GetAlertMessage()
        if self.currentAlertText ~= alertText then
        
            self.currentAlertText = alertText
            
            if self.currentAlertText then
                self.alertText:SetText(self.currentAlertText)
                self.alertWindow:SetIsVisible(true)
            end
            
        end
    
        // update only when visible
        GUIAnimatedScript.Update(self, deltaTime)
        self.playerName:SetText(OptionsDialogUI_GetNickname())
        
        if self.modsWindow:GetIsVisible() then
            self:UpdateModsWindow(self)
        end
        
        if self.playWindow:GetIsVisible() then
        
            if self.timeUpdateButtonPressed and self.timeUpdateButtonPressed + 4 < Shared.GetTime() then
            
                self.playWindow.updateButton:SetText("UPDATE")
                self.timeUpdateButtonPressed = nil
                
            end
            
            if not Client.GetServerListRefreshed() then
            
                for s = 0, Client.GetNumServers() - 1 do
                
                    if s + 1 > self.numServers then
                    
                        local serverEntry = BuildServerEntry(s)
                        self.serverList:AddEntry(serverEntry)
                        
                        self.numServers = self.numServers + 1
                        
                    end
                    
                end
                
            end
            
        end
        
        self:UpdateFindPeople(deltaTime)
        self.playNowWindow:UpdateLogic(self)
        
        self.fpsDisplay:SetText(string.format("FPS: %.0f", Client.GetFrameRate()))
        
        if self.updateAutoJoin then
        
            if not self.timeLastAutoJoinUpdate or self.timeLastAutoJoinUpdate + 10 < Shared.GetTime() then
            
                Client.RefreshServer(MainMenu_GetSelectedServer())
                
                if MainMenu_GetSelectedIsFull() then
                    self.timeLastAutoJoinUpdate = Shared.GetTime()
                else
                
                    MainMenu_JoinSelected()
                    self.autoJoinWindow:SetIsVisible(false)
                    
                end
                
            end
            
        end
        
    end
    
end

function GUIMainMenu:OnServerRefreshed(serverIndex)

    local serverEntry = BuildServerEntry(serverIndex)
    self.serverList:UpdateEntry(serverEntry)
    
end

function GUIMainMenu:ShowMenu()

    self.menuBackground:SetIsVisible(true)
    self.menuBackground:SetCSSClass("menu_bg_show", false)
    
    self.logo:SetIsVisible(true)
    
end

function GUIMainMenu:HideMenu()

    self.menuBackground:SetCSSClass("menu_bg_hide", false)

    if self.resumeLink then
        self.resumeLink:SetIsVisible(false)
    end
    if self.readyRoomLink then
        self.readyRoomLink:SetIsVisible(false)
    end
    if self.modsLink then
        self.modsLink:SetIsVisible(false)
    end
    self.playLink:SetIsVisible(false)
    self.tutorialLink:SetIsVisible(false)
    self.optionLink:SetIsVisible(false)
    if self.quitLink then
        self.quitLink:SetIsVisible(false)
    end
    if self.disconnectLink then
        self.disconnectLink:SetIsVisible(false)
    end
    
    self.logo:SetIsVisible(false)
    
end

function GUIMainMenu:OnAnimationsEnd(item)
    
    if item == self.scanLine:GetBackground() then
        self.scanLine:SetCSSClass("scanline")
    end
    
end

function GUIMainMenu:OnAnimationCompleted(animatedItem, animationName, itemHandle)

    if animationName == "ANIMATE_LINK_BG" then
    
        if self.modsLink then
            self.modsLink:ReloadCSSClass()
        end
        if self.quitLink then
            self.quitLink:ReloadCSSClass()
        end
        self.highlightServer:ReloadCSSClass()
        if self.disconnectLink then
            self.disconnectLink:ReloadCSSClass()
        end
        if self.resumeLink then
            self.resumeLink:ReloadCSSClass()
        end
        if self.readyRoomLink then
            self.readyRoomLink:ReloadCSSClass()
        end
        self.playLink:ReloadCSSClass()
        self.tutorialLink:ReloadCSSClass()
        self.optionLink:ReloadCSSClass()
        
    elseif animationName == "ANIMATE_BLINKING_ARROW" then
    
        self.blinkingArrow:SetCSSClass("blinking_arrow")
        
    elseif animationName == "ANIMATE_BLINKING_ARROW_TWO" then
    
        self.blinkingArrowTwo:SetCSSClass("blinking_arrow_two")
        
    elseif animationName == "MAIN_MENU_OPACITY" then
    
        if self.menuBackground:HasCSSClass("menu_bg_hide") then
            self.menuBackground:SetIsVisible(false)
        end    

    elseif animationName == "MAIN_MENU_MOVE" then
    
        if self.menuBackground:HasCSSClass("menu_bg_show") then

            if self.resumeLink then
                self.resumeLink:SetIsVisible(true)
            end
            if self.readyRoomLink then
                self.readyRoomLink:SetIsVisible(true)
            end
            if self.modsLink then
                self.modsLink:SetIsVisible(true)
            end
            self.playLink:SetIsVisible(true)
            self.tutorialLink:SetIsVisible(true)
            self.optionLink:SetIsVisible(true)
            if self.quitLink then
                self.quitLink:SetIsVisible(true)
            end
            if self.disconnectLink then
                self.disconnectLink:SetIsVisible(true)
            end
        end
        
    elseif animationName == "SHOWWINDOW_UP" then
    
        self.showWindowAnimation:SetCSSClass("showwindow_animation2")
    
    elseif animationName == "SHOWWINDOW_RIGHT" then
    
        self.windowToOpen:SetIsVisible(true)
        self.showWindowAnimation:SetIsVisible(false)
        
    elseif animationName == "SHOWWINDOW_LEFT" then

        self.showWindowAnimation:SetCSSClass("showwindow_animation2_close")
        
    elseif animationName == "SHOWWINDOW_DOWN" then

        self.showWindowAnimation:SetCSSClass("showwindow_hidden")
        self.showWindowAnimation:SetIsVisible(false)
        
    end

end

function GUIMainMenu:OnWindowOpened(window)

    self.openedWindows = self.openedWindows + 1
    
    self.showWindowAnimation:SetCSSClass("showwindow_animation1")
    
end

function GUIMainMenu:OnWindowClosed(window)
    
    self.openedWindows = self.openedWindows - 1
    
    if self.openedWindows <= 0 then
    
        self:ShowMenu()
        self.showWindowAnimation:SetCSSClass("showwindow_animation1_close")
        self.showWindowAnimation:SetIsVisible(true)
        
    end
    
end

function GUIMainMenu:SetupWindow(window, title)

    window:SetCanBeDragged(false)
    window:SetWindowName(title)
    window:AddClass("main_menu_window")
    window:SetInitialVisible(false)
    window:SetIsVisible(false)
    window:DisableResizeTile()
    
    local eventCallbacks =
    {
        OnShow = function(self)
            self.scriptHandle:OnWindowOpened(self)
            MainMenu_OnWindowOpen()
        end,
        
        OnHide = function(self)
            self.scriptHandle:OnWindowClosed(self)
        end
    }
    
    window:AddEventCallbacks(eventCallbacks)
    
end

function GUIMainMenu:OnResolutionChanged(oldX, oldY, newX, newY)

    GUIAnimatedScript.OnResolutionChanged(self, oldX, oldY, newX, newY)

    for _,window in ipairs(self.windows) do
        window:ReloadCSSClass()
    end
    
    // this is a hack. fix reloading of slidebars instead
    if self.generalForm then
        self.generalForm:Uninitialize()
        self.generalForm = CreateGeneralForm(self, self.optionWindow:GetContentBox())
    end    
    
end
