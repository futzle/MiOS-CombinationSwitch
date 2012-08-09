module ("L_CombinationSwitch1Plugin_LockStatus", package.seeall)

local MAIN

local LOCK_SERVICE_ID = "urn:micasaverde-com:serviceId:DoorLock1"
local LOCK_VARIABLE_STATUS = "Status"

local INDEX_SWITCH_DEVICE_ID = "DeviceId"
local INDEX_SWITCH_VALUE = "Value"

function initialize(main)
	MAIN = main
	local supportedDevices = MAIN.getDevicesWithService(nil, LOCK_SERVICE_ID)
	if (#supportedDevices == 0) then
		return false
	end
	return true
end

function name()
	return "Lock Status"
end

function configureState(combinationDeviceId, index)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, LOCK_SERVICE_ID)
	local jsSelectedDevice = MAIN.jsSetupState("selectedDevice", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, supportedDevices[1])
	local jsSelectedValue = MAIN.jsSetupState("selectedValue", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_VALUE, 1)

	local result = "(function() {" ..
		jsSelectedDevice ..
		jsSelectedValue ..
		"return selectedDevice + '=' + selectedValue; " ..
		"})()"
	return result;
end

function configureSelect(combinationDeviceId, index, state)
	local selectedDevice, selectedValue = state:match("(%d+)=(%d)")
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, LOCK_SERVICE_ID)

	local deviceSelectElement = MAIN.htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID)

	local result = MAIN.template([[
		~deviceSelectElement~ is
		<select onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_SWITCH_VALUE~", $F(this), 0);'>
			<option value='0' ~unlockedSelected~>Unlocked</option>
			<option value='1' ~lockedSelected~>Locked</option>
		</select>
		]], {
			deviceSelectElement = deviceSelectElement,
			combinationDeviceId = combinationDeviceId,
			combinationServiceId = MAIN.pluginId,
			index = index,
			INDEX_SWITCH_VALUE = INDEX_SWITCH_VALUE,
			unlockedSelected = (0 == tonumber(selectedValue) and " selected='selected'" or "" ),
			lockedSelected = (1 == tonumber(selectedValue) and " selected='selected'" or "" ),
		})

	return result
end

function register(combinationDeviceId, index)
	MAIN.debug("Registering watch index " .. index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, combinationDeviceId)
	if (watchDeviceId == nil) then return false end
	local watchDeviceIdNum = tonumber(watchDeviceId)
	if (watchDeviceIdNum >= 0 and luup.devices[watchDeviceIdNum]) then
		local watchDeviceName = luup.devices[watchDeviceIdNum].description
		local watchVariableValue = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_VALUE, DEVICE_ID)
		MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
			" Lock Status: " .. watchVariableValue)
		luup.variable_watch("watch_callback", LOCK_SERVICE_ID, LOCK_VARIABLE_STATUS, watchDeviceIdNum)
	end
	return true
end

function count(combinationDeviceId, index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, combinationDeviceId)
	local watchDeviceIdNum = tonumber(watchDeviceId)
	local watchVariableValue = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_VALUE, DEVICE_ID)
	return luup.variable_get(LOCK_SERVICE_ID, LOCK_VARIABLE_STATUS, watchDeviceIdNum) == watchVariableValue and 1 or 0
end
