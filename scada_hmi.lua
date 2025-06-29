-- SCADA HMI (Human Machine Interface) Client
-- Operator Control Interface for Mekanism Fusion Reactor SCADA System

local CONFIG = {
    MONITOR_SIDE = "top",
    MODEM_SIDE = "back",
    CHANNELS = {
        HMI = 104,
        ALARM = 105
    },
    
    CLIENT_ID = "HMI_01",
    UPDATE_INTERVAL = 0.5,
    
    COLORS = {
        BG = colors.black,
        TEXT = colors.white,
        HEADER = colors.lightBlue,
        SUCCESS = colors.green,
        WARNING = colors.orange,
        ERROR = colors.red,
        CRITICAL = colors.purple,
        INACTIVE = colors.gray,
        BUTTON_ACTIVE = colors.blue,
        BUTTON_INACTIVE = colors.gray
    },
    
    SCREENS = {
        OVERVIEW = "overview",
        REACTOR = "reactor", 
        FUEL = "fuel",
        ENERGY = "energy",
        LASER = "laser",
        ALARMS = "alarms",
        TRENDS = "trends"
    }
}

local HMI = {
    monitor = nil,
    modem = nil,
    running = true,
    current_screen = CONFIG.SCREENS.OVERVIEW,
    
    -- Data from SCADA server
    data = {
        reactor = {},
        fuel = {},
        energy = {},
        laser = {},
        system = {},
        alarms = {},
        rtu_status = {}
    },
    
    -- Screen navigation
    buttons = {},
    touch_areas = {},
    
    -- Status flags
    connected_to_server = false,
    last_server_update = 0,
    pending_commands = {}
}

function HMI:init()
    self.monitor = peripheral.wrap(CONFIG.MONITOR_SIDE)
    if not self.monitor then
        error("No monitor found on side: " .. CONFIG.MONITOR_SIDE)
    end
    
    self.modem = peripheral.wrap(CONFIG.MODEM_SIDE)
    if not self.modem then
        error("No modem found on side: " .. CONFIG.MODEM_SIDE)
    end
    
    -- Open communication channels
    self.modem.open(CONFIG.CHANNELS.HMI)
    self.modem.open(CONFIG.CHANNELS.ALARM)
    
    -- Configure monitor
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.clear()
    self.monitor.setTextScale(0.5)
    
    -- Register with SCADA server
    self:registerWithServer()
    
    print("HMI Client initialized: " .. CONFIG.CLIENT_ID)
end

function HMI:registerWithServer()
    self.modem.transmit(CONFIG.CHANNELS.HMI, CONFIG.CHANNELS.HMI, {
        type = "hmi_register",
        client_id = CONFIG.CLIENT_ID,
        timestamp = os.epoch("utc")
    })
    print("Registration request sent to SCADA server")
end

function HMI:sendCommand(command, data)
    local command_packet = {
        type = "command_request",
        client_id = CONFIG.CLIENT_ID,
        command = command,
        data = data or {},
        timestamp = os.epoch("utc")
    }
    
    self.modem.transmit(CONFIG.CHANNELS.HMI, CONFIG.CHANNELS.HMI, command_packet)
    
    table.insert(self.pending_commands, {
        command = command,
        timestamp = os.epoch("utc")
    })
    
    print("Command sent: " .. command)
end

function HMI:requestData(data_type)
    self.modem.transmit(CONFIG.CHANNELS.HMI, CONFIG.CHANNELS.HMI, {
        type = "data_request",
        client_id = CONFIG.CLIENT_ID,
        data_type = data_type or "all",
        timestamp = os.epoch("utc")
    })
end

function HMI:processMessage(channel, message)
    if not message or not message.type then return end
    
    if channel == CONFIG.CHANNELS.HMI then
        if message.type == "realtime_update" then
            self.data = message.data
            self.connected_to_server = true
            self.last_server_update = os.epoch("utc")
            
        elseif message.type == "data_response" and message.client_id == CONFIG.CLIENT_ID then
            self.data = message.data
            self.connected_to_server = true
            
        elseif message.type == "command_response" and message.client_id == CONFIG.CLIENT_ID then
            -- Handle command responses
            for i, pending in ipairs(self.pending_commands) do
                if pending.command == message.command then
                    table.remove(self.pending_commands, i)
                    break
                end
            end
            
            if message.result.success then
                print("Command successful: " .. message.command)
            else
                print("Command failed: " .. message.command .. " - " .. message.result.message)
            end
        end
        
    elseif channel == CONFIG.CHANNELS.ALARM then
        if message.type == "alarm_update" then
            self.data.alarms = message.alarms
        end
    end
end

