o = obslua

version = "1.0.0"
debug = true

function script_description()
	local desc = {
        "Let Lichess know when you start streaming. Notify us when you start streaming and we'll check if you should be shown as Live.",
        "You are on version " .. version,
    }
    return table.concat(desc, "\n\n")
end

function script_load()
    o.obs_frontend_add_event_callback(obs_frontend_callback)
end

function script_unload()
end

function obs_frontend_callback(event, private_data)
    -- in debug mode, trigger on recording start/stop for easier testing
    if debug then
        if event == o.OBS_FRONTEND_EVENT_RECORDING_STARTED then
        notify_lichess_stream_status("started")
        elseif event == o.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
        notify_lichess_stream_status("stopped")
        end
    end

    if event == o.OBS_FRONTEND_EVENT_STREAMING_STARTED then
        notify_lichess_stream_status("started")
    elseif event == o.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
        notify_lichess_stream_status("stopped")
    end
end

function open_url(url)
    local os_name = package.config:sub(1,1) == '\\' and 'Windows' or io.popen('uname'):read('*l')

    if os_name == 'Windows' then
        os.execute('start "" "' .. url .. '"')
    elseif os_name == 'Darwin' then
        os.execute('open "' .. url .. '"')
    else
        os.execute('xdg-open "' .. url .. '"')
    end
end

function validate_credentials()
    if not PROP_API_KEY or PROP_API_KEY == "" then
        o.script_log(o.LOG_ERROR, "API Key is not set")
        return false
    end

    if not PROP_LICHESS_HOST or PROP_LICHESS_HOST == "" then
        o.script_log(o.LOG_ERROR, "Lichess Host is not set")
        return false
    end

    return true
end

function make_lichess_request(curl_command)
    local handle = io.popen(curl_command)
    local response = handle:read("*a")
    handle:close()
    return response
end

function notify_lichess_stream_status(started_or_stopped)
    if not validate_credentials() then
        return
    end

    local url = PROP_LICHESS_HOST .. "/api/user/lichess/note"
    local curl_command = string.format('curl -s -X POST -H "Authorization: Bearer %s" -d "text=%s" "%s"', PROP_API_KEY, started_or_stopped, url)
    local response = make_lichess_request(curl_command)

    if response and response ~= "" then
        o.script_log(o.LOG_INFO, "Notified Lichess that stream " .. started_or_stopped .. ": " .. response)
    else
        o.script_log(o.LOG_WARNING, "Lichess stream notification sent (no response)")
    end
end

function test_lichess_connection()
    if not validate_credentials() then
        return
    end

    local url = PROP_LICHESS_HOST .. "/api/account"
    local curl_command = string.format('curl -s -H "Authorization: Bearer %s" "%s"', PROP_API_KEY, url)
    local response = make_lichess_request(curl_command)

    if response and response ~= "" then
        local id = parse_json_id(response)
        if id then
            o.script_log(o.LOG_INFO, "Successful Test Result: Lichess account ID: " .. id)
        else
            o.script_log(o.LOG_ERROR, "Failed to parse account ID from response")
        end
    else
        o.script_log(o.LOG_ERROR, "Failed to get response from Lichess API")
    end
end

function parse_json_id(json_str)
    local id = json_str:match('"id"%s*:%s*"([^"]+)"')
    return id
end

function script_properties()
    local p = o.obs_properties_create()
    o.obs_properties_add_text(p, "lichess_host", "Lichess Host", o.OBS_TEXT_DEFAULT)
    o.obs_properties_add_text(p, "api_key", "API Key", o.OBS_TEXT_PASSWORD)
    o.obs_properties_add_button(p, "action_get_api_key", "Get API Key", function(props, prop)
        open_url("https://lichess.org/account/oauth/token/create?description=OBS+Live+Notification")
    end)
    o.obs_properties_add_button(p, "action_test", "Test", function(props, prop)
        test_lichess_connection()
    end)
    -- o.obs_properties_add_button(p, "action_check_for_updates", "Check for Updates", function(props, prop)
    --     -- todo
    -- end)
    return p
end

function script_defaults(s)
    o.obs_data_set_default_string(s, "lichess_host", "https://lichess.org")
    o.obs_data_set_default_string(s, "api_key", "")
end

function script_update(s)
    PROP_LICHESS_HOST = o.obs_data_get_string(s, "lichess_host")
    PROP_API_KEY = o.obs_data_get_string(s, "api_key")
end
