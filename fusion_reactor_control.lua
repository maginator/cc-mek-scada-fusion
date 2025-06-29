-- Mekanism Fusion Reactor Control System
-- Für CCTweaked Computer mit Wireless Modems

-- Konfiguration
local CONFIG = {
    MONITOR_SIDE = "top",           -- Seite des Monitors
    MODEM_SIDE = "back",           -- Seite des Wireless Modems
    REACTOR_CHANNEL = 100,         -- Kanal für Reactor-Kommunikation
    FUEL_CHANNEL = 101,            -- Kanal für Treibstoff-Systeme
    ENERGY_CHANNEL = 102,          -- Kanal für Energiespeicher
    LASER_CHANNEL = 103,           -- Kanal für Laser-Steuerung
    UPDATE_INTERVAL = 1,           -- Update-Intervall in Sekunden
    COLORS = {
        BG = colors.black,
        TEXT = colors.white,
        HEADER = colors.lightBlue,
        SUCCESS = colors.green,
        WARNING = colors.orange,
        ERROR = colors.red,
        INACTIVE = colors.gray
    }
}

-- Globale Variablen
local monitor = nil
local modem = nil
local reactorData = {}
local fuelData = {}
local energyData = {}
local laserData = {}
local currentScreen = "main"
local running = true

-- Initialisierung
local function init()
    -- Monitor initialisieren
    monitor = peripheral.wrap(CONFIG.MONITOR_SIDE)
    if not monitor then
        error("Kein Monitor gefunden auf Seite: " .. CONFIG.MONITOR_SIDE)
    end
    
    -- Wireless Modem initialisieren
    modem = peripheral.wrap(CONFIG.MODEM_SIDE)
    if not modem then
        error("Kein Wireless Modem gefunden auf Seite: " .. CONFIG.MODEM_SIDE)
    end
    
    -- Kanäle öffnen
    modem.open(CONFIG.REACTOR_CHANNEL)
    modem.open(CONFIG.FUEL_CHANNEL)
    modem.open(CONFIG.ENERGY_CHANNEL)
    modem.open(CONFIG.LASER_CHANNEL)
    
    -- Monitor konfigurieren
    monitor.setBackgroundColor(CONFIG.COLORS.BG)
    monitor.setTextColor(CONFIG.COLORS.TEXT)
    monitor.clear()
    monitor.setTextScale(0.5)
    
    print("System initialisiert!")
end

-- Utility-Funktionen
local function formatNumber(num)
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

local function getPercentage(current, max)
    if max == 0 then return 0 end
    return math.floor((current / max) * 100)
end

local function drawProgressBar(mon, x, y, width, percentage, color)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(CONFIG.COLORS.INACTIVE)
    mon.write(string.rep(" ", width))
    
    local filled = math.floor((percentage / 100) * width)
    if filled > 0 then
        mon.setCursorPos(x, y)
        mon.setBackgroundColor(color)
        mon.write(string.rep(" ", filled))
    end
    
    mon.setBackgroundColor(CONFIG.COLORS.BG)
    mon.setCursorPos(x + math.floor(width/2) - 1, y)
    mon.setTextColor(CONFIG.COLORS.TEXT)
    mon.write(percentage .. "%")
end

-- Kommunikationsfunktionen
local function sendCommand(channel, command, data)
    modem.transmit(channel, channel, {
        command = command,
        data = data,
        timestamp = os.epoch("utc")
    })
end

local function processMessage(channel, message)
    if not message or not message.data then return end
    
    if channel == CONFIG.REACTOR_CHANNEL then
        reactorData = message.data
    elseif channel == CONFIG.FUEL_CHANNEL then
        fuelData = message.data
    elseif channel == CONFIG.ENERGY_CHANNEL then
        energyData = message.data
    elseif channel == CONFIG.LASER_CHANNEL then
        laserData = message.data
    end
end

