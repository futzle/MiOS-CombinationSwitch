module ("L_CombinationSwitch1Plugin_VariableContainer", package.seeall)

local MAIN

local VCONTAINER_SERVICE_ID = "urn:upnp-org:serviceId:VContainer1"

local INDEX_VCONTAINER_DEVICE_ID = "DeviceId"
local INDEX_VCONTAINER_VARIABLE_SLOT = "Slot"
local INDEX_VCONTAINER_VALUE = "Value"
local INDEX_VCONTAINER_COMPARISON = "Comparison"

function initialize(main)
	MAIN = main
	local supportedDevices = MAIN.getDevicesWithService(nil, VCONTAINER_SERVICE_ID)
	if (#supportedDevices == 0) then
		return false
	end
	return true
end

function name()
	return "Variable Container"
end

function configureState(combinationDeviceId, index)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, VCONTAINER_SERVICE_ID)
	local jsSelectedDevice = MAIN.jsSetupState("selectedDevice", combinationDeviceId, MAIN.pluginId, index .. INDEX_VCONTAINER_DEVICE_ID, supportedDevices[1])
	local jsSelectedSlot = MAIN.jsSetupState("selectedSlot", combinationDeviceId, MAIN.pluginId, index .. INDEX_VCONTAINER_VARIABLE_SLOT, 1)
	local jsCurrentValue = MAIN.jsSetupState("currentValue", combinationDeviceId, MAIN.pluginId, index .. INDEX_VCONTAINER_VALUE, 0)
	local jsComparison = MAIN.jsSetupState("comparison", combinationDeviceId, MAIN.pluginId, index .. INDEX_VCONTAINER_COMPARISON, [["eq"]])

	local result = "(function() {" ..
		jsSelectedDevice ..
		jsSelectedSlot ..
		jsCurrentValue ..
		jsComparison ..
		"return selectedDevice + ':' + selectedSlot + ':' + comparison + ':' + currentValue; " ..
		"})()"
 	return result;
end

function configureSelect(combinationDeviceId, index, state)
	local selectedDevice, selectedSlot, comparison, currentValue = state:match("(%d+):(%d+):([^:]+):(.*)")
	selectedDevice = tonumber(selectedDevice)
	selectedSlot = tonumber(selectedSlot)
	local supportedDevices = MAIN.getDevicesWithService(combinationDeviceId, VCONTAINER_SERVICE_ID)

	-- JavaScript runs when user selects a different Variable Container device:
	-- Change the list of 5 variable names. Set the slot to Variable 1.
	local deviceSelectExtraJS = "$('combiSlot" .. index .. "').innerHTML = "
	local firstSelected = " selected='selected'"
	for slot = 1,5 do
		deviceSelectExtraJS = deviceSelectExtraJS .. "\"<option value='" .. slot .. "'" .. firstSelected ..
			">\" +" .. "get_device_state($F(this), '" .. VCONTAINER_SERVICE_ID ..
			"', 'VariableName" .. slot .. "', 0).escapeHTML()" ..
			"+ \"</option>\" + "
		firstSelected = ""
	end
	deviceSelectExtraJS = deviceSelectExtraJS .. "''; set_device_state(" .. combinationDeviceId ..
		", '" .. MAIN.pluginId .. "', '" .. index .. INDEX_VCONTAINER_VARIABLE_SLOT .. "', 1, 0);"

	local deviceSelectElement = MAIN.htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, MAIN.pluginId, index .. INDEX_VCONTAINER_DEVICE_ID, deviceSelectExtraJS)
	local variableName = {}
	for slot = 1,5 do
		local n = luup.variable_get(VCONTAINER_SERVICE_ID, "VariableName" .. slot, selectedDevice)
		table.insert(variableName, n)
	end

	local result = MAIN.template([[
		~deviceSelectElement~ variable 
		<select id='combiSlot~index~' onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_VCONTAINER_VARIABLE_SLOT~", $F(this), 0);'>
			<option ~variable1selected~ value="1">~variableName1~</option>
			<option ~variable2selected~ value="2">~variableName2~</option>
			<option ~variable3selected~ value="3">~variableName3~</option>
			<option ~variable4selected~ value="4">~variableName4~</option>
			<option ~variable5selected~ value="5">~variableName5~</option>
		</select>
                <select onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_VCONTAINER_COMPARISON~", $F(this), 0);'>
                        <option value='eq' ~eqSelected~>is</option>
                </select>
		<input type="text" size="15" value="~currentValue~" onchange='warnSave(); set_device_state(~combinationDeviceId~, "~combinationServiceId~", "~index~~INDEX_VCONTAINER_VALUE~", $F(this), 0);'> 
		]], {
			deviceSelectElement = deviceSelectElement,
			combinationDeviceId = combinationDeviceId,
			combinationServiceId = MAIN.pluginId,
			index = index,
			INDEX_VCONTAINER_VARIABLE_SLOT = INDEX_VCONTAINER_VARIABLE_SLOT,
			INDEX_VCONTAINER_COMPARISON = INDEX_VCONTAINER_COMPARISON,
			INDEX_VCONTAINER_VALUE = INDEX_VCONTAINER_VALUE,
			variableName1 = variableName[1],
			variableName2 = variableName[2],
			variableName3 = variableName[3],
			variableName4 = variableName[4],
			variableName5 = variableName[5],
			variable1selected = (selectedSlot == 1 and "selected='selected'" or ""),
			variable2selected = (selectedSlot == 2 and "selected='selected'" or ""),
			variable3selected = (selectedSlot == 3 and "selected='selected'" or ""),
			variable4selected = (selectedSlot == 4 and "selected='selected'" or ""),
			variable5selected = (selectedSlot == 5 and "selected='selected'" or ""),
			currentValue = MAIN.htmlEscape(currentValue),
			eqSelected = (comparison == "eq" and "selected='selected'" or ""),
		})

	return result
