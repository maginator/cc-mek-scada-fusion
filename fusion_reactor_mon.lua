-- SCADA RTU/PLC - Fusion Reactor Control Unit
-- Remote Terminal Unit for Mekanism Fusion Reactor SCADA System

-- RTU Configuration
local CONFIG = {
    CABLE_MODEM_SIDE = "back",        -- Cable Modem for peripheral network
    WIRELESS_MODEM_SIDE = "top",      -- Wireless Modem for SCADA Server communication
    REACTOR_CHANNEL = 100,            -- Communication channel to SCADA Server
    UPDATE_INTERVAL = 1,              -- Fast update interval for reactor control
    RTU_ID = "REACTOR_RTU_01",        -- Unique RTU identifier
    
    -- Geräte-Patterns
    DEVICE_PATTERNS = {
        FUSION_REACTOR = "fusion_reactor",
        REACTOR_CONTROLLER = "reactor_controller", 
        REACTOR_FRAME = "reactor_frame",
        REACTOR_GLASS = "reactor_glass"
    }
}

local cableModem = nil
local wirelessModem = nil
local running = true

-- Initialisierung
local function init()
    -- Cable Modem für Peripherie-Netzwerk
    cableModem = peripheral.wrap(CONFIG.CABLE_MODEM_SIDE)
    if not cableModem then
        error("Kein Cable Modem gefunden auf Seite: " .. CONFIG.CABLE_MODEM_SIDE)
    end
    
    -- Wireless Modem für Hauptcontroller-Kommunikation
    wirelessModem = peripheral.wrap(CONFIG.WIRELESS_MODEM_SIDE)
    if not wirelessModem then
        error("Kein Wireless Modem gefunden auf Seite: " .. CONFIG.WIRELESS_MODEM_SIDE)
    end
    
    wirelessModem.open(CONFIG.REACTOR_CHANNEL)
    print("SCADA RTU - Reactor Control Unit started")
    print("RTU ID: " .. CONFIG.RTU_ID)
    print("Cable Modem: " .. CONFIG.CABLE_MODEM_SIDE)
    print("SCADA Channel: " .. CONFIG.REACTOR_CHANNEL)
end

-- Fusion Reactor finden
local function findFusionReactor()
    local reactor = nil
    local peripherals = cableModem.getNamesRemote()
    
    for _, name in ipairs(peripherals) do
        if string.find(name:lower(), CONFIG.DEVICE_PATTERNS.FUSION_REACTOR) or
           string.find(name:lower(), CONFIG.DEVICE_PATTERNS.REACTOR_CONTROLLER) then
            reactor = cableModem.getPeripheral(name)
            print("Fusion Reactor gefunden: " .. name)
            break
        end
    end
    
    return reactor
end

-- Reactor-Daten sammeln
local function getReactorData()
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
    
    local reactor = findFusionReactor()
    if not reactor then
        print("Kein Fusion Reactor gefunden!")
        return data
    end
    
    -- Reactor-Status prüfen
    local success, formed = pcall(reactor.isFormed)
    if success then
        data.formed = formed
        
        if formed then
            -- Ignition Status
            local success2, ignited = pcall(reactor.isIgnited)
            if success2 then
                data.ignited = ignited
                data.status = ignited and "RUNNING" or "FORMED"
            end
            
            -- Temperaturen
            local success3, plasmaTemp = pcall(reactor.getPlasmaTemperature)
            if success3 then
                data.plasmaTemperature = plasmaTemp
                data.temperature = plasmaTemp -- Haupt-Temperatur für Anzeige
            end
            
            local success4, caseTemp = pcall(reactor.getCaseTemperature)
            if success4 then
                data.caseTemperature = caseTemp
            end
            
            -- Energie-Output
            local success5, energyOutput = pcall(reactor.getProductionRate)
            if success5 then
                data.energyOutput = energyOutput
            end
            
            -- Injection Rate
            local success6, injectionRate = pcall(reactor.getInjectionRate)
            if success6 then
                data.injectionRate = injectionRate
            end
            
            -- Energie-Speicher im Reactor
            local success7, stored = pcall(reactor.getEnergyStored)
            if success7 then
                data.stored = stored
            end
            
            local success8, capacity = pcall(reactor.getMaxEnergyStored)
            if success8 then
                data.capacity = capacity
            end
            
        else
            data.status = "NOT_FORMED"
        end
    end
    
    return data
