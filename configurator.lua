-- SCADA System Configurator
-- Interactive configuration setup for SCADA components

local CONFIG_FILE = "scada_config.lua"

local Configurator = {
    config = {
        -- Network Configuration
        network = {
            channels = {
                reactor = 100,
                fuel = 101,
                energy = 102,
                laser = 103,
                hmi = 104,
                alarm = 105,
                historian = 106
            },
            wireless_range = 64,
            broadcast_strength = 64
        },
        
        -- Component IDs
        components = {
            server_id = "SCADA_SERVER_01",
            hmi_id = "HMI_CLIENT_01",
            historian_id = "HISTORIAN_01"
        },
        
        -- RTU Configuration
        rtu = {
            auto_detect = true,
            update_interval = 1,
            timeout = 5
        },
        
        -- HMI Configuration
        hmi = {
            monitor_side = "auto",
            touch_enabled = true,
            screen_scale = 0.5,
            theme = "default"
        },
        
        -- Server Configuration
        server = {
            data_retention = {
                realtime = 3600,
                hourly = 604800,
                daily = 2592000
            },
            alarm_enabled = true,
            historian_enabled = true
        }
    }
}

function Configurator:detectPeripherals()
    local peripherals = {
        monitors = {},
        modems = {wireless = {}, cable = {}},
        sides = {"top", "bottom", "left", "right", "front", "back"}
    }
    
    for _, side in ipairs(peripherals.sides) do
        local peripheral_type = peripheral.getType(side)
        if peripheral_type then
            if peripheral_type == "monitor" then
                table.insert(peripherals.monitors, {side = side, type = peripheral_type})
            elseif peripheral_type == "modem" then
                local modem = peripheral.wrap(side)
                if modem then
                    if modem.isWireless() then
                        table.insert(peripherals.modems.wireless, {side = side, modem = modem})
                    else
                        table.insert(peripherals.modems.cable, {side = side, modem = modem})
                    end
                end
            end
        end
    end
    
    return peripherals
end

function Configurator:detectMekanismDevices()
    local devices = {
        reactor = {},
        energy = {},
        fuel = {},
        laser = {},
        unknown = {}
    }
    
    local peripherals = self:detectPeripherals()
    
    for _, cable_modem in ipairs(peripherals.modems.cable) do
        local modem = cable_modem.modem
        local connected_devices = modem.getNamesRemote()
        
        for _, device_name in ipairs(connected_devices) do
            local device_type = self:classifyDevice(device_name)
            table.insert(devices[device_type], {
                name = device_name,
                cable_side = cable_modem.side,
                modem = modem
            })
        end
    end
    
    return devices
end

function Configurator:classifyDevice(device_name)
    local name_lower = device_name:lower()
    
    -- Reactor devices
    if name_lower:find("fusion_reactor") or name_lower:find("reactor_controller") then
        return "reactor"
    end
    
    -- Energy storage devices
    if name_lower:find("induction_matrix") or name_lower:find("induction_casing") or 
       name_lower:find("energy_cube") or name_lower:find("induction_cell") then
        return "energy"
    end
    
    -- Fuel system devices
    if name_lower:find("dynamic_tank") or name_lower:find("chemical_tank") or
       name_lower:find("electrolytic_separator") then
        return "fuel"
    end
    
    -- Laser devices
    if name_lower:find("laser") then
        return "laser"
    end
    
    return "unknown"
end

function Configurator:showDetectedDevices()
    print("=== DETECTING HARDWARE ===")
    
    local peripherals = self:detectPeripherals()
    local devices = self:detectMekanismDevices()
    
    print("Monitors found:")
    for _, monitor in ipairs(peripherals.monitors) do
        print("  - " .. monitor.side .. " (" .. monitor.type .. ")")
    end
    
    print("\nWireless Modems found:")
    for _, modem in ipairs(peripherals.modems.wireless) do
        print("  - " .. modem.side)
    end
    
    print("\nCable Modems found:")
    for _, modem in ipairs(peripherals.modems.cable) do
        print("  - " .. modem.side)
    end
    
    print("\nMekanism Devices detected:")
    for category, device_list in pairs(devices) do
        if #device_list > 0 then
            print("  " .. category:upper() .. ":")
            for _, device in ipairs(device_list) do
                print("    - " .. device.name .. " (via " .. device.cable_side .. ")")
            end
        end
    end
    
    return peripherals, devices
end

