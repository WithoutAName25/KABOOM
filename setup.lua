local config = require("lib.config")
local dialog = require("lib.menu.dialog")
local select = require("lib.menu.select")
local utils = require("lib.utils")

local function configure(setting, name, type)
  local list = { peripheral.find(type) }
  local names = utils.map(list, peripheral.getName)
  local peripheralName = select.select("Select peripheral name for " .. name, names)
  config.set(setting, peripheralName)
end

configure(config.reactor, "Reactor", "draconic_reactor")
configure(config.fluxGateIn, "Flux Input Gate", "flow_gate")
configure(config.fluxGateOut, "Flux Output Gate", "flow_gate")
configure(config.monitor, "Monitor", "monitor")

local run = dialog.ask("Start program", true)

if run then
  local dir = fs.getDir(shell.getRunningProgram())
  shell.run("/" .. fs.combine(dir, "startup.lua"))
end
