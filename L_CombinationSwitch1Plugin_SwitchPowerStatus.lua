module ("L_CombinationSwitch1Plugin_SwitchPowerStatus", package.seeall)

-- Passed to this module during initialization.
-- Contains some useful constants and utility functions.
local MAIN

local SWITCH_SERVICE_ID = "urn:upnp-org:serviceId:SwitchPower1"
local SWITCH_VARIABLE_STATUS = "Status"

local INDEX_SWITCH_DEVICE_ID = "DeviceId"
local INDEX_SWITCH_VALUE = "Value"

-- initialize(main)
-- Public.
-- Parameters:
--   main: a table of values and utility functions common to the ovarall plugin.
-- Returns true if this plugin should be used, false otherwise.
function initialize(main)
	MAIN = main
	local supportedDevices = MAIN.getDevicesWithService(nil, SWITCH_SERVICE_ID)
	if (#supportedDevices == 0) then
		return false
	end
	return true
end

-- name()
-- Public.
-- Returns string, the human-readable name of the plugin.
function name()
	return "Switch Power Status"
end

-- configureState(combinationDeviceId, index)
-- Public.
-- Parameters:
--   combinationDeviceId: integer, device ID of the virtual switch.
--   index: integer, origin 1. The index of the watch within the combination switch.
-- Returns a string, JavaScript code that is eval'd by Configure tab.
-- JavaScript code fetches the watch info from state variables, sets reasonable
-- defaults if they don't exist, and returns a serialized string which
-- is passed to configureSelect().
function configureState(combinationDeviceId, index)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, SWITCH_SERVICE_ID)
	local jsSelectedDevice = MAIN.jsSetupState("selectedDevice", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, supportedDevices[1])
	local jsSelectedValue = MAIN.jsSetupState("selectedValue", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_VALUE, 1)

	local result = "(function() {" ..
		jsSelectedDevice ..
		jsSelectedValue ..
		"return selectedDevice + '=' + selectedValue; " ..
		"})()"
	return result;
end

-- configureSelect(combinationDeviceId, index, state)
-- Public.
-- Parameters:
--   index: integer, origin 1. The index of the watch within the combination switch.
--   state: string, produced by configureState().
-- Returns a string, XHTML that is inserted into the Configure Tab.
-- Uses state variable to determine selected options. Contains onSelect/onChange
-- code that sets state variables to the values the user changes the options to.
function configureSelect(combinationDeviceId, index, state)
	local selectedDevice, selectedValue = state:match("(%d+)=(%d)")
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, SWITCH_SERVICE_ID)

	local deviceSelectElement = MAIN.htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID)

	local result = MAIN.template([[
		~deviceSelectElement~ is
		<select onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_SWITCH_VALUE~", jQuery(this).val(), 0);'>
			<option value='0' ~offSelected~>Off</option>
			<option value='1' ~onSelected~>On</option>
		</select>
		]], {
			deviceSelectElement = deviceSelectElement,
			combinationDeviceId = combinationDeviceId,
			combinationServiceId = MAIN.pluginId,
			index = index,
			INDEX_SWITCH_VALUE = INDEX_SWITCH_VALUE,
			offSelected = (0 == tonumber(selectedValue) and " selected='selected'" or "" ),
			onSelected = (1 == tonumber(selectedValue) and " selected='selected'" or "" ),
		})

	return result
end

-- register(combinationDeviceId, index)
-- Public.
-- Watch whatever state variables that hold the state
-- that this index in the switch uses.
-- Return: true if the variable will be watched.
function register(combinationDeviceId, index)
	MAIN.debug("Registering watch index " .. index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, combinationDeviceId)
	if (watchDeviceId == nil) then return false end
	local watchDeviceIdNum = tonumber(watchDeviceId)
	if (watchDeviceIdNum >= 0 and luup.devices[watchDeviceIdNum]) then
		local watchDeviceName = luup.devices[watchDeviceIdNum].description
		local watchVariableValue = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_VALUE, DEVICE_ID)
		MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
			" Switch Power Status: " .. watchVariableValue)
		luup.variable_watch("watch_callback", SWITCH_SERVICE_ID, SWITCH_VARIABLE_STATUS, watchDeviceIdNum)
	end
	return true
end

-- count(combinationDeviceId, index)
-- Public.
-- Return 0 or 1, if the index is false or true respectively.
function count(combinationDeviceId, index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, combinationDeviceId)
	local watchDeviceIdNum = tonumber(watchDeviceId)
	local watchVariableValue = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_VALUE, DEVICE_ID)
	return luup.variable_get(SWITCH_SERVICE_ID, SWITCH_VARIABLE_STATUS, watchDeviceIdNum) == watchVariableValue and 1 or 0
end
