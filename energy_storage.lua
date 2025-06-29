-- SCADA RTU/PLC - Energy Storage Control Unit
-- Remote Terminal Unit for Mekanism Energy Storage SCADA System

-- RTU Configuration
local CONFIG = {
    CABLE_MODEM_SIDE = "back",        -- Cable Modem for peripheral network
    WIRELESS_MODEM_SIDE = "top",      -- Wireless Modem for SCADA Server communication
    ENERGY_CHANNEL = 102,             -- Communication channel to SCADA Server
    UPDATE_INTERVAL = 2,              -- Update interval for energy monitoring
    RTU_ID = "ENERGY_RTU_01",         -- Unique RTU identifier
    
    -- Geräte-Patterns
    DEVICE_PATTERNS = {
        INDUCTION_MATRIX = "induction_matrix",
        INDUCTION_CASING = "induction_casing", 
        INDUCTION_CELL = "induction_cell",
        INDUCTION_PROVIDER = "induction_provider",
        ENERGY_CUBE = "energy_cube",
        BASIC_ENERGY_CUBE = "basic_energy_cube",
        ADVANCED_ENERGY_CUBE = "advanced_energy_cube",
        ELITE_ENERGY_CUBE = "elite_energy_cube",
        ULTIMATE_ENERGY_CUBE = "ultimate_energy_cube"
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
    
    wirelessModem.open(CONFIG.ENERGY_CHANNEL)
    print("SCADA RTU - Energy Storage Control Unit started")
    print("RTU ID: " .. CONFIG.RTU_ID)
    print("Cable Modem: " .. CONFIG.CABLE_MODEM_SIDE)
    print("SCADA Channel: " .. CONFIG.ENERGY_CHANNEL)
end

-- Energiespeicher finden
local function findEnergyStorages()
    local storages = {}
    local peripherals = cableModem.getNamesRemote()
    
    for _, name in ipairs(peripherals) do
        local device_found = false
        
        -- Prüfe alle Energy Storage Patterns
        for pattern_name, pattern in pairs(CONFIG.DEVICE_PATTERNS) do
            if string.find(name:lower(), pattern) then
                local device = cableModem.getPeripheral(name)
                table.insert(storages, {
                    name = name,
                    device = device,
                    type = pattern_name
                })
                print("Energy Storage gefunden: " .. name .. " (" .. pattern_name .. ")")
                device_found = true
                break
            end
        end
    end
    
    return storages
end

-- Einzelnes Energy Storage Device auslesen
local function getStorageData(storage)
    local data = {
        stored = 0,
        capacity = 0,
        input_rate = 0,
        output_rate = 0,
        type = storage.type
    }
    
    local device = storage.device
    
    -- Energie-Level
    local success1, stored = pcall(device.getEnergyStored)
    if success1 then
        data.stored = stored
    end
    
    local success2, capacity = pcall(device.getMaxEnergyStored)
    if success2 then
        data.capacity = capacity
    end
    
    -- Input/Output Raten (falls verfügbar)
    local success3, inputRate = pcall(device.getLastInput)
    if success3 then
        data.input_rate = inputRate
    end
    
    local success4, outputRate = pcall(device.getLastOutput)
    if success4 then
        data.output_rate = outputRate
    end
    
    -- Für Induction Matrix - spezielle Methoden
    if storage.type == "INDUCTION_MATRIX" then
        local success5, transferCap = pcall(device.getTransferCap)
        if success5 then
            data.transfer_capacity = transferCap
        end
        
        local success6, formed = pcall(device.isFormed)
        if success6 then
            data.formed = formed
        end
    end
    
    return data
end

-- Alle Energiespeicher-Daten sammeln
local function getEnergyData()
    local data = {
        stored = 0,
        maxStored = 0,
        inputRate = 0,
        outputRate = 0,
        storageCount = 0,
        storages = {}
    }
    
    local storages = findEnergyStorages()
    
    for _, storage in ipairs(storages) do
        local storageData = getStorageData(storage)
        
        -- Gesamtwerte akkumulieren
        data.stored = data.stored + storageData.stored
        data.maxStored = data.maxStored + storageData.capacity
        data.inputRate = data.inputRate + storageData.input_rate
        data.outputRate = data.outputRate + storageData.output_rate
        data.storageCount = data.storageCount + 1
        
        -- Einzelne Storage-Info speichern
        table.insert(data.storages, {
            name = storage.name,
            type = storageData.type,
            stored = storageData.stored,
            capacity = storageData.capacity,
            percentage = storageData.capacity > 0 and (storageData.stored / storageData.capacity * 100) or 0
        })
        
        print(storage.name .. ": " .. math.floor(storageData.stored) .. "/" .. math.floor(storageData.capacity) .. " FE")
    end
    
    -- Gesamtprozentsatz berechnen
    data.percentage = data.maxStored > 0 and (data.stored / data.maxStored * 100) or 0
    
    return data
end

-- Nachrichten verarbeiten
local function handleMessage(message)
    if not message or not message.command then return end
    
    if message.command == "status" then
        -- Status-Anfrage vom Hauptcontroller
        local energyData = getEnergyData()
        
        wirelessModem.transmit(CONFIG.ENERGY_CHANNEL, CONFIG.ENERGY_CHANNEL, {
            type = "energy_status",
            rtu_id = CONFIG.RTU_ID,
            data = energyData,
            timestamp = os.epoch("utc")
        })
        
    elseif message.command == "details" then
        -- Detaillierte Informationen über alle Speicher
        local energyData = getEnergyData()
        
        wirelessModem.transmit(CONFIG.ENERGY_CHANNEL, CONFIG.ENERGY_CHANNEL, {
            type = "energy_details",
            rtu_id = CONFIG.RTU_ID,
            data = energyData,
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
            local energyData = getEnergyData()
            
            wirelessModem.transmit(CONFIG.ENERGY_CHANNEL, CONFIG.ENERGY_CHANNEL, {
                type = "energy_status",
                rtu_id = CONFIG.RTU_ID,
                data = energyData,
                timestamp = os.epoch("utc")
            })
            
            -- Debug-Output
            local percentage = energyData.maxStored > 0 and (energyData.stored / energyData.maxStored * 100) or 0
            print("Energy: " .. math.floor(percentage) .. "% (" .. 
                  math.floor(energyData.stored) .. "/" .. math.floor(energyData.maxStored) .. " FE)")
            
            updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
            
        elseif event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            if channel == CONFIG.ENERGY_CHANNEL then
                handleMessage(message)
            end
            
        elseif event == "key" and p1 == keys.q then
            running = false
        end
    end
    
    wirelessModem.close(CONFIG.ENERGY_CHANNEL)
    print("Energy Storage Monitor beendet")
end

-- Fehlerbehandlung
local function safeMain()
    local success, error = pcall(main)
    if not success then
        print("Fehler: " .. error)
    end
end

print("=== SCADA RTU/PLC - ENERGY STORAGE CONTROL UNIT ===")
print("RTU ID: " .. CONFIG.RTU_ID)
print("Searching for Energy Storage Devices via Cable Modem...")
print("Press 'q' to shutdown")

safeMain()