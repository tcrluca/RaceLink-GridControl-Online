-- RaceLink GridControl Online 0.2.0
-- Server-loaded local-car rolling collision controller.
local function newController()
-- Event-configured local-car collision control. Each participant must run the app.
-- Never bypass CSP physics permissions; only undo changes made by this module.
local M={}
local physics,ac=physics,ac
function M.setAPI(p,a) physics=p;ac=a end
local enabled,changed=false,false
local status='ROLLING COLLISIONS: NORMAL / NO-COLLISION OFF'
local elapsed,clearFor=0,0
local function read(object,key)
    local ok,value=pcall(function()return object[key]end)
    if ok then return value end
    return nil
end
-- CSP exposes some zero-wrapper native calls as LuaJIT FFI cdata.
-- These are callable too; pcall still validates execution and permission result.
local function callable(value)
    local kind=type(value)
    return kind=='function' or kind=='cdata'
end
local function permitted()
    if not physics then return false,'PHYSICS NAMESPACE UNAVAILABLE' end
    if not callable(physics.allowed) then return false,'PERMISSION API UNAVAILABLE' end
    local ok,value=pcall(physics.allowed)
    if not ok then return false,'PERMISSION CHECK FAILED' end
    if value~=true then return false,'PHYSICS NOT ALLOWED IN THIS SESSION' end
    if not callable(physics.disableCarCollisions) then return false,'COLLISION API UNAVAILABLE' end
    if callable(ac.getPatchVersionCode) then
        local good,version=pcall(ac.getPatchVersionCode)
        if not good or not tonumber(version) or tonumber(version)<3424 then return false,'CSP 0.2.8+ REQUIRED' end
    end
    if not callable(ac.areCarsColliding) then return false,'OVERLAP CHECK UNAVAILABLE' end
    return true
end
local function setDisabled(value)
    local ok,result=pcall(physics.disableCarCollisions,0,value,true)
    return ok and result~=false
end
local function separated(sim)
    local count=tonumber(read(sim,'carsCount'))
    if not count or count<1 then return false end
    local own=ac.getCar(0)
    if not own or read(own,'isConnected')==false then return false end
    for i=1,count-1 do
        local car=ac.getCar(i)
        if car and read(car,'isConnected')~=false then
            local ok,overlap=pcall(ac.areCarsColliding,0,i)
            if not ok or overlap~=false then return false end
        end
    end
    return true
end
function M.setEnabled(value)
    enabled=value==true
    if enabled then
        local ok,why=permitted()
        status=ok and 'ROLLING COLLISIONS: NO-COLLISION ARMED / API READY' or 'ROLLING COLLISIONS: '..why
    else
        status=changed and 'ROLLING COLLISIONS: RESTORE PENDING' or 'ROLLING COLLISIONS: NORMAL / NO-COLLISION OFF'
    end
end
function M.isEnabled()return enabled end
function M.isActive()return changed end
function M.getStatus()return status end
function M.getDiagnostics()
    local allowed='missing'
    if physics and callable(physics.allowed) then local ok,value=pcall(physics.allowed);allowed=ok and tostring(value) or 'error' end
    local patch='?'
    if callable(ac.getPatchVersionCode) then local ok,value=pcall(ac.getPatchVersionCode);if ok then patch=tostring(value)end end
    return 'CSP '..tostring(patch)..' / physics='..type(physics)..' / allowed='..allowed
        ..' / permissionAPI='..type(physics and physics.allowed)..' / versionAPI='..type(ac.getPatchVersionCode)
        ..' / collision='..type(physics and physics.disableCarCollisions)..' / overlap='..type(ac.areCarsColliding)
