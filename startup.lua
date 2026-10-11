local dir = fs.getDir(shell.getRunningProgram())
local run = "/" .. fs.combine(dir, "run.lua")
if multishell then
  local id = shell.openTab(run, "-s")
  multishell.setTitle(id, "KABOOM")
  multishell.setFocus(id)
else
  shell.run(run)
end