-- GUI-Funktionen
local function drawHeader(mon)
    local w, h = mon.getSize()
    
    mon.setBackgroundColor(CONFIG.COLORS.HEADER)
    mon.setTextColor(CONFIG.COLORS.TEXT)
    mon.setCursorPos(1, 1)
    mon.write(string.rep(" ", w))
    
    local title = "MEKANISM FUSION REACTOR CONTROL v1.0"
    mon.setCursorPos(math.floor((w - #title) / 2) + 1, 1)
    mon.write(title)
    
    mon.setBackgroundColor(CONFIG.COLORS.BG)
end

local function drawMainScreen(mon)
    local w, h = mon.getSize()
    
    -- Header
    drawHeader(mon)
    
    -- Reactor Status
    mon.setTextColor(CONFIG.COLORS.TEXT)
    mon.setCursorPos(2, 3)
    mon.write("FUSION REACTOR STATUS:")
    
    local reactorStatus = reactorData.status or "UNBEKANNT"
    local statusColor = CONFIG.COLORS.INACTIVE
    if reactorStatus == "RUNNING" then
        statusColor = CONFIG.COLORS.SUCCESS
    elseif reactorStatus == "HEATING" then
        statusColor = CONFIG.COLORS.WARNING
    elseif reactorStatus == "ERROR" then
        statusColor = CONFIG.COLORS.ERROR
    end
    
    mon.setCursorPos(2, 4)
    mon.setTextColor(statusColor)
    mon.write("Status: " .. reactorStatus)
    
    -- Temperatur
    mon.setTextColor(CONFIG.COLORS.TEXT)
    mon.setCursorPos(2, 5)
    local temp = reactorData.temperature or 0
    local maxTemp = reactorData.maxTemperature or 100000000
    mon.write("Temperatur: " .. formatNumber(temp) .. "K / " .. formatNumber(maxTemp) .. "K")
    
    -- Temperatur-Balken
    local tempPercent = getPercentage(temp, maxTemp)
    local tempColor = CONFIG.COLORS.SUCCESS
    if tempPercent > 80 then
        tempColor = CONFIG.COLORS.ERROR
    elseif tempPercent > 60 then
        tempColor = CONFIG.COLORS.WARNING
    end
    drawProgressBar(mon, 2, 6, 30, tempPercent, tempColor)
    
    -- Energie-Output
    mon.setTextColor(CONFIG.COLORS.TEXT)
    mon.setCursorPos(2, 8)
    local energyOutput = reactorData.energyOutput or 0
    mon.write("Energie-Output: " .. formatNumber(energyOutput) .. " FE/t")
    
    -- Treibstoff-Status
    mon.setCursorPos(2, 10)
    mon.write("TREIBSTOFF STATUS:")
    
    local deuterium = fuelData.deuterium or 0
    local maxDeuterium = fuelData.maxDeuterium or 1000
    local tritium = fuelData.tritium or 0
    local maxTritium = fuelData.maxTritium or 1000
    
    mon.setCursorPos(2, 11)
    mon.write("Deuterium: " .. formatNumber(deuterium) .. " / " .. formatNumber(maxDeuterium))
    local deutPercent = getPercentage(deuterium, maxDeuterium)
    drawProgressBar(mon, 2, 12, 25, deutPercent, CONFIG.COLORS.SUCCESS)
    
    mon.setCursorPos(2, 13)
    mon.write("Tritium: " .. formatNumber(tritium) .. " / " .. formatNumber(maxTritium))
    local tritPercent = getPercentage(tritium, maxTritium)
    drawProgressBar(mon, 2, 14, 25, tritPercent, CONFIG.COLORS.SUCCESS)
    
    -- Energiespeicher-Status
    mon.setCursorPos(35, 3)
    mon.write("ENERGIESPEICHER:")
    
    local storedEnergy = energyData.stored or 0
    local maxEnergy = energyData.maxStored or 1000000
    mon.setCursorPos(35, 4)
    mon.write("Gespeichert: " .. formatNumber(storedEnergy) .. " FE")
    mon.setCursorPos(35, 5)
    mon.write("Kapazität: " .. formatNumber(maxEnergy) .. " FE")
    
    local energyPercent = getPercentage(storedEnergy, maxEnergy)
    drawProgressBar(mon, 35, 6, 25, energyPercent, CONFIG.COLORS.SUCCESS)
    
    -- Laser-Status
    mon.setCursorPos(35, 8)
    mon.write("FUSION LASER:")
    
    local laserStatus = laserData.status or "OFFLINE"
    local laserColor = laserStatus == "ACTIVE" and CONFIG.COLORS.SUCCESS or CONFIG.COLORS.INACTIVE
    
    mon.setCursorPos(35, 9)
    mon.setTextColor(laserColor)
    mon.write("Status: " .. laserStatus)
    
    mon.setTextColor(CONFIG.COLORS.TEXT)
    mon.setCursorPos(35, 10)
    local laserEnergy = laserData.energy or 0
    mon.write("Energie: " .. formatNumber(laserEnergy) .. " FE")
    
    -- Steuerungsbuttons
    mon.setBackgroundColor(CONFIG.COLORS.SUCCESS)
    mon.setTextColor(CONFIG.COLORS.TEXT)
    mon.setCursorPos(2, h-3)
    mon.write(" START REACTOR ")
    
    mon.setBackgroundColor(CONFIG.COLORS.ERROR)
    mon.setCursorPos(18, h-3)
    mon.write(" STOP REACTOR ")
    
    mon.setBackgroundColor(CONFIG.COLORS.WARNING)
    mon.setCursorPos(32, h-3)
    mon.write(" ACTIVATE LASER ")
    
    mon.setBackgroundColor(CONFIG.COLORS.INACTIVE)
    mon.setCursorPos(49, h-3)
    mon.write(" SETTINGS ")
    
    mon.setBackgroundColor(CONFIG.COLORS.BG)
end

local function handleTouch(x, y)
    local w, h = monitor.getSize()
    
    -- Button-Bereiche definieren
    if y == h-3 then
        if x >= 2 and x <= 15 then
            -- Start Reactor
            sendCommand(CONFIG.REACTOR_CHANNEL, "start", {})
            print("Reactor-Start-Befehl gesendet")
        elseif x >= 18 and x <= 30 then
            -- Stop Reactor
            sendCommand(CONFIG.REACTOR_CHANNEL, "stop", {})
            print("Reactor-Stop-Befehl gesendet")
        elseif x >= 32 and x <= 47 then
            -- Activate Laser
            sendCommand(CONFIG.LASER_CHANNEL, "activate", {})
            print("Laser-Aktivierungs-Befehl gesendet")
        elseif x >= 49 and x <= 58 then
            -- Settings (nicht implementiert)
            print("Settings noch nicht implementiert")
        end
    end
end

-- Datenabfrage-Funktionen
local function requestData()
    sendCommand(CONFIG.REACTOR_CHANNEL, "status", {})
    sendCommand(CONFIG.FUEL_CHANNEL, "status", {})
    sendCommand(CONFIG.ENERGY_CHANNEL, "status", {})
    sendCommand(CONFIG.LASER_CHANNEL, "status", {})
end

-- Hauptloop
local function main()
    init()
    
    -- Timer für regelmäßige Updates
    local updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
    
    while running do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        if event == "timer" and p1 == updateTimer then
            -- Daten aktualisieren
            requestData()
            
            -- Bildschirm neu zeichnen
            monitor.clear()
            if currentScreen == "main" then
                drawMainScreen(monitor)
            end
            
            -- Neuen Timer starten
            updateTimer = os.startTimer(CONFIG.UPDATE_INTERVAL)
            
        elseif event == "monitor_touch" and p1 == CONFIG.MONITOR_SIDE then
            -- Touch-Event verarbeiten
            handleTouch(p2, p3)
            
        elseif event == "modem_message" then
            -- Wireless-Nachricht verarbeiten
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            processMessage(channel, message)
            
        elseif event == "key" and p1 == keys.q then
            -- Programm beenden mit 'q'
            running = false
        end
    end
    
    -- Cleanup
    modem.closeAll()
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("System heruntergefahren")
end

-- Fehlerbehandlung
local function safeMain()
    local success, error = pcall(main)
    if not success then
        print("Fehler: " .. error)
        if monitor then
            monitor.clear()
            monitor.setCursorPos(1, 1)
            monitor.setTextColor(CONFIG.COLORS.ERROR)
            monitor.write("SYSTEM FEHLER:")
            monitor.setCursorPos(1, 2)
            monitor.write(error)
        end
    end
end

-- Programm starten
print("Mekanism Fusion Reactor Control System")
print("Drücken Sie 'q' zum Beenden")
print("Starte System...")

safeMain()