-- Define the module
local M = {}

--local log = require("wswrite").log
-- local function log(msg)
-- 	wswrite("dynkey", msg)
-- end
local sha256 = vim.fn.sha256

-- Initialize the global context table
local context = {}

local dynkey_context = "ctx_dynkey"

-- Default config table for user options
M.config = {
	data_dir = vim.fn.expand("~/.var/app/dynkey"), -- Default to ~/.var/app/dynkey
	key_groups = {}, -- Table to store key groups
	shadow_groups = {}, -- Shadow copy for storing previous associations
}

function M.write_shadow_to_disk(group_id, shadow)
	local sha = sha256(group_id)
	local shadow_file = M.config.data_dir .. "/" .. sha .. ".json"

	-- Ensure the directory exists
	vim.fn.mkdir(M.config.data_dir, "p")

	local file = io.open(shadow_file, "w")
	if file then
		file:write(vim.fn.json_encode(shadow))
		file:close()
		--log("Shadow written to disk for group: " .. group_id)
	else
		log("Error writing shadow to disk. ")
	end
end
function M.read_shadow_from_disk(group_id)
	local sha = sha256(group_id)
	local shadow_file = M.config.data_dir .. "/" .. sha .. ".json"
	local file = io.open(shadow_file, "r")
	if file then
		local content = file:read("*a")
		file:close()
		return vim.fn.json_decode(content)
	else
		return nil -- Shadow file doesn't exist, assume empty shadow
	end
end
-- Shared function to generate a unique key based on a key_id and assigned keys
local function generate_unique_key(key_id, assigned_keys)
	-- Ensure key_id is a valid string
	if type(key_id) ~= "string" then
		log("Error: key_id must be a string. ")
		return nil
	end

	-- Clean key_id by removing non-alphanumeric characters
	local key_id_cleaned = key_id:gsub("[^%w]", ""):lower() -- Remove non-alphanumeric and lowercase it

	-- Try to assign keys from the cleaned key_id
	for i = 1, #key_id_cleaned do
		local candidate_key = key_id_cleaned:sub(i, i) -- Extract each letter
		if not assigned_keys[candidate_key] then
			return candidate_key
		end
	end

	-- Fallback: Try lowercase 'a' to 'z'
	for i = 97, 122 do -- ASCII codes for 'a' to 'z'
		local candidate_key = string.char(i)
		if not assigned_keys[candidate_key] then
			return candidate_key
		end
	end

	-- Fallback: Try uppercase 'A' to 'Z'
	for i = 65, 90 do -- ASCII codes for 'A' to 'Z'
		local candidate_key = string.char(i)
		if not assigned_keys[candidate_key] then
			return candidate_key
		end
	end

	-- Fallback: Try '0' to '9'
	for i = 48, 57 do -- ASCII codes for '0' to '9'
		local candidate_key = string.char(i)
		if not assigned_keys[candidate_key] then
			return candidate_key
		end
	end

	-- If all options are exhausted, return nil (no available keys)
	return nil
end

-- Adds a key group with an ID and a prefix for the key group
-- The group is not finalized by default
function M.add_group(key_group_id, prefix_keys)
	-- Create a new group if it doesn't already exist
	if not M.config.key_groups[key_group_id] then
		M.config.key_groups[key_group_id] = {
			prefix = prefix_keys, -- Store the prefix for this group
			keys = {}, -- Initialize keys for this group
			pending_keys = {}, -- Initialize a table for pending key assignments
			is_finalized = false, -- Key group is not finalized by default
		}
	else
		log("Key group already exists.")
	end

	-- Ensure a shadow group exists as well
	if not M.config.shadow_groups[key_group_id] then
		local loaded_shadow = M.read_shadow_from_disk(key_group_id)
		if loaded_shadow then
			M.config.shadow_groups[key_group_id] = loaded_shadow
		else
			M.config.shadow_groups[key_group_id] = {}
		end
	end
end

-- Does not assign keys yet, just stores the pending key and mode
-- Dynamically asign a key to the key_id
-- NOTE: key_id is not the key itself, it is something identifying the key, for example, use case, the function name bound to the key, that when key is used, cursor goes to that function
-- key_id is the unique id for the key within our internal tables, it can for ex be the function name in case of functions, full buf file path in case of buffers etc., desc is what shows on menues using dynkey
function M.make_key(key_group_id, key_id, key_func, key_mode, desc)
	-- Check if the key group exists
	local key_group = M.config.key_groups[key_group_id]
	if key_group then
		if key_group.is_finalized then
			log("Cannot add keys. Key group is already finalized.")
			return
		end

		-- Add the key_id, function, and mode to the pending table
		key_group.pending_keys[key_id] = {
			func = key_func, -- Store the function to be assigned to the key
			mode = key_mode or "n", -- Store the mode (default to "n" if not provided)
			desc = desc,
		}
	else
		log("Key group not found.")
	end
end

