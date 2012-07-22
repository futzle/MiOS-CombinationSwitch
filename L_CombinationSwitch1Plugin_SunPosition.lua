module ("L_CombinationSwitch1Plugin_SunPosition", package.seeall)

local MAIN

local SUNPOSITION_SERVICE_ID = "urn:futzle-com:serviceId:AstronomicalPosition_Sun"
local SUNPOSITION_VARIABLE_ALTITUDE = "Altitude"
local SUNPOSITION_VARIABLE_AZIMUTH = "Azimuth"
local SUNPOSITION_VARIABLE_AZIMUTH360 = "Azimuth360"
local SUNPOSITION_VARIABLE_DECLINATION = "Declination"
local SUNPOSITION_VARIABLE_RIGHTASCENSION = "RightAscension"
local SUNPOSITION_VARIABLE_RIGHTASCENSION360 = "RightAscension360"

local INDEX_SUNPOSITION_DEVICE_ID = "DeviceId"
local INDEX_SUNPOSITION_VARIABLE = "Variable"
local INDEX_SUNPOSITION_VALUE_LOW = "Low"
local INDEX_SUNPOSITION_VALUE_HIGH = "High"

function initialize(main)
	MAIN = main
	local supportedDevices = MAIN.getDevicesWithService(nil, SUNPOSITION_SERVICE_ID)
	if (#supportedDevices == 0) then
		return false
	end
	return true
end

function name()
	return "Sun Position"
end

function configureState(combinationDeviceId, index)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, SUNPOSITION_SERVICE_ID)
	local jsSelectedDevice = MAIN.jsSetupState("selectedDevice", combinationDeviceId, MAIN.pluginId, index .. INDEX_SUNPOSITION_DEVICE_ID, supportedDevices[1])
	local jsVariable = MAIN.jsSetupState("variable", combinationDeviceId, MAIN.pluginId, index .. INDEX_SUNPOSITION_VARIABLE, "\"" .. SUNPOSITION_VARIABLE_ALTITUDE .. "\"")
	local jsCurrentLow = MAIN.jsSetupState("currentLow", combinationDeviceId, MAIN.pluginId, index .. INDEX_SUNPOSITION_VALUE_LOW, 0)
	local jsCurrentHigh = MAIN.jsSetupState("currentHigh", combinationDeviceId, MAIN.pluginId, index .. INDEX_SUNPOSITION_VALUE_HIGH, 90)

	local result = "(function() {" ..
		jsSelectedDevice ..
		jsVariable ..
		jsCurrentLow ..
		jsCurrentHigh ..
		"return selectedDevice + '=' + variable + ':' + currentLow + ',' + currentHigh; " ..
		"})()"
 	return result;
end

function configureSelect(combinationDeviceId, index, state)
	local selectedDevice, selectedVariable, selectedLow, selectedHigh = state:match("(%d+)=([^:]*):(%-?[%d.]*),(%-?[%d.]*)")
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, SUNPOSITION_SERVICE_ID)

	local deviceSelectElement = MAIN.htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, MAIN.pluginId, index .. INDEX_SUNPOSITION_DEVICE_ID)

	local result = MAIN.template([[
		~deviceSelectElement~ 
		<select onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_SUNPOSITION_VARIABLE~", $F(this), 0);'>
			<option value="Altitude" ~ALTITUDE_SELECTED~>Altitude</option>
			<option value="Azimuth360" ~AZIMUTH_SELECTED~>Azimuth</option>
			<option value="Declination" ~DECLINATION_SELECTED~>Declination</option>
			<option value="RightAscension360" ~RIGHTASCENSION_SELECTED~>Right Ascension</option>
		</select> is in range
		<input type="text" size="3" value="~selectedLow~" onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_SUNPOSITION_VALUE_LOW~", $F(this), 0);'>&deg; to
		<input type="text" size="3" value="~selectedHigh~" onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_SUNPOSITION_VALUE_HIGH~", $F(this), 0);'>&deg;
		]], {
			deviceSelectElement = deviceSelectElement,
			combinationDeviceId = combinationDeviceId,
			combinationServiceId = MAIN.pluginId,
			index = index,
			INDEX_SUNPOSITION_VARIABLE = INDEX_SUNPOSITION_VARIABLE,
			INDEX_SUNPOSITION_VALUE_LOW = INDEX_SUNPOSITION_VALUE_LOW,
			INDEX_SUNPOSITION_VALUE_HIGH = INDEX_SUNPOSITION_VALUE_HIGH,
			ALTITUDE_SELECTED = (selectedVariable == "Altitude" and "selected='selected'" or ""),
			AZIMUTH_SELECTED = (selectedVariable == "Azimuth" and "selected='selected'" or ""),
			DECLINATION_SELECTED = (selectedVariable == "Declination" and "selected='selected'" or ""),
			RIGHTASCENSION_SELECTED = (selectedVariable == "RightAscension" and "selected='selected'" or ""),
			selectedLow = selectedLow,
			selectedHigh = selectedHigh,
		})

	return result
