local BASE = "https://raw.githubusercontent.com/wradley/cc-tweaked-libraries/refs/heads/main" -- todo: replace with tags

return {
  manifest_version = 1,
  updated = 1774127996, -- Sat Mar 21 2026 14:19:56 GMT-0700 (Pacific Daylight Time)
  packages = {
    log = {
      latest = "0.1.0",
      ["0.1.0"] = BASE .. "/lib/log/manifest.lua",
    },
    rednet_contracts = {
      latest = "0.1.0",
      ["0.1.0"] = BASE .. "/lib/rednet-contracts/manifest.lua",
    },
  },
}