function Configurator:configureNetwork()
    print("\n=== NETWORK CONFIGURATION ===")
    
    print("Current channel assignments:")
    for name, channel in pairs(self.config.network.channels) do
        print("  " .. name .. ": " .. channel)
    end
    
    print("\nWould you like to change channel assignments? (y/N)")
    local change_channels = read()
    
    if change_channels:lower() == "y" or change_channels:lower() == "yes" then
        print("Enter new base channel (current base: 100):")
        local base_channel = tonumber(read())
        
        if base_channel and base_channel > 0 and base_channel < 65000 then
            self.config.network.channels = {
                reactor = base_channel,
                fuel = base_channel + 1,
                energy = base_channel + 2,
                laser = base_channel + 3,
                hmi = base_channel + 4,
                alarm = base_channel + 5,
                historian = base_channel + 6
            }
            print("Channels updated!")
        else
            print("Invalid channel number, keeping defaults")
        end
    end
end

function Configurator:configureComponents(peripherals, devices)
    print("\n=== COMPONENT CONFIGURATION ===")
    
    -- Determine component type based on detected devices
    local component_type = self:determineComponentType(devices)
    
    print("Detected component type: " .. component_type:upper())
    
    if component_type == "server" then
        self:configureServer()
    elseif component_type == "hmi" then
        self:configureHMI(peripherals)
    elseif component_type == "rtu" then
        self:configureRTU(devices)
    elseif component_type == "historian" then
        self:configureHistorian()
    else
        print("Unable to auto-detect component type")
        self:manualComponentSelection()
    end
end

function Configurator:determineComponentType(devices)
    local has_devices = false
    for category, device_list in pairs(devices) do
        if category ~= "unknown" and #device_list > 0 then
            has_devices = true
            break
        end
    end
    
    local peripherals = self:detectPeripherals()
    local has_monitor = #peripherals.monitors > 0
    local has_wireless = #peripherals.modems.wireless > 0
    local has_cable = #peripherals.modems.cable > 0
    
    if has_devices and has_cable and has_wireless then
        return "rtu"
    elseif has_monitor and has_wireless then
        return "hmi"
    elseif has_wireless and not has_devices then
        return "server"
    else
        return "unknown"
    end
end

function Configurator:configureServer()
    print("Configuring SCADA Server...")
    
    print("Enter Server ID (current: " .. self.config.components.server_id .. "):")
    local server_id = read()
    if server_id ~= "" then
        self.config.components.server_id = server_id
    end
    
    print("Enable historian? (Y/n)")
    local historian = read()
    self.config.server.historian_enabled = historian:lower() ~= "n" and historian:lower() ~= "no"
    
    print("Enable alarms? (Y/n)")
    local alarms = read()
    self.config.server.alarm_enabled = alarms:lower() ~= "n" and alarms:lower() ~= "no"
end

