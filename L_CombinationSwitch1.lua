module("L_CombinationSwitch1", package.seeall)

local COMBINATION_SWITCH_SERVICE_ID = "urn:futzle-com:serviceId:CombinationSwitch1"
local SWITCH_SERVICE_ID = "urn:upnp-org:serviceId:SwitchPower1"

local DEBUG = false
local DEVICE_ID
local HANDLERS = {}
local ITEMS_NEEDED = 0
local WATCH = {}

local LFS = require("lfs")

function initialize(deviceId)
	DEVICE_ID = deviceId

	if ((luup.variable_get(COMBINATION_SWITCH_SERVICE_ID, "Threshold", DEVICE_ID) or "0") == "1") then
		DEBUG = true
	end

	debug("Combination virtual switch " .. DEVICE_ID .. " started")
  
	luup.attr_set("category_num", 3, DEVICE_ID)

	HANDLERS = loadHandlers()
	luup.register_handler("callback_handler", "CSCallback")

	ITEMS_NEEDED = luup.variable_get(COMBINATION_SWITCH_SERVICE_ID, "Threshold", DEVICE_ID) or 1
	ITEMS_NEEDED = tonumber(ITEMS_NEEDED)

	local numWatch = luup.variable_get(COMBINATION_SWITCH_SERVICE_ID, "WatchCount", DEVICE_ID) or 0

	for i = 1, numWatch do
		local watchPlugin = luup.variable_get(COMBINATION_SWITCH_SERVICE_ID, i .. "Plugin", DEVICE_ID) or ""
		if (watchPlugin ~= "") then
			registerWatch(i, watchPlugin)
		end
	end

	updateState()

	return true
end

function registerWatch(i, watchPlugin)
	if (HANDLERS[watchPlugin].register(DEVICE_ID, i)) then
		WATCH[i] = watchPlugin
	end
end

-- Search through the require() path for a file matching "L_CombinationSwitch1Plugin_*.lua" and
-- insert it into the HANDLERS table.
function loadHandlers()
	local handlers = {}
	for path in package.path:gmatch("([^;]*);?") do
		local dir = path:match("(.+)/%?(.*)")
		if (dir ~= nil) then
			local attrib, error = LFS.attributes(dir)
			if (attrib and attrib.mode == "directory") then
				for filename in LFS.dir(dir) do
					local pluginName = filename:match("^L_CombinationSwitch1Plugin_(%w+)%.lua")
					if (pluginName) then
						debug("Loading plugin: " .. pluginName)
						package.loaded["L_CombinationSwitch1Plugin_" .. pluginName] = nil
						local plugin, error = require("L_CombinationSwitch1Plugin_" .. pluginName)
						if (plugin ~= nil) then
							if (plugin.initialize({
									pluginId = COMBINATION_SWITCH_SERVICE_ID,
									debug = debug,
									getDevicesWithService = getDevicesWithService,
									jsSetupState = jsSetupState,
									htmlSelectDevice = htmlSelectDevice,
									htmlEscape = htmlEscape,
									template = template,
								})) then
								handlers[pluginName] = plugin
								debug("Loaded plugin: L_CombinationSwitch1Plugin_" .. pluginName .. ".lua implements " .. handlers[pluginName].name())
							end
						else
							debug("Ignoring error while loading plugin " .. pluginName .. ": " .. error)
						end
					end
				end
			end
		end
	end
	return handlers
end

function callback_handler(lul_request, lul_parameters, lul_outputformat)
	debug("Callback handler for " .. lul_request)
	if (lul_parameters.request == "handlers") then
		return jsonHandlerList(tonumber(lul_parameters.deviceId))
	elseif (lul_parameters.request == "configureState") then
		return jsConfigureState(tonumber(lul_parameters.combiDevice), tonumber(lul_parameters.index), lul_parameters.plugin)
	elseif (lul_parameters.request == "configureSelect") then
		return xmlConfigureSelect(tonumber(lul_parameters.combiDevice), tonumber(lul_parameters.index), lul_parameters.state, lul_parameters.plugin)
	end
end

