-- Universal RTU with GUI Interface
-- Auto-detecting RTU with robust error handling and status display

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
    CHANNELS = config.network and config.network.channels or {
        REACTOR = 100,
        FUEL = 101,
        ENERGY = 102,
        LASER = 103,
        HMI = 104,
        ALARM = 105
    },
    
    RTU_ID = config.rtu and config.rtu.id or "AUTO_RTU_01",
    SERVER_ID = config.components and config.components.server_id or "SCADA_SERVER_01",
    
    UPDATE_INTERVALS = {
        DATA_COLLECTION = config.rtu and config.rtu.update_interval or 1,
        HEARTBEAT = 10,
        STATUS_DISPLAY = 2,
        CONNECTION_CHECK = 5
    },
    
    CONNECTION_TIMEOUT = config.rtu and config.rtu.timeout or 15,
    AUTO_DETECT = config.rtu and config.rtu.auto_detect or true
}

local UniversalRTU = {
    -- Hardware
    wireless_modem = nil,
    cable_modem = nil,
    monitor = nil,
    
    -- Device detection
    detected_devices = {},
    rtu_type = "unknown",
    primary_device = nil,
    
    -- Status
    running = true,
    initialized = false,
    
    status = {
        wireless_connected = false,
        cable_connected = false,
        devices_detected = 0,
        server_connected = false,
        last_transmission = 0,
        data_points_sent = 0,
        uptime = 0,
        last_error = nil
    },
    
    -- Error handling
    errors = {},
    
    -- Data collection
    current_data = {},
    last_data_collection = 0,
    
    -- Display
    has_monitor = false,
    screen_w = 51,
    screen_h = 19
}

function UniversalRTU:addError(message, critical)
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
    
    -- Don't crash on errors
    if critical then
        self:displayCriticalError()
    end
end

function UniversalRTU:initializeModems()
    local success, error = pcall(function()
        -- Find wireless modem
        for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
            if peripheral.getType(side) == "modem" then
                local modem = peripheral.wrap(side)
                if modem then
                    if modem.isWireless() then
                        self.wireless_modem = modem
                        self.status.wireless_connected = true
                    else
                        self.cable_modem = modem
                        self.status.cable_connected = true
                    end
                end
            end
        end
        
        if not self.wireless_modem then
            error("No wireless modem found")
        end
        
        if not self.cable_modem then
            error("No cable modem found")
        end
        
        -- Open required channels on wireless modem
        for _, channel in pairs(CONFIG.CHANNELS) do
            self.wireless_modem.open(channel)
        end
    end)
    
    if not success then
        self:addError("Modem initialization failed: " .. error, true)
        return false
    end
    
    print("[+] Modems initialized")
    print("  Wireless: " .. (self.wireless_modem and "Yes" or "No"))
    print("  Cable: " .. (self.cable_modem and "Yes" or "No"))
    return true
end

function UniversalRTU:initializeMonitor()
    local success, error = pcall(function()
        local monitor = peripheral.find("monitor")
        if monitor then
            self.monitor = monitor
            self.screen_w, self.screen_h = monitor.getSize()
            
            -- Set appropriate scale
            if self.screen_w > 100 then
                monitor.setTextScale(0.5)
                self.screen_w, self.screen_h = monitor.getSize()
            end
            
            self.has_monitor = true
        end
    end)
    
    if not success then
        self:addError("Monitor initialization failed: " .. error)
        return false
    end
    
    if self.has_monitor then
        print("[+] Monitor initialized: " .. self.screen_w .. "x" .. self.screen_h)
    else
        print("[-] No monitor found - using computer display")
    end
    
    return true
end

