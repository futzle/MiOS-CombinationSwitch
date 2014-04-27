module ("L_CombinationSwitch1Plugin_WeatherCondition", package.seeall)

local MAIN

local WEATHER_SERVICE_ID = "urn:upnp-micasaverde-com:serviceId:Weather1"
local WEATHER_VARIABLE_CONDITION = "Condition"

local INDEX_SWITCH_DEVICE_ID = "DeviceId"
local INDEX_SWITCH_CONDITION = "MatchCondition"

function initialize(main)
	MAIN = main
	local supportedDevices = MAIN.getDevicesWithService(nil, WEATHER_SERVICE_ID)
	if (#supportedDevices == 0) then
		return false
	end
	return true
end

function name()
	return "Weather Conditons"
end

function configureState(combinationDeviceId, index)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, WEATHER_SERVICE_ID)
	local jsSelectedDevice = MAIN.jsSetupState("selectedDevice", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, supportedDevices[1])
	local jsMatchCondition = MAIN.jsSetupState("matchCondition", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_CONDITION, [["Rain"]])

	local result = "(function() {" ..
		jsSelectedDevice ..
		jsMatchCondition ..
		"return selectedDevice + '=' + matchCondition; " ..
		"})()"
	return result;
end

function configureSelect(combinationDeviceId, index, state)
	local selectedDevice, matchCondition = state:match("(%d+)=(.+)")
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, WEATHER_SERVICE_ID)

	local deviceSelectElement = MAIN.htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID)

	local possibleConditions = {
		"Chance of Showers",
		"Chance of Snow",
		"Chance of Storm",
		"Clear",
		"Cloudy",
		"Drizzle",
		"Flurries",
		"Fog",
		"Freezing Drizzle",
		"Freezing Rain",
		"Haze",
		"Heavy Rain",
		"Ice/Snow",
		"Isolated Thunderstorms",
		"Light Rain",
		"Light Snow",
		"Mostly Cloudy",
		"Mostly Sunny",
		"Overcast",
		"Partly Cloudy",
		"Partly Sunny",
		"Rain",
		"Rain and Snow",
		"Rain Showers",
		"Scattered Showers",
		"Showers",
		"Snow",
		"Snow Showers",
		"Snow Storm",
		"Sunny",
		"Thunderstorm",
		"Windy"
	}
	local result = deviceSelectElement .. " is <select onchange='warnSave(); set_device_state(" .. combinationDeviceId .. ", \"" .. MAIN.pluginId .. "\", \"" .. index .. INDEX_SWITCH_CONDITION .. "\", jQuery(this).val(), 0);'>"
	for i = 1, #possibleConditions do
		result = result .. "<option value='" .. possibleConditions[i] .. "'"
		if (possibleConditions[i] == matchCondition) then
			result = result .. " selected='selected'"
		end
		result = result .. ">" .. possibleConditions[i] .. "</option>"
	end
	result = result .. "</select>"

	return result
end

function register(combinationDeviceId, index)
	MAIN.debug("Registering watch index " .. index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, combinationDeviceId)
	if (watchDeviceId == nil) then return false end
	local watchDeviceIdNum = tonumber(watchDeviceId)
	if (watchDeviceIdNum >= 0 and luup.devices[watchDeviceIdNum]) then
		local watchDeviceName = luup.devices[watchDeviceIdNum].description
		local watchCondition = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_CONDITION, DEVICE_ID)
		MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
			" Weather condition: " .. watchCondition)
		luup.variable_watch("watch_callback", WEATHER_SERVICE_ID, WEATHER_VARIABLE_CONDITION, watchDeviceIdNum)
	end
	return true
end

function count(combinationDeviceId, index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, combinationDeviceId)
	local watchDeviceIdNum = tonumber(watchDeviceId)
	local watchCondition = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_CONDITION, DEVICE_ID)
	return luup.variable_get(WEATHER_SERVICE_ID, WEATHER_VARIABLE_CONDITION, watchDeviceIdNum) == watchCondition and 1 or 0
end
