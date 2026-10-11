local M = {}

function M.ask(question, default)
  local options = ""
  if default then
    options = " [Y/n]"
  else
    options = " [y/N]"
  end
  term.write(question .. options)
  local answer = read()
  if default then
    return answer == "" or answer:lower() == "y"
  else
    return answer:lower() == "y"
  end
end

return M
