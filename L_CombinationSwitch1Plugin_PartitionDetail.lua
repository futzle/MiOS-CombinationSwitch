module ("L_CombinationSwitch1Plugin_PartitionDetail", package.seeall)

local MAIN

local PARTITION_SERVICE_ID = "urn:micasaverde-com:serviceId:AlarmPartition2"
local PARTITION_VARIABLE_DETAIL = "DetailedArmMode"

local INDEX_SWITCH_DEVICE_ID = "DeviceId"
local INDEX_SWITCH_DETAIL = "MatchDetail"

function initialize(main)
	MAIN = main
	local supportedDevices = MAIN.getDevicesWithService(nil, PARTITION_SERVICE_ID)
	if (#supportedDevices == 0) then
		return false
	end
	return true
end

function name()
	return "Partition Detail"
end

function configureState(combinationDeviceId, index)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, PARTITION_SERVICE_ID)
	local jsSelectedDevice = MAIN.jsSetupState("selectedDevice", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, supportedDevices[1])
	local jsMatchDetail = MAIN.jsSetupState("matchDetail", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DETAIL, [["Ready"]])

	local result = "(function() {" ..
		jsSelectedDevice ..
		jsMatchDetail ..
		"return selectedDevice + '=' + matchDetail; " ..
		"})()"
	return result;
end

function configureSelect(combinationDeviceId, index, state)
	local selectedDevice, matchDetail = state:match("(%d+)=(.+)")
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, PARTITION_SERVICE_ID)

	local deviceSelectElement = MAIN.htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID)

	local possibleDetails = {
		"Disarmed",
		"Armed",
		"Stay",
		"StayInstant",
		"Night",
		"NightInstant",
		"Force",
		"Ready",
		"Vacation",
		"NotReady",
		"FailedToArm",
		"EntryDelay",
		"ExitDelay"
	}
	local result = deviceSelectElement .. " is in state <select onchange='warnSave(); set_device_state(" .. combinationDeviceId .. ", \"" .. MAIN.pluginId .. "\", \"" .. index .. INDEX_SWITCH_DETAIL .. "\", $F(this), 0);'>"
	for i = 1, #possibleDetails do
		result = result .. "<option value='" .. possibleDetails[i] .. "'"
		if (possibleDetails[i] == matchDetail) then
			result = result .. " selected='selected'"
		end
		result = result .. ">" .. possibleDetails[i] .. "</option>"
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
		local watchDetail = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DETAIL, DEVICE_ID)
		MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
			" Partition Detail status: " .. watchDetail)
		luup.variable_watch("watch_callback", PARTITION_SERVICE_ID, PARTITION_VARIABLE_DETAIL, watchDeviceIdNum)
	end
	return true
end

function count(combinationDeviceId, index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, combinationDeviceId)
	local watchDeviceIdNum = tonumber(watchDeviceId)
	local watchDetail = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DETAIL, DEVICE_ID)
	return luup.variable_get(PARTITION_SERVICE_ID, PARTITION_VARIABLE_DETAIL, watchDeviceIdNum) == watchDetail and 1 or 0
end
