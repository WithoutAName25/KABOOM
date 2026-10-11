local args = { ... }
local repo = "https://raw.githubusercontent.com/WithoutAName25/KABOOM/"
local target = "/KABOOM/"
local startupFile = "/startup/KABOOM.lua"

local refOverwrite = args[1]
local manifestRef = refOverwrite or "main"

local function abort(msg, cleanup)
  error({ abort = true, msg = msg, cleanup = cleanup or false }, 0)
end

local function printColor(color, ...)
  local old = term.getTextColor()
  if term.isColor() then term.setTextColor(color) end
  print(...)
  term.setTextColor(old)
end

local function get(ref, path)
  local res, err = http.get(repo .. ref .. "/" .. path, nil, true)
  if not res then
    abort(path .. ": " .. tostring(err), true)
    return
  end
  local data = res.readAll()
  res.close()
  return data
end

local function removeExistingInstall()
  if not fs.exists(target) then return end

  printColor(colors.red, target .. " already exists.")
  write("Remove it? [y/N] ")
  local answer = read()
  if answer:lower() ~= "y" then
    abort("Aborted.")
  end
  fs.delete(target)
end

local function downloadFiles(manifest)
  for _, f in ipairs(manifest.files) do
    print("Downloading " .. f)
    local data = get(refOverwrite or manifest.version, f)
    local dest = target .. f
    fs.makeDir(fs.getDir(dest))
    local h = fs.open(dest, "wb")
    h.write(data)
    h.close()
  end
end

local function configureAutostart(manifest)
  if not manifest.autostart then return end

  write("Should the program be added to startup? [Y/n]")
  local answer = read()
  if not answer:lower() ~= "n" then
    local h = fs.open(startupFile, "w")
    h.write(("shell.run(%q)\n"):format(target .. manifest.autostart))
  elseif fs.exists(startupFile) then
    fs.delete(startupFile)
  end
end

local function runSetup(manifest)
  if not manifest.setup then return end

  shell.run(target .. manifest.setup)
end

local function main()
  removeExistingInstall()

  local manifest = textutils.unserializeJSON(get(manifestRef, "manifest.json"))

  downloadFiles(manifest)

  local h = fs.open(target .. ".version", "w")
  h.write(manifest.version)
  h.close()
  printColor(colors.green, "Installed " .. manifest.version)

  configureAutostart(manifest)

  runSetup(manifest)
end

local ok, err = pcall(main, ...)
if not ok then
  if type(err) == "table" and err.abort then
    if err.cleanup and fs.exists(target) then
      fs.delete(target)
    end
    printColor(colors.red, err.msg)
  else
    error(err, 0)
  end
end
