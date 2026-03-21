local LIBS = "https://raw.githubusercontent.com/wradley/cc-tweaked-libraries/refs/heads/main" -- todo: replace with tags
local WHC  = "https://raw.githubusercontent.com/wradley/cc-wh-controller/refs/heads/main"    -- todo: replace with tags

return {
  manifest_version = 1,
  updated = 1774130098, -- Sat Mar 21 2026 14:54:58 GMT-0700 (Pacific Daylight Time)
  packages = {
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
