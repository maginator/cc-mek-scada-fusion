-- SCADA Data Historian - Historical Data Storage and Retrieval
-- Data logging, trending, and analysis for SCADA system

local CONFIG = {
    MODEM_SIDE = "back",
    HISTORIAN_CHANNEL = 106,
    
    -- Data storage configuration
    DATA_PATH = "/scada_data/",
    
    -- Retention policies (in seconds)
    RETENTION = {
        REALTIME = 3600,        -- 1 hour of realtime data
        HOURLY = 86400 * 7,     -- 1 week of hourly averages
        DAILY = 86400 * 30,     -- 30 days of daily averages
        MONTHLY = 86400 * 365   -- 1 year of monthly data
    },
    
    -- Collection intervals
    INTERVALS = {
        REALTIME = 5,           -- 5 second intervals
        HOURLY_AGG = 60,        -- Aggregate hourly every minute
        DAILY_AGG = 3600,       -- Aggregate daily every hour
        MONTHLY_AGG = 86400     -- Aggregate monthly every day
    },
    
    -- Data types to collect
    DATA_TYPES = {
        "reactor_temperature",
        "reactor_energy_output", 
        "energy_storage_percentage",
        "fuel_deuterium_level",
        "fuel_tritium_level",
        "laser_energy_level",
        "alarm_count"
    }
}

local Historian = {
    modem = nil,
    running = true,
    
    -- Data storage
    realtime_data = {},
    hourly_data = {},
    daily_data = {},
    monthly_data = {},
    
    -- Aggregation buffers
    aggregation_buffer = {},
    
    -- Last aggregation times
    last_hourly_agg = 0,
    last_daily_agg = 0,
    last_monthly_agg = 0,
    
    -- Current data snapshot
    current_data = {}
}

function Historian:init()
    self.modem = peripheral.wrap(CONFIG.MODEM_SIDE)
    if not self.modem then
        error("No modem found on side: " .. CONFIG.MODEM_SIDE)
    end
    
    self.modem.open(CONFIG.HISTORIAN_CHANNEL)
    
    -- Initialize data storage
    for _, data_type in ipairs(CONFIG.DATA_TYPES) do
        self.realtime_data[data_type] = {}
        self.hourly_data[data_type] = {}
        self.daily_data[data_type] = {}
        self.monthly_data[data_type] = {}
        self.aggregation_buffer[data_type] = {}
    end
    
    -- Set initial aggregation times
    local current_time = os.epoch("utc") / 1000
    self.last_hourly_agg = current_time
    self.last_daily_agg = current_time
    self.last_monthly_agg = current_time
    
    -- Create data directory
    if not fs.exists(CONFIG.DATA_PATH) then
        fs.makeDir(CONFIG.DATA_PATH)
    end
    
    -- Load existing data
    self:loadHistoricalData()
    
    print("SCADA Historian initialized")
    print("Data path: " .. CONFIG.DATA_PATH)
end

