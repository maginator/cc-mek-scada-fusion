-- SCADA HMI (Human Machine Interface) Client
-- Operator Control Interface for Mekanism Fusion Reactor SCADA System

-- Load configuration if available
local config = {}
if fs.exists("scada_config.lua") then
    local success, loaded_config = pcall(dofile, "scada_config.lua")
    if success and loaded_config then
        config = loaded_config
    end
end

-- Auto-detect monitor if configured as "auto"
local function detectMonitor()
    if config.hmi and config.hmi.monitor_side and config.hmi.monitor_side ~= "auto" then
        return config.hmi.monitor_side
    end
    
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "monitor" then
            return side
        end
    end
    return "top"  -- fallback
end

local CONFIG = {
    MONITOR_SIDE = detectMonitor(),
    MODEM_SIDE = "back",
    CHANNELS = config.network and config.network.channels or {
        HMI = 104,
        ALARM = 105
    },
    
    CLIENT_ID = config.components and config.components.hmi_id or "HMI_01",
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
        BUTTON_INACTIVE = colors.gray,
        
        -- Enhanced UI colors
        ACCENT = colors.cyan,
        PANEL_BG = colors.gray,
        PANEL_BORDER = colors.lightGray,
        VALUE_GOOD = colors.lime,
        VALUE_CAUTION = colors.yellow,
        VALUE_DANGER = colors.red,
        SHADOW = colors.black,
        HIGHLIGHT = colors.white
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

function HMI:drawProgressBar(x, y, width, percentage, color, label)
    -- Enhanced progress bar with borders and better styling
    
    -- Border frame
    self.monitor.setBackgroundColor(CONFIG.COLORS.PANEL_BORDER)
    self.monitor.setCursorPos(x-1, y-1)
    self.monitor.write(string.rep(" ", width+2))
    self.monitor.setCursorPos(x-1, y+1)
    self.monitor.write(string.rep(" ", width+2))
    
    -- Side borders
    self.monitor.setCursorPos(x-1, y)
    self.monitor.write(" ")
    self.monitor.setCursorPos(x+width, y)
    self.monitor.write(" ")
    
    -- Background
    self.monitor.setCursorPos(x, y)
    self.monitor.setBackgroundColor(CONFIG.COLORS.INACTIVE)
    self.monitor.write(string.rep(" ", width))
    
    -- Progress fill with gradient effect
    local filled = math.floor((percentage / 100) * width)
    if filled > 0 then
        self.monitor.setCursorPos(x, y)
        self.monitor.setBackgroundColor(color)
        self.monitor.write(string.rep(" ", filled))
        
        -- Add highlight effect
        if filled > 1 then
            self.monitor.setCursorPos(x, y)
            self.monitor.setBackgroundColor(CONFIG.COLORS.HIGHLIGHT)
            self.monitor.write(" ")
        end
    end
    
    -- Percentage text with better positioning
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
    local text = percentage .. "%"
    if label then
        text = label .. ": " .. text
    end
    
    self.monitor.setCursorPos(x + math.floor((width - #text) / 2), y)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write(text)
end

function HMI:drawHeader()
    local w, h = self.monitor.getSize()
    
    -- Enhanced header with gradient effect
    self.monitor.setBackgroundColor(CONFIG.COLORS.HEADER)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.setCursorPos(1, 1)
    self.monitor.write(string.rep(" ", w))
    
    -- Add shadow line
    self.monitor.setBackgroundColor(CONFIG.COLORS.SHADOW)
    self.monitor.setCursorPos(1, 2)
    self.monitor.write(string.rep(" ", w))
    
    -- Title with enhanced styling
    local title = "╔═══ SCADA HMI - MEKANISM FUSION REACTOR ═══╗"
    self.monitor.setCursorPos(math.max(1, math.floor((w - #title) / 2) + 1), 1)
    self.monitor.setBackgroundColor(CONFIG.COLORS.HEADER)
    self.monitor.setTextColor(CONFIG.COLORS.ACCENT)
    self.monitor.write(title)
    
    -- System time
    local time_str = textutils.formatTime(os.time(), false)
    self.monitor.setCursorPos(2, 1)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write(time_str)
    
    -- Connection status with indicator
    local conn_status = self.connected_to_server and "● ONLINE" or "● OFFLINE"
    local conn_color = self.connected_to_server and CONFIG.COLORS.SUCCESS or CONFIG.COLORS.ERROR
    self.monitor.setCursorPos(w - #conn_status - 1, 1)
    self.monitor.setTextColor(conn_color)
    self.monitor.write(conn_status)
    
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
end

function HMI:drawNavigation()
    local w, h = self.monitor.getSize()
    local nav_y = 4
    
    -- Enhanced navigation with better styling
    self.monitor.setCursorPos(1, nav_y)
    self.monitor.setBackgroundColor(CONFIG.COLORS.PANEL_BG)
    self.monitor.write(string.rep(" ", w))
    
    -- Navigation buttons with icons
    local buttons = {
        {name = "⌂ OVERVIEW", screen = CONFIG.SCREENS.OVERVIEW, icon = "⌂"},
        {name = "⚡ REACTOR", screen = CONFIG.SCREENS.REACTOR, icon = "⚡"},
        {name = "⛽ FUEL", screen = CONFIG.SCREENS.FUEL, icon = "⛽"},
        {name = "🔋 ENERGY", screen = CONFIG.SCREENS.ENERGY, icon = "🔋"},
        {name = "🔫 LASER", screen = CONFIG.SCREENS.LASER, icon = "🔫"},
        {name = "⚠ ALARMS", screen = CONFIG.SCREENS.ALARMS, icon = "⚠"}
    }
    
    local x_pos = 2
    self.buttons = {}
    
    for _, button in ipairs(buttons) do
        local is_active = (button.screen == self.current_screen)
        local bg_color = is_active and CONFIG.COLORS.BUTTON_ACTIVE or CONFIG.COLORS.BUTTON_INACTIVE
        local text_color = is_active and CONFIG.COLORS.TEXT or CONFIG.COLORS.INACTIVE
        
        -- Button background with border effect
        self.monitor.setCursorPos(x_pos, nav_y)
        self.monitor.setBackgroundColor(bg_color)
        self.monitor.setTextColor(text_color)
        
        local button_text = " " .. button.name .. " "
        self.monitor.write(button_text)
        
        -- Active indicator
        if is_active then
            self.monitor.setCursorPos(x_pos, nav_y + 1)
            self.monitor.setBackgroundColor(CONFIG.COLORS.ACCENT)
            self.monitor.write(string.rep(" ", #button_text))
        end
        
        -- Store button coordinates for touch handling
        table.insert(self.buttons, {
            x1 = x_pos,
            x2 = x_pos + #button_text - 1,
            y = nav_y,
            action = function() self.current_screen = button.screen end
        })
        
        x_pos = x_pos + #button_text + 1
    end
    
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
end

function HMI:drawPanel(x, y, width, height, title, bg_color)
    bg_color = bg_color or CONFIG.COLORS.PANEL_BG
    
    -- Panel background
    for row = 0, height - 1 do
        self.monitor.setCursorPos(x, y + row)
        self.monitor.setBackgroundColor(bg_color)
        self.monitor.write(string.rep(" ", width))
    end
    
    -- Panel border
    self.monitor.setBackgroundColor(CONFIG.COLORS.PANEL_BORDER)
    -- Top border
    self.monitor.setCursorPos(x, y)
    self.monitor.write(string.rep(" ", width))
    -- Bottom border
    self.monitor.setCursorPos(x, y + height - 1)
    self.monitor.write(string.rep(" ", width))
    -- Side borders
    for row = 1, height - 2 do
        self.monitor.setCursorPos(x, y + row)
        self.monitor.write(" ")
        self.monitor.setCursorPos(x + width - 1, y + row)
        self.monitor.write(" ")
    end
    
    -- Panel title
    if title then
        local title_text = " " .. title .. " "
        self.monitor.setCursorPos(x + math.floor((width - #title_text) / 2), y)
        self.monitor.setBackgroundColor(CONFIG.COLORS.ACCENT)
        self.monitor.setTextColor(CONFIG.COLORS.TEXT)
        self.monitor.write(title_text)
    end
end

function HMI:drawStatusIndicator(x, y, status, label)
    local status_char = "●"
    local color = CONFIG.COLORS.INACTIVE
    
    if status == "RUNNING" or status == "ONLINE" or status == "ACTIVE" then
        color = CONFIG.COLORS.VALUE_GOOD
    elseif status == "HEATING" or status == "WARNING" or status == "STANDBY" then
        color = CONFIG.COLORS.VALUE_CAUTION
    elseif status == "ERROR" or status == "OFFLINE" or status == "CRITICAL" then
        color = CONFIG.COLORS.VALUE_DANGER
    end
    
    self.monitor.setCursorPos(x, y)
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
    self.monitor.setTextColor(color)
    self.monitor.write(status_char)
    
    if label then
        self.monitor.setTextColor(CONFIG.COLORS.TEXT)
        self.monitor.write(" " .. label)
    end
end

function HMI:drawOverviewScreen()
    local w, h = self.monitor.getSize()
    
    -- Enhanced layout with panels
    
    -- Main status panel
    self:drawPanel(2, 6, 30, 8, "REACTOR STATUS")
    
    local reactor_status = self.data.reactor.status or "UNKNOWN"
    self:drawStatusIndicator(4, 8, reactor_status, "Reactor: " .. reactor_status)
    
    -- Temperature with enhanced display
    local temp = self.data.reactor.temperature or 0
    local maxTemp = self.data.reactor.maxTemperature or 100000000
    local tempPercent = self:getPercentage(temp, maxTemp)
    local tempColor = CONFIG.COLORS.VALUE_GOOD
    if tempPercent > 80 then
        tempColor = CONFIG.COLORS.VALUE_DANGER
    elseif tempPercent > 60 then
        tempColor = CONFIG.COLORS.VALUE_CAUTION
    end
    
    self.monitor.setCursorPos(4, 10)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write("🌡 Temperature: " .. self:formatNumber(temp) .. "K")
    self:drawProgressBar(4, 11, 26, tempPercent, tempColor, "TEMP")
    
    -- Energy panel
    self:drawPanel(34, 6, 26, 8, "ENERGY STORAGE")
    
    local energyPercent = self.data.energy.percentage or 0
    local energy_current = self.data.energy.current or 0
    local energy_max = self.data.energy.max or 1
    
    self.monitor.setCursorPos(36, 8)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write("🔋 Storage: " .. math.floor(energyPercent) .. "%")
    
    self.monitor.setCursorPos(36, 9)
    self.monitor.write(self:formatNumber(energy_current) .. "/" .. self:formatNumber(energy_max) .. " FE")
    self:drawProgressBar(36, 11, 22, energyPercent, CONFIG.COLORS.VALUE_GOOD, "PWR")
    
    -- Fuel panel
    self:drawPanel(2, 15, 28, 7, "FUEL LEVELS")
    
    local deuterium = self.data.fuel.deuterium or 0
    local maxDeuterium = self.data.fuel.maxDeuterium or 1000
    local deutPercent = self:getPercentage(deuterium, maxDeuterium)
    
    local tritium = self.data.fuel.tritium or 0
    local maxTritium = self.data.fuel.maxTritium or 1000
    local tritPercent = self:getPercentage(tritium, maxTritium)
    
    self.monitor.setCursorPos(4, 17)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write("⚒ Deuterium: " .. math.floor(deutPercent) .. "%")
    self:drawProgressBar(4, 18, 24, deutPercent, CONFIG.COLORS.VALUE_GOOD)
    
    self.monitor.setCursorPos(4, 19)
    self.monitor.write("☢ Tritium: " .. math.floor(tritPercent) .. "%")
    self:drawProgressBar(4, 20, 24, tritPercent, CONFIG.COLORS.VALUE_GOOD)
    
    -- Alarms panel
    self:drawPanel(32, 15, 28, 7, "SYSTEM ALERTS")
    
    local alarm_count = #self.data.alarms
    self.monitor.setCursorPos(34, 17)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    
    if alarm_count == 0 then
        self:drawStatusIndicator(34, 17, "ONLINE", "All Systems Normal")
    else
        self:drawStatusIndicator(34, 17, "WARNING", alarm_count .. " Active Alarms")
        
        local alarm_y = 18
        for i, alarm in ipairs(self.data.alarms) do
            if i > 3 then break end
            
            local color = CONFIG.COLORS.VALUE_CAUTION
            if alarm.severity == "CRITICAL" then
                color = CONFIG.COLORS.VALUE_DANGER
            end
            
            self.monitor.setCursorPos(36, alarm_y)
            self.monitor.setTextColor(color)
            self.monitor.write("⚠ " .. (alarm.id or "Unknown"))
            alarm_y = alarm_y + 1
        end
    end
    
    -- Control buttons
    self:drawControlButtons()
end

function HMI:drawButton(x, y, width, text, bg_color, text_color, action)
    -- Enhanced button with 3D effect
    text_color = text_color or CONFIG.COLORS.TEXT
    
    -- Button shadow
    self.monitor.setCursorPos(x + 1, y + 1)
    self.monitor.setBackgroundColor(CONFIG.COLORS.SHADOW)
    self.monitor.write(string.rep(" ", width))
    
    -- Button background
    self.monitor.setCursorPos(x, y)
    self.monitor.setBackgroundColor(bg_color)
    self.monitor.write(string.rep(" ", width))
    
    -- Button highlight
    self.monitor.setCursorPos(x, y)
    self.monitor.setBackgroundColor(CONFIG.COLORS.HIGHLIGHT)
    self.monitor.write(" ")
    
    -- Button text
    local text_x = x + math.floor((width - #text) / 2)
    self.monitor.setCursorPos(text_x, y)
    self.monitor.setBackgroundColor(bg_color)
    self.monitor.setTextColor(text_color)
    self.monitor.write(text)
    
    -- Store button for touch handling
    if action then
        table.insert(self.buttons, {
            x1 = x, x2 = x + width - 1, y = y,
            action = action
        })
    end
end

function HMI:drawControlButtons()
    local w, h = self.monitor.getSize()
    
    -- Control panel background
    self:drawPanel(2, h-8, w-2, 7, "REACTOR CONTROLS")
    
    -- Emergency SCRAM button (prominent)
    self:drawButton(4, h-6, 18, "⚠ EMERGENCY SCRAM", CONFIG.COLORS.ERROR, CONFIG.COLORS.TEXT, 
        function() self:sendCommand("reactor_scram") end)
    
    -- Reactor control buttons
    local reactor_running = (self.data.reactor.status == "RUNNING")
    
    if not reactor_running then
        self:drawButton(4, h-4, 14, "▶ START REACTOR", CONFIG.COLORS.SUCCESS, CONFIG.COLORS.TEXT,
            function() self:sendCommand("reactor_start") end)
    else
        self:drawButton(4, h-4, 14, "■ STOP REACTOR", CONFIG.COLORS.WARNING, CONFIG.COLORS.TEXT,
            function() self:sendCommand("reactor_stop") end)
    end
    
    -- Laser control buttons
    local laser_active = (self.data.laser.status == "ACTIVE")
    
    if not laser_active then
        self:drawButton(20, h-4, 12, "🔫 LASER ON", CONFIG.COLORS.BUTTON_ACTIVE, CONFIG.COLORS.TEXT,
            function() self:sendCommand("laser_activate") end)
    else
        self:drawButton(20, h-4, 12, "🔫 LASER OFF", CONFIG.COLORS.BUTTON_INACTIVE, CONFIG.COLORS.TEXT,
            function() self:sendCommand("laser_deactivate") end)
    end
    
    -- Additional controls
    self:drawButton(34, h-4, 12, "🔄 REFRESH", CONFIG.COLORS.BUTTON_INACTIVE, CONFIG.COLORS.TEXT,
        function() self:requestData() end)
    
    self:drawButton(48, h-4, 10, "⚙ CONFIG", CONFIG.COLORS.BUTTON_INACTIVE, CONFIG.COLORS.TEXT,
        function() 
            -- Launch configurator
            shell.run("configurator")
        end)
    
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
end

-- Additional screen implementations
function HMI:drawReactorScreen()
    local w, h = self.monitor.getSize()
    
    -- Reactor details panel
    self:drawPanel(2, 6, w-2, h-12, "REACTOR DETAILS")
    
    local temp = self.data.reactor.temperature or 0
    local maxTemp = self.data.reactor.maxTemperature or 100000000
    local tempPercent = self:getPercentage(temp, maxTemp)
    
    self.monitor.setCursorPos(4, 8)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write("🌡 Core Temperature: " .. self:formatNumber(temp) .. "K / " .. self:formatNumber(maxTemp) .. "K")
    self:drawProgressBar(4, 9, w-6, tempPercent, 
        tempPercent > 80 and CONFIG.COLORS.VALUE_DANGER or 
        tempPercent > 60 and CONFIG.COLORS.VALUE_CAUTION or CONFIG.COLORS.VALUE_GOOD)
    
    -- Plasma temperature
    local plasmaTemp = self.data.reactor.plasmaTemperature or 0
    self.monitor.setCursorPos(4, 11)
    self.monitor.write("⚡ Plasma Temperature: " .. self:formatNumber(plasmaTemp) .. "K")
    
    -- Injection rate
    local injectionRate = self.data.reactor.injectionRate or 0
    self.monitor.setCursorPos(4, 13)
    self.monitor.write("💉 Injection Rate: " .. injectionRate .. " mB/t")
    
    -- Production rate
    local productionRate = self.data.reactor.productionRate or 0
    self.monitor.setCursorPos(4, 15)
    self.monitor.write("⚡ Energy Production: " .. self:formatNumber(productionRate) .. " FE/t")
    
    self:drawControlButtons()
end

function HMI:drawFuelScreen()
    local w, h = self.monitor.getSize()
    
    -- Fuel status panel
    self:drawPanel(2, 6, w-2, h-12, "FUEL SYSTEM STATUS")
    
    -- Deuterium
    local deuterium = self.data.fuel.deuterium or 0
    local maxDeuterium = self.data.fuel.maxDeuterium or 1000
    local deutPercent = self:getPercentage(deuterium, maxDeuterium)
    
    self.monitor.setCursorPos(4, 8)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write("⚛ Deuterium Tank: " .. self:formatNumber(deuterium) .. " / " .. self:formatNumber(maxDeuterium) .. " mB")
    self:drawProgressBar(4, 9, w-6, deutPercent, CONFIG.COLORS.VALUE_GOOD)
    
    -- Tritium
    local tritium = self.data.fuel.tritium or 0
    local maxTritium = self.data.fuel.maxTritium or 1000
    local tritPercent = self:getPercentage(tritium, maxTritium)
    
    self.monitor.setCursorPos(4, 11)
    self.monitor.write("☢ Tritium Tank: " .. self:formatNumber(tritium) .. " / " .. self:formatNumber(maxTritium) .. " mB")
    self:drawProgressBar(4, 12, w-6, tritPercent, CONFIG.COLORS.VALUE_GOOD)
    
    -- Fuel consumption
    local fuelConsumption = self.data.fuel.consumptionRate or 0
    self.monitor.setCursorPos(4, 14)
    self.monitor.write("🔥 Fuel Consumption: " .. fuelConsumption .. " mB/t")
    
    self:drawControlButtons()
end

function HMI:drawEnergyScreen()
    local w, h = self.monitor.getSize()
    
    -- Energy system panel
    self:drawPanel(2, 6, w-2, h-12, "ENERGY STORAGE SYSTEM")
    
    local energyPercent = self.data.energy.percentage or 0
    local energy_current = self.data.energy.current or 0
    local energy_max = self.data.energy.max or 1
    local energy_input = self.data.energy.input or 0
    local energy_output = self.data.energy.output or 0
    
    self.monitor.setCursorPos(4, 8)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write("🔋 Energy Storage: " .. self:formatNumber(energy_current) .. " / " .. self:formatNumber(energy_max) .. " FE")
    self:drawProgressBar(4, 9, w-6, energyPercent, CONFIG.COLORS.VALUE_GOOD)
    
    self.monitor.setCursorPos(4, 11)
    self.monitor.write("📈 Input Rate: " .. self:formatNumber(energy_input) .. " FE/t")
    
    self.monitor.setCursorPos(4, 12)
    self.monitor.write("📉 Output Rate: " .. self:formatNumber(energy_output) .. " FE/t")
    
    local net_rate = energy_input - energy_output
    self.monitor.setCursorPos(4, 14)
    self.monitor.setTextColor(net_rate >= 0 and CONFIG.COLORS.VALUE_GOOD or CONFIG.COLORS.VALUE_CAUTION)
    self.monitor.write("💹 Net Rate: " .. (net_rate >= 0 and "+" or "") .. self:formatNumber(net_rate) .. " FE/t")
    
    self:drawControlButtons()
end

function HMI:drawLaserScreen()
    local w, h = self.monitor.getSize()
    
    -- Laser system panel
    self:drawPanel(2, 6, w-2, h-12, "LASER AMPLIFICATION SYSTEM")
    
    local laser_energy = self.data.laser.energy or 0
    local laser_max = self.data.laser.maxEnergy or 1000000000
    local laser_percent = self:getPercentage(laser_energy, laser_max)
    
    self.monitor.setCursorPos(4, 8)
    self.monitor.setTextColor(CONFIG.COLORS.TEXT)
    self.monitor.write("🔫 Laser Energy: " .. self:formatNumber(laser_energy) .. " / " .. self:formatNumber(laser_max) .. " J")
    self:drawProgressBar(4, 9, w-6, laser_percent, CONFIG.COLORS.VALUE_GOOD)
    
    local laser_status = self.data.laser.status or "OFFLINE"
    self:drawStatusIndicator(4, 11, laser_status, "Laser Status: " .. laser_status)
    
    -- Laser array status
    local laser_count = self.data.laser.count or 0
    self.monitor.setCursorPos(4, 13)
    self.monitor.write("🔧 Active Lasers: " .. laser_count)
    
    self:drawControlButtons()
end

function HMI:drawAlarmsScreen()
    local w, h = self.monitor.getSize()
    
    -- Alarms panel
    self:drawPanel(2, 6, w-2, h-12, "SYSTEM ALARMS & ALERTS")
    
    local alarms = self.data.alarms or {}
    
    if #alarms == 0 then
        self.monitor.setCursorPos(4, 8)
        self:drawStatusIndicator(4, 8, "ONLINE", "All Systems Operating Normally")
    else
        local y_pos = 8
        for i, alarm in ipairs(alarms) do
            if y_pos > h - 8 then break end
            
            local color = CONFIG.COLORS.VALUE_CAUTION
            local icon = "⚠"
            
            if alarm.severity == "CRITICAL" then
                color = CONFIG.COLORS.VALUE_DANGER
                icon = "🚨"
            elseif alarm.severity == "ERROR" then
                color = CONFIG.COLORS.VALUE_DANGER
                icon = "❌"
            end
            
            self.monitor.setCursorPos(4, y_pos)
            self.monitor.setTextColor(color)
            self.monitor.write(icon .. " " .. (alarm.id or "Unknown Alarm"))
            
            if alarm.message then
                self.monitor.setCursorPos(6, y_pos + 1)
                self.monitor.setTextColor(CONFIG.COLORS.TEXT)
                self.monitor.write(alarm.message)
                y_pos = y_pos + 2
            else
                y_pos = y_pos + 1
            end
        end
    end
    
    self:drawControlButtons()
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
    
    -- Draw screen-specific content
    self.monitor.setBackgroundColor(CONFIG.COLORS.BG)
    
    if self.current_screen == CONFIG.SCREENS.OVERVIEW then
        self:drawOverviewScreen()
    elseif self.current_screen == CONFIG.SCREENS.REACTOR then
        self:drawReactorScreen()
    elseif self.current_screen == CONFIG.SCREENS.FUEL then
        self:drawFuelScreen()
    elseif self.current_screen == CONFIG.SCREENS.ENERGY then
        self:drawEnergyScreen()
    elseif self.current_screen == CONFIG.SCREENS.LASER then
        self:drawLaserScreen()
    elseif self.current_screen == CONFIG.SCREENS.ALARMS then
        self:drawAlarmsScreen()
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