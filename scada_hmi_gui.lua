-- SCADA HMI Client with Enhanced GUI
-- Human Machine Interface with robust error handling and user-friendly displays

-- Load GUI library if available
local GUI = nil
if fs.exists("scada_gui.lua") then
    local success, gui_lib = pcall(dofile, "scada_gui.lua")
    if success then
        GUI = gui_lib
    end
elseif fs.exists("/scada/scada_gui.lua") then
    local success, gui_lib = pcall(dofile, "/scada/scada_gui.lua")
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
    MONITOR_SIDE = "top",
    CHANNELS = config.network and config.network.channels or {
        REACTOR = 100,
        FUEL = 101,
        ENERGY = 102,
        LASER = 103,
        HMI = 104,
        ALARM = 105
    },
    
    CLIENT_ID = config.components and config.components.hmi_id or "HMI_CLIENT_01",
    SERVER_ID = config.components and config.components.server_id or "SCADA_SERVER_01",
    
    UPDATE_INTERVALS = {
        DATA_REQUEST = 2,
        GUI_REFRESH = 0.5,
        CONNECTION_CHECK = 5
    },
    
    CONNECTION_TIMEOUT = 10
}

local HMIClient = {
    modem = nil,
    monitor = nil,
    gui = nil,
    running = true,
    
    -- Data storage
    system_data = {},
    last_update = 0,
    
    -- Status tracking
    status = {
        modem_connected = false,
        monitor_connected = false,
        server_connected = false,
        gui_enabled = false,
        connection_attempts = 0,
        last_error = nil
    },
    
    -- Error handling
    errors = {},
    
    -- GUI state
    current_screen = "overview",
    buttons = {},
    
    -- Screen dimensions
    w = 51, h = 19
}

function HMIClient:addError(message, critical)
    critical = critical or false
    local error_entry = {
        time = os.date("%H:%M:%S"),
        message = message,
        critical = critical
    }
    
    table.insert(self.errors, 1, error_entry)
    
    -- Keep only last 10 errors
    if #self.errors > 10 then
        table.remove(self.errors)
    end
    
    self.status.last_error = message
    
    print("[" .. error_entry.time .. "] " .. (critical and "CRITICAL: " or "ERROR: ") .. message)
    
    -- Don't crash, just log
    if critical then
        self:displayErrorScreen()
    end
end

function HMIClient:initializeMonitor()
    local success, error = pcall(function()
        -- Try configured side first
        if peripheral.getType(CONFIG.MONITOR_SIDE) == "monitor" then
            self.monitor = peripheral.wrap(CONFIG.MONITOR_SIDE)
        else
            -- Auto-detect monitor
            self.monitor = peripheral.find("monitor")
        end
        
        if not self.monitor then
            error("No monitor found")
        end
        
        self.w, self.h = self.monitor.getSize()
        
        -- Set appropriate scale for readability
        if self.w > 100 then
            self.monitor.setTextScale(0.5)
            self.w, self.h = self.monitor.getSize()
        end
        
        self.status.monitor_connected = true
    end)
    
    if not success then
        self:addError("Monitor initialization failed: " .. error)
        self.status.monitor_connected = false
        return false
    end
    
    print("[+] Monitor initialized: " .. self.w .. "x" .. self.h)
    return true
end

function HMIClient:initializeGUI()
    if not self.monitor then
        self:addError("Cannot initialize GUI - no monitor available")
        return false
    end
    
    if not GUI then
        self:addError("GUI library not available - using text mode")
        return false
    end
    
    local success, error = pcall(function()
        self.gui = GUI:init(self.monitor)
        self.status.gui_enabled = true
        self:createButtons()
    end)
    
    if not success then
        self:addError("GUI initialization failed: " .. error)
        self.status.gui_enabled = false
        return false
    end
    
    print("[+] GUI initialized successfully")
    return true
end

