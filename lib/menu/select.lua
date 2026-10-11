local M = {}

local function resetColors()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
end

function M.select(title, values)
  if #values == 0 then return nil end

  table.sort(values)

  local w, h = term.getSize()
  local listTop = 3
  local visible = h - listTop -- rows 3..h-1, last row is the help line
  local selected = 1
  local scroll = 0            -- how many are above the first line

  local function draw()
    resetColors()
    term.clear()
    term.setCursorPos(1, 1)
    term.write(title)

    for i = 1, visible do
      local idx = i + scroll
      local name = values[idx]
      if not name then break end
      local label = name:sub(1, w) .. (" "):rep(w - #name)

      term.setCursorPos(1, listTop + i - 1)
      if idx == selected then
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
      end
      term.write(label)
      resetColors()
    end

    term.setCursorPos(1, h)
    term.write("Up/Down, Enter or click to select")
  end

  while true do
    if selected <= scroll then
      scroll = selected - 1
    elseif selected > scroll + visible then
      scroll = selected - visible
    end
    draw()

    local event, a, _, c = os.pullEvent()
    if event == "key" then
      if a == keys.up and selected > 1 then
        selected = selected - 1
      elseif a == keys.down and selected < #values then
        selected = selected + 1
      elseif a == keys.enter or a == keys.numPadEnter then
        break
      end
    elseif event == "mouse_scroll" then
      selected = math.max(1, math.min(#values, selected + a))
    elseif event == "mouse_click" then
      local y = c
      if y >= listTop and y < listTop + visible then
        local idx = y - listTop + 1 + scroll
        if selected == idx then
          break
        elseif values[idx] then
          selected = idx
        end
      end
    end
  end

  term.clear()
  term.setCursorPos(1, 1)
  return values[selected]
end

return M
