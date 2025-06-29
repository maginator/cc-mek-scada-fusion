-- SCADA RTU/PLC - Fuel Management Control Unit
-- Remote Terminal Unit for Mekanism Fuel System SCADA Architecture

-- RTU Configuration
local CONFIG = {
    CABLE_MODEM_SIDE = "back",        -- Cable Modem for peripheral network
    WIRELESS_MODEM_SIDE = "top",      -- Wireless Modem for SCADA Server communication
    FUEL_CHANNEL = 101,               -- Communication channel to SCADA Server
    UPDATE_INTERVAL = 2,              -- Update interval for fuel monitoring
    RTU_ID = "FUEL_RTU_01",           -- Unique RTU identifier
    
    -- Bekannte Geräte-Namen (diese werden automatisch gefunden)
    DEVICE_PATTERNS = {
        DYNAMIC_TANK = "dynamic_tank",
        ELECTROLYTIC_SEPARATOR = "electrolytic_separator",
        CHEMICAL_TANK = "chemical_tank",
        PRESSURIZED_TUBE = "pressurized_tube"
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
    
    wirelessModem.open(CONFIG.FUEL_CHANNEL)
    print("SCADA RTU - Fuel Management Control Unit started")
    print("RTU ID: " .. CONFIG.RTU_ID)
    print("Cable Modem: " .. CONFIG.CABLE_MODEM_SIDE)
    print("SCADA Channel: " .. CONFIG.FUEL_CHANNEL)
end

-- Hilfsfunktion: Finde alle Mekanism-Geräte über Cable Modem
local function findMekanismDevices()
    local devices = {}
    
    -- Alle über Cable Modem verbundenen Peripheriegeräte scannen
    local peripherals = cableModem.getNamesRemote()
    
    for _, name in ipairs(peripherals) do
        local device = cableModem.getMethodsRemote(name)
        if device then
            local peripheral_obj = cableModem.getPeripheral(name)
            
            -- Dynamic Tanks erkennen
            if string.find(name:lower(), CONFIG.DEVICE_PATTERNS.DYNAMIC_TANK) then
                devices.dynamic_tanks = devices.dynamic_tanks or {}
                table.insert(devices.dynamic_tanks, {name = name, device = peripheral_obj})
                print("Dynamic Tank gefunden: " .. name)
                
            -- Chemical Tanks erkennen  
            elseif string.find(name:lower(), CONFIG.DEVICE_PATTERNS.CHEMICAL_TANK) then
                devices.chemical_tanks = devices.chemical_tanks or {}
                table.insert(devices.chemical_tanks, {name = name, device = peripheral_obj})
                print("Chemical Tank gefunden: " .. name)
                
            -- Electrolytic Separator erkennen
            elseif string.find(name:lower(), CONFIG.DEVICE_PATTERNS.ELECTROLYTIC_SEPARATOR) then
                devices.separators = devices.separators or {}
                table.insert(devices.separators, {name = name, device = peripheral_obj})
                print("Electrolytic Separator gefunden: " .. name)
            end
        end
    end
    
    return devices
end

-- Dynamic Tank Daten lesen
local function getDynamicTankData(tank_device)
    local tank_data = {
        stored = 0,
        capacity = 0,
        chemical_type = "unknown"
    }
    
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

-- Treibstoffdaten sammeln
local function getFuelData()
    local data = {
        deuterium = 0,
        maxDeuterium = 0,
        tritium = 0,
        maxTritium = 0,
        production_rate = 0,
        separator_status = "OFFLINE",
        tank_count = 0
    }
    
    -- Alle Mekanism-Geräte über Cable Modem finden
    local devices = findMekanismDevices()
    
    -- Dynamic Tanks prüfen
    if devices.dynamic_tanks then
        for _, tank in ipairs(devices.dynamic_tanks) do
            local tank_data = getDynamicTankData(tank.device)
            data.tank_count = data.tank_count + 1
            
            if string.find(tank_data.chemical_type:lower(), "deuterium") then
                data.deuterium = tank_data.stored
                data.maxDeuterium = tank_data.capacity
                print("Dynamic Tank - Deuterium: " .. data.deuterium .. "/" .. data.maxDeuterium)
                
            elseif string.find(tank_data.chemical_type:lower(), "tritium") then
                data.tritium = tank_data.stored  
                data.maxTritium = tank_data.capacity
                print("Dynamic Tank - Tritium: " .. data.tritium .. "/" .. data.maxTritium)
            end
        end
    end
    
    -- Normale Chemical Tanks als Fallback
    if devices.chemical_tanks then
        for _, tank in ipairs(devices.chemical_tanks) do
            local success, tanks = pcall(tank.device.getChemicalTanks)
            if success and tanks then
                for _, chemical_tank in ipairs(tanks) do
                    local chemical = chemical_tank.stored
                    if chemical and chemical.name then
                        if string.find(chemical.name:lower(), "deuterium") and data.deuterium == 0 then
                            data.deuterium = chemical.amount or 0
                            data.maxDeuterium = chemical_tank.capacity or 0
                            print("Chemical Tank - Deuterium: " .. data.deuterium .. "/" .. data.maxDeuterium)
                            
                        elseif string.find(chemical.name:lower(), "tritium") and data.tritium == 0 then
                            data.tritium = chemical.amount or 0
                            data.maxTritium = chemical_tank.capacity or 0
                            print("Chemical Tank - Tritium: " .. data.tritium .. "/" .. data.maxTritium)
                        end
                    end
                end
            end
        end
    end
    
    -- Electrolytic Separator Status prüfen
    if devices.separators then
        for _, separator in ipairs(devices.separators) do
            local success, energy = pcall(separator.device.getEnergyNeeded)
            if success and energy then
                data.separator_status = energy > 0 and "RUNNING" or "IDLE"
                
                -- Produktionsrate schätzen
                local success2, energyUsage = pcall(separator.device.getEnergyUsage)
                if success2 and energyUsage then
                    data.production_rate = energyUsage / 1000
                end
                break
            end
        end
    end
    
    return data
end

-- Nachrichten verarbeiten
local function handleMessage(message)
    if not message or not message.command then return end
    
    if message.command == "status" then
        -- Status-Anfrage vom Hauptcontroller
        local fuelData = getFuelData()
        
        wirelessModem.transmit(CONFIG.FUEL_CHANNEL, CONFIG.FUEL_CHANNEL, {
            type = "fuel_status",
            rtu_id = CONFIG.RTU_ID,
            data = fuelData,
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
            local fuelData = getFuelData()
            
            wirelessModem.transmit(CONFIG.FUEL_CHANNEL, CONFIG.FUEL_CHANNEL, {
                type = "fuel_status",
                rtu_id = CONFIG.RTU_ID,
                data = fuelData,
                timestamp = os.epoch("utc")
            })
            
            updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
            
        elseif event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            if channel == CONFIG.FUEL_CHANNEL then
                handleMessage(message)
            end
            
        elseif event == "key" and p1 == keys.q then
            running = false
        end
    end
    
    wirelessModem.close(CONFIG.FUEL_CHANNEL)
    print("Treibstoff-Monitor beendet")
end

-- Fehlerbehandlung
local function safeMain()
    local success, error = pcall(main)
    if not success then
        print("Fehler: " .. error)
    end
end

print("=== SCADA RTU/PLC - FUEL MANAGEMENT CONTROL UNIT ===")
print("RTU ID: " .. CONFIG.RTU_ID)
print("Searching for Mekanism Fuel Devices via Cable Modem...")
print("Press 'q' to shutdown")

safeMain()