end
function M.update(dt,formation,sim)
    dt=math.min(math.max(tonumber(dt) or 0,0),0.1)
    local wanted=enabled and formation and read(sim,'isReplayActive')~=true
    if wanted then
        if changed then clearFor=0;return end
        local allowed,why=permitted()
        if not allowed then status='ROLLING COLLISIONS: '..why;return end
        if setDisabled(true) then
            changed=true;clearFor=0;elapsed=0
            status='ROLLING COLLISIONS: DISABLED / LOCAL CAR'
        else status='ROLLING COLLISIONS: REQUEST FAILED' end
        return
    end
    if not changed then return end
    if read(sim,'isPaused')==true then return end
    elapsed=elapsed+dt
    if elapsed<0.1 then return end
    local interval=elapsed;elapsed=0
    if not separated(sim) then
        clearFor=0;status='ROLLING COLLISIONS: RESTORE WAITING / CARS OVERLAP OR DATA UNAVAILABLE';return
    end
    clearFor=clearFor+interval
    if clearFor<0.5 then status='ROLLING COLLISIONS: RESTORE WAITING / CHECKING SEPARATION';return end
    if setDisabled(false) then
        changed=false;clearFor=0;status='ROLLING COLLISIONS: NORMAL / RESTORED'
    else status='ROLLING COLLISIONS: RESTORE FAILED / RETRYING' end
end
function M.release()
    if changed and physics and callable(physics.disableCarCollisions) and setDisabled(false) then changed=false end
    enabled=false;clearFor=0;elapsed=0
end
return M

end
-- The following wrapper is bundled after the collision controller.
local controller = newController()
controller.setAPI(physics, ac)
local channel
local setupError
local ok, result = pcall(function()
  return ac.connect({ac.StructItem.key('racelink.gridcontrol.rolling.v1'),
    appTick=ac.StructItem.int32(),want=ac.StructItem.int32(),
    serverTick=ac.StructItem.int32(),active=ac.StructItem.int32(),
    message=ac.StructItem.string(160)},false,ac.SharedNamespace.Shared)
end)
if ok then channel=result else setupError='BRIDGE API UNAVAILABLE' end
local configOK, config = pcall(ac.configValues, {rollingGhostEnabled=false})
local serverEnabled = configOK and config and config.rollingGhostEnabled==true
local lastAppTick = channel and channel.appTick or 0
local appAge = 99
local lastStatus
local function read(object, key)
  local good, value = pcall(function() return object[key] end)
  return good and value or nil
end
local function statusText()
  if setupError or not channel then return setupError or 'BRIDGE UNAVAILABLE' end
  if not serverEnabled then return 'DISABLED BY SERVER' end
  if appAge>2 and not controller.isActive() then return 'WAITING FOR GRIDCONTROL APP' end
  return controller.getStatus():gsub('^ROLLING COLLISIONS: ', '')
end
function script.update(dt)
  dt=math.min(math.max(tonumber(dt) or 0,0),0.1)
  local sim=ac.getSim()
  if channel then
    if channel.appTick~=lastAppTick then appAge=0;lastAppTick=channel.appTick
    elseif read(sim,'isPaused')~=true then appAge=appAge+dt end
  end
  local raceType=ac.SessionType and ac.SessionType.Race or 3
  local race=read(sim,'isOnlineRace')==true and read(sim,'raceSessionType')==raceType
    and read(sim,'isReplayActive')~=true
  local wanted=channel and serverEnabled and race and appAge<=2 and channel.want==1
  if controller.isEnabled()~=(serverEnabled==true) then controller.setEnabled(serverEnabled==true) end
  controller.update(dt,wanted==true,sim)
  local text=statusText()
  if channel then
    channel.active=controller.isActive() and 1 or 0
    channel.message=text
    channel.serverTick=(channel.serverTick+1)%1000000000
  end
  if text~=lastStatus then ac.log('[RaceLink GridControl Online 0.2.0] '..text);lastStatus=text end
end
function script.drawUI()
  -- Visible status also confirms the companion is alive if the app is missing.
  ui.transparentWindow('RaceLinkGridControlOnlineStatus',vec2(24,350),vec2(610,82),true,false,function()
    ui.drawRectFilled(vec2(0,0),vec2(610,82),rgbm(0.025,0.035,0.05,0.92),6)
    ui.dwriteDrawText('GRIDCONTROL ONLINE 0.2.0',18,vec2(12,8),rgbm(0.3,0.85,1,1))
    ui.dwriteDrawText(statusText(),16,vec2(12,36),rgbm(1,1,1,1))
    ui.dwriteDrawText('Local car only | requires GridControl 0.7.8.16.31+',12,vec2(12,62),rgbm(0.7,0.75,0.8,1))
  end)
end
ac.onRelease(function()
  controller.release()
  if channel then channel.active=0;channel.message='ONLINE MODULE STOPPED' end
end)
