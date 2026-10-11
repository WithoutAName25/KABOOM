local M = {}

function M.map(list, f)
  local res = {}
  for i, v in ipairs(list) do
    res[i] = f(v)
  end
  return res
end

return M