function jsonHandlerList()
	local r = {}
	for handlerId, handlerPlugin in pairs(HANDLERS) do
		table.insert(r, "{ \"id\":\"" .. handlerId .. "\",\"name\":\"" .. handlerPlugin.name() .. "\"}")
	end
	return "[" .. table.concat(r, ",") .. "]"
end

function jsConfigureState(combinationSwitchId, index, pluginId)
	return HANDLERS[pluginId].configureState(combinationSwitchId, index)
end

function xmlConfigureSelect(combinationSwitchId, index, state, pluginId)
	debug("Getting configuration for plugin " .. pluginId)
	return HANDLERS[pluginId].configureSelect(combinationSwitchId, index, state)
end

function watch_callback(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	debug("Watched variable changed: " .. lul_device .. " " .. lul_service .. " " .. lul_variable .. " from " .. lul_value_old .. " to " .. lul_value_new)
	updateState()
end

function countVotes(WATCH)
	local count = 0
	local entries = 0
	for index, plugin in pairs(WATCH) do
		entries = entries + 1
		count = count + HANDLERS[plugin].count(DEVICE_ID, index)
	end
	return count, entries
end

function updateState()
	local count, entries = countVotes(WATCH)
	luup.variable_set(COMBINATION_SWITCH_SERVICE_ID, "Label", count .. "/" .. entries, DEVICE_ID)
	luup.variable_set(COMBINATION_SWITCH_SERVICE_ID, "Status", count >= ITEMS_NEEDED and 1 or 0, DEVICE_ID)
	luup.variable_set(SWITCH_SERVICE_ID, "Status", count >= ITEMS_NEEDED and 1 or 0, DEVICE_ID)
end

function trigger()
	luup.variable_set(COMBINATION_SWITCH_SERVICE_ID, "Trigger", 1, DEVICE_ID)
	luup.variable_set(COMBINATION_SWITCH_SERVICE_ID, "Trigger", 0, DEVICE_ID)
end

function debug(s)
	if (DEBUG) then
		luup.log(s)
	end
end

-- Returns a list of ids of devices that include the urn:upnp-org:serviceId:SwitchPower1 service ID.
function getDevicesWithService(combinationSwitchId, serviceId)
	local supportedDevices = {}
	for i, d in pairs(luup.devices) do
		if (luup.device_supports_service(serviceId, i)) then
			table.insert(supportedDevices,i)
		end
	end
	table.sort(supportedDevices)
	return supportedDevices
end

function jsSetupState(jsVariable, combinationDeviceId, combinationServiceId, variableName, defaultValue)
	return "var " .. jsVariable .. " = get_device_state(" ..
		combinationDeviceId .. ", '" .. combinationServiceId ..
		"', '" .. variableName .. "', 0); if (" ..
		jsVariable .. " == undefined) { " ..
		jsVariable .. " = " .. defaultValue .. "; set_device_state(" ..
		combinationDeviceId .. ", '" .. combinationServiceId ..
		"', '" .. variableName .. "', " .. jsVariable .. ", 0); }"
end

function htmlSelectDevice(supportedDevices, selectedDevice, combinationDeviceId, combinationServiceId, variableName, extraJavaScript)
	local deviceSelect = {}
	for i, d in ipairs(supportedDevices) do
		table.insert(deviceSelect, template([[
			<option value='~d~' ~selected~>~desc~</option>
		]], {	
				d = d,
				desc = htmlEscape(luup.devices[d].description),
				selected = (d == tonumber(selectedDevice) and " selected='selected'" or "" ),
			}))
	end
	return "<select onchange=\"warnSave(); set_device_state(" ..
		combinationDeviceId .. ", '" .. combinationServiceId ..
		"', '" .. variableName .. "', jQuery(this).val(), 0);" ..
		(htmlEscape(extraJavaScript) or "") .. "\">" ..
		table.concat(deviceSelect) .. "</select>"
end

function htmlEscape(s)
	if (s == nil) then return nil end
	return s:gsub("[&<>\"']", {
		["&"] = "&amp;", 
		["<"] = "&lt;", 
		[">"] = "&gt;", 
		["\""] = "&quot;", 
		["'"] = "&apos;", 
	})
end

function template(s, substitutions)
	local s = s:gsub("~([%w_]+)~", substitutions)
	return s
end

