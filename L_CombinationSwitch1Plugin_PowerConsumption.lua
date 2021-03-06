module ("L_CombinationSwitch1Plugin_PowerConsumption", package.seeall)

local MAIN

local POWER_SERVICE_ID = "urn:micasaverde-com:serviceId:EnergyMetering1"
local POWER_VARIABLE_WATTS = "Watts"

local INDEX_POWER_DEVICE_ID = "DeviceId"
local INDEX_POWER_VALUE_LOW = "Low"
local INDEX_POWER_VALUE_HIGH = "High"

function initialize(main)
	MAIN = main
	local supportedDevices = MAIN.getDevicesWithService(nil, POWER_SERVICE_ID)
	if (#supportedDevices == 0) then
		return false
	end
	return true
end

function name()
	return "Power Consumption"
end

function configureState(combinationDeviceId, index)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, POWER_SERVICE_ID)
	local jsSelectedDevice = MAIN.jsSetupState("selectedDevice", combinationDeviceId, MAIN.pluginId, index .. INDEX_POWER_DEVICE_ID, supportedDevices[1])
	local jsCurrentLow = MAIN.jsSetupState("currentLow", combinationDeviceId, MAIN.pluginId, index .. INDEX_POWER_VALUE_LOW, [["1"]])
	local jsCurrentHigh = MAIN.jsSetupState("currentHigh", combinationDeviceId, MAIN.pluginId, index .. INDEX_POWER_VALUE_HIGH, [[""]])

	local result = "(function() {" ..
		jsSelectedDevice ..
		jsCurrentLow ..
		jsCurrentHigh ..
		"return selectedDevice + '=' + currentLow + ',' + currentHigh; " ..
		"})()"
 	return result;
end

function configureSelect(combinationDeviceId, index, state)
	local selectedDevice, selectedLow, selectedHigh = state:match("(%d+)=(%-?%d*),(%-?%d*)")
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, POWER_SERVICE_ID)

	local deviceSelectElement = MAIN.htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, MAIN.pluginId, index .. INDEX_POWER_DEVICE_ID)

	local result = MAIN.template([[
		~deviceSelectElement~ is in range
		<input type="text" size="4" value="~selectedLow~" onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_POWER_VALUE_LOW~", jQuery(this).val(), 0);'>&nbsp;W to
		<input type="text" size="4" value="~selectedHigh~" onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_POWER_VALUE_HIGH~", jQuery(this).val(), 0);'>&nbsp;W
		]], {
			deviceSelectElement = deviceSelectElement,
			combinationDeviceId = combinationDeviceId,
			combinationServiceId = MAIN.pluginId,
			index = index,
			INDEX_POWER_VALUE_LOW = INDEX_POWER_VALUE_LOW,
			INDEX_POWER_VALUE_HIGH = INDEX_POWER_VALUE_HIGH,
			selectedLow = selectedLow,
			selectedHigh = selectedHigh,
		})

	return result
end

function register(combinationDeviceId, index)
	MAIN.debug("Registering watch index " .. index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_POWER_DEVICE_ID, combinationDeviceId)
	if (watchDeviceId == nil) then return false end
	local watchDeviceIdNum = tonumber(watchDeviceId)
	if (watchDeviceIdNum >= 0 and luup.devices[watchDeviceIdNum]) then
		local watchDeviceName = luup.devices[watchDeviceIdNum].description
		local watchVariableValueLow = luup.variable_get(MAIN.pluginId, index .. INDEX_POWER_VALUE_LOW, DEVICE_ID)
		local watchVariableValueHigh = luup.variable_get(MAIN.pluginId, index .. INDEX_POWER_VALUE_HIGH, DEVICE_ID)
		MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
			" Energy metering power: " .. watchVariableValueLow .. "-" .. watchVariableValueHigh)
		luup.variable_watch("watch_callback", POWER_SERVICE_ID, POWER_VARIABLE_WATTS, watchDeviceIdNum)
	end
	return true
end

function count(combinationDeviceId, index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_POWER_DEVICE_ID, combinationDeviceId)
	local watchDeviceIdNum = tonumber(watchDeviceId)
	local currentValue = luup.variable_get(POWER_SERVICE_ID, POWER_VARIABLE_WATTS, watchDeviceIdNum)
	local watchVariableValueLow = luup.variable_get(MAIN.pluginId, index .. INDEX_POWER_VALUE_LOW, DEVICE_ID)
	local inRange = 1
	if (watchVariableValueLow ~= "") then
		if (tonumber(currentValue) < tonumber(watchVariableValueLow)) then
			inRange = 0
		end
	end
	local watchVariableValueHigh = luup.variable_get(MAIN.pluginId, index .. INDEX_POWER_VALUE_HIGH, DEVICE_ID)
	if (watchVariableValueHigh ~= "") then
		if (tonumber(currentValue) > tonumber(watchVariableValueHigh)) then
			inRange = 0
		end
	end
	return inRange
end
