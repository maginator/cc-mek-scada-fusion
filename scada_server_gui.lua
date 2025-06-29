-- SCADA Server with GUI Interface
-- Enhanced version with graphical interface and robust error handling

-- Load GUI library if available
local GUI = nil
if fs.exists("scada_gui.lua") then
    local success, gui_lib = pcall(dofile, "scada_gui.lua")
    if success then
        GUI = gui_lib
    end
end

-- Load configuration if available
local config = {}
if fs.exists("/scada/config.lua") then
    local success, loaded_config = pcall(dofile, "/scada/config.lua")
    if success and loaded_config then
        config = loaded_config
    end
elseif fs.exists("scada_config.lua") then
    local success, loaded_config = pcall(dofile, "scada_config.lua")
    if success and loaded_config then
        config = loaded_config
    end
end

local CONFIG = {
    MODEM_SIDE = "back",
    CHANNELS = config.network and config.network.channels or {
        REACTOR = 100,
        FUEL = 101,
        ENERGY = 102,
        LASER = 103,
        HMI = 104,
        ALARM = 105
    },
    
    SERVER_ID = config.components and config.components.server_id or "SCADA_SERVER_01",
    
    UPDATE_INTERVALS = {
        DATA_COLLECTION = 1,
        HMI_UPDATE = 0.5,
        HISTORIAN = 5,
        ALARM_CHECK = 0.5,
        GUI_REFRESH = 0.5
    },
    
    ALARM_THRESHOLDS = {
        REACTOR_TEMP_WARNING = 80000000,
        REACTOR_TEMP_CRITICAL = 95000000,
        ENERGY_LOW = 10,
        FUEL_LOW = 15,
        LASER_OFFLINE_TIME = 30
    }
}

local ScadaServer = {
    modem = nil,
    running = true,
    last_update = 0,
    
    -- Data storage
    rtu_data = {},
    hmi_clients = {},
    alarms = {},
    
    -- GUI components
    gui = nil,
    monitor = nil,
    has_gui = false,
    errors = {},
    
    -- Status tracking
    status = {
        modem_connected = false,
        rtus_connected = 0,
        hmi_connected = 0,
        data_points = 0,
        uptime = 0,
        last_error = nil
    }
}

function ScadaServer:addError(message, critical)
    critical = critical or false
    local error_entry = {
        time = os.date("%H:%M:%S"),
        message = message,
        critical = critical
    }
    
    table.insert(self.errors, 1, error_entry) -- Add to front
    
    -- Keep only last 10 errors
    if #self.errors > 10 then
        table.remove(self.errors)
    end
    
    self.status.last_error = message
    
    print("[" .. error_entry.time .. "] " .. (critical and "CRITICAL: " or "ERROR: ") .. message)
    
    -- Don't crash on errors, just log them
    if not critical then
        return
    end
end

function ScadaServer:initializeGUI()
    -- Try to find monitor
    local monitor = peripheral.find("monitor")
    if not monitor then
        self:addError("No monitor found - running in text mode")
        return false
    end
    
    if not GUI then
        self:addError("GUI library not available - running in text mode")
        return false
    end
    
    -- Initialize GUI
    local success, error = pcall(function()
        self.monitor = monitor
        self.gui = GUI:init(monitor)
        self.has_gui = true
        
        -- Set appropriate text scale
        local w, h = monitor.getSize()
        if w > 100 then
            monitor.setTextScale(0.5)
        end
        
        self:createGUIComponents()
    end)
    
    if not success then
        self:addError("Failed to initialize GUI: " .. error)
        return false
    end
    
    return true
end

