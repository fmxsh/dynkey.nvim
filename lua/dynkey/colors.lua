-- mymodule.lua
local M = {}

-- Utility function to generate a random bright hex color
local function generate_bright_color()
	local r = math.random(128, 255) -- Restrict to high values for brightness
	local g = math.random(128, 255)
	local b = math.random(128, 255)
	return r, g, b, string.format("#%02X%02X%02X", r, g, b)
end

-- Utility function to generate a brighter version of a color
local function generate_brighter_color(r, g, b)
	-- Increase RGB values, but cap them at 255
	local brighter_r = math.min(r + 40, 255)
	local brighter_g = math.min(g + 40, 255)
	local brighter_b = math.min(b + 40, 255)
	return string.format("#%02X%02X%02X", brighter_r, brighter_g, brighter_b)
end

-- Utility function to generate a dimmer version of a color
local function generate_dimmer_color(r, g, b)
	-- Decrease RGB values slightly, but not below 0
	local dimmer_r = math.max(r - 80, 0)
	local dimmer_g = math.max(g - 80, 0)
	local dimmer_b = math.max(b - 80, 0)
	return string.format("#%02X%02X%02X", dimmer_r, dimmer_g, dimmer_b)
end

-- Function to apply color highlights based on the given buffer
function M.apply_color(buf, lines)
	-- Remember the previous dimmer color
	local previous_dimmer_color = nil

	-- Apply color highlights to the key (first 4 chars) and rest of the row
	for i, line in ipairs(lines) do
		-- Match the general pattern: key followed by space(s) and some text
		if line:match("^%s*%S+%s+%S+") then
			-- Generate a unique bright random color for each row
			local r, g, b, bright_color = generate_bright_color()

			-- Create a brighter version of the color for the first 4 chars (the key)
			local brighter_color = generate_brighter_color(r, g, b)

			-- Create a dimmer version of the color for the rest of the row (text part)
			local dimmer_color = generate_dimmer_color(r, g, b)

			-- Create a unique highlight group for the brighter color
			local highlight_group_bright = "FunctionKeyHighlightBright" .. i
			vim.cmd(string.format("highlight %s guifg=%s", highlight_group_bright, brighter_color))

			-- Create a unique highlight group for the dimmer color
			local highlight_group_dim = "FunctionKeyHighlightDim" .. i
			vim.cmd(string.format("highlight %s guifg=%s", highlight_group_dim, dimmer_color))

			-- Apply the brighter highlight to the first 4 characters (the key part)
			vim.api.nvim_buf_add_highlight(buf, -1, highlight_group_bright, i - 1, 0, 3)

			-- Apply the dimmer highlight to the rest of the row (text part)
			vim.api.nvim_buf_add_highlight(buf, -1, highlight_group_dim, i - 1, 3, -1)

			-- Remember the dimmer color for the next line (for rows without a key)
			previous_dimmer_color = highlight_group_dim
		else
			-- The current row has no key, so we apply the previous dimmer color
			if previous_dimmer_color then
				-- Apply the previous dimmer color to the entire row
				vim.api.nvim_buf_add_highlight(buf, -1, previous_dimmer_color, i - 1, 0, -1)
			end
		end
	end
end

return M
