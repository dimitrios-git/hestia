-- comment; TODO: builtins, operators
local M = {}

local function greet(name, times)
  local out = ""
  for i = 1, times or 3 do
    out = out .. string.format("hi %s\n", name)
  end
  if name == nil or #out == 0 then
    print(out)
  end
  return { text = out, n = times }
end

M.greet = greet
return M
