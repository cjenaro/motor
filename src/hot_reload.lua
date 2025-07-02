-- Hot Reload Module for Motor
-- Provides file watching and module reloading for development mode

---@class HotReload
local hot_reload = {}

-- File modification times cache
local file_mtimes = {}

-- Modules to watch and their file paths
local watched_modules = {}

-- Development mode flag
local dev_mode = false

-- Reload callbacks for critical modules
local reload_callbacks = {}

-- Check if a file has been modified
---@param filepath string File path to check
---@return boolean True if file was modified
local function file_modified(filepath)
	local attr = io.popen("stat -c %Y " .. filepath .. " 2>/dev/null"):read("*a")
	if not attr or attr == "" then
		return false
	end

	local mtime = tonumber(attr:match("%d+"))
	if not mtime then
		return false
	end

	local last_mtime = file_mtimes[filepath]
	file_mtimes[filepath] = mtime

	return last_mtime and mtime > last_mtime
end

-- Clear module from package.loaded to force reload
---@param module_name string Module name to clear
local function clear_module(module_name)
	package.loaded[module_name] = nil

	-- Also clear any submodules
	---@diagnostic disable-next-line: unused-local
	for name, _ in pairs(package.loaded) do
		if string.find(name, "^" .. module_name .. "%.") then
			package.loaded[name] = nil
		end
	end
end

-- Reload a module safely
---@param module_name string Module name to reload
---@param filepath string File path (unused but kept for consistency)
---@return boolean True if reload was successful
local function reload_module(module_name, filepath)
	---@diagnostic disable-next-line: unused-local
	print("🔄 Reloading module: " .. module_name)

	-- Clear from cache
	clear_module(module_name)

	-- Try to reload
	local reload_ok, result = pcall(require, module_name)
	if not reload_ok then
		print("❌ Failed to reload " .. module_name .. ": " .. tostring(result))
		return false
	end

	-- Execute any registered callbacks for this module
	local callback = reload_callbacks[module_name]
	if callback then
		print("🔄 Executing reload callback for: " .. module_name)
		local callback_ok, callback_err = pcall(callback)
		if not callback_ok then
			print("⚠️  Reload callback failed for " .. module_name .. ": " .. tostring(callback_err))
		end
	end

	print("✅ Successfully reloaded: " .. module_name)
	return true
end

-- Add a module to watch list
---@param module_name string Module name to watch
---@param filepath string File path of the module
function hot_reload.watch_module(module_name, filepath)
	if not dev_mode then
		return
	end

	watched_modules[module_name] = filepath

	-- Initialize file mtime
	local attr = io.popen("stat -c %Y " .. filepath .. " 2>/dev/null"):read("*a")
	if attr and attr ~= "" then
		file_mtimes[filepath] = tonumber(attr:match("%d+"))
	end

	print("👀 Watching module: " .. module_name .. " (" .. filepath .. ")")
end

-- Check all watched files for changes
---@return boolean True if any modules were reloaded
function hot_reload.check_for_changes()
	if not dev_mode then
		return false
	end

	local reloaded = false

	for module_name, filepath in pairs(watched_modules) do
		if file_modified(filepath) then
			if reload_module(module_name, filepath) then
				reloaded = true
			end
		end
	end

	return reloaded
end

-- Enable development mode
---@return nil
function hot_reload.enable_dev_mode()
	dev_mode = true
	print("🔥 Hot reload enabled for development")
end

-- Disable development mode
---@return nil
function hot_reload.disable_dev_mode()
	dev_mode = false
	watched_modules = {}
	file_mtimes = {}
	print("❄️  Hot reload disabled")
end

-- Check if dev mode is enabled
---@return boolean
function hot_reload.is_dev_mode()
	return dev_mode
end

-- Auto-discover and watch common Lua files in a directory
---@param directory string Directory path to watch
---@param module_prefix string? Module prefix for discovered files
function hot_reload.watch_directory(directory, module_prefix)
	if not dev_mode then
		return
	end

	module_prefix = module_prefix or ""

	-- Use find command to get all .lua files
	local find_cmd = "find " .. directory .. " -name '*.lua' -type f 2>/dev/null"
	local handle = io.popen(find_cmd)

	if not handle then
		print("⚠️  Could not scan directory: " .. directory)
		return
	end

	for filepath in handle:lines() do
		-- Convert filepath to module name
		local relative_path = filepath:gsub("^" .. directory .. "/", "")
		local module_name = relative_path:gsub("/", "."):gsub("%.lua$", "")

		if module_prefix ~= "" then
			module_name = module_prefix .. "." .. module_name
		end

		-- Skip init.lua files as they're usually entry points
		if not module_name:match("%.init$") and module_name ~= "init" then
			hot_reload.watch_module(module_name, filepath)
		end
	end

	handle:close()
end

-- Watch application files (controllers, models, etc.)
---@param app_root string? Application root directory
function hot_reload.watch_app_files(app_root)
	if not dev_mode then
		return
	end

	app_root = app_root or "."

	-- Watch controllers
	local controllers_dir = app_root .. "/app/controllers"
	hot_reload.watch_directory(controllers_dir, "app.controllers")

	-- Watch models
	local models_dir = app_root .. "/app/models"
	hot_reload.watch_directory(models_dir, "app.models")

	-- Watch config files
	local config_dir = app_root .. "/config"
	hot_reload.watch_directory(config_dir, "config")
	
	-- Also watch routes file specifically since it's critical for hot reload
	local routes_file = app_root .. "/config/routes.lua"
	hot_reload.watch_module("config.routes", routes_file)
end

-- Register a callback to be executed when a specific module is reloaded
---@param module_name string Module name to watch for reloads
---@param callback function Function to call when module is reloaded
function hot_reload.on_reload(module_name, callback)
	reload_callbacks[module_name] = callback
	print("📋 Registered reload callback for: " .. module_name)
end

return hot_reload