end

function register(combinationDeviceId, index)
	MAIN.debug("Registering watch index " .. index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_VCONTAINER_DEVICE_ID, combinationDeviceId)
	local watchSlot = luup.variable_get(MAIN.pluginId, index .. INDEX_VCONTAINER_VARIABLE_SLOT, combinationDeviceId)
	if (watchDeviceId == nil or watchSlot == nil) then return false end
	local watchDeviceIdNum = tonumber(watchDeviceId)
	if (watchDeviceIdNum >= 0 and luup.devices[watchDeviceIdNum]) then
		local watchDeviceName = luup.devices[watchDeviceIdNum].description
		local watchVariableValue = luup.variable_get(MAIN.pluginId, index .. INDEX_VCONTAINER_VALUE, DEVICE_ID)
		local watchSlotName = luup.variable_get(VCONTAINER_SERVICE_ID, "VariableName" .. watchSlot, watchDeviceIdNum)
		MAIN.debug("Watching " .. watchDeviceName .. " [" .. watchDeviceId .. "] " ..
			" Variable Container : " .. watchSlotName .. ": " .. watchVariableValue)
		luup.variable_watch("watch_callback", VCONTAINER_SERVICE_ID, "Variable" .. watchSlot, watchDeviceIdNum)
	end
	return true
end

function count(combinationDeviceId, index)
	local watchDeviceId = luup.variable_get(MAIN.pluginId, index .. INDEX_VCONTAINER_DEVICE_ID, combinationDeviceId)
	local watchDeviceIdNum = tonumber(watchDeviceId)
	local watchVariableSlot = luup.variable_get(MAIN.pluginId, index .. INDEX_VCONTAINER_VARIABLE_SLOT, DEVICE_ID)
	local watchVariableValue = luup.variable_get(MAIN.pluginId, index .. INDEX_VCONTAINER_VALUE, DEVICE_ID)
	local watchComparison = luup.variable_get(MAIN.pluginId, index .. INDEX_VCONTAINER_COMPARISON, DEVICE_ID)
	local currentValue = luup.variable_get(VCONTAINER_SERVICE_ID, "Variable" .. watchVariableSlot, watchDeviceIdNum)
	if (watchComparison == "eq") then
		return (currentValue == watchVariableValue) and 1 or 0
	end
end
