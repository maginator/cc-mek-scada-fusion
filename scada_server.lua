-- SCADA Server - Central Data Acquisition and Control System
-- Mekanism Fusion Reactor SCADA Architecture

local CONFIG = {
    MODEM_SIDE = "back",
    CHANNELS = {
        REACTOR = 100,
        FUEL = 101,
        ENERGY = 102,
        LASER = 103,
        HMI = 104,
        ALARM = 105
    },
    
    UPDATE_INTERVALS = {
        DATA_COLLECTION = 1,
        HMI_UPDATE = 0.5,
        HISTORIAN = 5,
        ALARM_CHECK = 0.5
    },
    
    DATA_RETENTION = {
        REALTIME_POINTS = 1000,
        HISTORICAL_POINTS = 10000
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
    
    -- Real-time data storage
    data = {
        reactor = {},
        fuel = {},
        energy = {},
        laser = {},
        system = {
            startup_time = os.epoch("utc"),
            last_update = 0,
            status = "INITIALIZING"
        }
    },
    
    -- Historical data storage
    historian = {
        reactor = {},
        fuel = {},
        energy = {},
        laser = {},
        alarms = {}
    },
    
    -- Active alarms
    alarms = {},
    
    -- HMI clients
    hmi_clients = {},
    
    -- RTU/PLC status
    rtu_status = {
        reactor = {last_seen = 0, online = false},
        fuel = {last_seen = 0, online = false},
        energy = {last_seen = 0, online = false},
        laser = {last_seen = 0, online = false}
    }
}

function ScadaServer:init()
    self.modem = peripheral.wrap(CONFIG.MODEM_SIDE)
    if not self.modem then
        error("No modem found on side: " .. CONFIG.MODEM_SIDE)
    end
    
    -- Open all communication channels
    for name, channel in pairs(CONFIG.CHANNELS) do
        self.modem.open(channel)
        print("Opened channel " .. channel .. " for " .. name)
    end
    
    print("SCADA Server initialized")
    print("Channels: " .. textutils.serialize(CONFIG.CHANNELS))
    
    self.data.system.status = "RUNNING"
    self.data.system.last_update = os.epoch("utc")
end

function ScadaServer:processMessage(channel, message)
    if not message or not message.type then return end
    
    local timestamp = os.epoch("utc")
    
    if channel == CONFIG.CHANNELS.REACTOR then
        if message.type == "reactor_status" then
            self.data.reactor = message.data
            self.data.reactor.timestamp = timestamp
            self.rtu_status.reactor.last_seen = timestamp
            self.rtu_status.reactor.online = true
            self:addHistoricalData("reactor", message.data)
        end
        
    elseif channel == CONFIG.CHANNELS.FUEL then
        if message.type == "fuel_status" then
            self.data.fuel = message.data
            self.data.fuel.timestamp = timestamp
            self.rtu_status.fuel.last_seen = timestamp
            self.rtu_status.fuel.online = true
            self:addHistoricalData("fuel", message.data)
        end
        
    elseif channel == CONFIG.CHANNELS.ENERGY then
        if message.type == "energy_status" then
            self.data.energy = message.data
            self.data.energy.timestamp = timestamp
            self.rtu_status.energy.last_seen = timestamp
            self.rtu_status.energy.online = true
            self:addHistoricalData("energy", message.data)
        end
        
    elseif channel == CONFIG.CHANNELS.LASER then
        if message.type == "laser_status" then
            self.data.laser = message.data
            self.data.laser.timestamp = timestamp
            self.rtu_status.laser.last_seen = timestamp
            self.rtu_status.laser.online = true
            self:addHistoricalData("laser", message.data)
        end
        
    elseif channel == CONFIG.CHANNELS.HMI then
        self:handleHMIMessage(message)
    end
end

function ScadaServer:handleHMIMessage(message)
    if message.type == "hmi_register" then
        table.insert(self.hmi_clients, {
            id = message.client_id,
            registered = os.epoch("utc")
        })
        print("HMI client registered: " .. message.client_id)
        
    elseif message.type == "command_request" then
        self:executeCommand(message.command, message.data, message.client_id)
        
    elseif message.type == "data_request" then
        self:sendDataToHMI(message.client_id, message.data_type)
    end
end

function ScadaServer:executeCommand(command, data, client_id)
    local result = {success = false, message = "Unknown command"}
    
    if command == "reactor_start" then
        self.modem.transmit(CONFIG.CHANNELS.REACTOR, CONFIG.CHANNELS.REACTOR, {
            command = "start",
            data = data,
            timestamp = os.epoch("utc")
        })
        result = {success = true, message = "Reactor start command sent"}
        
    elseif command == "reactor_stop" then
        self.modem.transmit(CONFIG.CHANNELS.REACTOR, CONFIG.CHANNELS.REACTOR, {
            command = "stop",
            data = data,
            timestamp = os.epoch("utc")
        })
        result = {success = true, message = "Reactor stop command sent"}
        
    elseif command == "reactor_scram" then
        self.modem.transmit(CONFIG.CHANNELS.REACTOR, CONFIG.CHANNELS.REACTOR, {
            command = "scram",
            data = data,
            timestamp = os.epoch("utc")
        })
        result = {success = true, message = "Emergency SCRAM executed"}
        
    elseif command == "laser_activate" then
        self.modem.transmit(CONFIG.CHANNELS.LASER, CONFIG.CHANNELS.LASER, {
            command = "activate",
            data = data,
            timestamp = os.epoch("utc")
        })
        result = {success = true, message = "Laser activation command sent"}
        
    elseif command == "laser_deactivate" then
        self.modem.transmit(CONFIG.CHANNELS.LASER, CONFIG.CHANNELS.LASER, {
            command = "deactivate",
            data = data,
            timestamp = os.epoch("utc")
        })
        result = {success = true, message = "Laser deactivation command sent"}
    end
    
    -- Send command result back to HMI
    self.modem.transmit(CONFIG.CHANNELS.HMI, CONFIG.CHANNELS.HMI, {
        type = "command_response",
        client_id = client_id,
        command = command,
        result = result,
        timestamp = os.epoch("utc")
    })
    
    -- Log command in historian
    self:addHistoricalData("commands", {
        command = command,
        data = data,
        client_id = client_id,
        result = result
    })
end

function ScadaServer:sendDataToHMI(client_id, data_type)
    local data_packet = {
        type = "data_response",
        client_id = client_id,
        timestamp = os.epoch("utc")
    }
    
    if data_type == "all" or not data_type then
        data_packet.data = {
            reactor = self.data.reactor,
            fuel = self.data.fuel,
            energy = self.data.energy,
            laser = self.data.laser,
            system = self.data.system,
            alarms = self.alarms,
            rtu_status = self.rtu_status
        }
    elseif data_type == "historical" then
        data_packet.data = {
            historian = self.historian
        }
    else
        data_packet.data = self.data[data_type] or {}
    end
    
    self.modem.transmit(CONFIG.CHANNELS.HMI, CONFIG.CHANNELS.HMI, data_packet)
end

function ScadaServer:addHistoricalData(category, data)
    if not self.historian[category] then
        self.historian[category] = {}
    end
    
    local entry = {
        timestamp = os.epoch("utc"),
        data = data
    }
    
    table.insert(self.historian[category], entry)
    
    -- Maintain historical data size limits
    if #self.historian[category] > CONFIG.DATA_RETENTION.HISTORICAL_POINTS then
        table.remove(self.historian[category], 1)
    end
end

function ScadaServer:checkAlarms()
    local current_time = os.epoch("utc")
    local new_alarms = {}
    
    -- Reactor temperature alarms
    if self.data.reactor.temperature then
        if self.data.reactor.temperature > CONFIG.ALARM_THRESHOLDS.REACTOR_TEMP_CRITICAL then
            table.insert(new_alarms, {
                id = "REACTOR_TEMP_CRITICAL",
                severity = "CRITICAL",
                message = "Reactor temperature critical: " .. math.floor(self.data.reactor.temperature) .. "K",
                timestamp = current_time
            })
        elseif self.data.reactor.temperature > CONFIG.ALARM_THRESHOLDS.REACTOR_TEMP_WARNING then
            table.insert(new_alarms, {
                id = "REACTOR_TEMP_WARNING",
                severity = "WARNING",
                message = "Reactor temperature high: " .. math.floor(self.data.reactor.temperature) .. "K",
                timestamp = current_time
            })
        end
    end
    
    -- Energy storage low alarm
    if self.data.energy.percentage and self.data.energy.percentage < CONFIG.ALARM_THRESHOLDS.ENERGY_LOW then
        table.insert(new_alarms, {
            id = "ENERGY_LOW",
            severity = "WARNING",
            message = "Energy storage low: " .. math.floor(self.data.energy.percentage) .. "%",
            timestamp = current_time
        })
    end
    
    -- Fuel low alarms
    if self.data.fuel.deuterium and self.data.fuel.maxDeuterium then
        local deut_percent = (self.data.fuel.deuterium / self.data.fuel.maxDeuterium) * 100
        if deut_percent < CONFIG.ALARM_THRESHOLDS.FUEL_LOW then
            table.insert(new_alarms, {
                id = "DEUTERIUM_LOW",
                severity = "WARNING",
                message = "Deuterium fuel low: " .. math.floor(deut_percent) .. "%",
                timestamp = current_time
            })
        end
    end
    
    -- RTU offline alarms
    for rtu_name, rtu_info in pairs(self.rtu_status) do
        if rtu_info.online and (current_time - rtu_info.last_seen) > (CONFIG.ALARM_THRESHOLDS.LASER_OFFLINE_TIME * 1000) then
            table.insert(new_alarms, {
                id = "RTU_OFFLINE_" .. rtu_name:upper(),
                severity = "ALARM",
                message = rtu_name:upper() .. " RTU offline",
                timestamp = current_time
            })
            rtu_info.online = false
        end
    end
    
    -- Update active alarms
    self.alarms = new_alarms
    
    -- Broadcast alarms to HMI clients
    if #new_alarms > 0 then
        self.modem.transmit(CONFIG.CHANNELS.ALARM, CONFIG.CHANNELS.ALARM, {
            type = "alarm_update",
            alarms = new_alarms,
            timestamp = current_time
        })
        
        -- Add to historian
        for _, alarm in ipairs(new_alarms) do
            self:addHistoricalData("alarms", alarm)
        end
    end
end

function ScadaServer:broadcastToHMI()
    local data_packet = {
        type = "realtime_update",
        data = {
            reactor = self.data.reactor,
            fuel = self.data.fuel,
            energy = self.data.energy,
            laser = self.data.laser,
            system = self.data.system,
            alarms = self.alarms,
            rtu_status = self.rtu_status
        },
        timestamp = os.epoch("utc")
    }
    
    self.modem.transmit(CONFIG.CHANNELS.HMI, CONFIG.CHANNELS.HMI, data_packet)
end

function ScadaServer:requestDataFromRTUs()
    local request = {
        command = "status",
        timestamp = os.epoch("utc")
    }
    
    self.modem.transmit(CONFIG.CHANNELS.REACTOR, CONFIG.CHANNELS.REACTOR, request)
    self.modem.transmit(CONFIG.CHANNELS.FUEL, CONFIG.CHANNELS.FUEL, request)
    self.modem.transmit(CONFIG.CHANNELS.ENERGY, CONFIG.CHANNELS.ENERGY, request)
    self.modem.transmit(CONFIG.CHANNELS.LASER, CONFIG.CHANNELS.LASER, request)
end

function ScadaServer:printStatus()
    local reactor_status = self.data.reactor.status or "UNKNOWN"
    local reactor_temp = self.data.reactor.temperature or 0
    local energy_percent = self.data.energy.percentage or 0
    local fuel_deut = self.data.fuel.deuterium or 0
    local fuel_trit = self.data.fuel.tritium or 0
    
    print(string.format("SCADA STATUS | Reactor: %s (%dK) | Energy: %d%% | Fuel: D:%d T:%d | Alarms: %d",
        reactor_status, math.floor(reactor_temp), math.floor(energy_percent), 
        math.floor(fuel_deut), math.floor(fuel_trit), #self.alarms))
end

function ScadaServer:run()
    self:init()
    
    local dataTimer = os.startTimer(CONFIG.UPDATE_INTERVALS.DATA_COLLECTION)
    local hmiTimer = os.startTimer(CONFIG.UPDATE_INTERVALS.HMI_UPDATE)
    local historianTimer = os.startTimer(CONFIG.UPDATE_INTERVALS.HISTORIAN)
    local alarmTimer = os.startTimer(CONFIG.UPDATE_INTERVALS.ALARM_CHECK)
    
    while self.running do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        if event == "timer" then
            if p1 == dataTimer then
                self:requestDataFromRTUs()
                self:printStatus()
                dataTimer = os.startTimer(CONFIG.UPDATE_INTERVALS.DATA_COLLECTION)
                
            elseif p1 == hmiTimer then
                self:broadcastToHMI()
                hmiTimer = os.startTimer(CONFIG.UPDATE_INTERVALS.HMI_UPDATE)
                
            elseif p1 == historianTimer then
                -- Periodic historian maintenance
                historianTimer = os.startTimer(CONFIG.UPDATE_INTERVALS.HISTORIAN)
                
            elseif p1 == alarmTimer then
                self:checkAlarms()
                alarmTimer = os.startTimer(CONFIG.UPDATE_INTERVALS.ALARM_CHECK)
            end
            
        elseif event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            self:processMessage(channel, message)
            
        elseif event == "key" and p1 == keys.q then
            self.running = false
        end
    end
    
    self.modem.closeAll()
    print("SCADA Server shutdown complete")
end

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(ScadaServer.run, ScadaServer)
    if not success then
        print("SCADA Server Error: " .. error)
    end
end

print("=== MEKANISM FUSION REACTOR SCADA SERVER ===")
print("Starting centralized data acquisition and control system...")
print("Press 'q' to shutdown")

safeRun()