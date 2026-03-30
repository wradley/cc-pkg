return {
  manifest_version = 1,
  updated = 1774870898, -- Mon Mar 30 2026 14:54:58 GMT-0700 (Pacific Daylight Time)
  packages = {
    luaunit = {
      latest = "3.4",
      ["3.4"] = {
        manifest    = "manifest.lua",
        source_base = "https://raw.githubusercontent.com/wradley/cc-tweaked-libraries/49c97c84f65cc796d5882c3afcc55618c6dbbae5/lib/luaunit",
      },
    },
    log = {
      latest = "0.1.0",
      ["0.1.0"] = {
        manifest    = "manifest.lua",
        source_base = "https://raw.githubusercontent.com/wradley/cc-tweaked-libraries/49c97c84f65cc796d5882c3afcc55618c6dbbae5/lib/log",
      },
    },
    rednet_contracts = {
      latest = "0.1.1",
      ["0.1.1"] = {
        manifest    = "manifest.lua",
        source_base = "https://raw.githubusercontent.com/wradley/cc-tweaked-libraries/3a3bcd979132b69915e486a5f92930cff8133a0a/lib/rednet-contracts",
      },
      ["0.1.0"] = {
        manifest    = "manifest.lua",
        source_base = "https://raw.githubusercontent.com/wradley/cc-tweaked-libraries/49c97c84f65cc796d5882c3afcc55618c6dbbae5/lib/rednet-contracts",
      },
    },
    ["wh-controller"] = {
      latest = "0.2.0",
      ["0.2.0"] = {
        manifest    = "manifest.lua",
        source_base = "https://raw.githubusercontent.com/wradley/cc-wh-controller/refs/heads/main",
      },
    },
    ["inventory-coordinator"] = {
      latest = "0.2.0",
      ["0.2.0"] = {
        manifest    = "manifest.lua",
        source_base = "https://raw.githubusercontent.com/wradley/cc-global-sync/refs/heads/main",
      },
    },
  },
}
