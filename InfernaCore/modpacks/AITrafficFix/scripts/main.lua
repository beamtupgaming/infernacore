local TrafficAIFix = {}
TrafficAIFix.id = "ai_traffic_fix"

TrafficAIFix.config = {
    smoothing = {
        maxBrakePerSecond = 4.5,
        maxAccelPerSecond = 3.0,
        lowRollSpeed = 1.0,
    },
    emergency = {
        detectRadius = 60.0,
        stopRadius = 14.0,
        slowFactor = 0.35,
        memorySeconds = 2.2,
    },
    scene = {
        detectRadius = 35.0,
        heavyBrakeRadius = 10.0,
        lightBrakeRadius = 20.0,
        stopGap = 4.5,
    },
}

TrafficAIFix.state = {
    speedByVehicle = {},
    emergencySeenAt = {},
    subscriptions = {},
}

local TRAFFIC_EVENT_HOOKS = {
    vehicle = {
        "vehicle.ai.update",
        "vehicle.update",
        "traffic.vehicle.update",
    },
    traffic = {
        "traffic.tick",
        "traffic.update",
        "world.traffic.tick",
    },
}

local function subscribeTrafficHooks(api, modTag, onVehicleUpdate, onTrafficTick)
    if not (api and api.events and api.events.subscribe) then
        if api and api.log then
            api.log("[" .. modTag .. "] Warning: no event system found; verify SDK hook names")
        end
        return {}
    end

    local subscriptions = {}

    local function trySubscribe(eventNames, handler)
        for _, eventName in ipairs(eventNames) do
            local ok, token = pcall(api.events.subscribe, eventName, handler)
            if ok and token then
                table.insert(subscriptions, token)
                if api and api.log then
                    api.log("[" .. modTag .. "] subscribed to " .. eventName)
                end
                return true
            end
        end
        return false
    end

    local vehicleHooked = trySubscribe(TRAFFIC_EVENT_HOOKS.vehicle, onVehicleUpdate)
    local trafficHooked = trySubscribe(TRAFFIC_EVENT_HOOKS.traffic, onTrafficTick)

    if (not vehicleHooked) and (not trafficHooked) and api and api.log then
        api.log("[" .. modTag .. "] Warning: no compatible traffic event hooks found; verify SDK event names")
    end

    return subscriptions
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function getNow(api)
    if api and api.time and api.time.nowSeconds then
        return api.time.nowSeconds()
    end
    if os and os.clock then
        return os.clock()
    end
    return 0
end

local function getDelta(context)
    if context and context.deltaTime and context.deltaTime > 0 then
        return context.deltaTime
    end
    if context and context.dt and context.dt > 0 then
        return context.dt
    end
    return 0.1
end

local function getVehicleId(vehicle)
    if not vehicle then
        return nil
    end
    return vehicle.id or vehicle.vehicleId or vehicle.entityId
end

local function getPosition(entity)
    if not entity then
        return nil
    end
    return entity.position or entity.pos or entity.location
end

local function getSpeed(vehicle)
    if not vehicle then
        return 0
    end
    return vehicle.speed or vehicle.currentSpeed or vehicle.velocity or 0
end

local function getSpeedLimit(vehicle, context)
    if vehicle and vehicle.speedLimit then
        return vehicle.speedLimit
    end
    if context and context.speedLimit then
        return context.speedLimit
    end
    return 13.8
end

local function distance(a, b)
    if not a or not b then
        return math.huge
    end
    local ax, ay, az = a.x or 0, a.y or 0, a.z or 0
    local bx, by, bz = b.x or 0, b.y or 0, b.z or 0
    local dx = ax - bx
    local dy = ay - by
    local dz = az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function isEmergencyVehicle(vehicle)
    if not vehicle then
        return false
    end
    if vehicle.isEmergency == true then
        return true
    end
    if vehicle.tags then
        if vehicle.tags.emergency == true then
            return true
        end
        if vehicle.tags.police == true or vehicle.tags.fire == true or vehicle.tags.ambulance == true then
            return true
        end
    end
    local kind = string.lower(vehicle.type or "")
    return kind == "emergency" or kind == "police" or kind == "fire" or kind == "ambulance"
end

local function findNearestEmergency(selfVehicle, context)
    if not context then
        return math.huge
    end
    local myPos = getPosition(selfVehicle)
    if not myPos then
        return math.huge
    end
    local list = context.vehicles or context.nearbyVehicles or context.worldVehicles
    if not list then
        return math.huge
    end

    local myId = getVehicleId(selfVehicle)
    local nearest = math.huge

    for _, other in ipairs(list) do
        local otherId = getVehicleId(other)
        if otherId and otherId ~= myId and isEmergencyVehicle(other) then
            local d = distance(myPos, getPosition(other))
            if d < nearest then
                nearest = d
            end
        end
    end

    return nearest
end

local function findNearestSceneVehicle(selfVehicle, context)
    if not context then
        return math.huge
    end
    local myPos = getPosition(selfVehicle)
    if not myPos then
        return math.huge
    end

    local list = context.sceneVehicles or context.blockingVehicles or context.disabledVehicles
    if not list then
        return math.huge
    end

    local nearest = math.huge
    for _, other in ipairs(list) do
        local d = distance(myPos, getPosition(other))
        if d < nearest then
            nearest = d
        end
    end

    return nearest