function ScadaServer:createGUIComponents()
    if not self.has_gui then return end
    
    local w, h = self.monitor.getSize()
    
    -- Main status panel
    self.status_panel = self.gui:createPanel(1, 1, w, 8, "SCADA SERVER STATUS")
    self.status_panel.background = self.gui.COLORS.BG_DARK
    self.status_panel.border_color = self.gui.COLORS.PRIMARY
    
    -- RTU data panel
    local panel_height = math.floor((h - 10) / 2)
    self.rtu_panel = self.gui:createPanel(1, 9, math.floor(w/2), panel_height, "RTU DATA")
    self.rtu_panel.background = self.gui.COLORS.BG_DARK
    self.rtu_panel.border_color = self.gui.COLORS.SUCCESS
    
    -- Alarms panel
    self.alarm_panel = self.gui:createPanel(math.floor(w/2) + 1, 9, math.ceil(w/2), panel_height, "ALARMS")
    self.alarm_panel.background = self.gui.COLORS.BG_DARK
    self.alarm_panel.border_color = self.gui.COLORS.ERROR
    
    -- Errors panel
    self.error_panel = self.gui:createPanel(1, 9 + panel_height, w, h - 8 - panel_height, "SYSTEM ERRORS")
    self.error_panel.background = self.gui.COLORS.BG_DARK
    self.error_panel.border_color = self.gui.COLORS.WARNING
end

function ScadaServer:updateGUI()
    if not self.has_gui then return end
    
    local success, error = pcall(function()
        self.gui:render()
        
        -- Update status panel
        local x, y = self.status_panel.x + 2, self.status_panel.y + 2
        
        self.gui:drawText(x, y, "Server ID: " .. CONFIG.SERVER_ID, self.gui.COLORS.TEXT_PRIMARY)
        y = y + 1
        self.gui:drawText(x, y, "Uptime: " .. math.floor(self.status.uptime) .. "s", self.gui.COLORS.TEXT_PRIMARY)
        y = y + 1
        
        local modem_status = self.status.modem_connected and "[+] Connected" or "[-] Disconnected"
        local modem_color = self.status.modem_connected and self.gui.COLORS.SUCCESS or self.gui.COLORS.ERROR
        self.gui:drawText(x, y, "Modem: " .. modem_status, modem_color)
        y = y + 1
        
        self.gui:drawText(x, y, "RTUs: " .. self.status.rtus_connected, self.gui.COLORS.TEXT_PRIMARY)
        y = y + 1
        self.gui:drawText(x, y, "HMI Clients: " .. self.status.hmi_connected, self.gui.COLORS.TEXT_PRIMARY)
        y = y + 1
        self.gui:drawText(x, y, "Data Points: " .. self.status.data_points, self.gui.COLORS.TEXT_PRIMARY)
        
        -- Update RTU panel
        x, y = self.rtu_panel.x + 2, self.rtu_panel.y + 2
        local rtu_count = 0
        for rtu_id, data in pairs(self.rtu_data) do
            if y < self.rtu_panel.y + self.rtu_panel.height - 2 then
                local age = os.clock() - (data.last_update or 0)
                local status_text = age < 5 and "[+] Online" or "[-] Offline"
                local status_color = age < 5 and self.gui.COLORS.SUCCESS or self.gui.COLORS.ERROR
                
                self.gui:drawText(x, y, rtu_id:sub(1, 12), self.gui.COLORS.TEXT_PRIMARY)
                self.gui:drawText(x + 15, y, status_text, status_color)
                y = y + 1
                rtu_count = rtu_count + 1
            end
        end
        
        if rtu_count == 0 then
            self.gui:drawText(x, y, "No RTUs connected", self.gui.COLORS.TEXT_MUTED)
        end
        
        -- Update alarms panel
        x, y = self.alarm_panel.x + 2, self.alarm_panel.y + 2
        local alarm_count = 0
        for _, alarm in ipairs(self.alarms) do
            if y < self.alarm_panel.y + self.alarm_panel.height - 2 then
                local alarm_color = alarm.level == "CRITICAL" and self.gui.COLORS.ERROR or self.gui.COLORS.WARNING
                local text = "[" .. alarm.level .. "] " .. alarm.message:sub(1, 25)
                self.gui:drawText(x, y, text, alarm_color)
                y = y + 1
                alarm_count = alarm_count + 1
            end
        end
        
        if alarm_count == 0 then
            self.gui:drawText(x, y, "No active alarms", self.gui.COLORS.SUCCESS)
        end
        
        -- Update errors panel
        x, y = self.error_panel.x + 2, self.error_panel.y + 2
        for i, error_entry in ipairs(self.errors) do
            if y < self.error_panel.y + self.error_panel.height - 2 then
                local error_color = error_entry.critical and self.gui.COLORS.ERROR or self.gui.COLORS.WARNING
                local text = error_entry.time .. " " .. error_entry.message:sub(1, 40)
                self.gui:drawText(x, y, text, error_color)
                y = y + 1
            else
                break
            end
        end
        
        if #self.errors == 0 then
            self.gui:drawText(x, y, "No recent errors", self.gui.COLORS.SUCCESS)
        end
    end)
    
    if not success then
        self:addError("GUI update failed: " .. error)
        self.has_gui = false -- Disable GUI on repeated failures
    end