-- Utility functions
function HMI:formatNumber(num)
    if num >= 1000000000 then
        return string.format("%.2fG", num / 1000000000)
    elseif num >= 1000000 then
        return string.format("%.2fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.2fK", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

function HMI:getPercentage(current, max)
    if max == 0 then return 0 end
    return math.floor((current / max) * 100)
end

function HMI:drawProgressBar(x, y, width, percentage, color)
    self.monitor.setCursorPos(x, y)
    self.monitor.setBackgroundColor(CONFIG.COLORS.INACTIVE)
    self.monitor.write(string.rep(" ", width))
    
    local filled = math.floor((percentage / 100) * width)
    if filled > 0 then
        self.monitor.setCursorPos(x, y)
        self.monitor.setBackgroundColor(color)
        self.monitor.write(string.rep(" ", filled))
    end
    
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
    self.monitor.setCursorPos(x + math.floor(width/2) - 1, y)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write(percentage .. "%")
end

function HMI:drawHeader()
    local w, h = self.monitor.getSize()
    
    -- Header background
    self.monitor.setBackgroundColor(CONFIG.COLORS.HEADER)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.setCursorPos(1, 1)
    self.monitor.write(string.rep(" ", w))
    
    -- Title
    local title = "SCADA HMI - MEKANISM FUSION REACTOR SYSTEM"
    self.monitor.setCursorPos(math.floor((w - #title) / 2) + 1, 1)
    self.monitor.write(title)
    
    -- Connection status
    local conn_status = self.connected_to_server and "CONNECTED" or "DISCONNECTED"
    local conn_color = self.connected_to_server and CONFIG.COLORS.SUCCESS or CONFIG.COLORS.ERROR
    self.monitor.setCursorPos(w - #conn_status - 1, 1)
    self.monitor.setTextColor(conn_color)
    self.monitor.write(conn_status)
    
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
end

function HMI:drawNavigation()
    local w, h = self.monitor.getSize()
    local nav_y = 3
    
    -- Clear navigation area
    self.monitor.setCursorPos(1, nav_y)
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
    self.monitor.write(string.rep(" ", w))
    
    -- Navigation buttons
    local buttons = {
        {name = "OVERVIEW", screen = CONFIG.SCREENS.OVERVIEW},
        {name = "REACTOR", screen = CONFIG.SCREENS.REACTOR},
        {name = "FUEL", screen = CONFIG.SCREENS.FUEL},
        {name = "ENERGY", screen = CONFIG.SCREENS.ENERGY},
        {name = "LASER", screen = CONFIG.SCREENS.LASER},
        {name = "ALARMS", screen = CONFIG.SCREENS.ALARMS}
    }
    
    local x_pos = 2
    self.buttons = {}
    
    for _, button in ipairs(buttons) do
        local color = (button.screen == self.current_screen) and CONFIG.COLORS.BUTTON_ACTIVE or CONFIG.COLORS.BUTTON_INACTIVE
        
        self.monitor.setCursorPos(x_pos, nav_y)
        self.monitor.setBackgroundColor(color)
        self.monitor.setTextColor(CONFIG.COLORS.TEXT)
        self.monitor.write(" " .. button.name .. " ")
        
        -- Store button coordinates for touch handling
        table.insert(self.buttons, {
            x1 = x_pos,
            x2 = x_pos + #button.name + 1,
            y = nav_y,
            action = function() self.current_screen = button.screen end
        })
        
        x_pos = x_pos + #button.name + 3
    end
    
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
end

function HMI:drawOverviewScreen()
    local w, h = self.monitor.getSize()
    
    -- System status overview
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.setCursorPos(2, 5)
    self.monitor.write("SYSTEM OVERVIEW")
    
    -- Reactor status
    local reactor_status = self.data.reactor.status or "UNKNOWN"
    local status_color = CONFIG.COLORS.INACTIVE
    if reactor_status == "RUNNING" then
        status_color = CONFIG.COLORS.SUCCESS
    elseif reactor_status == "HEATING" then
        status_color = CONFIG.COLORS.WARNING
    elseif reactor_status == "ERROR" then
        status_color = CONFIG.COLORS.ERROR
    end
    
    self.monitor.setCursorPos(2, 7)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write("Reactor Status:")
    self.monitor.setCursorPos(18, 7)
    self.monitor.setTextColor(status_color)
    self.monitor.write(reactor_status)
    
    -- Temperature
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.setCursorPos(2, 8)
    local temp = self.data.reactor.temperature or 0
    local maxTemp = self.data.reactor.maxTemperature or 100000000
    self.monitor.write("Temperature: " .. self:formatNumber(temp) .. "K")
    
    local tempPercent = self:getPercentage(temp, maxTemp)
    local tempColor = CONFIG.COLORS.SUCCESS
    if tempPercent > 80 then
        tempColor = CONFIG.COLORS.CRITICAL
    elseif tempPercent > 60 then
        tempColor = CONFIG.COLORS.WARNING
    end
    self:drawProgressBar(2, 9, 30, tempPercent, tempColor)
    
    -- Energy
    self.monitor.setCursorPos(35, 7)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    local energyPercent = self.data.energy.percentage or 0
    self.monitor.write("Energy Storage: " .. math.floor(energyPercent) .. "%")
    self:drawProgressBar(35, 8, 25, energyPercent, CONFIG.COLORS.SUCCESS)
    
    -- Fuel levels
    self.monitor.setCursorPos(2, 11)
    self.monitor.write("Fuel Levels:")
    
    local deuterium = self.data.fuel.deuterium or 0
    local maxDeuterium = self.data.fuel.maxDeuterium or 1000
    local deutPercent = self:getPercentage(deuterium, maxDeuterium)
    
    self.monitor.setCursorPos(2, 12)
    self.monitor.write("Deuterium: " .. math.floor(deutPercent) .. "%")
    self:drawProgressBar(2, 13, 20, deutPercent, CONFIG.COLORS.SUCCESS)
    
    -- Alarms summary
    self.monitor.setCursorPos(35, 11)
    self.monitor.write("Active Alarms: " .. #self.data.alarms)
    
    if #self.data.alarms > 0 then
        local alarm_y = 12
        for i, alarm in ipairs(self.data.alarms) do
            if i > 3 then break end -- Show only first 3 alarms
            
            local color = CONFIG.COLORS.WARNING
            if alarm.severity == "CRITICAL" then
                color = CONFIG.COLORS.CRITICAL
            elseif alarm.severity == "ERROR" then
                color = CONFIG.COLORS.ERROR
            end
            
            self.monitor.setCursorPos(35, alarm_y)
            self.monitor.setTextColor(color)
            self.monitor.write(alarm.id)
            alarm_y = alarm_y + 1
        end
    end
    
    -- Control buttons
    self:drawControlButtons()
end

function HMI:drawControlButtons()
    local w, h = self.monitor.getSize()
    
    -- Emergency SCRAM button
    self.monitor.setBackgroundColor(CONFIG.COLORS.ERROR)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.setCursorPos(2, h-5)
    self.monitor.write(" EMERGENCY SCRAM ")
    
    table.insert(self.buttons, {
        x1 = 2, x2 = 18, y = h-5,
        action = function() self:sendCommand("reactor_scram") end
    })
    
    -- Reactor control buttons
    self.monitor.setBackgroundColor(CONFIG.COLORS.SUCCESS)
    self.monitor.setCursorPos(2, h-3)
    self.monitor.write(" START REACTOR ")
    
    table.insert(self.buttons, {
        x1 = 2, x2 = 16, y = h-3,
        action = function() self:sendCommand("reactor_start") end
    })
    
    self.monitor.setBackgroundColor(CONFIG.COLORS.WARNING)
    self.monitor.setCursorPos(18, h-3)
    self.monitor.write(" STOP REACTOR ")
    
    table.insert(self.buttons, {
        x1 = 18, x2 = 31, y = h-3,
        action = function() self:sendCommand("reactor_stop") end
    })
    
    -- Laser control
    self.monitor.setBackgroundColor(CONFIG.COLORS.BUTTON_ACTIVE)
    self.monitor.setCursorPos(35, h-3)
    self.monitor.write(" LASER ON ")
    
    table.insert(self.buttons, {
        x1 = 35, x2 = 45, y = h-3,
        action = function() self:sendCommand("laser_activate") end
    })
    
    self.monitor.setCursorPos(47, h-3)
    self.monitor.write(" LASER OFF ")
    
    table.insert(self.buttons, {
        x1 = 47, x2 = 58, y = h-3,
        action = function() self:sendCommand("laser_deactivate") end
    })
    
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
end

function HMI:handleTouch(x, y)
    for _, button in ipairs(self.buttons) do
        if x >= button.x1 and x <= button.x2 and y == button.y then
            if button.action then
                button.action()
                return true
            end
        end
    end
    return false
end

function HMI:render()
    self.monitor.clear()
    self.buttons = {}
    
    self:drawHeader()
    self:drawNavigation()
    
    if self.current_screen == CONFIG.SCREENS.OVERVIEW then
        self:drawOverviewScreen()
    end
    
    -- Connection timeout check
    local current_time = os.epoch("utc")
    if self.connected_to_server and (current_time - self.last_server_update) > 5000 then
        self.connected_to_server = false
    end
end

function HMI:run()
    self:init()
    
    local updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
    
    while self.running do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        if event == "timer" and p1 == updateTimer then
            self:requestData()
            self:render()
            updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
            
        elseif event == "monitor_touch" and p1 == CONFIG.MONITOR_SIDE then
            self:handleTouch(p2, p3)
            
        elseif event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            self:processMessage(channel, message)
            
        elseif event == "key" and p1 == keys.q then
            self.running = false
        end
    end
    
    self.modem.closeAll()
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
    self.monitor.write("HMI Client shutdown")
end

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(HMI.run, HMI)
    if not success then
        print("HMI Error: " .. error)
        if HMI.monitor then
            HMI.monitor.clear()
            HMI.monitor.setCursorPos(1, 1)
            HMI.monitor.setTextColor(CONFIG.COLORS.ERROR)
            HMI.monitor.write("HMI ERROR: " .. error)
        end
    end
end

print("=== MEKANISM FUSION REACTOR SCADA HMI ===")
print("Starting Human Machine Interface...")
print("Press 'q' to shutdown")

safeRun()