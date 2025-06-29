-- SCADA RTU/PLC - Laser Control Unit
-- Remote Terminal Unit for Mekanism Fusion Laser SCADA System

-- RTU Configuration
local CONFIG = {
    CABLE_MODEM_SIDE = "back",        -- Cable Modem for peripheral network
    WIRELESS_MODEM_SIDE = "top",      -- Wireless Modem for SCADA Server communication
    LASER_CHANNEL = 103,              -- Communication channel to SCADA Server
    UPDATE_INTERVAL = 1,              -- Fast update interval for laser control
    RTU_ID = "LASER_RTU_01",          -- Unique RTU identifier
    
    -- Geräte-Patterns
    DEVICE_PATTERNS = {
        LASER = "laser",
        LASER_AMPLIFIER = "laser_amplifier",
        LASER_TRACTOR_BEAM = "laser_tractor_beam"
    },
    
    -- Laser-Konfiguration
    MIN_ENERGY_TO_ACTIVATE = 1000000,  -- Mindest-Energie für Laser-Aktivierung
    LASER_FOCUS_TARGET = "fusion_reactor" -- Standard-Ziel für Laser
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
    
    wirelessModem.open(CONFIG.LASER_CHANNEL)
    print("SCADA RTU - Laser Control Unit started")
    print("RTU ID: " .. CONFIG.RTU_ID)
    print("Cable Modem: " .. CONFIG.CABLE_MODEM_SIDE)
    print("SCADA Channel: " .. CONFIG.LASER_CHANNEL)
end

-- Laser-Geräte finden
local function findLasers()
    local lasers = {}
    local peripherals = cableModem.getNamesRemote()
    
    for _, name in ipairs(peripherals) do
        for pattern_name, pattern in pairs(CONFIG.DEVICE_PATTERNS) do
            if string.find(name:lower(), pattern) then
                local device = cableModem.getPeripheral(name)
                table.insert(lasers, {
                    name = name,
                    device = device,
                    type = pattern_name
                })
                print("Laser Device gefunden: " .. name .. " (" .. pattern_name .. ")")
                break
            end
        end
    end
    
    return lasers
end

-- Einzelnes Laser-Device auslesen
local function getLaserData(laser)
    local data = {
        status = "OFFLINE",
        energy = 0,
        maxEnergy = 0,
        redstone_signal = false,
        type = laser.type,
        canFire = false
    }
    
    local device = laser.device
    
    -- Energie-Level
    local success1, energy = pcall(device.getEnergyStored)
    if success1 then
        data.energy = energy
    end
    
    local success2, maxEnergy = pcall(device.getMaxEnergyStored)
    if success2 then
        data.maxEnergy = maxEnergy
    end
    
    -- Status basierend auf Energie
    if data.energy >= CONFIG.MIN_ENERGY_TO_ACTIVATE then
        data.canFire = true
        data.status = "READY"
    elseif data.energy > 0 then
        data.status = "CHARGING"
    else
        data.status = "NO_POWER"
    end
    
    -- Redstone-Signal prüfen (falls Laser über Redstone gesteuert wird)
    local success3, redstone = pcall(device.getRedstoneOutput)
    if success3 then
        data.redstone_signal = redstone > 0
        if data.redstone_signal and data.canFire then
            data.status = "ACTIVE"
        end
    end
    
    return data
end

-- Alle Laser-Daten sammeln
local function getLaserSystemData()
    local data = {
        status = "OFFLINE",
        totalEnergy = 0,
        maxTotalEnergy = 0,
        readyLasers = 0,
        totalLasers = 0,
        lasers = {}
    }
    
    local lasers = findLasers()
    
    for _, laser in ipairs(lasers) do
        local laserData = getLaserData(laser)
        
        -- Gesamtwerte akkumulieren
        data.totalEnergy = data.totalEnergy + laserData.energy
        data.maxTotalEnergy = data.maxTotalEnergy + laserData.maxEnergy
        data.totalLasers = data.totalLasers + 1
        
        if laserData.canFire then
            data.readyLasers = data.readyLasers + 1
        end
        
        -- Einzelne Laser-Info speichern
        table.insert(data.lasers, {
            name = laser.name,
            type = laserData.type,
            status = laserData.status,
            energy = laserData.energy,
            maxEnergy = laserData.maxEnergy,
            percentage = laserData.maxEnergy > 0 and (laserData.energy / laserData.maxEnergy * 100) or 0
        })
        
        print(laser.name .. ": " .. laserData.status .. " (" .. math.floor(laserData.energy) .. " FE)")
    end
    
    -- Gesamt-Status bestimmen
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

-- Laser-Steuerung
local function controlLaser(command)
    local lasers = findLasers()
    local success_count = 0
    
    for _, laser in ipairs(lasers) do
        local device = laser.device
        
        if command == "activate" then
            -- Laser aktivieren (über Redstone oder direkte Methode)
            local success1, result1 = pcall(device.setRedstoneOutput, 15)
            if success1 then
                success_count = success_count + 1
                print("Laser aktiviert: " .. laser.name)
            else
                -- Versuche alternative Aktivierungsmethode
                local success2, result2 = pcall(device.activate)
                if success2 then
                    success_count = success_count + 1
                    print("Laser aktiviert (alt): " .. laser.name)
                else
                    print("Fehler beim Aktivieren von " .. laser.name .. ": " .. tostring(result2))
                end
            end
            
        elseif command == "deactivate" then
            -- Laser deaktivieren
            local success1, result1 = pcall(device.setRedstoneOutput, 0)
            if success1 then
                success_count = success_count + 1
                print("Laser deaktiviert: " .. laser.name)
            else
                -- Versuche alternative Deaktivierungsmethode
                local success2, result2 = pcall(device.deactivate)
                if success2 then
                    success_count = success_count + 1
                    print("Laser deaktiviert (alt): " .. laser.name)
                else
                    print("Fehler beim Deaktivieren von " .. laser.name .. ": " .. tostring(result2))
                end
            end
            
        elseif command == "pulse" then
            -- Kurzer Laser-Puls (aktivieren, kurz warten, deaktivieren)
            local success1, result1 = pcall(device.setRedstoneOutput, 15)
            if success1 then
                sleep(0.1) -- 100ms Puls
                local success2, result2 = pcall(device.setRedstoneOutput, 0)
                if success2 then
                    success_count = success_count + 1
                    print("Laser-Puls ausgeführt: " .. laser.name)
                end
            end
        end
    end
    
    return success_count > 0
end

-- Nachrichten verarbeiten
local function handleMessage(message)
    if not message or not message.command then return end
    
    if message.command == "status" then
        -- Status-Anfrage vom Hauptcontroller
        local laserData = getLaserSystemData()
        
        wirelessModem.transmit(CONFIG.LASER_CHANNEL, CONFIG.LASER_CHANNEL, {
            type = "laser_status",
            rtu_id = CONFIG.RTU_ID,
            data = laserData,
            timestamp = os.epoch("utc")
        })
        
    elseif message.command == "activate" then
        local success = controlLaser("activate")
        
        wirelessModem.transmit(CONFIG.LASER_CHANNEL, CONFIG.LASER_CHANNEL, {
            type = "command_response",
            rtu_id = CONFIG.RTU_ID,
            command = "activate",
            success = success,
            timestamp = os.epoch("utc")
        })
        
    elseif message.command == "deactivate" then
        local success = controlLaser("deactivate")
        
        wirelessModem.transmit(CONFIG.LASER_CHANNEL, CONFIG.LASER_CHANNEL, {
            type = "command_response",
            rtu_id = CONFIG.RTU_ID,
            command = "deactivate",
            success = success,
            timestamp = os.epoch("utc")
        })
        
    elseif message.command == "pulse" then
        local success = controlLaser("pulse")
        
        wirelessModem.transmit(CONFIG.LASER_CHANNEL, CONFIG.LASER_CHANNEL, {
            type = "command_response",
            rtu_id = CONFIG.RTU_ID,
            command = "pulse",
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
            local laserData = getLaserSystemData()
            
            wirelessModem.transmit(CONFIG.LASER_CHANNEL, CONFIG.LASER_CHANNEL, {
                type = "laser_status",
                rtu_id = CONFIG.RTU_ID,
                data = laserData,
                timestamp = os.epoch("utc")
            })
            
            -- Debug-Output
            print("Laser System: " .. laserData.status .. 
                  " | Ready: " .. laserData.readyLasers .. "/" .. laserData.totalLasers ..
                  " | Energy: " .. math.floor(laserData.totalEnergy) .. " FE")
            
            updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
            
        elseif event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            if channel == CONFIG.LASER_CHANNEL then
                handleMessage(message)
            end
            
        elseif event == "key" and p1 == keys.q then
            running = false
        end
    end
    
    wirelessModem.close(CONFIG.LASER_CHANNEL)
    print("Fusion Laser Control beendet")
end

-- Fehlerbehandlung
local function safeMain()
    local success, error = pcall(main)
    if not success then
        print("Fehler: " .. error)
    end
end

print("=== SCADA RTU/PLC - LASER CONTROL UNIT ===")
print("RTU ID: " .. CONFIG.RTU_ID)
print("Searching for Laser Devices via Cable Modem...")
print("Press 'q' to shutdown")

safeMain()