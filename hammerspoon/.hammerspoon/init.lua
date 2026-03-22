

local function resizeOnNewWindow(appName, x, y, w, h, delay)
  delay = delay or 0.5
  local wf = hs.window.filter.new(appName)
  wf:subscribe(hs.window.filter.windowCreated, function(win)
    hs.timer.doAfter(delay, function()
      if win then win:setFrame({x=x, y=y, w=w, h=h}) end
    end)
  end)
end

-- e.g test current size window of app 
-- local win = hs.application.find("Zed"):mainWindow()            
-- print(win:size())
-- after edit reload config on Hammerspoon  

resizeOnNewWindow("Cursor", 22, 40, 1699, 1070)
resizeOnNewWindow("Zed", 16, 38, 1699, 1070)
