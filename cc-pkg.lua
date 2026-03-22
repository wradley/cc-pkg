-- cc-pkg v0.1.0
-- Package manager for CC:Tweaked programs and libraries.
-- https://github.com/wradley/cc-pkg

local VERSION = "0.1.0"
local REGISTRY_URL = "https://raw.githubusercontent.com/wradley/cc-pkg/refs/heads/main/registry.lua"
local REGISTRY_PATH = "/var/cc-pkg/registry.lua"

--------------------------------------------------------------------------------
-- HTTP
--------------------------------------------------------------------------------

local function httpGet(url)
  local response, err = http.get(url)
  if not response then
    return nil, err or ("request failed: " .. url)
  end
  local body = response.readAll()
  response.close()
  return body
end

--------------------------------------------------------------------------------
-- Filesystem
--------------------------------------------------------------------------------

local function writeFile(path, content)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
  local f = fs.open(path, "w")
  if not f then return false, "could not open for writing: " .. path end
  f.write(content)
  f.close()
  return true
end

local function readFile(path)
  if not fs.exists(path) then return nil, "not found: " .. path end
  local f = fs.open(path, "r")
  local content = f.readAll()
  f.close()
  return content
end

--------------------------------------------------------------------------------
-- Lua data files
-- Load a string that returns a table (registry, manifest).
--------------------------------------------------------------------------------

local function loadData(src, label)
  local fn, err = load(src, label or "?")
  if not fn then return nil, "parse error: " .. err end
  local ok, result = pcall(fn)
  if not ok then return nil, "eval error: " .. tostring(result) end
  if type(result) ~= "table" then
    return nil, "expected table, got " .. type(result)
  end
  return result
end

--------------------------------------------------------------------------------
-- Registry
--------------------------------------------------------------------------------

local function fetchRegistry()
  print("Fetching registry...")
  local body, err = httpGet(REGISTRY_URL)
  if not body then return false, "fetch failed: " .. err end
  local _, err2 = loadData(body, "registry")
  if err2 then return false, "invalid registry: " .. err2 end
  local ok, err3 = writeFile(REGISTRY_PATH, body)
  if not ok then return false, err3 end
  print("Saved to " .. REGISTRY_PATH)
  return true
end

local function loadRegistry()
  local body, err = readFile(REGISTRY_PATH)
  if not body then return nil, err end
  return loadData(body, "registry")
end

---Resolve a package name + optional version to a manifest URL and resolved version.
---@return string|nil url
---@return string|nil err
---@return string|nil resolvedVersion
local function resolveManifestUrl(registry, name, version)
  local pkg = registry.packages[name]
  if not pkg then return nil, "unknown package: " .. name end
  local ver = version or pkg.latest
  if not ver then return nil, "no latest version for: " .. name end
  local url = pkg[ver]
  if not url then return nil, name .. " version not found: " .. ver end
  return url, nil, ver
end

--------------------------------------------------------------------------------
-- Manifests
--------------------------------------------------------------------------------

local function fetchManifest(url)
  local body, err = httpGet(url)
  if not body then return nil, "manifest fetch failed: " .. err end
  local m, err2 = loadData(body, "manifest")
  if not m then return nil, "invalid manifest: " .. err2 end
  return m
end

--------------------------------------------------------------------------------
-- Install paths
--------------------------------------------------------------------------------

local function installBase(manifest)
  if manifest.type == "library" then
    return "/lib/" .. manifest.name .. "/" .. manifest.version
  end
  return "/programs/" .. manifest.name .. "/" .. manifest.version
end

