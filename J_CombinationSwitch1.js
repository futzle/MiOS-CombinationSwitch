var pluginList;

var entityMap = { 
 "&": "&amp;", 
 "<": "&lt;", 
 ">": "&gt;", 
 '"': '&quot;', 
 "'": '&#39;', 
 "/": '&#x2F;' 
}; 

function escapeHtml(string) { 
  return String(string).replace(/[&<>"'\/]/g, function (s) { 
    return entityMap[s]; 
  }); 
}

function configuration(deviceId)
{
	var html = '';
	html += '<p id="configuration_saveChanges" style="display:none; font-weight: bold; text-align: center;">Close dialog and press SAVE to commit changes.</p>';
	html += '<div id="itemList"></div>';

	html += '<div><p>Switch is on when ';
	html += '<input type="text" size="3" onchange="warnSave(); set_device_state(' + deviceId + ', \'urn:futzle-com:serviceId:CombinationSwitch1\', \'Threshold\', jQuery(this).val(), 0)" value="';
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
				jQuery('#itemList').html('Failed to get plugins');
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

				jQuery('#itemList').html(html);

				// Populate existing settings.
				for (i = 1; i <= count; i++)
				{
					if (jQuery("#pluginDetail" + i).length > 0)
					{
						var pluginId = get_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", i + "Plugin", 0);
						pluginSettings(deviceId, i, pluginId, jQuery("#pluginDetail" + i));
					}
				}
			}
		}, 
		onFailure: function () {
			jQuery('#itemList').html('Failed to get plugins');
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
	jQuery.each(pluginList, function(i, plugin) {
		html += '<option value="' + plugin["id"] + '"' + (currentPlugin == plugin["id"] ? ' selected="selected"' : '') + '>' + escapeHtml(plugin["name"]) + '</option>';
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
			output_format: "text"
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
					output_format: "text"
				},
				onSuccess: function (response) {
					resultElement.html(response.responseText);
				}, 
				onFailure: function () {
					resultElement.html('Failed to get plugins');
				}
			});
		}, 
		onFailure: function () {
			resultElement.html('Failed to get plugins');
		}
	});
}

function pluginSelected(deviceId, i, selectElement)
{
	warnSave();
	var pluginId = jQuery(selectElement).val();
	var count = get_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", "WatchCount");
	if (count == undefined) { count = 0; } else { count = count - 0; }
	set_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", i + "Plugin", pluginId, 0);
	if (i > count)
	{
		jQuery('#addEntryPluginDefault').remove();
		set_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", "WatchCount", i, 0);
		var tableElement = selectElement.parentNode.parentNode.parentNode;
		var newRow = tableElement.insertRow(-1);
		newRow.setAttribute("id", "pluginRow" + (i+1));
		jQuery(newRow).html(selectPlugin(deviceId, i+1, count+1));
	}

	pluginSettings(deviceId, i, pluginId, jQuery("#pluginDetail" + i));

}

function removeRow(deviceId, i, removeElement)
{
	warnSave();
	set_device_state(deviceId, "urn:futzle-com:serviceId:CombinationSwitch1", i + "Plugin", "", 0);
	removeElement.parentNode.parentNode.remove();
}

function warnSave()
{
	jQuery('#configuration_saveChanges').show();
}