function HMIClient:createButtons()
    if not self.status.gui_enabled then return end
    
    -- Navigation buttons
    local button_width = math.floor(self.w / 4) - 1
    local button_y = self.h - 3
    
    self.buttons = {}
    
    -- Overview button
    local overview_btn = self.gui:createButton(1, button_y, button_width, 2, "Overview", "primary")
    overview_btn.onclick = function() self.current_screen = "overview" end
    table.insert(self.buttons, overview_btn)
    
    -- Reactor button
    local reactor_btn = self.gui:createButton(button_width + 2, button_y, button_width, 2, "Reactor", "default")
    reactor_btn.onclick = function() self.current_screen = "reactor" end
    table.insert(self.buttons, reactor_btn)
    
    -- Energy button
    local energy_btn = self.gui:createButton(button_width * 2 + 3, button_y, button_width, 2, "Energy", "default")
    energy_btn.onclick = function() self.current_screen = "energy" end
    table.insert(self.buttons, energy_btn)
    
    -- Status button
    local status_btn = self.gui:createButton(button_width * 3 + 4, button_y, button_width, 2, "Status", "default")
    status_btn.onclick = function() self.current_screen = "status" end
    table.insert(self.buttons, status_btn)
    
    -- Emergency SCRAM button (always visible)
    self.scram_button = self.gui:createButton(self.w - 12, 1, 12, 3, "EMERGENCY\nSCRAM", "danger")
    self.scram_button.onclick = function() self:emergencyScram() end
end

function HMIClient:initializeModem()
    local success, error = pcall(function()
        -- Try configured side first
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
        
        -- Open required channels
        self.modem.open(CONFIG.CHANNELS.HMI)
        self.modem.open(CONFIG.CHANNELS.ALARM)
        
        self.status.modem_connected = true
    end)
    
    if not success then
        self:addError("Modem initialization failed: " .. error, true)
        self.status.modem_connected = false
        return false
    end
    
    print("[+] Modem initialized")
    return true
end

function HMIClient:requestData()
    if not self.modem or not self.status.modem_connected then
        return
    end
    
    local success, error = pcall(function()
        local request = {
            type = "HMI_REQUEST",
            data = {
                client_id = CONFIG.CLIENT_ID,
                request_type = "SYSTEM_STATUS"
            },
            sender_id = CONFIG.CLIENT_ID,
            timestamp = os.time()
        }
        
        self.modem.transmit(CONFIG.CHANNELS.HMI, CONFIG.CHANNELS.HMI, request)
        self.status.connection_attempts = self.status.connection_attempts + 1
    end)
    
    if not success then
        self:addError("Data request failed: " .. error)
    end
end

function HMIClient:processMessages()
    if not self.modem then return end
    
    local success, error = pcall(function()
        local event, side, channel, reply_channel, message, distance = os.pullEvent("modem_message")
        
        if type(message) ~= "table" then
            return
        end
        
        if message.type == "SYSTEM_STATUS" then
            self:handleSystemStatus(message.data)
        elseif message.type == "ALARM" then
            self:handleAlarm(message.data)
        elseif message.type == "COMMAND_RESPONSE" then
            self:handleCommandResponse(message.data)
        end
    end)
    
    if not success then
        self:addError("Message processing error: " .. error)
    end
end

function HMIClient:handleSystemStatus(data)
    self.system_data = data
    self.last_update = os.clock()
    self.status.server_connected = true
    
    -- Reset connection counter on successful data
    self.status.connection_attempts = 0
end

function HMIClient:handleAlarm(alarm_data)
    -- Flash screen or show alarm notification
    if self.status.gui_enabled then
        local alarm_window = self.gui:showMessage("ALARM", alarm_data.message, "error")
    else
        term.setTextColor(colors.red)
        print("[ALARM] " .. alarm_data.message)
        term.setTextColor(colors.white)
    end
end

function HMIClient:handleCommandResponse(response)
    if response.success then
        print("[+] Command executed successfully")
    else
        self:addError("Command failed: " .. (response.error or "Unknown error"))
    end
end

function HMIClient:emergencyScram()
    if not self.modem then
        self:addError("Cannot send SCRAM - no modem connection")
        return
    end
    
    local success, error = pcall(function()
        local scram_command = {
            type = "EMERGENCY_COMMAND",
            data = {
                command = "SCRAM",
                reason = "HMI Emergency Stop"
            },
            sender_id = CONFIG.CLIENT_ID,
            timestamp = os.time()
        }
        
        -- Send to all channels
        for _, channel in pairs(CONFIG.CHANNELS) do
            self.modem.transmit(channel, CONFIG.CHANNELS.HMI, scram_command)
        end
        
        print("[!] EMERGENCY SCRAM INITIATED")
    end)
    
    if not success then
        self:addError("Emergency SCRAM failed: " .. error, true)
    end