-- Finalize the key group, assigns keys, and updates the shadow group
function M.finalize(key_group_id)
	local key_group = M.config.key_groups[key_group_id]
	local shadow_group = M.config.shadow_groups[key_group_id]

	-- Track whether shadow has been modified
	local shadow_modified = false
	if key_group and not key_group.is_finalized then
		-- Remove keys from shadow group that no longer exist
		for key_id, _ in pairs(shadow_group) do
			if not key_group.pending_keys[key_id] then
				shadow_group[key_id] = nil -- Remove from shadow
				shadow_modified = true -- Mark shadow as modified
			end
		end

		-- Assign keys from pending table
		local assigned_keys = {} -- Track already assigned keys
		-- put all our shadow keys in assigned keys as they are reserved
		for _, the_key in pairs(shadow_group) do
			assigned_keys[the_key] = true -- Mark the key as assigned
		end
		for key_id, key_data in pairs(key_group.pending_keys) do
			local key_func = key_data.func -- Extract the function
			if type(key_id) == "string" then
				if shadow_group[key_id] then
					key_group.keys[shadow_group[key_id]] = key_data -- Use shadow key and key data
					assigned_keys[shadow_group[key_id]] = true
				else
					local new_key = generate_unique_key(key_id, assigned_keys)

					if new_key then
						key_group.keys[new_key] = key_data -- Store both func and mode
						shadow_group[key_id] = new_key -- Update shadow
						shadow_modified = true -- Mark shadow as modified
						assigned_keys[new_key] = true
					else
						log("Error: No available keys for key_id.")
					end
				end
			else
				log("Error: key_id must be a string.")
			end
		end

		-- Mark the group as finalized
		key_group.is_finalized = true

		-- Write the updated shadow to disk only if modified
		if shadow_modified then
			M.write_shadow_to_disk(key_group_id, shadow_group)
		else
			log("No changes detected in shadow, skipping write.")
		end
	else
		log("Key group not found or already finalized (2).")
	end
end
--
--
--
--
--
--
--
--
--
--
--
function M.unbind_latest_bindings(context_id)
	-- Check if there is a previously bound key group in the context and unbind it
	--log("Latest bound: " .. context[context_id].last_bound_key_group_id)
	if context[context_id] and context[context_id].last_bound_key_group_id then
		M.unbind_keys(context[context_id].last_bound_key_group_id)
	end
end
-- Function to bind all keys in a key group with their specified mode
function M.bind_keys(context_id, key_group_id)
	-- Ensure a table exists for the given context_id
	context[context_id] = context[context_id] or {}

	local key_group = M.config.key_groups[key_group_id]
	local keypoint = require("keypoint")
	if key_group and key_group.is_finalized then
		-- Iterate through each key-function pair in the key group and bind them

		for action_key, key_data in pairs(key_group.keys) do
			-- Create keybinding with a prefix in the specified mode
			--			vim.api.nvim_set_keymap(
			--				key_data.mode, -- Mode (e.g., normal, insert, visual)
			--				key_group.prefix .. key, -- Full key combination (prefix + key)
			--				[[:lua ]] .. key_data.func .. [[<CR>]], -- Function to call
			--				{ noremap = true, silent = true, desc = key_data.desc } -- Keymap options
			--			)
			keypoint.add_action_key(key_group.prefix, action_key, key_data.func, key_data.desc)
		end

		-- Update the context to store the current key group
		context[context_id].last_bound_key_group_id = key_group_id
	else
		log("Key group not found or not finalized. ")
	end
end

-- Function to unbind all keys in a key group with their specified mode
function M.unbind_keys(key_group_id)
	local key_group = M.config.key_groups[key_group_id]
	local keypoint = require("keypoint")
	if key_group then
		key_group.is_finalized = false
		-- Iterate through each key-function pair in the key group and unbind them
		for key, key_data in pairs(key_group.keys) do
			local mode = key_data.mode or "n" -- Use the mode specified during binding
			-- Unbind the key (remove the mapping)
			--vim.api.nvim_del_keymap(mode, key_group.prefix .. key)
			keypoint.remove_action_key(key_group.prefix, key)
		end
		-- NOTE: Important, remove our internal representation of the keys
		M.config.key_groups[key_group_id] = nil -- completely remove it
	else
		log("Key group not found. ")
	end
end

-- Setup function to initialize the plugin
function M.setup(user_config)
	-- Merge user_config with default config
	M.config = vim.tbl_extend("force", M.config, user_config or {})
end

-- TODO: Is this even used, where?
function M.run_dynamic_key(prefix_key, action_key)
	-- Ensure the prefix key exists and is finalized
	local key_group = M.config.key_groups[prefix_key]

	if not key_group or not key_group.is_finalized then
		log("Error: Prefix key group not found or not finalized: " .. prefix_key)
		return
	end

	-- Check if the action key exists under the given prefix key
	local key_data = key_group.keys[action_key]
	if key_data then
		-- Execute the stored function for the action key
		key_data.func()

		-- Collect some statistics of what keys are used the most
		--record_key_stats(prefix_key, action_key)
	else
		log("Error: Action key _" .. action_key .. "_ not found under prefix _" .. prefix_key .. "_")
	end
end

-- Function to retrieve the key assigned to a given key_id in a key group
function M.get_key(key_group_id, key_id)
	-- Check if the key group exists and is finalized
	local key_group = M.config.key_groups[key_group_id]
	if not key_group or not key_group.is_finalized then
		log("dynkey - get_key: Error: Key group not found or not finalized.")
		return nil
	end

	-- Check if the key_id has an assigned key in the shadow group
	local shadow_group = M.config.shadow_groups[key_group_id]
	local assigned_key = shadow_group and shadow_group[key_id]

	if assigned_key then
		return assigned_key -- Return the assigned key for the given key_id
	else
		log("dynkey - get_key: Error: No key assigned for key_id.")
		return nil
	end
end
-- Return the module for use in the plugin
return M
