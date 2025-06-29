-- Universal SCADA RTU/PLC - Auto-Detecting Remote Terminal Unit
-- Automatically detects and configures for reactor, energy, fuel, or laser systems

-- Load configuration if available
local config = {}
if fs.exists("scada_config.lua") then
    local success, loaded_config = pcall(dofile, "scada_config.lua")
    if success and loaded_config then
        config = loaded_config
    end
end

-- Default configuration with auto-detection
local CONFIG = {
    RTU_ID = config.rtu and config.rtu.id or "AUTO_RTU_01",
    RTU_TYPE = config.rtu and config.rtu.type or "auto",
    
    -- Communication channels (from config or defaults)
    CHANNELS = config.network and config.network.channels or {
        reactor = 100,
        fuel = 101,
        energy = 102,
        laser = 103,
        hmi = 104,
        alarm = 105
    },
    
    -- Auto-detection settings
    AUTO_DETECT = config.rtu and config.rtu.auto_detect or true,
    UPDATE_INTERVAL = config.rtu and config.rtu.update_interval or 1,
    TIMEOUT = config.rtu and config.rtu.timeout or 5,
    
    -- Device classification patterns
    DEVICE_PATTERNS = {
        reactor = {
            "fusion_reactor", "reactor_controller", "reactor_frame", "reactor_glass"
        },
        energy = {
            "induction_matrix", "induction_casing", "induction_cell", "induction_provider",
            "energy_cube", "basic_energy_cube", "advanced_energy_cube", "elite_energy_cube", "ultimate_energy_cube"
        },
        fuel = {
            "dynamic_tank", "chemical_tank", "electrolytic_separator", "pressurized_tube"
        },
        laser = {
            "laser", "laser_amplifier", "laser_tractor_beam"
        }
    }
}

local UniversalRTU = {
    -- Hardware detection
    modems = {wireless = nil, cable = nil},
    modem_sides = {wireless = nil, cable = nil},
    
    -- Component configuration
    rtu_type = nil,
    rtu_channel = nil,
    devices = {},
    
    -- Runtime state
    running = true,
    last_update = 0,
    connection_status = "INITIALIZING"
}

function UniversalRTU:init()
    print("=== UNIVERSAL SCADA RTU/PLC ===")
    print("Auto-detecting hardware and Mekanism devices...")
    
    -- Auto-detect peripheral connections
    self:detectModems()
    
    if not self.modems.wireless then
        error("No wireless modem found. RTU requires wireless modem for SCADA communication.")
    end
    
    if not self.modems.cable then
        print("WARNING: No cable modem found. RTU will operate in monitoring mode only.")
    end
    
    -- Auto-detect RTU type and devices
    if CONFIG.AUTO_DETECT then
        self:autoDetectRTUType()
    else
        self.rtu_type = CONFIG.RTU_TYPE
    end
    
    if not self.rtu_type or self.rtu_type == "auto" then
        error("Unable to determine RTU type. Please run configurator or specify RTU_TYPE manually.")
    end
    
    -- Set communication channel based on RTU type
    self.rtu_channel = CONFIG.CHANNELS[self.rtu_type]
    if not self.rtu_channel then
        error("No channel configured for RTU type: " .. self.rtu_type)
    end
    
    -- Open communication channel
    self.modems.wireless.open(self.rtu_channel)
    
    print("RTU Configuration:")
    print("  Type: " .. self.rtu_type:upper())
    print("  ID: " .. CONFIG.RTU_ID)
    print("  Channel: " .. self.rtu_channel)
    print("  Wireless Modem: " .. self.modem_sides.wireless)
    if self.modem_sides.cable then
        print("  Cable Modem: " .. self.modem_sides.cable)
    end
    
    self.connection_status = "RUNNING"
end

function UniversalRTU:detectModems()
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            local modem = peripheral.wrap(side)
            if modem then
                if modem.isWireless() then
                    self.modems.wireless = modem
                    self.modem_sides.wireless = side
                    print("Wireless modem detected: " .. side)
                else
                    self.modems.cable = modem
                    self.modem_sides.cable = side
                    print("Cable modem detected: " .. side)
                end
            end
        end
    end
end