function Historian:collectRealtimeData(data)
    local timestamp = os.epoch("utc") / 1000
    
    -- Extract and store relevant data points
    if data.reactor then
        self:addDataPoint("reactor_temperature", timestamp, data.reactor.temperature or 0)
        self:addDataPoint("reactor_energy_output", timestamp, data.reactor.energyOutput or 0)
    end
    
    if data.energy then
        self:addDataPoint("energy_storage_percentage", timestamp, data.energy.percentage or 0)
    end
    
    if data.fuel then
        local deut_percent = 0
        local trit_percent = 0
        
        if data.fuel.maxDeuterium and data.fuel.maxDeuterium > 0 then
            deut_percent = (data.fuel.deuterium or 0) / data.fuel.maxDeuterium * 100
        end
        
        if data.fuel.maxTritium and data.fuel.maxTritium > 0 then
            trit_percent = (data.fuel.tritium or 0) / data.fuel.maxTritium * 100
        end
        
        self:addDataPoint("fuel_deuterium_level", timestamp, deut_percent)
        self:addDataPoint("fuel_tritium_level", timestamp, trit_percent)
    end
    
    if data.laser then
        local laser_percent = 0
        if data.laser.maxTotalEnergy and data.laser.maxTotalEnergy > 0 then
            laser_percent = (data.laser.totalEnergy or 0) / data.laser.maxTotalEnergy * 100
        end
        self:addDataPoint("laser_energy_level", timestamp, laser_percent)
    end
    
    if data.alarms then
        self:addDataPoint("alarm_count", timestamp, #data.alarms)
    end
    
    -- Store current snapshot
    self.current_data = {
        timestamp = timestamp,
        data = data
    }
end

function Historian:addDataPoint(data_type, timestamp, value)
    if not self.realtime_data[data_type] then
        self.realtime_data[data_type] = {}
    end
    
    -- Add to realtime storage
    table.insert(self.realtime_data[data_type], {
        timestamp = timestamp,
        value = value
    })
    
    -- Add to aggregation buffer
    if not self.aggregation_buffer[data_type] then
        self.aggregation_buffer[data_type] = {}
    end
    
    table.insert(self.aggregation_buffer[data_type], {
        timestamp = timestamp,
        value = value
    })
    
    -- Clean old realtime data
    self:cleanOldData(self.realtime_data[data_type], CONFIG.RETENTION.REALTIME, timestamp)
end

function Historian:cleanOldData(data_array, retention_period, current_time)
    local cutoff_time = current_time - retention_period
    
    local i = 1
    while i <= #data_array do
        if data_array[i].timestamp < cutoff_time then
            table.remove(data_array, i)
        else
            break
        end
    end
end

function Historian:aggregateHourlyData()
    local current_time = os.epoch("utc") / 1000
    
    if current_time - self.last_hourly_agg < CONFIG.INTERVALS.HOURLY_AGG then
        return
    end
    
    local hour_start = math.floor(self.last_hourly_agg / 3600) * 3600
    local hour_end = hour_start + 3600
    
    for data_type, buffer in pairs(self.aggregation_buffer) do
        local hour_values = {}
        
        -- Collect values from the last hour
        for _, point in ipairs(buffer) do
            if point.timestamp >= hour_start and point.timestamp < hour_end then
                table.insert(hour_values, point.value)
            end
        end
        
        if #hour_values > 0 then
            local aggregated = self:calculateAggregates(hour_values)
            aggregated.timestamp = hour_start
            
            table.insert(self.hourly_data[data_type], aggregated)
            
            -- Clean old hourly data
            self:cleanOldData(self.hourly_data[data_type], CONFIG.RETENTION.HOURLY, current_time)
        end
        
        -- Clear processed data from buffer
        local new_buffer = {}
        for _, point in ipairs(buffer) do
            if point.timestamp >= hour_end then
                table.insert(new_buffer, point)
            end
        end
        self.aggregation_buffer[data_type] = new_buffer
    end
    
    self.last_hourly_agg = current_time
    print("Hourly aggregation completed")
end

function Historian:aggregateDailyData()
    local current_time = os.epoch("utc") / 1000
    
    if current_time - self.last_daily_agg < CONFIG.INTERVALS.DAILY_AGG then
        return
    end
    
    local day_start = math.floor(self.last_daily_agg / 86400) * 86400
    local day_end = day_start + 86400
    
    for data_type, hourly_data in pairs(self.hourly_data) do
        local day_values = {}
        
        for _, point in ipairs(hourly_data) do
            if point.timestamp >= day_start and point.timestamp < day_end then
                table.insert(day_values, point.average)
            end
        end
        
        if #day_values > 0 then
            local aggregated = self:calculateAggregates(day_values)
            aggregated.timestamp = day_start
            
            table.insert(self.daily_data[data_type], aggregated)
            
            -- Clean old daily data
            self:cleanOldData(self.daily_data[data_type], CONFIG.RETENTION.DAILY, current_time)
        end
    end
    
    self.last_daily_agg = current_time
    print("Daily aggregation completed")
end

function Historian:calculateAggregates(values)
    if #values == 0 then
        return {min = 0, max = 0, average = 0, count = 0}
    end
    
    local sum = 0
    local min_val = values[1]
    local max_val = values[1]
    
    for _, value in ipairs(values) do
        sum = sum + value
        if value < min_val then min_val = value end
        if value > max_val then max_val = value end
    end
    
    return {
        min = min_val,
        max = max_val,
        average = sum / #values,
        count = #values
    }
end

function Historian:getTrendData(data_type, period, start_time, end_time)
    local data_source = nil
    
    if period == "realtime" then
        data_source = self.realtime_data[data_type] or {}
    elseif period == "hourly" then
        data_source = self.hourly_data[data_type] or {}
    elseif period == "daily" then
        data_source = self.daily_data[data_type] or {}
    elseif period == "monthly" then
        data_source = self.monthly_data[data_type] or {}
    else
        return {}
    end
    
    local filtered_data = {}
    for _, point in ipairs(data_source) do
        if point.timestamp >= start_time and point.timestamp <= end_time then
            table.insert(filtered_data, point)
        end
    end
    
    return filtered_data
end

function Historian:saveHistoricalData()
    local filename = CONFIG.DATA_PATH .. "historian_" .. os.date("%Y%m%d") .. ".dat"
    
    local save_data = {
        hourly_data = self.hourly_data,
        daily_data = self.daily_data,
        monthly_data = self.monthly_data,
        last_hourly_agg = self.last_hourly_agg,
        last_daily_agg = self.last_daily_agg,
        last_monthly_agg = self.last_monthly_agg
    }
    
    local file = fs.open(filename, "w")
    if file then
        file.write(textutils.serialize(save_data))
        file.close()
        print("Historical data saved to: " .. filename)
    else
        print("Failed to save historical data")
    end
end

function Historian:loadHistoricalData()
    local filename = CONFIG.DATA_PATH .. "historian_" .. os.date("%Y%m%d") .. ".dat"
    
    if fs.exists(filename) then
        local file = fs.open(filename, "r")
        if file then
            local content = file.readAll()
            file.close()
            
            local success, data = pcall(textutils.unserialize, content)
            if success and data then
                self.hourly_data = data.hourly_data or {}
                self.daily_data = data.daily_data or {}
                self.monthly_data = data.monthly_data or {}
                self.last_hourly_agg = data.last_hourly_agg or 0
                self.last_daily_agg = data.last_daily_agg or 0
                self.last_monthly_agg = data.last_monthly_agg or 0
                
                print("Historical data loaded from: " .. filename)
                return
            end
        end
    end
    
    print("No existing historical data found, starting fresh")
end

function Historian:handleMessage(channel, message)
    if not message or not message.type then return end
    
    if message.type == "realtime_update" then
        self:collectRealtimeData(message.data)
        
    elseif message.type == "trend_request" then
        local trend_data = self:getTrendData(
            message.data_type,
            message.period,
            message.start_time,
            message.end_time
        )
        
        -- Send trend data back
        self.modem.transmit(CONFIG.HISTORIAN_CHANNEL, CONFIG.HISTORIAN_CHANNEL, {
            type = "trend_response",
            client_id = message.client_id,
            data_type = message.data_type,
            period = message.period,
            data = trend_data,
            timestamp = os.epoch("utc")
        })
        
    elseif message.type == "save_request" then
        self:saveHistoricalData()
    end
end

function Historian:printStatus()
    local rt_count = 0
    local hourly_count = 0
    local daily_count = 0
    
    for _, data_type in ipairs(CONFIG.DATA_TYPES) do
        rt_count = rt_count + #(self.realtime_data[data_type] or {})
        hourly_count = hourly_count + #(self.hourly_data[data_type] or {})
        daily_count = daily_count + #(self.daily_data[data_type] or {})
    end
    
    print(string.format("HISTORIAN STATUS | RT Points: %d | Hourly: %d | Daily: %d | Alarms: %d",
        rt_count, hourly_count, daily_count, self.current_data.data and #(self.current_data.data.alarms or {}) or 0))
end

function Historian:run()
    self:init()
    
    local aggregationTimer = os.startTimer(CONFIG.INTERVALS.HOURLY_AGG)
    local saveTimer = os.startTimer(300) -- Save every 5 minutes
    
    while self.running do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        if event == "timer" then
            if p1 == aggregationTimer then
                self:aggregateHourlyData()
                self:aggregateDailyData()
                self:printStatus()
                aggregationTimer = os.startTimer(CONFIG.INTERVALS.HOURLY_AGG)
                
            elseif p1 == saveTimer then
                self:saveHistoricalData()
                saveTimer = os.startTimer(300)
            end
            
        elseif event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            if channel == CONFIG.HISTORIAN_CHANNEL then
                self:handleMessage(channel, message)
            end
            
        elseif event == "key" and p1 == keys.q then
            self.running = false
        end
    end
    
    -- Final save before shutdown
    self:saveHistoricalData()
    self.modem.close(CONFIG.HISTORIAN_CHANNEL)
    print("SCADA Historian shutdown complete")
end

-- Error handling wrapper
local function safeRun()
    local success, error = pcall(Historian.run, Historian)
    if not success then
        print("Historian Error: " .. error)
    end
end

print("=== SCADA DATA HISTORIAN ===")
print("Historical data storage and trending system")
print("Press 'q' to shutdown")

safeRun()