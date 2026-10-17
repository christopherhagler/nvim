-- Parse streamed MATLAB stack traces without executing their hyperlink commands.
local M = {}
function M.parse(output, root)
  local items, seen = {}, {}
  for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
    local path, number = line:match("opentoline%('([^']+)'%s*,%s*(%d+)")
    local plain = line:gsub("<[^>]+>", ""):gsub("[\b\r]", "")
    if not path then
      path, number = plain:match("Error in (.-) %(line (%d+)%)")
      if not path then path, number = plain:match("Error using (.-) %(line (%d+)%)") end
      if not path then path, number = plain:match("File: (.-) Line: (%d+)") end
      if path then
        path = path:match("^([^>]+)") or path
        if not path:match("%.m$") then path = path .. ".m" end
        if not vim.startswith(path, "/") and not path:match("^%a:[/\\]") then
          path = root .. "/" .. path
        end
        -- Plain function names cannot reliably locate package/path functions.
        if vim.fn.filereadable(path) == 0 then path = nil end
      end
    end
    if path then
      local key = path .. ":" .. number
      if not seen[key] then
        seen[key] = true
        items[#items + 1] = { filename = path, lnum = tonumber(number), text = vim.trim(plain), type = "E" }
      end
    end
  end
  return items
end
return M