function Configurator:configureHMI(peripherals)
    print("Configuring HMI Client...")
    
    print("Enter HMI ID (current: " .. self.config.components.hmi_id .. "):")
    local hmi_id = read()
    if hmi_id ~= "" then
        self.config.components.hmi_id = hmi_id
    end
    
    if #peripherals.monitors > 0 then
        print("Available monitors:")
        for i, monitor in ipairs(peripherals.monitors) do
            print("  " .. i .. ". " .. monitor.side)
        end
        print("Select monitor (1-" .. #peripherals.monitors .. ", or 'auto'):")
        local monitor_choice = read()
        
        if monitor_choice == "auto" then
            self.config.hmi.monitor_side = "auto"
        else
            local choice_num = tonumber(monitor_choice)
            if choice_num and choice_num >= 1 and choice_num <= #peripherals.monitors then
                self.config.hmi.monitor_side = peripherals.monitors[choice_num].side
            end
        end
    end
    
    print("Screen scale (0.5, 1.0, 1.5, 2.0) [current: " .. self.config.hmi.screen_scale .. "]:")
    local scale = tonumber(read())
    if scale and scale >= 0.5 and scale <= 2.0 then
        self.config.hmi.screen_scale = scale
    end
end

function Configurator:configureRTU(devices)
    print("Configuring RTU/PLC...")
    
    -- Determine RTU type based on detected devices
    local rtu_types = {}
    for category, device_list in pairs(devices) do
        if category ~= "unknown" and #device_list > 0 then
            table.insert(rtu_types, category)
        end
    end
    
    if #rtu_types == 1 then
        print("Auto-detected RTU type: " .. rtu_types[1]:upper())
        self.config.rtu.type = rtu_types[1]
    elseif #rtu_types > 1 then
        print("Multiple device types detected:")
        for i, rtu_type in ipairs(rtu_types) do
            print("  " .. i .. ". " .. rtu_type:upper())
        end
        print("Select primary RTU type (1-" .. #rtu_types .. "):")
        local choice = tonumber(read())
        if choice and choice >= 1 and choice <= #rtu_types then
            self.config.rtu.type = rtu_types[choice]
        end
    else
        print("No Mekanism devices detected. Manual configuration required.")
        self:manualRTUConfiguration()
        return
    end
    
    print("Enter RTU ID (e.g., REACTOR_RTU_01):")
    local rtu_id = read()
    if rtu_id ~= "" then
        self.config.rtu.id = rtu_id
    else
        self.config.rtu.id = (self.config.rtu.type or "GENERIC"):upper() .. "_RTU_01"
    end
    
    print("Update interval in seconds [current: " .. self.config.rtu.update_interval .. "]:")
    local interval = tonumber(read())
    if interval and interval > 0 then
        self.config.rtu.update_interval = interval
    end
end

function Configurator:manualRTUConfiguration()
    print("Manual RTU Configuration")
    print("Available RTU types:")
    print("  1. Reactor RTU")
    print("  2. Energy RTU") 
    print("  3. Fuel RTU")
    print("  4. Laser RTU")
    print("Select RTU type (1-4):")
    
    local choice = tonumber(read())
    local types = {"reactor", "energy", "fuel", "laser"}
    
    if choice and choice >= 1 and choice <= 4 then
        self.config.rtu.type = types[choice]
    else
        self.config.rtu.type = "generic"
    end
end

function Configurator:configureHistorian()
    print("Configuring Data Historian...")
    
    print("Enter Historian ID (current: " .. self.config.components.historian_id .. "):")
    local historian_id = read()
    if historian_id ~= "" then
        self.config.components.historian_id = historian_id
    end
    
    print("Data retention in hours - Realtime [current: " .. (self.config.server.data_retention.realtime / 3600) .. "]:")
    local realtime = tonumber(read())
    if realtime and realtime > 0 then
        self.config.server.data_retention.realtime = realtime * 3600
    end
end

function Configurator:saveConfig()
    local config_content = "-- SCADA System Configuration\n"
    config_content = config_content .. "-- Generated by SCADA Configurator\n\n"
    config_content = config_content .. "return " .. textutils.serialize(self.config)
    
    local file = fs.open(CONFIG_FILE, "w")
    if file then
        file.write(config_content)
        file.close()
        print("Configuration saved to: " .. CONFIG_FILE)
        return true
    else
        print("ERROR: Failed to save configuration")
        return false
    end
end

function Configurator:loadConfig()
    if fs.exists(CONFIG_FILE) then
        local success, loaded_config = pcall(dofile, CONFIG_FILE)
        if success and loaded_config then
            -- Merge loaded config with defaults
            for category, values in pairs(loaded_config) do
                if self.config[category] then
                    for key, value in pairs(values) do
                        self.config[category][key] = value
                    end
                else
                    self.config[category] = values
                end
            end
            print("Existing configuration loaded")
            return true
        end
    end
    print("Using default configuration")
    return false
end

function Configurator:showSummary()
    print("\n=== CONFIGURATION SUMMARY ===")
    print("Network Channels:")
    for name, channel in pairs(self.config.network.channels) do
        print("  " .. name .. ": " .. channel)
    end
    
    print("\nComponent IDs:")
    for name, id in pairs(self.config.components) do
        print("  " .. name .. ": " .. id)
    end
    
    if self.config.rtu then
        print("\nRTU Configuration:")
        print("  Type: " .. (self.config.rtu.type or "auto-detect"))
        print("  ID: " .. (self.config.rtu.id or "auto-generated"))
        print("  Update Interval: " .. self.config.rtu.update_interval .. "s")
    end
    
    if self.config.hmi then
        print("\nHMI Configuration:")
        print("  Monitor Side: " .. self.config.hmi.monitor_side)
        print("  Screen Scale: " .. self.config.hmi.screen_scale)
    end
end

function Configurator:run()
    print("=== SCADA SYSTEM CONFIGURATOR ===")
    print("Interactive setup for SCADA components\n")
    
    -- Load existing config if available
    self:loadConfig()
    
    -- Detect hardware
    local peripherals, devices = self:showDetectedDevices()
    
    print("\nPress Enter to continue with configuration...")
    read()
    
    -- Configure network
    self:configureNetwork()
    
    -- Configure components
    self:configureComponents(peripherals, devices)
    
    -- Show summary
    self:showSummary()
    
    print("\nSave configuration? (Y/n)")
    local save = read()
    if save:lower() ~= "n" and save:lower() ~= "no" then
        if self:saveConfig() then
            print("\nConfiguration complete!")
            print("You can now install and run SCADA components.")
            print("Configuration file: " .. CONFIG_FILE)
        end
    else
        print("Configuration not saved")
    end
end

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(Configurator.run, Configurator)
    if not success then
        print("CONFIGURATOR ERROR: " .. error)
        return false
    end
    return true
end

print("Starting SCADA System Configurator...")
safeRun()