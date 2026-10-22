-- Put ui.lua, cc.lua and loader.lua at the root of eystearisdown/wyattrz (main).
local url = "https://raw.githubusercontent.com/eystearisdown/wyattrz/main/cc.lua"
local ok, source = pcall(function() return game:HttpGet(url, true) end)
if not ok or type(source) ~= "string" then
    error("[CC] Không tải được cc.lua từ wyattrz: " .. tostring(source), 0)
end
local head = source:sub(1, 1000):lower()
if #source < 10000 or head:find("<!doctype", 1, true) or head:find("<html", 1, true) then
    error("[CC] GitHub chưa trả về cc.lua hợp lệ. Kiểm tra file ở gốc repo/nhánh main.", 0)
end
local run, compileError = loadstring(source, "@wyattrz/cc.lua")
if not run then error("[CC] Lỗi biên dịch cc.lua: " .. tostring(compileError), 0) end
return run()