function UniversalRTU:autoDetectRTUType()
    if not self.modems.cable then
        print("No cable modem found - cannot auto-detect RTU type")
        return
    end
    
    local connected_devices = self.modems.cable.getNamesRemote()
    local device_counts = {reactor = 0, energy = 0, fuel = 0, laser = 0}
    
    print("Scanning connected devices...")
    
    for _, device_name in ipairs(connected_devices) do
        local device_type = self:classifyDevice(device_name)
        if device_type ~= "unknown" then
            device_counts[device_type] = device_counts[device_type] + 1
            table.insert(self.devices, {
                name = device_name,
                type = device_type,
                peripheral = self.modems.cable.getPeripheral(device_name)
            })
            print("  " .. device_name .. " -> " .. device_type:upper())
        else
            print("  " .. device_name .. " -> UNKNOWN")
        end
    end
    
    -- Determine primary RTU type based on device counts
    local max_count = 0
    local primary_type = nil
    
    for device_type, count in pairs(device_counts) do
        if count > max_count then
            max_count = count
            primary_type = device_type
        end
    end
    
    if primary_type and max_count > 0 then
        self.rtu_type = primary_type
        print("Auto-detected RTU type: " .. primary_type:upper() .. " (" .. max_count .. " devices)")
        
        -- Update RTU ID to reflect detected type
        if CONFIG.RTU_ID == "AUTO_RTU_01" then
            CONFIG.RTU_ID = primary_type:upper() .. "_RTU_01"
        end
    else
        print("WARNING: No Mekanism devices detected")
        self.rtu_type = "generic"
    end
end

function UniversalRTU:classifyDevice(device_name)
    local name_lower = device_name:lower()
    
    for device_type, patterns in pairs(CONFIG.DEVICE_PATTERNS) do
        for _, pattern in ipairs(patterns) do
            if name_lower:find(pattern) then
                return device_type
            end
        end
    end
    
    return "unknown"
end

function UniversalRTU:getDevicesByType(device_type)
    local filtered_devices = {}
    for _, device in ipairs(self.devices) do
        if device.type == device_type then
            table.insert(filtered_devices, device)
        end
    end
    return filtered_devices
end

-- Reactor RTU Functions
function UniversalRTU:getReactorData()
    local data = {
        status = "OFFLINE",
        temperature = 0,
        maxTemperature = 100000000,
        energyOutput = 0,
        plasmaTemperature = 0,
        caseTemperature = 0,
        injectionRate = 0,
        formed = false,
        ignited = false,
        capacity = 0,
        stored = 0
    }
    
    local reactors = self:getDevicesByType("reactor")
    if #reactors == 0 then return data end
    
    local reactor = reactors[1].peripheral
    if not reactor then return data end
    
    local success, formed = pcall(reactor.isFormed)
    if success then
        data.formed = formed
        
        if formed then
            local success2, ignited = pcall(reactor.isIgnited)
            if success2 then
                data.ignited = ignited
                data.status = ignited and "RUNNING" or "FORMED"
            end
            
            local success3, plasmaTemp = pcall(reactor.getPlasmaTemperature)
            if success3 then
                data.plasmaTemperature = plasmaTemp
                data.temperature = plasmaTemp
            end
            
            local success4, caseTemp = pcall(reactor.getCaseTemperature)
            if success4 then
                data.caseTemperature = caseTemp
            end
            
            local success5, energyOutput = pcall(reactor.getProductionRate)
            if success5 then
                data.energyOutput = energyOutput
            end
            
            local success6, injectionRate = pcall(reactor.getInjectionRate)
            if success6 then
                data.injectionRate = injectionRate
            end
        else
            data.status = "NOT_FORMED"
        end
    end
    
    return data
end

function UniversalRTU:controlReactor(command)
    local reactors = self:getDevicesByType("reactor")
    if #reactors == 0 then return false end
    
    local reactor = reactors[1].peripheral
    if not reactor then return false end
    
    if command == "start" then
        local success, result = pcall(reactor.activate)
        return success
    elseif command == "stop" then
        local success, result = pcall(reactor.deactivate)
        return success
    elseif command == "scram" then
        local success, result = pcall(reactor.scram)
        return success
    end
    
    return false
end

-- Energy RTU Functions
function UniversalRTU:getEnergyData()
    local data = {
        stored = 0,
        maxStored = 0,
        inputRate = 0,
        outputRate = 0,
        storageCount = 0,
        storages = {}
    }
    
    local energy_devices = self:getDevicesByType("energy")
    
    for _, device in ipairs(energy_devices) do
        local storage_data = self:getStorageDeviceData(device.peripheral)
        
        data.stored = data.stored + storage_data.stored
        data.maxStored = data.maxStored + storage_data.capacity
        data.inputRate = data.inputRate + storage_data.input_rate
        data.outputRate = data.outputRate + storage_data.output_rate
        data.storageCount = data.storageCount + 1
        
        table.insert(data.storages, {
            name = device.name,
            stored = storage_data.stored,
            capacity = storage_data.capacity,
            percentage = storage_data.capacity > 0 and (storage_data.stored / storage_data.capacity * 100) or 0
        })
    end
    
    data.percentage = data.maxStored > 0 and (data.stored / data.maxStored * 100) or 0
    
    return data
