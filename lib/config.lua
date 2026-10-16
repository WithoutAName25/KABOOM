local M = {}

local prefix = "kaboom."
M.changedEvent = "kaboom_config_changed"

local definitions = {
  { key = "reactor",             name = "peripheral.reactor",          type = "string",  default = nil,      description = "Reactor peripheral name" },
  { key = "fluxGateIn",          name = "peripheral.flux_gate_in",     type = "string",  default = nil,      description = "Input flux gate peripheral name" },
  { key = "fluxGateOut",         name = "peripheral.flux_gate_out",    type = "string",  default = nil,      description = "Output flux gate peripheral name" },
  { key = "monitor",             name = "peripheral.monitor",          type = "string",  default = nil,      description = "Monitor peripheral name" },

  { key = "maxTemperature",      name = "bound.max_temp",              type = "number",  default = 8000,     description = "Temperature that triggers an emergency" },
  { key = "minFieldStrength",    name = "bound.min_field_strength",    type = "number",  default = 10,       description = "Field strength (%) that triggers an emergency" },
  { key = "maxFuelConversion",   name = "bound.max_fuel_conv",         type = "number",  default = 90,       description = "Fuel conversion (%) that triggers shutdown" },

  { key = "emergencyInput",      name = "emergency.input",             type = "number",  default = 10000000, description = "Input gate rate during emergency" },

  { key = "refuelAutoStart",     name = "refuel.auto_start",           type = "boolean", default = true,     description = "Start automatically after refueling" },
  { key = "refuelMaxConversion", name = "refuel.max_fuel_conv",        type = "number",  default = 1,        description = "Max fuel conversion (%) needed for automatic restart" },
  { key = "refuelMinTotalFuel",  name = "refuel.min_total_fuel",       type = "number",  default = 10365,    description = "Total fuel needed for automatic restart" },

  { key = "targetTemperature",   name = "param.target_temp",           type = "number",  default = 7000,     description = "Target reactor temperature" },
  { key = "targetFieldStrength", name = "param.target_field_strength", type = "number",  default = 20,       description = "Target field strength (%)" },
  { key = "input",               name = "param.input",                 type = "number",  default = 0,        description = "Manual input gate rate" },
  { key = "inputAuto",           name = "param.input_auto",            type = "boolean", default = true,     description = "Control input gate automatically" },
  { key = "warmupInput",         name = "param.warmup_input",          type = "number",  default = 1000000,  description = "Input gate rate during warmup" },
  { key = "output",              name = "param.output",                type = "number",  default = 0,        description = "Manual output gate rate" },
  { key = "outputAuto",          name = "param.output_auto",           type = "boolean", default = true,     description = "Control output gate automatically" },
}

local values = {}

for _, d in ipairs(definitions) do
  d.name = prefix .. d.name
  M[d.key] = d.name
  settings.define(d.name, {
    description = d.description,
    default = d.default,
    type = d.type,
  })
end

function M.reload()
  for _, d in ipairs(definitions) do
    values[d.name] = settings.get(d.name)
  end
end

function M.get(name)
  return values[name]
end

function M.set(name, value)
  settings.set(name, value) -- validates the type first, errors on mismatch
  values[name] = value
  settings.save()
  os.queueEvent(M.changedEvent, name, value)
end

function M.snapshot()
  local copy = {}
  for name, value in pairs(values) do
    copy[name] = value
  end
  return copy
end

M.reload()

return M
