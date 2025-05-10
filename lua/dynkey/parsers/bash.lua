local function lang_bash()
	local parser = vim.treesitter.get_parser(0, "bash") -- Initialize Tree-sitter parser for Bash
	local tree = parser:parse()[1]
	if not tree then
		print("Failed to parse the buffer")
		return {}
	end

	local root = tree:root()

	-- Bash-specific Tree-sitter query for function definitions
	local query = vim.treesitter.query.parse(
		"bash",
		[[
        ; Match standalone function declarations
        (function_definition
            name: (word) @function_name)

        ; Match functions defined as <name>() { ... }
        (function_definition
            name: (word) @function_name
            body: (compound_statement))

        ; Match other variations with 'function' keyword
        (function_definition
            name: (word) @function_name)
        ]]
	)

	if not query then
		print("Failed to load query for Bash functions")
		return {}
	end

	local functions = {}

	-- Iterate over the matches
	for _, match, _ in query:iter_matches(root, 0) do
		local func_name = ""
		local start_row = nil

		-- Extract the function name
		for id, node in pairs(match) do
			local capture_name = query.captures[id]
			if capture_name == "function_name" then
				func_name = vim.treesitter.get_node_text(node, 0)
				start_row = node:range() -- Get line number
			end
		end

		-- Add to the list of functions
		if func_name ~= "" and start_row then
			table.insert(functions, { name = func_name, line = start_row + 1 })
		end
	end

	return functions
end

return lang_bash
