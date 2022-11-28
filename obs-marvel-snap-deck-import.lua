OBS = obslua
JSON = require("JSON")

-- OBS DATA
SOURCE_CurrentDeck = ""
HOTKEY_id = OBS.OBS_INVALID_HOTKEY_ID

Player_Data = {
	CurrentDeckId = "",
	Decks = {},
	PlayerId = "",
	SnapDir = ""
}

-- PATHS
PATH_Relative_Base = "/Standalone/States/nvprod/"
PATH_PlayState = PATH_Relative_Base .. "PlayState.json"
PATH_CollectionState = PATH_Relative_Base .. "CollectionState.json"
URL_SnapFan_Deck_Format = "https://snap.fan/p/%s/decks/%s/"



-- LOCAL FUNCTIONS
local function read_file(f)
	local file = io.open(f, "r")

	if file == nil then
		print("Unable to read file. File not found at location " .. f)
		return
	end

	local text = file:read("*all")
	file:close()
	return text
end

local function parse_file(f)
	local jsonStr = read_file(f)

	if (jsonStr == nil) then
		print("Unable to parse file")
		return
	end

	local i = jsonStr:find("%{")
	jsonStr = jsonStr:sub(i)

	return JSON:decode(jsonStr)
end

local function load_deck_list()
end

local function load_current_deck()
	local currentDeckBrowserSource = OBS.obs_get_source_by_name(SOURCE_CurrentDeck)
	local currentDeckUrl = string.format(URL_SnapFan_Deck_Format, Player_Data["PlayerId"], Player_Data["CurrentDeckId"])

	if currentDeckBrowserSource ~= nil then
		local settings = OBS.obs_data_create()
		OBS.obs_data_set_string(settings, "url", currentDeckUrl)
		OBS.obs_source_update(currentDeckBrowserSource, settings)
		OBS.obs_data_release(settings)
		OBS.obs_source_release(currentDeckBrowserSource)
	end
end

local function open_gui()
	-- local source = obs.obs_get_source_by_name(source_name)
	-- local text = read_file(file_location)

	-- if source ~= nil then
	-- 	local settings = obs.obs_data_create()
	-- 	obs.obs_data_set_string(settings, "text", text)
	-- 	obs.obs_source_update(source, settings)
	-- 	obs.obs_data_release(settings)
	-- 	obs.obs_source_release(source)
	-- end

    load_current_deck()
end


----------------------------------------------------------

local function get_player_id()
	local playerId = parse_file(Player_Data["SnapDir"] .. PATH_CollectionState)["ServerState"]["Account"]["Id"]

	if playerId == nil then
		print("ERROR: Could not acquire playerId from path: " .. Player_Data["SnapDir"])
	end

	return playerId
end

local function get_current_deck_id()
	local playState = parse_file(Player_Data["SnapDir"] .. PATH_PlayState)
	if playState ~= nil then
		return playState["SelectedDeckId"]
	end

	print('playState did not read properly')
end

local function get_all_decks()
	-- TODO
	return {}
end

local function load_player_data(settings)
	Player_Data["SnapDir"] = OBS.obs_data_get_string(settings, "path")

	if Player_Data["SnapDir"] == nil or Player_Data["SnapDir"] == "" then
		print("Skipping load of player data because SnapDir is nil")
		return
	end

	Player_Data["PlayerId"] = get_player_id()
	Player_Data["CurrentDeckId"] = get_current_deck_id()
	Player_Data["Decks"] = get_all_decks()
end

----------------------------------------------------------

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	local props = OBS.obs_properties_create()
	local p = OBS.obs_properties_add_list(props, "source", "Browser Source for Current Deck", OBS.OBS_COMBO_TYPE_EDITABLE, OBS.OBS_COMBO_FORMAT_STRING)
	local sources = OBS.obs_enum_sources()

	if sources ~= nil then
		for _, source in ipairs(sources) do
			local source_id = OBS.obs_source_get_id(source)
			if source_id == "browser_source" then
				local name = OBS.obs_source_get_name(source)
				OBS.obs_property_list_add_string(p, name, name)
			end
		end
	end
	OBS.source_list_release(sources)

	OBS.obs_properties_add_path(props, "path", "Path to Marvel Snap folder", OBS.OBS_PATH_DIRECTORY, nil, Player_Data["SnapDir"])

	return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Prompts the user for a URL to a Marvel Snap deck on Snap.fan and creates a new source with proper sizing and cropping.\n\nMade by JHobz"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	SOURCE_CurrentDeck = OBS.obs_data_get_string(settings, "source")
	load_player_data(settings)

	-- local playerId = get_player_id()

	print("script_update")
	-- Load_Deck_List()
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	OBS.obs_data_set_default_string(settings, "path", "")
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
	local hotkey_save_array = OBS.obs_hotkey_save(HOTKEY_id)
	OBS.obs_data_set_array(settings, "open_gui_hotkey", hotkey_save_array)
	OBS.obs_data_array_release(hotkey_save_array)
	OBS.obs_data_set_string(settings, "snap_player_id", Player_Data["PlayerId"])
	print('script_save')
end

-- a function named script_load will be called on startup
function script_load(settings)
	-- Connect hotkey and activation/deactivation signal callbacks
	--
	-- NOTE: These particular script callbacks do not necessarily have to
	-- be disconnected, as callbacks will automatically destroy themselves
	-- if the script is unloaded.  So there's no real need to manually
	-- disconnect callbacks that are intended to last until the script is
	-- unloaded.
	-- local sh = obs.obs_get_signal_handler()
	-- obs.signal_handler_connect(sh, "source_activate", source_activated)
	-- obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)

	HOTKEY_id = OBS.obs_hotkey_register_frontend("open_snap_gui", "Open Marvel Snap Deck List", open_gui)
	local hotkey_save_array = OBS.obs_data_get_array(settings, "open_gui_hotkey")
	OBS.obs_hotkey_load(HOTKEY_id, hotkey_save_array)
	OBS.obs_data_array_release(hotkey_save_array)
end