end

function register(combinationDeviceId, index)
	MAIN.debug("Registering watch index " .. index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SUNPOSITION_DEVICE_ID, combinationDeviceId)
	if (watchDeviceId == nil) then return false end
	local watchDeviceIdNum = tonumber(watchDeviceId)
	if (watchDeviceIdNum >= 0 and luup.devices[watchDeviceIdNum]) then
		local watchDeviceVariable = luup.variable_get(MAIN.pluginId, index .. INDEX_SUNPOSITION_VARIABLE, combinationDeviceId)
		local watchDeviceName = luup.devices[watchDeviceIdNum].description
		local watchVariableValueLow = luup.variable_get(MAIN.pluginId, index .. INDEX_SUNPOSITION_VALUE_LOW, DEVICE_ID)
		local watchVariableValueHigh = luup.variable_get(MAIN.pluginId, index .. INDEX_SUNPOSITION_VALUE_HIGH, DEVICE_ID)
		MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
			" Sun Position (" .. watchDeviceVariable .. "): " .. watchVariableValueLow .. "-" .. watchVariableValueHigh)
		luup.variable_watch("watch_callback", SUNPOSITION_SERVICE_ID, watchDeviceVariable, watchDeviceIdNum)
	end
	return true
end

function normalize(n)
	while (n < 0) do
		n = n + 360
	end
	while (n >= 360) do
		n = n - 360
	end
	return n
end

function count(combinationDeviceId, index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SUNPOSITION_DEVICE_ID, combinationDeviceId)
	local watchDeviceIdNum = tonumber(watchDeviceId)
	local watchVariable = luup.variable_get(MAIN.pluginId, index .. INDEX_SUNPOSITION_VARIABLE, combinationDeviceId)
	local watchVariableValueLow = luup.variable_get(MAIN.pluginId, index .. INDEX_SUNPOSITION_VALUE_LOW, DEVICE_ID)
	local watchVariableValueHigh = luup.variable_get(MAIN.pluginId, index .. INDEX_SUNPOSITION_VALUE_HIGH, DEVICE_ID)
	if (watchVariable:match("360")) then
		-- Wraparound test for Azimuth and Right Ascension
		local currentValue = luup.variable_get(SUNPOSITION_SERVICE_ID, watchVariable, watchDeviceIdNum)
		local range = normalize(tonumber(watchVariableValueHigh) - tonumber(watchVariableValueLow))
		local actual = normalize(tonumber(currentValue) - tonumber(watchVariableValueLow))
		return (actual <= range) and 1 or 0
	else
		-- Declination and Altitude don't wrap around.
		local currentValue = luup.variable_get(SUNPOSITION_SERVICE_ID, watchVariable, watchDeviceIdNum)
		return (tonumber(currentValue) >= tonumber(watchVariableValueLow) and
			tonumber(currentValue) <= tonumber(watchVariableValueHigh)) and 1 or 0
	end
end