end

function HMIClient:drawOverviewScreen()
    if not self.status.gui_enabled then return end
    
    local panel = self.gui:createPanel(1, 1, self.w, self.h - 5, "SYSTEM OVERVIEW")
    
    local x, y = 3, 3
    
    -- Connection status
    local conn_status = self.status.server_connected and "[+] Connected" or "[-] Disconnected"
    local conn_color = self.status.server_connected and self.gui.COLORS.SUCCESS or self.gui.COLORS.ERROR
    self.gui:drawText(x, y, "Server: " .. conn_status, conn_color)
    y = y + 1
    
    if self.last_update > 0 then
        local age = math.floor(os.clock() - self.last_update)
        self.gui:drawText(x, y, "Last Update: " .. age .. "s ago", self.gui.COLORS.TEXT_SECONDARY)
        y = y + 2
    else
        y = y + 2
    end
    
    -- System summary
    if self.system_data.rtu_data then
        local rtu_count = 0
        local online_count = 0
        
        for rtu_id, rtu_data in pairs(self.system_data.rtu_data) do
            rtu_count = rtu_count + 1
            if rtu_data.online then
                online_count = online_count + 1
            end
        end
        
        self.gui:drawText(x, y, "RTUs: " .. online_count .. "/" .. rtu_count .. " online", self.gui.COLORS.TEXT_PRIMARY)
        y = y + 1
    end
    
    if self.system_data.alarms then
        local alarm_count = #self.system_data.alarms
        local alarm_color = alarm_count > 0 and self.gui.COLORS.ERROR or self.gui.COLORS.SUCCESS
        self.gui:drawText(x, y, "Alarms: " .. alarm_count, alarm_color)
        y = y + 1
    end
    
    -- Quick reactor status
    if self.system_data.rtu_data then
        y = y + 1
        self.gui:drawText(x, y, "REACTOR STATUS:", self.gui.COLORS.TEXT_ACCENT)
        y = y + 1
        
        local reactor_found = false
        for rtu_id, rtu_data in pairs(self.system_data.rtu_data) do
            if rtu_data.data and rtu_data.data.reactor then
                reactor_found = true
                local reactor = rtu_data.data.reactor
                
                if reactor.temperature then
                    local temp_color = reactor.temperature > 80000000 and self.gui.COLORS.ERROR or self.gui.COLORS.SUCCESS
                    self.gui:drawText(x + 2, y, "Temperature: " .. math.floor(reactor.temperature/1000000) .. "M K", temp_color)
                    y = y + 1
                end
                
                if reactor.status then
                    local status_color = reactor.status == "RUNNING" and self.gui.COLORS.SUCCESS or self.gui.COLORS.WARNING
                    self.gui:drawText(x + 2, y, "Status: " .. reactor.status, status_color)
                    y = y + 1
                end
                break
            end
        end
        
        if not reactor_found then
            self.gui:drawText(x + 2, y, "No reactor data available", self.gui.COLORS.TEXT_MUTED)
        end
    end
end

