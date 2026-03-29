local LIBS = "https://raw.githubusercontent.com/wradley/cc-tweaked-libraries/refs/heads/main" -- todo: replace with tags
local WHC  = "https://raw.githubusercontent.com/wradley/cc-wh-controller/refs/heads/main"    -- todo: replace with tags

return {
  manifest_version = 1,
  updated = 1774870898, -- Mon Mar 30 2026 14:54:58 GMT-0700 (Pacific Daylight Time)
  packages = {
    luaunit = {
      latest = "3.4",
      ["3.4"] = LIBS .. "/lib/luaunit/manifest.lua",
    },
    log = {
      latest = "0.1.0",
      ["0.1.0"] = LIBS .. "/lib/log/manifest.lua",
    },
    rednet_contracts = {
      latest = "0.1.0",
      ["0.1.0"] = LIBS .. "/lib/rednet-contracts/manifest.lua",
    },
    ["wh-controller"] = {
      latest = "0.2.0",
      ["0.2.0"] = WHC .. "/manifest.lua",
    },
  },
}