end

local function setDesiredSpeed(api, vehicle, speed)
    local vehicleId = getVehicleId(vehicle)
    if not api or not vehicleId then
        return false
    end

    if api.vehicle and api.vehicle.setDesiredSpeed then
        api.vehicle.setDesiredSpeed(vehicleId, speed)
        return true
    end
    if api.setVehicleDesiredSpeed then
        api.setVehicleDesiredSpeed(vehicleId, speed)
        return true
    end
    if vehicle.setDesiredSpeed then
        vehicle.setDesiredSpeed(speed)
        return true
    end

    return false
end

local function smoothAndApply(vehicle, context, api, requested)
    local vehicleId = getVehicleId(vehicle)
    if not vehicleId then
        return
    end

    local cfg = TrafficAIFix.config.smoothing
    local dt = getDelta(context)
    local prev = TrafficAIFix.state.speedByVehicle[vehicleId] or getSpeed(vehicle)

    local delta = requested - prev
    local maxDown = -cfg.maxBrakePerSecond * dt
    local maxUp = cfg.maxAccelPerSecond * dt
    local bounded = clamp(delta, maxDown, maxUp)
    local finalSpeed = prev + bounded

    if finalSpeed > 0 and finalSpeed < cfg.lowRollSpeed then
        finalSpeed = cfg.lowRollSpeed
    end
    if requested <= 0.01 then
        finalSpeed = 0
    end

    TrafficAIFix.state.speedByVehicle[vehicleId] = finalSpeed
    setDesiredSpeed(api, vehicle, finalSpeed)
end

local function calcTargetSpeed(vehicle, context, api)
    local speedLimit = getSpeedLimit(vehicle, context)
    local current = getSpeed(vehicle)
    local target = math.min(current, speedLimit)

    local vehicleId = getVehicleId(vehicle)
    local now = getNow(api)

    if not isEmergencyVehicle(vehicle) then
        local eCfg = TrafficAIFix.config.emergency
        local emergencyDistance = findNearestEmergency(vehicle, context)
        if emergencyDistance <= eCfg.detectRadius then
            TrafficAIFix.state.emergencySeenAt[vehicleId] = now
            target = math.min(target, speedLimit * eCfg.slowFactor)
            if emergencyDistance <= eCfg.stopRadius then
                target = 0
            end
        else
            local seenAt = TrafficAIFix.state.emergencySeenAt[vehicleId]
            if seenAt and (now - seenAt) <= eCfg.memorySeconds then
                target = math.min(target, speedLimit * 0.5)
            end
        end
    end

    local sCfg = TrafficAIFix.config.scene
    local sceneDistance = findNearestSceneVehicle(vehicle, context)
    if sceneDistance <= sCfg.detectRadius then
        if sceneDistance <= sCfg.stopGap then
            target = 0
        elseif sceneDistance <= sCfg.heavyBrakeRadius then
            target = math.min(target, speedLimit * 0.2)
        elseif sceneDistance <= sCfg.lightBrakeRadius then
            target = math.min(target, speedLimit * 0.5)
        end
    end

    return clamp(target, 0, speedLimit)
end

local function processVehicle(api, vehicle, context)
    local target = calcTargetSpeed(vehicle, context, api)
    smoothAndApply(vehicle, context, api, target)
end

function TrafficAIFix.onVehicleAIUpdate(api, context)
    if not context or not context.vehicle then
        return
    end

    processVehicle(api, context.vehicle, context)
end

function TrafficAIFix.onTrafficTick(api, context)
    if not context or not context.vehicles then
        return
    end

    for _, vehicle in ipairs(context.vehicles) do
        local vehicleContext = {
            vehicle = vehicle,
            vehicles = context.vehicles,
            nearbyVehicles = context.nearbyVehicles,
            worldVehicles = context.worldVehicles,
            sceneVehicles = context.sceneVehicles,
            blockingVehicles = context.blockingVehicles,
            disabledVehicles = context.disabledVehicles,
            speedLimit = context.speedLimit,
            deltaTime = context.deltaTime,
            dt = context.dt,
        }
        processVehicle(api, vehicle, vehicleContext)
    end
end

function TrafficAIFix.init(api)
    if api and api.log then
        api.log("[ai_traffic_fix] initialized")
    end

    TrafficAIFix.state.subscriptions = subscribeTrafficHooks(
        api,
        TrafficAIFix.id,
        function(context)
            TrafficAIFix.onVehicleAIUpdate(api, context)
        end,
        function(context)
            TrafficAIFix.onTrafficTick(api, context)
        end
    )
end

function TrafficAIFix.shutdown(api)
    if api and api.events and api.events.unsubscribe then
        for _, token in ipairs(TrafficAIFix.state.subscriptions) do
            api.events.unsubscribe(token)
        end
    end

    TrafficAIFix.state.subscriptions = {}
    TrafficAIFix.state.speedByVehicle = {}
    TrafficAIFix.state.emergencySeenAt = {}

    if api and api.log then
        api.log("[ai_traffic_fix] shutdown")
    end
end

return TrafficAIFix
