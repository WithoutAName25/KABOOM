local config = require("lib.config")
local control = require("lib.control")

local function main(args)
  local reactor = peripheral.wrap(config.get(config.reactor))
  local gateIn = peripheral.wrap(config.get(config.fluxGateIn))
  local gateOut = peripheral.wrap(config.get(config.fluxGateOut))
  local monitor = peripheral.wrap(config.get(config.monitor))

  while true do
    local ok, err = pcall(control.tick, reactor, gateIn, gateOut)
    if not ok then
      if err == "Terminated" then
        error(err, 0)
      end
      printError(err)
    end
    sleep(0.05)
  end
end

local args = { ... }
local startShell = false
local rest = {}
for _, a in ipairs(args) do
  if a == "-s" or a == "--shell" then
    startShell = true
  else
    rest[#rest + 1] = a
  end
end


local ok, err = pcall(main, rest)
if not ok then
  printError(err)
end

if startShell then
  shell.setDir(fs.getDir(shell.getRunningProgram()))
  shell.run("shell")
end
