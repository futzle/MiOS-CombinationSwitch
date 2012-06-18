var pluginList;

function configuration(deviceId)
{
	var html = '';
	html += '<p id="configuration_saveChanges" style="display:none; font-weight: bold; text-align: center;">Close dialog and press SAVE to commit changes.</p>';
	html += '<div id="itemList"></div>';

	html += '<div><p>Switch is on when ';
	html += '<input type="text" size="3" onchange="warnSave(); set_device_state(' + deviceId + ', \'urn:futzle-com:serviceId:CombinationSwitch1\', \'Threshold\', $F(this), 0)" value="';
	var watchCount = get_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", "Threshold", 0);
	if (watchCount == undefined) { watchCount = 1; }
	html += watchCount + '"/> or more watched items are true.</p></div>';

	set_panel_html(html);

	new Ajax.Request("../port_3480/data_request", {
		method: "get",
		parameters: {
			id: "lr_CSCallback",
			request: "handlers",
			combiDevice: deviceId,
			rand: Math.random(),
			output_format: "json"
		},
		onSuccess: function (response) {
			pluginList = response.responseText.evalJSON();
			if (pluginList == undefined)
			{
				$('itemList').innerHTML = 'Failed to get plugins';
			}
			else
			{
				var html = '<table width="100%">';
				// Existing entries go from 1 to count.
				var count = get_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", "WatchCount", 0);
				if (count == undefined) { count = 0; } else { count = count - 0; }

				var i;
				for (i = 1; i <= count; i++)
				{
					var row = selectPlugin(deviceId, i, count);
					if (row != undefined)
					{
						html += '<tr id="pluginRow' + i + '">';
						html += row;
						html += '<td><input type="button" onclick="removeRow(' + deviceId + ',' + i + ', this)" value="Remove"/></td>';
						html += '</tr>';
					}
				}

				// Index of next entry to add.
				var next = count + 1;
				html += '<tr id="pluginRow' + next + '">';
				html += selectPlugin(deviceId, next, count);
				html += '</tr></table>';

				$('itemList').innerHTML = html;

				// Populate existing settings.
				for (i = 1; i <= count; i++)
				{
					if ($("pluginDetail" + i) != undefined)
					{
						var pluginId = get_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", i + "Plugin", 0);
						pluginSettings(deviceId, i, pluginId, $("pluginDetail" + i));
					}
				}
			}
		}, 
		onFailure: function () {
			$('itemList').innerHTML = 'Failed to get plugins';
		}
	});
}

function selectPlugin(deviceId, i, count)
{
	var currentPlugin = get_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", i + "Plugin", 0);
	if ((i <= count) && (currentPlugin == undefined || currentPlugin == ""))
	{
		return undefined;
	}

	var html = '';
	html += '<td><select onchange="pluginSelected(' + deviceId + ',' + i + ', this)">';
	if (i > count)
	{
		html += '<option id="addEntryPluginDefault" value="" selected="selected">Add new...</option>';
	}
	html += pluginList.inject("", function(a, plugin) {
		return a + '<option value="' + plugin["id"] + '"' + (currentPlugin == plugin["id"] ? ' selected="selected"' : '') + '>' + plugin["name"].escapeHTML() + '</option>';
	});
	html += '</select></td><td id="pluginDetail' + i + '">';
	html += '</td>';
	return html;
}

function pluginSettings(deviceId, i, pluginId, resultElement)
{
	new Ajax.Request("../port_3480/data_request", {
		method: "get",
		parameters: {
			id: "lr_CSCallback",
			request: "configureState",
			plugin: pluginId,
			combiDevice: deviceId,
			index: i,
			rand: Math.random(),
			output_format: "xml"
		},
		onSuccess: function (response) {
			var stateJavaScript = response.responseText;
			var state = eval(stateJavaScript);
			new Ajax.Request("../port_3480/data_request", {
				method: "get",
				parameters: {
					id: "lr_CSCallback",
					request: "configureSelect",
					plugin: pluginId,
					combiDevice: deviceId,
					index: i,
					state: state,
					rand: Math.random(),
					output_format: "xml"
				},
				onSuccess: function (response) {
					resultElement.innerHTML = response.responseText;
				}, 
				onFailure: function () {
					resultElement.innerHTML = 'Failed to get plugins';
				}
			});
		}, 
		onFailure: function () {
			resultElement.innerHTML = 'Failed to get plugins';
		}
	});
}

function pluginSelected(deviceId, i, selectElement)
{
	warnSave();
	var pluginId = $F(selectElement);
	var count = get_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", "WatchCount");
	if (count == undefined) { count = 0; } else { count = count - 0; }
	set_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", i + "Plugin", pluginId, 0);
	if (i > count)
	{
		Array($('addEntryPluginDefault')).invoke("remove");
		set_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", "WatchCount", i, 0);
		var tableElement = selectElement.parentNode.parentNode.parentNode;
		var newRow = tableElement.insertRow(-1);
		newRow.setAttribute("id", "pluginRow" + (i+1));
		newRow.innerHTML = selectPlugin(deviceId, i+1, count+1);
	}

	pluginSettings(deviceId, i, pluginId, $("pluginDetail" + i));

}

function removeRow(deviceId, i, removeElement)
{
	warnSave();
	set_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", i + "Plugin", "", 0);
	removeElement.parentNode.parentNode.remove();
}

function warnSave()
{
	$('configuration_saveChanges').show();
}
