class 'SharpshooterClient'

function SharpshooterClient:__init()
    self:RegisterEvents()
end

function SharpshooterClient:RegisterEvents()
    Events:Subscribe('Extension:Loaded', self, self.WebUIInit)
    Events:Subscribe('WebUIEvent', self, self.RecivedWebEvent)
    NetEvents:Subscribe('TimerUpdate', self, self.TimerUpdate)
end


function SharpshooterClient:WebUIInit()
    WebUI:Init()
    WebUI:Hide()
end

function SharpshooterClient:TimerUpdate(Time)
    Execute = 'setTimer("Time till next weapon: '..45-Time..'");'
    WebUI:ExecuteJS(Execute)
    WebUI:Show()
end

g_SharpshooterClient = SharpshooterClient()