function UniversalRTU:detectDevices()
    if not self.cable_modem then
        self:addError("Cannot detect devices - no cable modem", true)
        return false
    end
    
    local success, error = pcall(function()
        self.detected_devices = {}
        local connected_devices = self.cable_modem.getNamesRemote()
        
        for _, device_name in ipairs(connected_devices) do
            local device_type = self:classifyDevice(device_name)
            if device_type ~= "unknown" then
                table.insert(self.detected_devices, {
                    name = device_name,
                    type = device_type,
                    side = "cable_modem"
                })
            end
        end
        
        self.status.devices_detected = #self.detected_devices
        
        if #self.detected_devices == 0 then
            error("No Mekanism devices detected")
        end
        
        -- Determine RTU type based on detected devices
        self:determineRTUType()
    end)
    
    if not success then
        self:addError("Device detection failed: " .. error, true)
        return false
    end
    
    print("[+] Detected " .. #self.detected_devices .. " Mekanism devices")
    for _, device in ipairs(self.detected_devices) do
        print("  " .. device.type .. ": " .. device.name)
    end
    
    return true
end

function UniversalRTU:classifyDevice(device_name)
    local name_lower = device_name:lower()
    
    if name_lower:find("fusion_reactor") or name_lower:find("reactor_controller") then
        return "reactor"
    elseif name_lower:find("induction_matrix") or name_lower:find("energy_cube") then
        return "energy"
    elseif name_lower:find("dynamic_tank") or name_lower:find("chemical_tank") or 
           name_lower:find("electrolytic_separator") then
        return "fuel"
    elseif name_lower:find("laser") or name_lower:find("amplifier") then
        return "laser"
    else
        return "unknown"
    end
end

function UniversalRTU:determineRTUType()
    local type_counts = {}
    
    for _, device in ipairs(self.detected_devices) do
        type_counts[device.type] = (type_counts[device.type] or 0) + 1
    end
    
    -- Find the most common device type
    local max_count = 0
    local primary_type = "mixed"
    
    for device_type, count in pairs(type_counts) do
        if count > max_count then
            max_count = count
            primary_type = device_type
        end
    end
    
    self.rtu_type = primary_type
    
    -- Set primary device
    for _, device in ipairs(self.detected_devices) do
        if device.type == primary_type then
            self.primary_device = device
            break
        end
    end
    
    print("[+] RTU Type determined: " .. self.rtu_type)
    if self.primary_device then
        print("  Primary device: " .. self.primary_device.name)
    end
end

function UniversalRTU:collectData()
    if not self.cable_modem then
        return {}
    end
    
    local data = {
        rtu_id = CONFIG.RTU_ID,
        rtu_type = self.rtu_type,
        timestamp = os.time(),
        devices = {}
    }
    
    local success, error = pcall(function()
        for _, device in ipairs(self.detected_devices) do
            local device_data = self:collectDeviceData(device)
            if device_data then
                data.devices[device.name] = device_data
                
                -- Add to type-specific data
                if not data[device.type] then
                    data[device.type] = {}
                end
                
                for key, value in pairs(device_data) do
                    data[device.type][key] = value
                end
            end
        end
    end)
    
    if not success then
        self:addError("Data collection failed: " .. error)
        return {}
    end
    
    self.current_data = data
    self.last_data_collection = os.clock()
    
    return data
end

function UniversalRTU:collectDeviceData(device)
    if not self.cable_modem then
        return nil
    end
    
    local success, data = pcall(function()
        local device_peripheral = self.cable_modem.getNameLocal() and 
                                 peripheral.wrap(device.name) or nil
        
        if not device_peripheral then
            return nil
        end
        
        local device_data = {}
        
        if device.type == "reactor" then
            device_data = self:collectReactorData(device_peripheral)
        elseif device.type == "energy" then
            device_data = self:collectEnergyData(device_peripheral)
        elseif device.type == "fuel" then
            device_data = self:collectFuelData(device_peripheral)
        elseif device.type == "laser" then
            device_data = self:collectLaserData(device_peripheral)
        end
        
        device_data.device_name = device.name
        device_data.device_type = device.type
        device_data.online = true
        
        return device_data
    end)
    
    if not success then
        self:addError("Failed to collect data from " .. device.name .. ": " .. data)
        return {
            device_name = device.name,
            device_type = device.type,
            online = false,
            error = data
        }
    end
    
    return data
end

function UniversalRTU:collectReactorData(reactor)
    local data = {}
    
    -- Safe method calls with error handling
    local methods = {
        "getStatus", "getTemperature", "getFuel", "getPlasmaTemperature",
        "getCaseTemperature", "getInjectionRate", "getActiveCooledLogic"
    }
    
    for _, method in ipairs(methods) do
        if reactor[method] then
            local success, result = pcall(reactor[method], reactor)
            if success then
                if method == "getStatus" then
                    data.status = result
                elseif method == "getTemperature" then
                    data.temperature = result
                elseif method == "getFuel" then
                    data.fuel = result
                elseif method == "getPlasmaTemperature" then
                    data.plasma_temperature = result
                elseif method == "getCaseTemperature" then
                    data.case_temperature = result
                elseif method == "getInjectionRate" then
                    data.injection_rate = result
                elseif method == "getActiveCooledLogic" then
                    data.active_cooled = result
                end
            end
        end
    end
    
    return data
end

function UniversalRTU:collectEnergyData(energy_device)
    local data = {}
    
    local methods = {
        "getEnergy", "getMaxEnergy", "getEnergyPercentage",
        "getLastInput", "getLastOutput", "getTransferCap"
    }
    
    for _, method in ipairs(methods) do
        if energy_device[method] then
            local success, result = pcall(energy_device[method], energy_device)
            if success then
                if method == "getEnergy" then
                    data.stored = result
                elseif method == "getMaxEnergy" then
                    data.capacity = result
                elseif method == "getEnergyPercentage" then
                    data.percentage = result * 100
                elseif method == "getLastInput" then
                    data.input_rate = result
                elseif method == "getLastOutput" then
                    data.output_rate = result
                elseif method == "getTransferCap" then
                    data.transfer_cap = result
                end
            end
        end
    end
    
    return data
end

function UniversalRTU:collectFuelData(fuel_device)
    local data = {}
    
    local methods = {
        "getStored", "getCapacity", "getStoredPercentage"
    }
    
    for _, method in ipairs(methods) do
        if fuel_device[method] then
            local success, result = pcall(fuel_device[method], fuel_device)
            if success then
                if method == "getStored" then
                    data.stored = result
                elseif method == "getCapacity" then
                    data.capacity = result
                elseif method == "getStoredPercentage" then
                    data.percentage = result * 100
                end
            end
        end
    end
    
    return data
end

function UniversalRTU:collectLaserData(laser_device)
    local data = {}
    
    local methods = {
        "getEnergy", "isEnabled", "canLase"
    }
    
    for _, method in ipairs(methods) do
        if laser_device[method] then
            local success, result = pcall(laser_device[method], laser_device)
            if success then
                if method == "getEnergy" then
                    data.energy = result
                elseif method == "isEnabled" then
                    data.enabled = result
                elseif method == "canLase" then
                    data.can_lase = result
                end
            end
        end
    end
    
    return data
end

function UniversalRTU:sendData(data)
    if not self.wireless_modem or not data then
        return false
    end
    
    local success, error = pcall(function()
        local message = {
            type = "RTU_DATA",
            data = data,
            sender_id = CONFIG.RTU_ID,
            timestamp = os.time()
        }
        
        -- Send to appropriate channel based on RTU type
        local channel = CONFIG.CHANNELS.REACTOR -- Default
        if self.rtu_type == "energy" then
            channel = CONFIG.CHANNELS.ENERGY
        elseif self.rtu_type == "fuel" then
            channel = CONFIG.CHANNELS.FUEL
        elseif self.rtu_type == "laser" then
            channel = CONFIG.CHANNELS.LASER
        end
        
        self.wireless_modem.transmit(channel, CONFIG.CHANNELS.HMI, message)
        
        self.status.last_transmission = os.clock()
        self.status.data_points_sent = self.status.data_points_sent + 1
    end)
    
    if not success then
        self:addError("Data transmission failed: " .. error)
        return false
    end
    
    return true
end

function UniversalRTU:sendHeartbeat()
    if not self.wireless_modem then
        return
    end
    
    local success, error = pcall(function()
        local heartbeat = {
            type = "HEARTBEAT",
            data = {
                rtu_id = CONFIG.RTU_ID,
                rtu_type = self.rtu_type,
                devices_count = #self.detected_devices,
                uptime = self.status.uptime
            },
            sender_id = CONFIG.RTU_ID,
            timestamp = os.time()
        }
        
        self.wireless_modem.transmit(CONFIG.CHANNELS.HMI, CONFIG.CHANNELS.HMI, heartbeat)
    end)
    
    if not success then
        self:addError("Heartbeat failed: " .. error)
    end
end

function UniversalRTU:processCommands()
    if not self.wireless_modem then
        return
    end
    
    local success, error = pcall(function()
        local event, side, channel, reply_channel, message, distance = os.pullEvent("modem_message")
        
        if type(message) ~= "table" then
            return
        end
        
        if message.type == "EMERGENCY_COMMAND" and message.data.command == "SCRAM" then
            self:executeEmergencyStop()
        elseif message.type == "RTU_COMMAND" then
            self:executeCommand(message.data)
        end
    end)
    
    if not success then
        self:addError("Command processing error: " .. error)
    end
end

function UniversalRTU:executeEmergencyStop()
    print("[!] EMERGENCY STOP RECEIVED")
    
    local success, error = pcall(function()
        for _, device in ipairs(self.detected_devices) do
            if device.type == "reactor" then
                local reactor = peripheral.wrap(device.name)
                if reactor and reactor.scram then
                    reactor.scram()
                    print("[!] Reactor SCRAM executed: " .. device.name)
                end
            elseif device.type == "laser" then
                local laser = peripheral.wrap(device.name)
                if laser and laser.setEnabled then
                    laser.setEnabled(false)
                    print("[!] Laser disabled: " .. device.name)
                end
            end
        end
    end)
    
    if not success then
        self:addError("Emergency stop failed: " .. error, true)
    end
end

function UniversalRTU:executeCommand(command_data)
    local success, error = pcall(function()
        local device_name = command_data.device
        local command = command_data.command
        local params = command_data.params or {}
        
        if device_name and command then
            local device = peripheral.wrap(device_name)
            if device and device[command] then
                local result = device[command](device, table.unpack(params))
                print("[+] Command executed: " .. command .. " on " .. device_name)
            else
                self:addError("Command not found: " .. command .. " on " .. device_name)
            end
        end
    end)
    
    if not success then
        self:addError("Command execution failed: " .. error)
    end
end

function UniversalRTU:displayStatus()
    local target = self.has_monitor and self.monitor or term
    
    target.clear()
    target.setCursorPos(1, 1)
    
    -- Header
    target.setTextColor(colors.cyan)
    target.write("=== UNIVERSAL RTU STATUS ===")
    target.setCursorPos(1, 2)
    target.setTextColor(colors.white)
    
    -- Basic info
    target.write("RTU ID: " .. CONFIG.RTU_ID)
    target.setCursorPos(1, 3)
    target.write("Type: " .. self.rtu_type)
    target.setCursorPos(1, 4)
    target.write("Uptime: " .. math.floor(self.status.uptime) .. "s")
    
    -- Connection status
    target.setCursorPos(1, 6)
    target.setTextColor(colors.yellow)
    target.write("CONNECTIONS:")
    target.setCursorPos(1, 7)
    target.setTextColor(colors.white)
    
    local wireless_status = self.status.wireless_connected and "[+] Connected" or "[-] Disconnected"
    target.write("Wireless: " .. wireless_status)
    target.setCursorPos(1, 8)
    
    local cable_status = self.status.cable_connected and "[+] Connected" or "[-] Disconnected"
    target.write("Cable: " .. cable_status)
    target.setCursorPos(1, 9)
    target.write("Devices: " .. self.status.devices_detected)
    
    -- Data status
    target.setCursorPos(1, 11)
    target.setTextColor(colors.yellow)
    target.write("DATA:")
    target.setCursorPos(1, 12)
    target.setTextColor(colors.white)
    target.write("Points sent: " .. self.status.data_points_sent)
    
    if self.status.last_transmission > 0 then
        local age = math.floor(os.clock() - self.status.last_transmission)
        target.setCursorPos(1, 13)
        target.write("Last TX: " .. age .. "s ago")
    end
    
    -- Primary device status
    if self.primary_device and self.current_data[self.rtu_type] then
        target.setCursorPos(1, 15)
        target.setTextColor(colors.yellow)
        target.write(self.rtu_type:upper() .. " DATA:")
        target.setCursorPos(1, 16)
        target.setTextColor(colors.white)
        
        local data = self.current_data[self.rtu_type]
        if self.rtu_type == "reactor" and data.temperature then
            target.write("Temp: " .. math.floor(data.temperature/1000000) .. "MK")
        elseif self.rtu_type == "energy" and data.percentage then
            target.write("Energy: " .. math.floor(data.percentage) .. "%")
        elseif self.rtu_type == "fuel" and data.percentage then
            target.write("Fuel: " .. math.floor(data.percentage) .. "%")
        elseif self.rtu_type == "laser" and data.energy then
            target.write("Energy: " .. data.energy)
        end
    end
    
    -- Errors
    if #self.errors > 0 then
        target.setCursorPos(1, 18)
        target.setTextColor(colors.red)
        target.write("Last Error: " .. self.errors[1].message:sub(1, 40))
    end
    
    -- Instructions
    target.setCursorPos(1, self.has_monitor and self.screen_h or 19)
    target.setTextColor(colors.lightGray)
    target.write("Press Ctrl+T to stop")
end

function UniversalRTU:displayCriticalError()
    local target = self.has_monitor and self.monitor or term
    
    target.setBackgroundColor(colors.red)
    target.setTextColor(colors.white)
    target.clear()
    target.setCursorPos(1, 1)
    target.write("=== CRITICAL ERROR ===")
    target.setCursorPos(1, 3)
    target.write("RTU encountered critical error:")
    target.setCursorPos(1, 4)
    target.write(self.status.last_error or "Unknown error")
    target.setCursorPos(1, 6)
    target.write("Check connections and restart")
    target.setCursorPos(1, 8)
    target.write("Press any key to continue...")
    
    os.pullEvent("key")
    target.setBackgroundColor(colors.black)
end

function UniversalRTU:run()
    print("Starting Universal RTU...")
    print("Configuration: " .. (config and "Loaded" or "Default"))
    
    local start_time = os.clock()
    
    -- Initialize hardware
    if not self:initializeModems() then
        print("RTU cannot operate without modems")
        return
    end
    
    self:initializeMonitor()
    
    -- Detect devices
    if not self:detectDevices() then
        print("RTU cannot operate without Mekanism devices")
        return
    end
    
    print("Universal RTU initialized successfully")
    print("RTU Type: " .. self.rtu_type)
    print("Primary Device: " .. (self.primary_device and self.primary_device.name or "None"))
    print()
    
    self.initialized = true
    
    local last_data_collection = 0
    local last_heartbeat = 0
    local last_status_display = 0
    
    -- Main RTU loop
    while self.running do
        self.status.uptime = os.clock() - start_time
        
        -- Collect and send data
        if os.clock() - last_data_collection > CONFIG.UPDATE_INTERVALS.DATA_COLLECTION then
            local data = self:collectData()
            if data and next(data.devices) then
                self:sendData(data)
            end
            last_data_collection = os.clock()
        end
        
        -- Send heartbeat
        if os.clock() - last_heartbeat > CONFIG.UPDATE_INTERVALS.HEARTBEAT then
            self:sendHeartbeat()
            last_heartbeat = os.clock()
        end
        
        -- Update display
        if os.clock() - last_status_display > CONFIG.UPDATE_INTERVALS.STATUS_DISPLAY then
            self:displayStatus()
            last_status_display = os.clock()
        end
        
        -- Process commands (non-blocking with timeout)
        local has_event = false
        if self.wireless_modem then
            local timer = os.startTimer(0.1)
            local event = os.pullEvent()
            
            if event == "modem_message" then
                has_event = true
                self:processCommands()
            elseif event == "timer" and event == timer then
                -- Timeout, continue
            end
        end
        
        -- Small delay if no events
        if not has_event then
            sleep(0.1)
        end
    end
    
    print("Universal RTU shutdown complete")
end

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(UniversalRTU.run, UniversalRTU)
    if not success then
        print("Universal RTU crashed: " .. error)
        print("Check hardware connections and restart")
    end
end

-- Handle termination
os.pullEvent = os.pullEventRaw -- Disable Ctrl+T

-- Start RTU
term.clear()
term.setCursorPos(1, 1)
safeRun()