function HMIClient:drawReactorScreen()
    if not self.status.gui_enabled then return end
    
    local panel = self.gui:createPanel(1, 1, self.w, self.h - 5, "REACTOR CONTROL")
    
    local x, y = 3, 3
    
    local reactor_data = nil
    if self.system_data.rtu_data then
        for rtu_id, rtu_data in pairs(self.system_data.rtu_data) do
            if rtu_data.data and rtu_data.data.reactor then
                reactor_data = rtu_data.data.reactor
                break
            end
        end
    end
    
    if not reactor_data then
        self.gui:drawText(x, y, "No reactor data available", self.gui.COLORS.ERROR)
        self.gui:drawText(x, y + 1, "Check RTU connections", self.gui.COLORS.TEXT_MUTED)
        return
    end
    
    -- Reactor status
    if reactor_data.status then
        local status_color = reactor_data.status == "RUNNING" and self.gui.COLORS.SUCCESS or self.gui.COLORS.WARNING
        self.gui:drawText(x, y, "Status: " .. reactor_data.status, status_color)
        y = y + 1
    end
    
    -- Temperature
    if reactor_data.temperature then
        local temp_mk = math.floor(reactor_data.temperature / 1000000)
        local temp_color = self.gui.COLORS.SUCCESS
        
        if reactor_data.temperature > 95000000 then
            temp_color = self.gui.COLORS.ERROR
        elseif reactor_data.temperature > 80000000 then
            temp_color = self.gui.COLORS.WARNING
        end
        
        self.gui:drawText(x, y, "Temperature: " .. temp_mk .. " MK", temp_color)
        y = y + 1
        
        -- Temperature bar
        local bar_width = 30
        local temp_percent = math.min(100, (reactor_data.temperature / 100000000) * 100)
        local filled = math.floor((temp_percent / 100) * bar_width)
        
        self.gui:fillRect(x, y, bar_width, 1, self.gui.COLORS.BG_LIGHT)
        if filled > 0 then
            self.gui:fillRect(x, y, filled, 1, temp_color)
        end
        y = y + 2
    end
    
    -- Fuel levels
    if reactor_data.fuel then
        self.gui:drawText(x, y, "Fuel Levels:", self.gui.COLORS.TEXT_ACCENT)
        y = y + 1
        
        if reactor_data.fuel.deuterium then
            self.gui:drawText(x + 2, y, "Deuterium: " .. reactor_data.fuel.deuterium .. "%", self.gui.COLORS.TEXT_PRIMARY)
            y = y + 1
        end
        
        if reactor_data.fuel.tritium then
            self.gui:drawText(x + 2, y, "Tritium: " .. reactor_data.fuel.tritium .. "%", self.gui.COLORS.TEXT_PRIMARY)
            y = y + 1
        end
    end
end

function HMIClient:drawEnergyScreen()
    if not self.status.gui_enabled then return end
    
    local panel = self.gui:createPanel(1, 1, self.w, self.h - 5, "ENERGY SYSTEMS")
    
    local x, y = 3, 3
    
    local energy_data = nil
    if self.system_data.rtu_data then
        for rtu_id, rtu_data in pairs(self.system_data.rtu_data) do
            if rtu_data.data and rtu_data.data.energy then
                energy_data = rtu_data.data.energy
                break
            end
        end
    end
    
    if not energy_data then
        self.gui:drawText(x, y, "No energy data available", self.gui.COLORS.ERROR)
        return
    end
    
    -- Energy storage percentage
    if energy_data.percentage then
        local energy_color = self.gui.COLORS.SUCCESS
        if energy_data.percentage < 10 then
            energy_color = self.gui.COLORS.ERROR
        elseif energy_data.percentage < 25 then
            energy_color = self.gui.COLORS.WARNING
        end
        
        self.gui:drawText(x, y, "Storage: " .. energy_data.percentage .. "%", energy_color)
        y = y + 1
        
        -- Energy bar
        local bar_width = 35
        local filled = math.floor((energy_data.percentage / 100) * bar_width)
        
        self.gui:fillRect(x, y, bar_width, 1, self.gui.COLORS.BG_LIGHT)
        if filled > 0 then
            self.gui:fillRect(x, y, filled, 1, energy_color)
        end
        y = y + 2
    end
    
    -- Energy amounts
    if energy_data.stored and energy_data.capacity then
        self.gui:drawText(x, y, "Stored: " .. self:formatEnergy(energy_data.stored), self.gui.COLORS.TEXT_PRIMARY)
        y = y + 1
        self.gui:drawText(x, y, "Capacity: " .. self:formatEnergy(energy_data.capacity), self.gui.COLORS.TEXT_PRIMARY)
        y = y + 1
    end
    
    -- Input/Output rates
    if energy_data.input_rate then
        self.gui:drawText(x, y, "Input: " .. self:formatEnergy(energy_data.input_rate) .. "/t", self.gui.COLORS.SUCCESS)
        y = y + 1
    end
    
    if energy_data.output_rate then
        self.gui:drawText(x, y, "Output: " .. self:formatEnergy(energy_data.output_rate) .. "/t", self.gui.COLORS.WARNING)
        y = y + 1
    end
end

