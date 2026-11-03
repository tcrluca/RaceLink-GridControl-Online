-- RaceLink GridControl Online diagnostic 0.1.0
-- Read-only: never calls a function that changes car physics.
local VERSION = '0.1.0'
local elapsed = 1
local current = 'Waiting for first update'
local previous = nil

local function callable(value)
  return type(value) == 'function' or type(value) == 'cdata'
end

local function describe()
  local p = physics
  local permission = 'API MISSING'
  if p and callable(p.allowed) then
    local ok, value = pcall(p.allowed)
    permission = ok and tostring(value) or 'API ERROR'
  end
  local collision = p and callable(p.disableCarCollisions) and 'present' or 'missing'
  local overlap = ac and callable(ac.areCarsColliding) and 'present' or 'missing'
  local build = 'unknown'
  if ac and callable(ac.getPatchVersionCode) then
    local ok, value = pcall(ac.getPatchVersionCode)
    if ok then build = tostring(value) end
  end
  return 'CSP ' .. build .. ' | physics.allowed=' .. permission
    .. '\nCollision API: ' .. collision .. ' | overlap API: ' .. overlap
end

function script.update(dt)
  elapsed = elapsed + math.max(0, tonumber(dt) or 0)
  if elapsed < 1 then return end
  elapsed = 0
  current = describe()
  if current ~= previous then
    ac.log('[RaceLink GridControl Online diagnostic ' .. VERSION .. '] '
      .. current:gsub('\n', ' | ') .. ' | READ ONLY')
    previous = current
  end
end

function script.drawUI()
  ui.transparentWindow('RaceLinkGridControlOnlineDiagnostic', vec2(24, 350), vec2(600, 110), true, false, function()
    ui.drawRectFilled(vec2(0, 0), vec2(600, 110), rgbm(0.025, 0.035, 0.05, 0.92), 6)
    ui.dwriteDrawText('GRIDCONTROL ONLINE DIAGNOSTIC ' .. VERSION, 18, vec2(12, 8), rgbm(0.3, 0.85, 1, 1))
    ui.dwriteDrawText(current, 16, vec2(12, 34), rgbm(1, 1, 1, 1))
    ui.dwriteDrawText('READ ONLY - car collisions are unchanged', 14, vec2(12, 86), rgbm(0.7, 0.75, 0.8, 1))
  end)
end
