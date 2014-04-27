module ("L_CombinationSwitch1Plugin_HVACMode", package.seeall)

local MAIN

local HVAC_SERVICE_ID = "urn:upnp-org:serviceId:HVAC_UserOperatingMode1"
local HVAC_VARIABLE_MODE = "ModeStatus"

local INDEX_SWITCH_DEVICE_ID = "DeviceId"
local INDEX_SWITCH_MODE = "MatchMode"

function initialize(main)
	MAIN = main
	local supportedDevices = MAIN.getDevicesWithService(nil, HVAC_SERVICE_ID)
	if (#supportedDevices == 0) then
		return false
	end
	return true
end

function name()
	return "HVAC Mode"
end

function configureState(combinationDeviceId, index)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, HVAC_SERVICE_ID)
	local jsSelectedDevice = MAIN.jsSetupState("selectedDevice", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, supportedDevices[1])
	local jsMatchMode = MAIN.jsSetupState("matchMode", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_MODE, [["AutoChangeOver"]])

	local result = "(function() {" ..
		jsSelectedDevice ..
		jsMatchMode ..
		"return selectedDevice + '=' + matchMode; " ..
		"})()"
	return result;
end

function configureSelect(combinationDeviceId, index, state)
	local selectedDevice, matchMode = state:match("(%d+)=(.+)")
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, HVAC_SERVICE_ID)

	local deviceSelectElement = MAIN.htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID)

	local possibleMode = {
		"AutoChangeOver",
		"CoolOn",
		"HeatOn",
		"Off"
	}
	local result = deviceSelectElement .. " is in mode <select onchange='warnSave(); set_device_state(" .. combinationDeviceId .. ", \"" .. MAIN.pluginId .. "\", \"" .. index .. INDEX_SWITCH_MODE .. "\", jQuery(this).val(), 0);'>"
	for i = 1, #possibleMode do
		result = result .. "<option value='" .. possibleMode[i] .. "'"
		if (possibleMode[i] == matchMode) then
			result = result .. " selected='selected'"
		end
		result = result .. ">" .. possibleMode[i] .. "</option>"
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
		local watchMode = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_MODE, DEVICE_ID)
		MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
			" HVAC Mode: " .. watchMode)
		luup.variable_watch("watch_callback", HVAC_SERVICE_ID, HVAC_VARIABLE_MODE, watchDeviceIdNum)
	end
	return true
end

function count(combinationDeviceId, index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, combinationDeviceId)
	local watchDeviceIdNum = tonumber(watchDeviceId)
	local watchMode = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_MODE, DEVICE_ID)
	return luup.variable_get(HVAC_SERVICE_ID, HVAC_VARIABLE_MODE, watchDeviceIdNum) == watchMode and 1 or 0
end