end

function UniversalRTU:getStorageDeviceData(device)
    local data = {stored = 0, capacity = 0, input_rate = 0, output_rate = 0}
    
    local success1, stored = pcall(device.getEnergyStored)
    if success1 then data.stored = stored end
    
    local success2, capacity = pcall(device.getMaxEnergyStored)
    if success2 then data.capacity = capacity end
    
    local success3, inputRate = pcall(device.getLastInput)
    if success3 then data.input_rate = inputRate end
    
    local success4, outputRate = pcall(device.getLastOutput)
    if success4 then data.output_rate = outputRate end
    
    return data
end

-- Fuel RTU Functions
function UniversalRTU:getFuelData()
    local data = {
        deuterium = 0,
        maxDeuterium = 0,
        tritium = 0,
        maxTritium = 0,
        production_rate = 0,
        separator_status = "OFFLINE",
        tank_count = 0
    }
    
    local fuel_devices = self:getDevicesByType("fuel")
    
    for _, device in ipairs(fuel_devices) do
        if device.name:lower():find("dynamic_tank") then
            local tank_data = self:getDynamicTankData(device.peripheral)
            
            if tank_data.chemical_type:lower():find("deuterium") then
                data.deuterium = tank_data.stored
                data.maxDeuterium = tank_data.capacity
            elseif tank_data.chemical_type:lower():find("tritium") then
                data.tritium = tank_data.stored
                data.maxTritium = tank_data.capacity
            end
            
            data.tank_count = data.tank_count + 1
            
        elseif device.name:lower():find("separator") then
            local success, energy = pcall(device.peripheral.getEnergyNeeded)
            if success and energy then
                data.separator_status = energy > 0 and "RUNNING" or "IDLE"
            end
        end
    end
    
    return data
end

function UniversalRTU:getDynamicTankData(tank_device)
    local tank_data = {stored = 0, capacity = 0, chemical_type = "unknown"}
    
    local success, result = pcall(tank_device.getChemicalTanks)
    if success and result and result[1] then
        local tank_info = result[1]
        tank_data.capacity = tank_info.capacity or 0
        
        if tank_info.stored then
            tank_data.stored = tank_info.stored.amount or 0
            tank_data.chemical_type = tank_info.stored.name or "unknown"
        end
    end
    
    return tank_data
end

-- Laser RTU Functions
function UniversalRTU:getLaserData()
    local data = {
        status = "OFFLINE",
        totalEnergy = 0,
        maxTotalEnergy = 0,
        readyLasers = 0,
        totalLasers = 0,
        lasers = {}
    }
    
    local laser_devices = self:getDevicesByType("laser")
    
    for _, device in ipairs(laser_devices) do
        local laser_data = self:getLaserDeviceData(device.peripheral)
        
        data.totalEnergy = data.totalEnergy + laser_data.energy
        data.maxTotalEnergy = data.maxTotalEnergy + laser_data.maxEnergy
        data.totalLasers = data.totalLasers + 1
        
        if laser_data.canFire then
            data.readyLasers = data.readyLasers + 1
        end
        
        table.insert(data.lasers, {
            name = device.name,
            status = laser_data.status,
            energy = laser_data.energy,
            maxEnergy = laser_data.maxEnergy,
            percentage = laser_data.maxEnergy > 0 and (laser_data.energy / laser_data.maxEnergy * 100) or 0
        })
    end
    
    if data.readyLasers == data.totalLasers and data.totalLasers > 0 then
        data.status = "READY"
    elseif data.readyLasers > 0 then
        data.status = "PARTIAL_READY"
    elseif data.totalEnergy > 0 then
        data.status = "CHARGING"
    else
        data.status = "OFFLINE"
    end
    
    return data
end