end

function ScadaServer:initializeModem()
    local success, error = pcall(function()
        -- Try to find modem on configured side first
        if peripheral.getType(CONFIG.MODEM_SIDE) == "modem" then
            self.modem = peripheral.wrap(CONFIG.MODEM_SIDE)
        else
            -- Auto-detect modem
            self.modem = peripheral.find("modem")
        end
        
        if not self.modem then
            error("No modem found")
        end
        
        if not self.modem.isWireless() then
            error("Wireless modem required")
        end
        
        -- Open all required channels
        for name, channel in pairs(CONFIG.CHANNELS) do
            self.modem.open(channel)
        end
        
        self.status.modem_connected = true
    end)
    
    if not success then
        self:addError("Modem initialization failed: " .. error, true)
        self.status.modem_connected = false
        return false
    end
    
    print("[+] Modem initialized on " .. (CONFIG.MODEM_SIDE or "auto-detected side"))
    return true
end

function ScadaServer:processMessages()
    if not self.modem then return end
    
    local success, error = pcall(function()
        local event, side, channel, reply_channel, message, distance = os.pullEvent("modem_message")
        
        if type(message) ~= "table" then
            return
        end
        
        local msg_type = message.type
        local msg_data = message.data
        local sender_id = message.sender_id
        
        if msg_type == "RTU_DATA" then
            self:handleRTUData(sender_id, msg_data)
        elseif msg_type == "HMI_REQUEST" then
            self:handleHMIRequest(sender_id, msg_data, reply_channel)
        elseif msg_type == "ALARM" then
            self:handleAlarm(sender_id, msg_data)
        elseif msg_type == "HEARTBEAT" then
            self:handleHeartbeat(sender_id, msg_data)
        end
        
        self.status.data_points = self.status.data_points + 1
    end)
    
    if not success then
        self:addError("Message processing error: " .. error)
    end
end

function ScadaServer:handleRTUData(sender_id, data)
    if not self.rtu_data[sender_id] then
        print("[+] New RTU connected: " .. sender_id)
        self.status.rtus_connected = self.status.rtus_connected + 1
    end
    
    self.rtu_data[sender_id] = {
        data = data,
        last_update = os.clock(),
        online = true
    }
    
    -- Check for alarm conditions
    self:checkAlarms(sender_id, data)
end

function ScadaServer:handleHMIRequest(sender_id, request, reply_channel)
    -- Update HMI client registry
    if not self.hmi_clients[sender_id] then
        print("[+] New HMI client connected: " .. sender_id)
        self.status.hmi_connected = self.status.hmi_connected + 1
    end
    
    self.hmi_clients[sender_id] = {
        last_contact = os.clock(),
        reply_channel = reply_channel
    }
    
    -- Send current system status
    local response = {
        type = "SYSTEM_STATUS",
        data = {
            rtu_data = self.rtu_data,
            alarms = self.alarms,
            server_status = self.status
        },
        sender_id = CONFIG.SERVER_ID,
        timestamp = os.time()
    }
    
    if self.modem then
        self.modem.transmit(reply_channel, CONFIG.CHANNELS.HMI, response)
    end
