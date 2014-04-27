module ("L_CombinationSwitch1Plugin_SecuritySensor", package.seeall)

local MAIN

local SENSOR_SERVICE_ID = "urn:micasaverde-com:serviceId:SecuritySensor1"
local SENSOR_VARIABLE_TRIPPED = "Tripped"
local SENSOR_VARIABLE_ARMED = "Armed"

local INDEX_SWITCH_DEVICE_ID = "DeviceId"
local INDEX_SWITCH_TRIPPED = "IsTripped"
local INDEX_SWITCH_ARMED = "IsArmed"

function initialize(main)
	MAIN = main
	local supportedDevices = MAIN.getDevicesWithService(nil, SENSOR_SERVICE_ID)
	if (#supportedDevices == 0) then
		return false
	end
	return true
end

function name()
	return "Security Sensor"
end

function configureState(combinationDeviceId, index)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, SENSOR_SERVICE_ID)
	local jsSelectedDevice = MAIN.jsSetupState("selectedDevice", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, supportedDevices[1])
	local jsIsTripped = MAIN.jsSetupState("isTripped", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_TRIPPED, [["1"]])
	local jsIsArmed = MAIN.jsSetupState("isArmed", combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_ARMED, [["x"]])

	local result = "(function() {" ..
		jsSelectedDevice ..
		jsIsTripped ..
		jsIsArmed ..
		"return selectedDevice + '=' + isTripped + ':' + isArmed; " ..
		"})()"
	return result;
end

function configureSelect(combinationDeviceId, index, state)
	local selectedDevice, isTripped, isArmed = state:match("(%d+)=([01x]):([01x])")
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, SENSOR_SERVICE_ID)

	local deviceSelectElement = MAIN.htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID)

	local result = MAIN.template([[
		~deviceSelectElement~ is
		<select onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_SWITCH_TRIPPED~", jQuery(this).val().substring(0, 1), 0); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_SWITCH_ARMED~", jQuery(this).val().substring(1, 2), 0);'>
			<option value='1x' ~selected1x~>Tripped</option>
			<option value='0x' ~selected0x~>Not tripped</option>
			<option value='10' ~selected10~>Tripped while bypassed</option>
			<option value='00' ~selected00~>Not tripped while bypassed</option>
			<option value='11' ~selected11~>Tripped while armed</option>
			<option value='01' ~selected01~>Not tripped while armed</option>
			<option value='x0' ~selectedx0~>Bypassed</option>
			<option value='x1' ~selectedx1~>Armed</option>
		</select>
		]], {
			deviceSelectElement = deviceSelectElement,
			combinationDeviceId = combinationDeviceId,
			combinationServiceId = MAIN.pluginId,
			index = index,
			INDEX_SWITCH_VALUE = INDEX_SWITCH_VALUE,
			INDEX_SWITCH_TRIPPED = INDEX_SWITCH_TRIPPED,
			INDEX_SWITCH_ARMED = INDEX_SWITCH_ARMED,
			selected1x = ("1" == isTripped and "x" == isArmed and " selected='selected'" or "" ),
			selected0x = ("0" == isTripped and "x" == isArmed and " selected='selected'" or "" ),
			selected10 = ("1" == isTripped and "0" == isArmed and " selected='selected'" or "" ),
			selected00 = ("0" == isTripped and "0" == isArmed and " selected='selected'" or "" ),
			selected11 = ("1" == isTripped and "1" == isArmed and " selected='selected'" or "" ),
			selected01 = ("0" == isTripped and "1" == isArmed and " selected='selected'" or "" ),
			selectedx0 = ("x" == isTripped and "0" == isArmed and " selected='selected'" or "" ),
			selectedx1 = ("x" == isTripped and "1" == isArmed and " selected='selected'" or "" ),
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
		local watchTripped = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_TRIPPED, DEVICE_ID)
		if (watchTripped ~= "x") then
			MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
				" Tripped: " .. watchTripped)
			luup.variable_watch("watch_callback", SENSOR_SERVICE_ID, SENSOR_VARIABLE_TRIPPED, watchDeviceIdNum)
		end
		local watchArmed = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_ARMED, DEVICE_ID)
		if (watchArmed ~= "x") then
			MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
				" Tripped: " .. watchTripped)
			luup.variable_watch("watch_callback", SENSOR_SERVICE_ID, SENSOR_VARIABLE_ARMED, watchDeviceIdNum)
		end
	end
	return true
end

function count(combinationDeviceId, index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_DEVICE_ID, combinationDeviceId)
	local watchDeviceIdNum = tonumber(watchDeviceId)
	local watchTripped = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_TRIPPED, DEVICE_ID)
	if (watchTripped ~= "x") then
		if (luup.variable_get(SENSOR_SERVICE_ID, SENSOR_VARIABLE_TRIPPED, watchDeviceIdNum) ~= watchTripped) then
			return 0
		end
	end
	local watchArmed = luup.variable_get(MAIN.pluginId, index .. INDEX_SWITCH_ARMED, DEVICE_ID)
	if (watchArmed ~= "x") then
		if (luup.variable_get(SENSOR_SERVICE_ID, SENSOR_VARIABLE_ARMED, watchDeviceIdNum) ~= watchArmed) then
			return 0
		end
	end
	return 1
end