local function installDest(manifest, filePath)
  local base = installBase(manifest)
  local rel = filePath
  if manifest.source_prefix then
    local prefix = manifest.source_prefix .. "/"
    if rel:sub(1, #prefix) == prefix then
      rel = rel:sub(#prefix + 1)
    end
  end
  return base .. "/" .. rel
end

--------------------------------------------------------------------------------
-- Dep resolution
--
-- Populates `resolved` (name → {version, manifest}) and `queue` (ordered list
-- of deps to install, dependencies before dependents) via DFS. Each name is
-- marked in `resolved` before recursing to handle diamond deps correctly.
--------------------------------------------------------------------------------

local function collectDeps(manifest, registry, resolved, queue)
  for depName, depInfo in pairs(manifest.deps or {}) do
    if resolved[depName] then
      if resolved[depName].version ~= depInfo.version then
        return false, string.format(
          "version conflict: %s requires %s@%s but %s@%s is already resolved",
          manifest.name, depName, depInfo.version,
          depName, resolved[depName].version
        )
      end
      -- same version already resolved, nothing to do
    else
      if not registry then
        return false, string.format(
          "registry required to resolve dep '%s' — run 'cc-pkg fetch' first",
          depName
        )
      end
      local url, err, ver = resolveManifestUrl(registry, depName, depInfo.version)
      if not url then return false, "dep " .. depName .. ": " .. err end

      -- mark before recursing to prevent infinite loops on circular deps
      resolved[depName] = { version = ver, url = url }

      local depManifest, err2 = fetchManifest(url)
      if not depManifest then return false, "dep " .. depName .. ": " .. err2 end

      -- recurse into dep's own deps before enqueuing it (deps first)
      local ok, err3 = collectDeps(depManifest, registry, resolved, queue)
      if not ok then return false, err3 end

      resolved[depName].manifest = depManifest
      table.insert(queue, { name = depName, version = ver, manifest = depManifest })
    end
  end
  return true
end

--------------------------------------------------------------------------------
-- File installation
--------------------------------------------------------------------------------

local function downloadPackage(manifest, force)
  local base = installBase(manifest)
  if not force and fs.exists(base) then
    return true, "already installed"
  end
  for _, filePath in ipairs(manifest.files or {}) do
    local srcUrl = manifest.source_base .. "/" .. filePath
    local dest = installDest(manifest, filePath)
    local body, err = httpGet(srcUrl)
    if not body then
      return false, "download failed (" .. filePath .. "): " .. err
    end
    local ok, err2 = writeFile(dest, body)
    if not ok then return false, "write failed (" .. dest .. "): " .. err2 end
    print("  + " .. dest)
  end
  return true
end

--------------------------------------------------------------------------------
-- Bin stub
--------------------------------------------------------------------------------

local function createBinStub(manifest)
  local entryPath = installDest(manifest, manifest.bin)
  local stubPath = "/bin/" .. manifest.name
  local content = string.format('shell.run("%s", ...)\n', entryPath)
  local ok, err = writeFile(stubPath, content)
  if not ok then return false, err end
  print("  bin stub -> " .. stubPath)
  return true
end

local function warnIfNoBin()
  for dir in shell.path():gmatch("[^:]+") do
    if dir == "/bin" then return end
  end
  print("")
  print("Note: /bin is not in your shell path.")
  print("  Add to startup.lua:")
  print("    shell.setPath(shell.path()..\":/bin\")")
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

local function cmdFetch()
  local ok, err = fetchRegistry()
  if not ok then printError(err) end
end

local function cmdInstall(name, opts)
  -- opts: { version, url, force }

  local registry

  if opts.url then
    -- with --url, use cached registry for dep resolution (may be nil if absent)
    registry = loadRegistry()
  else
    -- without --url, always freshen the registry first
    local ok, err = fetchRegistry()
    if not ok then
      printError("Could not fetch registry: " .. err)
      return
    end
    registry, _ = loadRegistry()
    if not registry then
      printError("Registry unavailable after fetch — this should not happen.")
      return
    end
  end

  -- resolve manifest URL for the root package
  local rootUrl = opts.url
  if not rootUrl then
    local url, err = resolveManifestUrl(registry, name, opts.version)
    if not url then printError(err); return end
    rootUrl = url
  end

  -- fetch root manifest
  local manifest, err = fetchManifest(rootUrl)
  if not manifest then printError(err); return end

  -- check already installed
  if not opts.force and fs.exists(installBase(manifest)) then
    print(manifest.name .. "@" .. manifest.version .. " is already installed.")
    print("Use --force to reinstall.")
    return
  end

  -- resolve and install deps
  local resolved = {}
  local depQueue = {}
  local ok2, err2 = collectDeps(manifest, registry, resolved, depQueue)
  if not ok2 then
    printError("Dependency resolution failed: " .. err2)
    return
  end

  for _, item in ipairs(depQueue) do
    if fs.exists(installBase(item.manifest)) then
      print("  dep " .. item.name .. "@" .. item.version .. " (already installed)")
    else
      print("Installing dep " .. item.name .. "@" .. item.version)
      local ok3, err3 = downloadPackage(item.manifest, false)
      if not ok3 then
        printError("Failed to install dep " .. item.name .. ": " .. err3)
        return
      end
    end
  end

  -- install root package
  print("Installing " .. manifest.name .. "@" .. manifest.version)
  local ok4, err4 = downloadPackage(manifest, opts.force)
  if not ok4 then printError(err4); return end

  -- run install script if present
  if manifest.install_script then
    local scriptPath = installBase(manifest) .. "/" .. manifest.install_script
    if fs.exists(scriptPath) then
      print("Running install script...")
      shell.run(scriptPath)
    else
      print("Warning: install_script not found at " .. scriptPath)
    end
  end

  -- create bin stub if manifest declares an entry point
  if manifest.type == "program" and manifest.bin then
    local ok5, err5 = createBinStub(manifest)
    if not ok5 then
      printError("Warning: could not create bin stub: " .. err5)
    else
      warnIfNoBin()
    end
  end

  if manifest.type == "program" and next(resolved) then
    print("")
    print("Add to your program's startup before requiring any deps:")
    for depName, depInfo in pairs(resolved) do
      local libBase = "/lib/" .. depName .. "/" .. depInfo.version
      print(string.format(
        '  package.path = "%s/?.lua;%s/?/init.lua;" .. package.path',
        libBase, libBase
      ))
    end
  end

  print("")
  print("Installed " .. manifest.name .. "@" .. manifest.version .. ".")
end

local function cmdList()
  local found = false

  if fs.exists("/lib") then
    for _, name in ipairs(fs.list("/lib")) do
      if fs.isDir("/lib/" .. name) then
        for _, version in ipairs(fs.list("/lib/" .. name)) do
          if fs.isDir("/lib/" .. name .. "/" .. version) then
            print("lib  " .. name .. " @ " .. version)
            found = true
          end
        end
      end
    end
  end

  if fs.exists("/programs") then
    for _, name in ipairs(fs.list("/programs")) do
      if fs.isDir("/programs/" .. name) then
        for _, version in ipairs(fs.list("/programs/" .. name)) do
          if fs.isDir("/programs/" .. name .. "/" .. version) then
            print("prog " .. name .. " @ " .. version)
            found = true
          end
        end
      end
    end
  end

  if not found then print("No packages installed.") end
end

local function cmdHelp()
  print("cc-pkg v" .. VERSION)
  print("")
  print("Commands:")
  print("  fetch              Update local package registry")
  print("  install <name>     Install a package (fetches")
  print("                     registry first)")
  print("    -t <version>       Install a specific version")
  print("    --url <url>        Install from a manifest URL")
  print("                       directly")
  print("    --force            Reinstall even if already")
  print("                       installed")
  print("  list               Show installed packages")
end

--------------------------------------------------------------------------------
-- Argument parsing
--------------------------------------------------------------------------------

local function parseArgs(args)
  local result = { flags = {} }
  local i = 1
  while i <= #args do
    local a = args[i]
    if i == 1 then
      result.cmd = a
    elseif a == "-t" then
      i = i + 1
      result.flags.version = args[i]
    elseif a == "--url" then
      i = i + 1
      result.flags.url = args[i]
    elseif a == "--force" then
      result.flags.force = true
    elseif a:sub(1, 1) ~= "-" and not result.name then
      result.name = a
    end
    i = i + 1
  end
  return result
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

local parsed = parseArgs({...})
local cmd = parsed.cmd

if cmd == "fetch" then
  cmdFetch()
elseif cmd == "install" then
  if not parsed.name then
    printError("Usage: cc-pkg install <name> [-t <version>] [--url <url>] [--force]")
  else
    cmdInstall(parsed.name, parsed.flags)
  end
elseif cmd == "list" then
  cmdList()
elseif cmd == nil or cmd == "help" then
  cmdHelp()
else
  printError("Unknown command: " .. tostring(cmd))
  print("Run 'cc-pkg help' for usage.")
end