end

function ScadaServer:handleAlarm(sender_id, alarm_data)
    table.insert(self.alarms, 1, {
        source = sender_id,
        level = alarm_data.level or "WARNING",
        message = alarm_data.message or "Unknown alarm",
        timestamp = os.time()
    })
    
    -- Keep only last 20 alarms
    if #self.alarms > 20 then
        table.remove(self.alarms)
    end
    
    print("[!] ALARM from " .. sender_id .. ": " .. (alarm_data.message or "Unknown"))
end

function ScadaServer:handleHeartbeat(sender_id, data)
    -- Just update last contact time
    if self.rtu_data[sender_id] then
        self.rtu_data[sender_id].last_update = os.clock()
    end
end

function ScadaServer:checkAlarms(rtu_id, data)
    if not data then return end
    
    local success, error = pcall(function()
        -- Check reactor temperature
        if data.reactor and data.reactor.temperature then
            local temp = data.reactor.temperature
            if temp > CONFIG.ALARM_THRESHOLDS.REACTOR_TEMP_CRITICAL then
                self:triggerAlarm(rtu_id, "CRITICAL", "Reactor temperature critical: " .. temp)
            elseif temp > CONFIG.ALARM_THRESHOLDS.REACTOR_TEMP_WARNING then
                self:triggerAlarm(rtu_id, "WARNING", "Reactor temperature high: " .. temp)
            end
        end
        
        -- Check energy levels
        if data.energy and data.energy.percentage then
            if data.energy.percentage < CONFIG.ALARM_THRESHOLDS.ENERGY_LOW then
                self:triggerAlarm(rtu_id, "WARNING", "Energy low: " .. data.energy.percentage .. "%")
            end
        end
        
        -- Check fuel levels
        if data.fuel and data.fuel.percentage then
            if data.fuel.percentage < CONFIG.ALARM_THRESHOLDS.FUEL_LOW then
                self:triggerAlarm(rtu_id, "WARNING", "Fuel low: " .. data.fuel.percentage .. "%")
            end
        end
    end)
    
    if not success then
        self:addError("Alarm check failed: " .. error)
    end
end

function ScadaServer:triggerAlarm(source, level, message)
    local alarm = {
        source = source,
        level = level,
        message = message,
        timestamp = os.time()
    }
    
    table.insert(self.alarms, 1, alarm)
    
    -- Broadcast alarm to all HMI clients
    if self.modem then
        local alarm_msg = {
            type = "ALARM",
            data = alarm,
            sender_id = CONFIG.SERVER_ID,
            timestamp = os.time()
        }
        
        self.modem.transmit(CONFIG.CHANNELS.ALARM, CONFIG.CHANNELS.HMI, alarm_msg)
    end
end

function ScadaServer:cleanup()
    -- Remove offline RTUs
    local current_time = os.clock()
    for rtu_id, rtu_data in pairs(self.rtu_data) do
        if current_time - rtu_data.last_update > 30 then -- 30 seconds timeout
            print("[-] RTU disconnected: " .. rtu_id)
            self.rtu_data[rtu_id] = nil
            self.status.rtus_connected = math.max(0, self.status.rtus_connected - 1)
        end
    end
    
    -- Remove offline HMI clients
    for hmi_id, hmi_data in pairs(self.hmi_clients) do
        if current_time - hmi_data.last_contact > 60 then -- 60 seconds timeout
            print("[-] HMI client disconnected: " .. hmi_id)
            self.hmi_clients[hmi_id] = nil
            self.status.hmi_connected = math.max(0, self.status.hmi_connected - 1)
        end
    end
