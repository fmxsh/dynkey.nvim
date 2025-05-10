local function lang_php()
	-- Get the Tree-sitter parser for the PHP language
	local parser = vim.treesitter.get_parser(0, "php")
	local tree = parser:parse()[1]
	if not tree then
		print("Failed to parse the buffer")
		return {}
	end

	local root = tree:root()

	-- Tree-sitter query for PHP class, method, and function declarations
	local query = vim.treesitter.query.parse(
		"php",
		[[
        ; Match standalone function declarations
        (function_definition
            name: (name) @function_name)

        ; Match method declarations inside a class
        (method_declaration
            name: (name) @method_name)

        ; Match class declarations
        (class_declaration
            name: (name) @class_name)
        ]]
	)

	if not query then
		print("Failed to load query for declarations")
		return {}
	end

	local declarations = {}

	-- Iterate over the matches in the query
	for _, match, _ in query:iter_matches(root, 0) do
		local decl_name = ""
		local start_row = nil

		-- Loop through the matched nodes (functions, methods, or classes)
		for id, node in pairs(match) do
			local capture_name = query.captures[id]
			if node then -- Ensure that the node is not nil
				if capture_name == "function_name" then
					-- Standalone function declaration
					decl_name = vim.treesitter.get_node_text(node, 0)
					start_row = node:range()
				elseif capture_name == "method_name" then
					-- Method inside a class
					decl_name = vim.treesitter.get_node_text(node, 0)
					start_row = node:range()
				elseif capture_name == "class_name" then
					-- Class declaration
					decl_name = vim.treesitter.get_node_text(node, 0)
					start_row = node:range()
				end
			end
		end

		if decl_name ~= "" and start_row then
			table.insert(declarations, { name = decl_name, line = start_row + 1 }) -- Store the declaration name and line number
		end
	end

	return declarations
end
return lang_php