function HMIClient:drawStatusScreen()
    if not self.status.gui_enabled then return end
    
    local panel = self.gui:createPanel(1, 1, self.w, self.h - 5, "SYSTEM STATUS")
    
    local x, y = 3, 3
    
    -- HMI Client status
    self.gui:drawText(x, y, "HMI Client: " .. CONFIG.CLIENT_ID, self.gui.COLORS.TEXT_ACCENT)
    y = y + 1
    
    local modem_status = self.status.modem_connected and "[+] Connected" or "[-] Disconnected"
    local modem_color = self.status.modem_connected and self.gui.COLORS.SUCCESS or self.gui.COLORS.ERROR
    self.gui:drawText(x, y, "Modem: " .. modem_status, modem_color)
    y = y + 1
    
    local monitor_status = self.status.monitor_connected and "[+] Connected" or "[-] Disconnected"
    local monitor_color = self.status.monitor_connected and self.gui.COLORS.SUCCESS or self.gui.COLORS.ERROR
    self.gui:drawText(x, y, "Monitor: " .. monitor_status, monitor_color)
    y = y + 1
    
    local server_status = self.status.server_connected and "[+] Connected" or "[-] Disconnected"
    local server_color = self.status.server_connected and self.gui.COLORS.SUCCESS or self.gui.COLORS.ERROR
    self.gui:drawText(x, y, "Server: " .. server_status, server_color)
    y = y + 2
    
    -- Error display
    if #self.errors > 0 then
        self.gui:drawText(x, y, "Recent Errors:", self.gui.COLORS.ERROR)
        y = y + 1
        
        for i = 1, math.min(5, #self.errors) do
            local error_entry = self.errors[i]
            local error_text = error_entry.time .. " " .. error_entry.message:sub(1, 35)
            local error_color = error_entry.critical and self.gui.COLORS.ERROR or self.gui.COLORS.WARNING
            self.gui:drawText(x, y, error_text, error_color)
            y = y + 1
        end
    else
        self.gui:drawText(x, y, "No recent errors", self.gui.COLORS.SUCCESS)
    end
end

function HMIClient:formatEnergy(energy)
    if energy > 1000000000 then
        return string.format("%.1fG", energy / 1000000000)
    elseif energy > 1000000 then
        return string.format("%.1fM", energy / 1000000)
    elseif energy > 1000 then
        return string.format("%.1fK", energy / 1000)
    else
        return tostring(energy)
    end
end

function HMIClient:displayErrorScreen()
    if self.status.gui_enabled and self.gui then
        local error_window = self.gui:showMessage("SYSTEM ERROR", 
            "Critical error occurred. Check connections and restart if needed.", "error")
    else
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.clear()
        term.setCursorPos(1, 1)
        print("=== CRITICAL ERROR ===")
        print("HMI Client encountered a critical error")
        print("Last error: " .. (self.status.last_error or "Unknown"))
        print("Press any key to continue...")
        os.pullEvent("key")
        term.setBackgroundColor(colors.black)
    end
end

function HMIClient:displayTextInterface()
    -- Fallback text interface when GUI is not available
    term.clear()
    term.setCursorPos(1, 1)
    
    term.setTextColor(colors.cyan)
    print("=== SCADA HMI CLIENT ===")
    term.setTextColor(colors.white)
    
    print("Client ID: " .. CONFIG.CLIENT_ID)
    
    local conn_status = self.status.server_connected and "[+] Connected" or "[-] Disconnected"
    print("Server: " .. conn_status)
    
    if self.last_update > 0 then
        local age = math.floor(os.clock() - self.last_update)
        print("Last Update: " .. age .. " seconds ago")
    else
        print("Last Update: Never")
    end
    
    if #self.errors > 0 then
        print()
        term.setTextColor(colors.red)
        print("ERRORS:")
        term.setTextColor(colors.white)
        for i = 1, math.min(3, #self.errors) do
            print("  " .. self.errors[i].message)
        end
    end
    
    print()
    print("Press 's' for SCRAM, 'q' to quit")
end

function HMIClient:handleInput()
    local success, error = pcall(function()
        if self.status.gui_enabled then
            -- Handle GUI input
            local event, button, x, y = os.pullEvent()
            
            if event == "monitor_touch" or event == "mouse_click" then
                -- Check button clicks
                for _, btn in ipairs(self.buttons) do
                    if btn:onMouseClick(x, y, button) then
                        break
                    end
                end
                
                -- Check SCRAM button
                if self.scram_button:onMouseClick(x, y, button) then
                    -- SCRAM button handled by its onclick
                end
            end
        else
            -- Handle keyboard input for text mode
            local event, key = os.pullEvent("char")
            
            if key == "s" or key == "S" then
                self:emergencyScram()
            elseif key == "q" or key == "Q" then
                self.running = false
            end
        end
    end)
    
    if not success then
        self:addError("Input handling error: " .. error)
    end
end

function HMIClient:updateDisplay()
    if self.status.gui_enabled then
        local success, error = pcall(function()
            self.gui:render()
            
            -- Draw current screen
            if self.current_screen == "overview" then
                self:drawOverviewScreen()
            elseif self.current_screen == "reactor" then
                self:drawReactorScreen()
            elseif self.current_screen == "energy" then
                self:drawEnergyScreen()
            elseif self.current_screen == "status" then
                self:drawStatusScreen()
            end
            
            -- Always draw SCRAM button
            if self.scram_button then
                self.scram_button:draw()
            end
            
            -- Draw navigation buttons
            for _, btn in ipairs(self.buttons) do
                -- Highlight current screen button
                if (self.current_screen == "overview" and btn.text == "Overview") or
                   (self.current_screen == "reactor" and btn.text == "Reactor") or
                   (self.current_screen == "energy" and btn.text == "Energy") or
                   (self.current_screen == "status" and btn.text == "Status") then
                    btn.style = "primary"
                else
                    btn.style = "default"
                end
                btn:draw()
            end
        end)
        
        if not success then
            self:addError("GUI update failed: " .. error)
            self.status.gui_enabled = false -- Fall back to text mode
        end
    else
        self:displayTextInterface()
    end
end

function HMIClient:checkConnection()
    local current_time = os.clock()
    
    if current_time - self.last_update > CONFIG.CONNECTION_TIMEOUT then
        if self.status.server_connected then
            self:addError("Lost connection to SCADA server")
            self.status.server_connected = false
        end
    end
end

function HMIClient:run()
    print("Starting SCADA HMI Client...")
    print("Configuration: " .. (config and "Loaded" or "Default"))
    
    -- Initialize components
    if not self:initializeModem() then
        self:addError("Failed to initialize modem", true)
    end
    
    if not self:initializeMonitor() then
        self:addError("Failed to initialize monitor")
    end
    
    if self.status.monitor_connected and term.isColor() then
        self:initializeGUI()
    end
    
    print("HMI Client initialized")
    print("GUI Mode: " .. (self.status.gui_enabled and "Enabled" or "Text mode"))
    print("Screen: " .. self.w .. "x" .. self.h)
    print()
    
    local last_request = 0
    local last_display_update = 0
    local last_connection_check = 0
    
    -- Main client loop
    while self.running do
        -- Request data periodically
        if os.clock() - last_request > CONFIG.UPDATE_INTERVALS.DATA_REQUEST then
            self:requestData()
            last_request = os.clock()
        end
        
        -- Process messages (non-blocking)
        local has_event = false
        if self.modem then
            local timer = os.startTimer(0.1)
            local event = os.pullEvent()
            
            if event == "modem_message" then
                has_event = true
                self:processMessages()
            elseif event == "timer" and event == timer then
                -- Timeout, continue
            else
                -- Other events (input, etc.)
                self:handleInput()
            end
        end
        
        -- Update display
        if os.clock() - last_display_update > CONFIG.UPDATE_INTERVALS.GUI_REFRESH then
            self:updateDisplay()
            last_display_update = os.clock()
        end
        
        -- Check connection
        if os.clock() - last_connection_check > CONFIG.UPDATE_INTERVALS.CONNECTION_CHECK then
            self:checkConnection()
            last_connection_check = os.clock()
        end
        
        -- Small delay if no events
        if not has_event then
            sleep(0.05)
        end
    end
    
    print("HMI Client shutdown complete")
end

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(HMIClient.run, HMIClient)
    if not success then
        print("HMI Client crashed: " .. error)
        print("Check monitor and modem connections")
    end
end

-- Handle termination
os.pullEvent = os.pullEventRaw -- Disable Ctrl+T

-- Start HMI client
term.clear()
term.setCursorPos(1, 1)
safeRun()