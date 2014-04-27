module ("L_CombinationSwitch1Plugin_LightSensor", package.seeall)

local MAIN

local LIGHT_SENSOR_SERVICE_ID = "urn:micasaverde-com:serviceId:LightSensor1"
local LIGHT_SENSOR_VARIABLE_CURRENT_LEVEL = "CurrentLevel"

local INDEX_LIGHT_SENSOR_DEVICE_ID = "DeviceId"
local INDEX_LIGHT_SENSOR_VALUE_LOW = "Low"
local INDEX_LIGHT_SENSOR_VALUE_HIGH = "High"

function initialize(main)
	MAIN = main
	local supportedDevices = MAIN.getDevicesWithService(nil, LIGHT_SENSOR_SERVICE_ID)
	if (#supportedDevices == 0) then
		return false
	end
	return true
end

function name()
	return "Light Sensor Level"
end

function configureState(combinationDeviceId, index)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, LIGHT_SENSOR_SERVICE_ID)
	local jsSelectedDevice = MAIN.jsSetupState("selectedDevice", combinationDeviceId, MAIN.pluginId, index .. INDEX_LIGHT_SENSOR_DEVICE_ID, supportedDevices[1])
	local jsCurrentLow = MAIN.jsSetupState("currentLow", combinationDeviceId, MAIN.pluginId, index .. INDEX_LIGHT_SENSOR_VALUE_LOW, 1)
	local jsCurrentHigh = MAIN.jsSetupState("currentHigh", combinationDeviceId, MAIN.pluginId, index .. INDEX_LIGHT_SENSOR_VALUE_HIGH, 100)

	local result = "(function() {" ..
		jsSelectedDevice ..
		jsCurrentLow ..
		jsCurrentHigh ..
		"return selectedDevice + '=' + currentLow + ',' + currentHigh; " ..
		"})()"
 	return result;
end

function configureSelect(combinationDeviceId, index, state)
	local selectedDevice, selectedLow, selectedHigh = state:match("(%d+)=(%d+),(%d+)")
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, LIGHT_SENSOR_SERVICE_ID)

	local deviceSelectElement = MAIN.htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, MAIN.pluginId, index .. INDEX_LIGHT_SENSOR_DEVICE_ID)

	local result = MAIN.template([[
		~deviceSelectElement~ is in range
		<input type="text" size="4" value="~selectedLow~" onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_LIGHT_SENSOR_VALUE_LOW~", jQuery(this).val(), 0);'> to
		<input type="text" size="4" value="~selectedHigh~" onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_LIGHT_SENSOR_VALUE_HIGH~", jQuery(this).val(), 0);'> 
		]], {
			deviceSelectElement = deviceSelectElement,
			combinationDeviceId = combinationDeviceId,
			combinationServiceId = MAIN.pluginId,
			index = index,
			INDEX_LIGHT_SENSOR_VALUE_LOW = INDEX_LIGHT_SENSOR_VALUE_LOW,
			INDEX_LIGHT_SENSOR_VALUE_HIGH = INDEX_LIGHT_SENSOR_VALUE_HIGH,
			selectedLow = selectedLow,
			selectedHigh = selectedHigh,
		})

	return result
end

function register(combinationDeviceId, index)
	MAIN.debug("Registering watch index " .. index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_LIGHT_SENSOR_DEVICE_ID, combinationDeviceId)
	if (watchDeviceId == nil) then return false end
	local watchDeviceIdNum = tonumber(watchDeviceId)
	if (watchDeviceIdNum >= 0 and luup.devices[watchDeviceIdNum]) then
		local watchDeviceName = luup.devices[watchDeviceIdNum].description
		local watchVariableValueLow = luup.variable_get(MAIN.pluginId, index .. INDEX_LIGHT_SENSOR_VALUE_LOW, DEVICE_ID)
		local watchVariableValueHigh = luup.variable_get(MAIN.pluginId, index .. INDEX_LIGHT_SENSOR_VALUE_HIGH, DEVICE_ID)
		MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
			" Light sensor level: " .. watchVariableValueLow .. "-" .. watchVariableValueHigh)
		luup.variable_watch("watch_callback", LIGHT_SENSOR_SERVICE_ID, LIGHT_SENSOR_VARIABLE_CURRENT_LEVEL, watchDeviceIdNum)
	end
	return true
end

function count(combinationDeviceId, index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_LIGHT_SENSOR_DEVICE_ID, combinationDeviceId)
	local watchDeviceIdNum = tonumber(watchDeviceId)
	local watchVariableValueLow = luup.variable_get(MAIN.pluginId, index .. INDEX_LIGHT_SENSOR_VALUE_LOW, DEVICE_ID)
	local watchVariableValueHigh = luup.variable_get(MAIN.pluginId, index .. INDEX_LIGHT_SENSOR_VALUE_HIGH, DEVICE_ID)
	local currentValue = luup.variable_get(LIGHT_SENSOR_SERVICE_ID, LIGHT_SENSOR_VARIABLE_CURRENT_LEVEL, watchDeviceIdNum)
	return (tonumber(currentValue) >= tonumber(watchVariableValueLow) and
		 tonumber(currentValue) <= tonumber(watchVariableValueHigh)) and 1 or 0
end
