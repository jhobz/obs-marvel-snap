OBS = obslua
JSON = require("JSON")

-- OBS DATA
SOURCE_CurrentDeck = ""
HOTKEY_id = OBS.OBS_INVALID_HOTKEY_ID
DEBUG_MODE = false
TIMER_INTERVAL = 1000
CHANGE_FN = nil

Player_Data = {
	-- Decks is an array of tables with the following format:
	-- {
	-- 	1: {
	--		Name: string,
	-- 		CardBack: object,
	-- 		CardBackId: string,
	-- 		Cards: object[],
	-- 		CardIds: string[],
	-- 		TimeCreatedOrderBy: string (datetime)
	-- 		Id: string
	-- 		DataVersion: int
	-- 		TimeCreated: string (datetime)
	-- 		TimeUpdated: string (datetime)
	--	},
	-- 	2: { ... },
	-- 	...
	-- }
	Decks = {},
	CurrentDeckId = "",
	PlayerId = "",
	SnapDir = ""
}

-- PATHS
PATH_Relative_Base = "/Standalone/States/nvprod/"
PATH_PlayState = PATH_Relative_Base .. "PlayState.json"
PATH_CollectionState = PATH_Relative_Base .. "CollectionState.json"
URL_SnapFan_Deck_Format = "https://snap.fan/p/%s/decks/%s/"



----------------------------------------------------------
-- UTILITY FUNCTIONS
----------------------------------------------------------
local function debug(s)
	if DEBUG_MODE then
		print(s)
	end
end

local function read_file(f)
	local file = io.open(f, "r")

	if file == nil then
		assert(false, "ERROR: Unable to read file. File not found at location " .. f)
		return
	end

	local text = file:read("*all")
	file:close()
	return text
end

local function parse_file(f)
	local jsonStr = read_file(f)

	if (jsonStr == nil) then
		assert(false, "ERROR: Unable to parse JSON from file " .. f)
		return
	end

	local i = jsonStr:find("%{")
	jsonStr = jsonStr:sub(i)

	return JSON:decode(jsonStr)
end

----------------------------------------------------------
-- SNAP FUNCTIONS
----------------------------------------------------------
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



local function get_player_id()
	local playerId = parse_file(Player_Data["SnapDir"] .. PATH_CollectionState)["ServerState"]["Account"]["Id"]
	if playerId ~= nil then
		return playerId
	end

	assert(false, "ERROR: Could not acquire playerId from path: " .. Player_Data["SnapDir"])
end

local function get_current_deck_id()
	local playState = parse_file(Player_Data["SnapDir"] .. PATH_PlayState)
	if playState ~= nil then
		return playState["SelectedDeckId"]
	end

	assert(false, "ERROR: playState did not read properly")
end

local function get_all_decks()
	local decks = parse_file(Player_Data["SnapDir"] .. PATH_CollectionState)["ServerState"]["Decks"]
	if decks ~= nil then
		return decks
	end

	assert(false, "ERROR: could not read full deck list")
end

local function load_player_data(settings)
	Player_Data["SnapDir"] = OBS.obs_data_get_string(settings, "path")

	if Player_Data["SnapDir"] == nil or Player_Data["SnapDir"] == "" then
		debug("Skipping load of player data because SnapDir is nil")
		return
	end

	Player_Data["PlayerId"] = get_player_id()
	Player_Data["CurrentDeckId"] = get_current_deck_id()
	Player_Data["Decks"] = get_all_decks()
end

----------------------------------------------------------
-- OBS-RELATED FUNCTIONS
----------------------------------------------------------
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

	-- OBS.timer_remove(CHANGE_FN)
	get_all_decks()
end

----------------------------------------------------------
-- OBS EVENT CALLBACKS
----------------------------------------------------------
-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	debug("script_properties")

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
	OBS.obs_properties_add_bool(props, "debug", "Debug Mode")
	return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Prompts the user for a URL to a Marvel Snap deck on Snap.fan and creates a new source with proper sizing and cropping.\n\nMade by JHobz"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	debug("script_update")

	SOURCE_CurrentDeck = OBS.obs_data_get_string(settings, "source")
	DEBUG_MODE = OBS.obs_data_get_bool(settings, "debug")

	local function check_for_change()
		---@diagnostic disable-next-line: deprecated
		debug(unpack({a = "hello"}))
		---@diagnostic disable-next-line: deprecated
		local cache = {unpack(Player_Data)}
		load_player_data(settings)
		-- TODO: Check against all values
		if cache["CurrentDeckId"] ~= Player_Data["CurrentDeckId"] then
			-- TODO: Potentially perform more actions?
			load_current_deck()
		end
	end

	if CHANGE_FN == nil then
		CHANGE_FN = check_for_change
	end

	OBS.timer_remove(CHANGE_FN)
	OBS.timer_add(CHANGE_FN, TIMER_INTERVAL)
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	OBS.obs_data_set_default_string(settings, "path", "")
	OBS.obs_data_set_default_bool(settings, "debug", false)
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
	debug('script_save')

	local hotkey_save_array = OBS.obs_hotkey_save(HOTKEY_id)
	OBS.obs_data_set_array(settings, "open_gui_hotkey", hotkey_save_array)
	OBS.obs_data_array_release(hotkey_save_array)
	OBS.obs_data_set_string(settings, "snap_player_id", Player_Data["PlayerId"])
end

-- a function named script_load will be called on startup
function script_load(settings)
	debug("script_load")
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