-- cc-pkg installer
-- wget https://raw.githubusercontent.com/wradley/cc-pkg/refs/heads/main/install.lua
-- then: install.lua

local CCPKG_URL    = "https://raw.githubusercontent.com/wradley/cc-pkg/refs/heads/main/cc-pkg.lua"
local CCPKG_BIN    = "/bin/cc-pkg"
local SNIPPET_PATH = "/etc/cc-pkg/startup.lua"
local STARTUP_PATH = "/startup.lua"
local DOFILE_LINE  = 'dofile("/etc/cc-pkg/startup.lua")'

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r")
  local s = f.readAll()
  f.close()
  return s
end

local function writeFile(path, content)
  local f = fs.open(path, "w")
  f.write(content)
  f.close()
end

--------------------------------------------------------------------------------
-- Steps
--------------------------------------------------------------------------------

-- 1. Download cc-pkg to /bin/cc-pkg
print("Downloading cc-pkg...")
ensureDir("/bin")
if fs.exists(CCPKG_BIN) then fs.delete(CCPKG_BIN) end
if not shell.run("wget", CCPKG_URL, CCPKG_BIN) then
  printError("Failed to download cc-pkg.")
  return
end
print("Installed to " .. CCPKG_BIN)

-- 2. Write startup snippet
print("Writing startup configuration...")
ensureDir("/etc/cc-pkg")
writeFile(SNIPPET_PATH, [[
-- cc-pkg startup configuration. Re-run install.lua to update.

-- Add /bin to shell path if not already present.
local inBin = false
for dir in shell.path():gmatch("[^:]+") do
  if dir == "/bin" then inBin = true; break end
end
if not inBin then
  shell.setPath(shell.path() .. ":/bin")
end

-- Register shell completion for cc-pkg.
-- Completion functions return suffix strings (the part after what is typed).
local function complete(choices, text)
  local results = {}
  for _, choice in ipairs(choices) do
    if choice:sub(1, #text) == text then
      results[#results + 1] = choice:sub(#text + 1)
    end
  end
  return results
end

local function packageNames()
  if not fs.exists("/var/cc-pkg/registry.lua") then return {} end
  local f = fs.open("/var/cc-pkg/registry.lua", "r")
  local src = f.readAll()
  f.close()
  local fn = load(src)
  if not fn then return {} end
  local ok, reg = pcall(fn)
  if not ok or type(reg) ~= "table" or type(reg.packages) ~= "table" then return {} end
  local names = {}
  for name in pairs(reg.packages) do names[#names + 1] = name end
  table.sort(names)
  return names
end

shell.setCompletionFunction("bin/cc-pkg", function(shl, idx, text, prev)
  if idx == 1 then
    return complete({"fetch", "install", "list", "help"}, text)
  elseif prev[1] == "install" then
    if idx == 2 then
      return complete(packageNames(), text)
    else
      return complete({"-t", "--url", "--force"}, text)
    end
  end
end)
]])
print("Written to " .. SNIPPET_PATH)

-- 3. Add dofile line to /startup.lua if not already present
local existing = readFile(STARTUP_PATH) or ""
if existing:find(DOFILE_LINE, 1, true) then
  print(STARTUP_PATH .. " already configured.")
else
  local updated = existing
  if updated ~= "" and not updated:match("\n$") then
    updated = updated .. "\n"
  end
  updated = updated .. DOFILE_LINE .. "\n"
  writeFile(STARTUP_PATH, updated)
  print("Updated " .. STARTUP_PATH)
end

print("")
print("Done! Reboot or run the following to apply now:")
print('  dofile("' .. SNIPPET_PATH .. '")')
