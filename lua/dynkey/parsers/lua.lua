-- Function to handle Lua-specific Tree-sitter parsing
local function lang_lua()
	local parser = vim.treesitter.get_parser(0, "lua")
	local tree = parser:parse()[1]
	if not tree then
		print("Failed to parse the buffer")
		return {}
	end
	local root = tree:root()

	-- NOTE: Had @function_name first but @func_name seems the correct capture
	-- Lua-specific Tree-sitter query
	local query = vim.treesitter.query.parse(
		"lua",
		[[
        ; Match standalone function declarations
        (function_declaration
            name: (identifier) @func_name)

        ; Match function declarations in tables (dot-indexed)
        (function_declaration
            name: (dot_index_expression
                table: (identifier) @table_name
                field: (identifier) @field_name))
    ; Match function definitions in table constructors
;    (table_constructor
;        (field
;            name: (identifier) @table_field_name
;            value: (function_definition)))
	    ; Match function definitions in table constructors
    (field
      name: (identifier) @table_field_name
      value: (function_definition))
            ]]
	)

	if not query then
		print("Failed to load query for functions")
		return {}
	end

	local functions = {}

	-- Iterate over the matches in the query
	for _, match, _ in query:iter_matches(root, 0) do
		local func_name = ""
		local start_row = nil

		-- Check if the match is a standalone function or a function in a table
		for id, node in pairs(match) do
			local capture_name = query.captures[id]
			if capture_name == "function_name" then
				-- Standalone function
				func_name = vim.treesitter.get_node_text(node, 0)
				start_row = node:range()
			elseif capture_name == "table_name" then
				-- Table function: concatenate table and field names
				local table_name = vim.treesitter.get_node_text(node, 0)
				local field_name = vim.treesitter.get_node_text(match[id + 1], 0) -- Field name is the next capture
				func_name = table_name .. "." .. field_name
				start_row = node:range()
			elseif capture_name == "table_field_name" then
				-- Table constructor function
				func_name = vim.treesitter.get_node_text(node, 0)
				start_row = node:range()
			end
		end

		if func_name ~= "" and start_row then
			table.insert(functions, { name = func_name, line = start_row + 1 }) -- Store function name and line
		end
	end
	return functions
end

return lang_lua