end

function ScadaServer:displayTextStatus()
    -- Text-mode status display
    term.clear()
    term.setCursorPos(1, 1)
    
    term.setTextColor(colors.cyan)
    print("=== SCADA SERVER STATUS ===")
    term.setTextColor(colors.white)
    
    print("Server ID: " .. CONFIG.SERVER_ID)
    print("Uptime: " .. math.floor(self.status.uptime) .. " seconds")
    
    local modem_status = self.status.modem_connected and "[+] Connected" or "[-] Disconnected"
    print("Modem: " .. modem_status)
    
    print("RTUs Connected: " .. self.status.rtus_connected)
    print("HMI Clients: " .. self.status.hmi_connected)
    print("Data Points: " .. self.status.data_points)
    
    if #self.alarms > 0 then
        print()
        term.setTextColor(colors.red)
        print("ACTIVE ALARMS:")
        term.setTextColor(colors.white)
        for i = 1, math.min(3, #self.alarms) do
            local alarm = self.alarms[i]
            print("  [" .. alarm.level .. "] " .. alarm.message)
        end
    end
    
    if #self.errors > 0 then
        print()
        term.setTextColor(colors.yellow)
        print("RECENT ERRORS:")
        term.setTextColor(colors.white)
        for i = 1, math.min(3, #self.errors) do
            local error_entry = self.errors[i]
            print("  " .. error_entry.time .. " " .. error_entry.message)
        end
    end
    
    print()
    print("Press Ctrl+T to stop server")
end

function ScadaServer:run()
    print("Starting SCADA Server...")
    print("Configuration: " .. (config and "Loaded" or "Default"))
    
    local start_time = os.clock()
    
    -- Initialize modem
    if not self:initializeModem() then
        print("Failed to initialize modem. Continuing with limited functionality...")
    end
    
    -- Initialize GUI
    if term.isColor() then
        self:initializeGUI()
        print("GUI Mode: " .. (self.has_gui and "Enabled" or "Text mode"))
    else
        print("GUI Mode: Text mode (basic computer)")
    end
    
    print("SCADA Server started successfully")
    print("Listening on channels: " .. textutils.serialize(CONFIG.CHANNELS))
    print()
    
    local last_gui_update = 0
    local last_cleanup = 0
    
    -- Main server loop
    while self.running do
        self.status.uptime = os.clock() - start_time
        
        -- Process messages (non-blocking with timeout)
        local has_event = false
        if self.modem then
            local success, result = pcall(function()
                return os.pullEvent("modem_message")
            end)
            
            if success then
                has_event = true
                self:processMessages()
            end
        end
        
        -- Update GUI periodically
        if self.has_gui and os.clock() - last_gui_update > CONFIG.UPDATE_INTERVALS.GUI_REFRESH then
            self:updateGUI()
            last_gui_update = os.clock()
        elseif not self.has_gui and os.clock() - last_gui_update > 2 then
            self:displayTextStatus()
            last_gui_update = os.clock()
        end
        
        -- Cleanup periodically
        if os.clock() - last_cleanup > 10 then
            self:cleanup()
            last_cleanup = os.clock()
        end
        
        -- Small delay to prevent overwhelming CPU
        if not has_event then
            sleep(0.1)
        end
    end
    
    print("SCADA Server shutdown complete")
end

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(ScadaServer.run, ScadaServer)
    if not success then
        print("SCADA Server crashed: " .. error)
        print("Check hardware connections and restart")
    end
end

-- Handle Ctrl+T termination
local function handleTermination()
    ScadaServer.running = false
    print("Shutting down SCADA Server...")
end

-- Set up termination handler
os.pullEvent = os.pullEventRaw -- Disable Ctrl+T handling
term.clear()
term.setCursorPos(1, 1)

-- Start server
safeRun()