function UniversalRTU:getLaserDeviceData(device)
    local data = {status = "OFFLINE", energy = 0, maxEnergy = 0, canFire = false}
    
    local success1, energy = pcall(device.getEnergyStored)
    if success1 then data.energy = energy end
    
    local success2, maxEnergy = pcall(device.getMaxEnergyStored)
    if success2 then data.maxEnergy = maxEnergy end
    
    if data.energy >= 1000000 then -- Min energy threshold
        data.canFire = true
        data.status = "READY"
    elseif data.energy > 0 then
        data.status = "CHARGING"
    else
        data.status = "NO_POWER"
    end
    
    return data
end

function UniversalRTU:controlLaser(command)
    local laser_devices = self:getDevicesByType("laser")
    local success_count = 0
    
    for _, device in ipairs(laser_devices) do
        local laser = device.peripheral
        
        if command == "activate" then
            local success = pcall(laser.setRedstoneOutput, 15)
            if success then success_count = success_count + 1 end
        elseif command == "deactivate" then
            local success = pcall(laser.setRedstoneOutput, 0)
            if success then success_count = success_count + 1 end
        end
    end
    
    return success_count > 0
end

-- Generic data collection based on RTU type
function UniversalRTU:collectData()
    if self.rtu_type == "reactor" then
        return self:getReactorData()
    elseif self.rtu_type == "energy" then
        return self:getEnergyData()
    elseif self.rtu_type == "fuel" then
        return self:getFuelData()
    elseif self.rtu_type == "laser" then
        return self:getLaserData()
    else
        return {status = "UNKNOWN_TYPE", type = self.rtu_type}
    end
end

-- Generic control execution
function UniversalRTU:executeCommand(command)
    if self.rtu_type == "reactor" then
        return self:controlReactor(command)
    elseif self.rtu_type == "laser" then
        return self:controlLaser(command)
    else
        return false
    end
end

function UniversalRTU:sendStatusUpdate()
    local data = self:collectData()
    
    self.modems.wireless.transmit(self.rtu_channel, self.rtu_channel, {
        type = self.rtu_type .. "_status",
        rtu_id = CONFIG.RTU_ID,
        data = data,
        timestamp = os.epoch("utc")
    })
end

function UniversalRTU:handleMessage(message)
    if not message or not message.command then return end
    
    if message.command == "status" then
        self:sendStatusUpdate()
        
    elseif message.command == "start" or message.command == "stop" or 
           message.command == "scram" or message.command == "activate" or 
           message.command == "deactivate" then
        
        local success = self:executeCommand(message.command)
        
        self.modems.wireless.transmit(self.rtu_channel, self.rtu_channel, {
            type = "command_response",
            rtu_id = CONFIG.RTU_ID,
            command = message.command,
            success = success,
            timestamp = os.epoch("utc")
        })
    end
end

function UniversalRTU:printStatus()
    local data = self:collectData()
    
    if self.rtu_type == "reactor" then
        print(string.format("REACTOR RTU | Status: %s | Temp: %dK | Output: %d FE/t",
            data.status, math.floor(data.temperature), math.floor(data.energyOutput)))
    elseif self.rtu_type == "energy" then
        print(string.format("ENERGY RTU | Storage: %d%% | Stored: %s FE | Count: %d",
            math.floor(data.percentage), self:formatNumber(data.stored), data.storageCount))
    elseif self.rtu_type == "fuel" then
        print(string.format("FUEL RTU | D: %s | T: %s | Separator: %s",
            self:formatNumber(data.deuterium), self:formatNumber(data.tritium), data.separator_status))
    elseif self.rtu_type == "laser" then
        print(string.format("LASER RTU | Status: %s | Ready: %d/%d | Energy: %s FE",
            data.status, data.readyLasers, data.totalLasers, self:formatNumber(data.totalEnergy)))
    else
        print("GENERIC RTU | Type: " .. self.rtu_type .. " | Devices: " .. #self.devices)
    end
end

function UniversalRTU:formatNumber(num)
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

function UniversalRTU:run()
    self:init()
    
    local updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
    
    while self.running do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        if event == "timer" and p1 == updateTimer then
            self:sendStatusUpdate()
            self:printStatus()
            updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
            
        elseif event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            if channel == self.rtu_channel then
                self:handleMessage(message)
            end
            
        elseif event == "key" and p1 == keys.q then
            self.running = false
        end
    end
    
    self.modems.wireless.close(self.rtu_channel)
    print("Universal RTU shutdown complete")
end

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(UniversalRTU.run, UniversalRTU)
    if not success then
        print("RTU ERROR: " .. error)
    end
end

print("Starting Universal SCADA RTU/PLC...")
print("Press 'q' to shutdown")

safeRun()