end

-- Reactor-Steuerung
local function controlReactor(command)
    local reactor = findFusionReactor()
    if not reactor then
        print("Kein Fusion Reactor für Steuerung gefunden!")
        return false
    end
    
    if command == "start" then
        local success, result = pcall(reactor.activate)
        if success then
            print("Reactor-Start-Befehl ausgeführt")
            return true
        else
            print("Fehler beim Reactor-Start: " .. tostring(result))
        end
        
    elseif command == "stop" then
        local success, result = pcall(reactor.deactivate)
        if success then
            print("Reactor-Stop-Befehl ausgeführt")
            return true
        else
            print("Fehler beim Reactor-Stop: " .. tostring(result))
        end
        
    elseif command == "scram" then
        -- Notfall-Abschaltung
        local success, result = pcall(reactor.scram)
        if success then
            print("Reactor SCRAM ausgeführt!")
            return true
        else
            print("Fehler beim SCRAM: " .. tostring(result))
        end
    end
    
    return false
end

-- Nachrichten verarbeiten
local function handleMessage(message)
    if not message or not message.command then return end
    
    if message.command == "status" then
        -- Status-Anfrage vom Hauptcontroller
        local reactorData = getReactorData()
        
        wirelessModem.transmit(CONFIG.REACTOR_CHANNEL, CONFIG.REACTOR_CHANNEL, {
            type = "reactor_status",
            rtu_id = CONFIG.RTU_ID,
            data = reactorData,
            timestamp = os.epoch("utc")
        })
        
    elseif message.command == "start" then
        local success = controlReactor("start")
        
        wirelessModem.transmit(CONFIG.REACTOR_CHANNEL, CONFIG.REACTOR_CHANNEL, {
            type = "command_response",
            rtu_id = CONFIG.RTU_ID,
            command = "start",
            success = success,
            timestamp = os.epoch("utc")
        })
        
    elseif message.command == "stop" then
        local success = controlReactor("stop")
        
        wirelessModem.transmit(CONFIG.REACTOR_CHANNEL, CONFIG.REACTOR_CHANNEL, {
            type = "command_response",
            rtu_id = CONFIG.RTU_ID,
            command = "stop",
            success = success,
            timestamp = os.epoch("utc")
        })
        
    elseif message.command == "scram" then
        local success = controlReactor("scram")
        
        wirelessModem.transmit(CONFIG.REACTOR_CHANNEL, CONFIG.REACTOR_CHANNEL, {
            type = "command_response", 
            rtu_id = CONFIG.RTU_ID,
            command = "scram",
            success = success,
            timestamp = os.epoch("utc")
        })
    end
end

-- Hauptloop
local function main()
    init()
    
    local updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
    
    while running do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        if event == "timer" and p1 == updateTimer then
            -- Automatische Status-Updates senden
            local reactorData = getReactorData()
            
            wirelessModem.transmit(CONFIG.REACTOR_CHANNEL, CONFIG.REACTOR_CHANNEL, {
                type = "reactor_status",
                rtu_id = CONFIG.RTU_ID,
                data = reactorData,
                timestamp = os.epoch("utc")
            })
            
            -- Debug-Output
            print("Status: " .. reactorData.status .. 
                  " | Temp: " .. math.floor(reactorData.temperature) .. "K" ..
                  " | Output: " .. math.floor(reactorData.energyOutput) .. " FE/t")
            
            updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
            
        elseif event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            if channel == CONFIG.REACTOR_CHANNEL then
                handleMessage(message)
            end
            
        elseif event == "key" and p1 == keys.q then
            running = false
        end
    end
    
    wirelessModem.close(CONFIG.REACTOR_CHANNEL)
    print("Fusion Reactor Monitor beendet")
end

-- Fehlerbehandlung
local function safeMain()
    local success, error = pcall(main)
    if not success then
        print("Fehler: " .. error)
    end
end

print("=== SCADA RTU/PLC - FUSION REACTOR CONTROL UNIT ===")
print("RTU ID: " .. CONFIG.RTU_ID)
print("Searching for Fusion Reactor via Cable Modem...")
print("Press 'q' to shutdown")

safeMain()