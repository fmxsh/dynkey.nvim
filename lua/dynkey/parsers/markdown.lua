-- Function to extract heading titles from Markdown using Tree-sitter
local function lang_markdown()
	local parser = vim.treesitter.get_parser(0, "markdown")
	local tree = parser:parse()[1]
	if not tree then
		print("Failed to parse the buffer")
		return {}
	end
	local root = tree:root()

	-- Markdown-specific Tree-sitter query
	local query = vim.treesitter.query.parse(
		"markdown",
		[[
        (atx_heading
            (inline) @content)

        (setext_heading
            (paragraph (inline) @content))
        ]]
	)

	if not query then
		print("Failed to load query for markdown headings")
		return {}
	end

	local headings = {}

	-- Iterate over matches
	for _, match, _ in query:iter_matches(root, 0) do
		for id, node in pairs(match) do
			local capture_name = query.captures[id]
			if capture_name == "content" then
				local heading_text = vim.treesitter.get_node_text(node, 0)
				table.insert(headings, heading_text)
			end
		end
	end

	return headings
end

return lang_markdown
