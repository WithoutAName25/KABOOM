local M = {}

local config = require("lib.config")

local MAX_DEPLETION = 99
local BASE_HEAT_RISE = 444.7

local TEMP_PROPORTIONAL_GAIN = 0.7
local TEMP_INTEGRAL_TIME = 30
local MAX_INTEGRAL_CORRECTION = 300
local INTEGRAL_ACTIVE_BAND = 150
local INTEGRAL_MAX_APPROACHING_TEMPERATURE_RATE = 1
local MAX_TIME_STEP = 1

local emergencyState = {
  tempToHigh = false,
  fieldToWeak = false
}

local temperatureController = {
  integralCorrection = 0,
  lastUpdate = nil,
  lastTemperature = nil,
}

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(value, maximum))
end

local function resetTemperatureController()
  temperatureController.integralCorrection = 0
  temperatureController.lastUpdate = nil
  temperatureController.lastTemperature = nil
end

local function elapsedSinceLastUpdate()
  local now = os.clock()
  local lastUpdate = temperatureController.lastUpdate
  temperatureController.lastUpdate = now
  if not lastUpdate then
    return 0
  end
  return math.min(now - lastUpdate, MAX_TIME_STEP)
end

local function readState(reactor)
  local state = reactor.getReactorInfo()
  if not state then return nil end

  state.energySaturationFraction = state.energySaturation / state.maxEnergySaturation
  state.fieldStrengthFraction    = state.fieldStrength / state.maxFieldStrength
  state.fuelConversionFraction   = state.fuelConversion / state.maxFuelConversion
  state.fuelConversionLevel      = state.fuelConversionFraction * 1.3 - 0.3

  return state
end

local function computeInput(state, cfg)
  if not cfg[config.inputAuto] then
    return cfg[config.input]
  end

  if state.status == "warming_up" then
    return cfg[config.warmupInput]
  end

  local targetFieldStrength = cfg[config.targetFieldStrength] / 100
  return state.fieldDrainRate / (1 - targetFieldStrength)
end

local function heatRiseFromDepletion(depletion)
  return depletion ^ 3 / (100 - depletion)
end

local function equilibriumDepletion(targetTemperature, conversionLevel)
  local scaledTemperature = clamp(targetTemperature / 200, 0, 99)
  local heatResistance = scaledTemperature ^ 4 / (100 - scaledTemperature)

  local requiredDepletionHeat = heatResistance * (1 - conversionLevel)
      - 1000 * conversionLevel
      - BASE_HEAT_RISE

  if requiredDepletionHeat <= 0 then
    return 0
  end
  if requiredDepletionHeat >= heatRiseFromDepletion(MAX_DEPLETION) then
    return MAX_DEPLETION
  end

  local lowDepletion, highDepletion = 0, MAX_DEPLETION
  for _ = 1, 50 do
    local midDepletion = (lowDepletion + highDepletion) / 2
    if heatRiseFromDepletion(midDepletion) < requiredDepletionHeat then
      lowDepletion = midDepletion
    else
      highDepletion = midDepletion
    end
  end
  return (lowDepletion + highDepletion) / 2
end

local function computeOutput(state, cfg)
  if not cfg[config.outputAuto] then
    resetTemperatureController()
    return cfg[config.output]
  end

  if state.status ~= "running" then
    resetTemperatureController()
    return 0
  end

  local timeStep = elapsedSinceLastUpdate()

  local temperatureRate = 0
  if temperatureController.lastTemperature and timeStep > 0 then
    temperatureRate = (state.temperature - temperatureController.lastTemperature) / timeStep
  end
  temperatureController.lastTemperature = state.temperature

  local maxTemperature = cfg[config.maxTemperature]

  if state.energySaturationFraction >= 0.999 then
    return 1000000
  end
  local maxGenerationRate = state.generationRate / (1 - state.energySaturationFraction)

  local targetTemperature = cfg[config.targetTemperature]
  local temperatureError = targetTemperature - state.temperature

  local proportionalCorrection = TEMP_PROPORTIONAL_GAIN * temperatureError
  local candidateIntegralCorrection = clamp(
    temperatureController.integralCorrection
    + TEMP_PROPORTIONAL_GAIN / TEMP_INTEGRAL_TIME * temperatureError * timeStep,
    -MAX_INTEGRAL_CORRECTION,
    MAX_INTEGRAL_CORRECTION
  )

  local rawCorrectedTarget = targetTemperature + proportionalCorrection + candidateIntegralCorrection
  local correctedTarget = clamp(rawCorrectedTarget, 0, maxTemperature)
  print(correctedTarget)
  local targetDepletion = equilibriumDepletion(correctedTarget, state.fuelConversionLevel)

  local saturatedHigh = temperatureError > 0
      and (rawCorrectedTarget >= maxTemperature or targetDepletion >= MAX_DEPLETION)
  local saturatedLow = temperatureError < 0
      and (rawCorrectedTarget <= 0 or targetDepletion <= 0)
  local nearTarget = math.abs(temperatureError) < INTEGRAL_ACTIVE_BAND
  local approachingQuickly = temperatureError * temperatureRate > 0
      and math.abs(temperatureRate) > INTEGRAL_MAX_APPROACHING_TEMPERATURE_RATE

  if nearTarget and not approachingQuickly and not (saturatedHigh or saturatedLow) then
    temperatureController.integralCorrection = candidateIntegralCorrection
  end

  return math.floor(targetDepletion / MAX_DEPLETION * maxGenerationRate)
end

local function checkEmergency(state, cfg)
  if state.temperature > cfg[config.maxTemperature] then
    if not emergencyState.tempToHigh then
      print("Temp too high: " .. state.temperature)
    end
    emergencyState.tempToHigh = true
  end
  local fieldStrengthPercent = state.fieldStrengthFraction * 100
  if (state.status == "running" or state.status == "stopping") and fieldStrengthPercent < cfg[config.minFieldStrength] then
    if not emergencyState.fieldToWeak then
      print("Field too weak: " .. fieldStrengthPercent)
    end
    emergencyState.fieldToWeak = true
  end

  return emergencyState.tempToHigh or emergencyState.fieldToWeak
end

local function checkFuelDepleted(state, cfg)
  return state.fuelConversionFraction * 100 > cfg[config.maxFuelConversion]
end

function M.tick(reactor, gateIn, gateOut)
  local cfg = config.snapshot()
  local state = readState(reactor)

  local emergency = state == nil or checkEmergency(state, cfg)
  if emergency then
    resetTemperatureController()
    gateIn.setFlowOverride(cfg[config.emergencyInput])
    gateOut.setFlowOverride(0)
    if state == nil or (state.status ~= "stopping" and state.status ~= "cooling" and state.status ~= "cold") then
      reactor.stopReactor()
    end
  else
    gateIn.setSignalLowFlow(computeInput(state, cfg))
    gateOut.setSignalLowFlow(computeOutput(state, cfg))
  end
  gateIn.setOverrideEnabled(emergency)
  gateOut.setOverrideEnabled(emergency)

  if state ~= nil and state.status == "running" and checkFuelDepleted(state, cfg) then
    reactor.stopReactor()
  end

  return state, emergencyState
end

return M
