-- ========================================
-- ICYCLES - Desktop Scanner
-- ========================================
-- Scans Desktop directory for items
-- Outputs to Data/ListedDesktopItems.lua
-- ========================================

function Initialize()
  -- Called on skin load
end

function Update()
  return ""
end

-- ========================================
-- MAIN FUNCTION: Scan Desktop
-- ========================================
function ScanDesktop()
  -- Load Desktop path from UserDesktopData
  local userDataPath = SKIN:GetVariable("CURRENTPATH") .. "..\\Data\\UserDesktopData.ldb"
  local userData = LoadDataFile(userDataPath)

  if not userData or not userData.desktopPath then
    LogError("Cannot load Desktop path from UserDesktopData.ldb")
    -- Fallback: try to get Desktop path directly
    local userProfile = os.getenv("USERPROFILE") or "C:\\Users\\Default"
    userData = {desktopPath = userProfile .. "\\Desktop"}
  end

  local desktopPath = userData.desktopPath
  print("Scanner: Scanning Desktop at " .. desktopPath)

  -- Scan directory
  local items = EnumerateDirectory(desktopPath)

  -- Update item count in UserDesktopData
  if userData then
    userData.desktopItemCount = #items
    -- Save updated user data (optional - could be done elsewhere)
  end

  print("Scanner: Found " .. #items .. " items")
  return items
end

-- ========================================
-- ENUMERATE DIRECTORY: Get all files
-- ========================================
function EnumerateDirectory(path)
  local items = {}

  -- Use io.popen to run dir command (Windows)
  -- /B = bare format (filenames only)
  -- /A-D = files only (exclude directories for now - can be toggled)
  local handle = io.popen('dir "' .. path .. '" /B 2>nul')

  if not handle then
    LogError("Cannot enumerate directory: " .. path)
    return items
  end

  for filename in handle:lines() do
    -- Skip system files and Rainmeter temp files
    if not filename:match("^desktop%.ini$") and
       not filename:match("^Thumbs%.db$") and
       not filename:match("%.tmp$") then

      local fullPath = path .. "\\" .. filename
      local itemData = ExtractItemData(fullPath, filename)

      if itemData then
        table.insert(items, itemData)
      end
    end
  end

  handle:close()

  -- Sort alphabetically by name
  table.sort(items, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  return items
end

-- ========================================
-- EXTRACT ITEM DATA: Get metadata
-- ========================================
function ExtractItemData(fullPath, filename)
  local item = {}

  -- Extract name (remove extension)
  local name, ext = filename:match("^(.+)%.([^%.]+)$")
  if not name then
    -- No extension (folder or file without extension)
    name = filename
    ext = ""
  end

  item.name = name
  item.path = fullPath
  item.ext = ext:lower()

  -- Determine type
  if ext:lower() == "lnk" then
    item.type = "shortcut"
    item.target = ResolveShortcut(fullPath)
    item.icon = item.target and (item.target .. ",0") or nil
  elseif ext:lower() == "url" then
    item.type = "url"
    item.target = ResolveURLFile(fullPath)
    item.icon = nil  -- URLs typically don't have icons
  elseif ext:lower() == "exe" then
    item.type = "executable"
    item.target = fullPath
    item.icon = fullPath .. ",0"
  elseif ext == "" then
    -- Check if it's a folder
    local attr = GetFileAttributes(fullPath)
    if attr and attr:match("d") then
      item.type = "folder"
      item.target = fullPath
      item.icon = "C:\\Windows\\System32\\imageres.dll,3"  -- Default folder icon
    else
      item.type = "file"
      item.target = fullPath
      item.icon = nil
    end
  else
    item.type = "file"
    item.target = fullPath
    item.icon = nil
  end

  -- Get timestamp (last modified)
  item.timestamp = GetFileTimestamp(fullPath)

  return item
end

-- ========================================
-- RESOLVE SHORTCUT: Get .lnk target
-- ========================================
function ResolveShortcut(lnkPath)
  -- Windows shortcut resolution requires COM objects or PowerShell
  -- Since we're avoiding PowerShell, we'll use a simple approach:
  -- Extract target from .lnk using binary parsing (basic)

  -- For now, return the lnk path itself
  -- In production, this could use a plugin or PowerShell fallback
  -- Rainmeter's FileView plugin can handle icons directly from .lnk

  -- Simple heuristic: assume target is in Program Files or similar
  local target = lnkPath:gsub("%.lnk$", ".exe")
  return target
end

-- ========================================
-- RESOLVE URL FILE: Get URL from .url file
-- ========================================
function ResolveURLFile(urlPath)
  -- .url files are INI format with [InternetShortcut] section
  local file = io.open(urlPath, "r")
  if not file then return nil end

  local url = nil
  for line in file:lines() do
    local match = line:match("^URL=(.+)$")
    if match then
      url = match
      break
    end
  end

  file:close()
  return url
end

-- ========================================
-- GET FILE ATTRIBUTES: Check if folder
-- ========================================
function GetFileAttributes(path)
  -- Use attrib command to get file attributes
  local handle = io.popen('attrib "' .. path .. '" 2>nul')
  if not handle then return nil end

  local result = handle:read("*a")
  handle:close()

  return result
end

-- ========================================
-- GET FILE TIMESTAMP: Last modified time
-- ========================================
function GetFileTimestamp(path)
  -- Use dir command to get timestamp
  -- This is a simplified approach - returns epoch time approximation
  return os.time()  -- Placeholder - could parse dir output for real timestamp
end

-- ========================================
-- SAVE FUNCTION: Write items to file
-- ========================================
function SaveScannedItems()
  local success, items = pcall(ScanDesktop)

  if not success then
    LogError("Failed to scan Desktop: " .. tostring(items))
    return false
  end

  -- Serialize items
  local serialized = SerializeTable(items)

  -- Build file path
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local filePath = skinPath .. "..\\Data\\ListedDesktopItems.lua"

  -- Write to temp file first (atomic write)
  local tempPath = filePath .. ".tmp"
  local writeSuccess, err = pcall(function()
    local file = io.open(tempPath, "w")
    if not file then
      error("Cannot open file for writing: " .. tempPath)
    end
    file:write("-- Auto-generated by Scanner.lua\n")
    file:write("-- Last scan: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
    file:write("-- Item count: " .. #items .. "\n\n")
    file:write("return " .. serialized)
    file:close()
  end)

  if not writeSuccess then
    LogError("Failed to write ListedDesktopItems.lua: " .. tostring(err))
    return false
  end

  -- Rename temp to actual
  os.remove(filePath)
  local renameSuccess = os.rename(tempPath, filePath)

  if not renameSuccess then
    LogError("Failed to rename temp file to ListedDesktopItems.lua")
    return false
  end

  print("Scanner: Saved " .. #items .. " items successfully")
  return true
end

-- ========================================
-- UTILITY: Load data file
-- ========================================
function LoadDataFile(path)
  local success, result = pcall(dofile, path)
  if success then
    return result
  else
    LogError("Failed to load data file: " .. path .. " - " .. tostring(result))
    return nil
  end
end

-- ========================================
-- UTILITY: Serialize Lua table
-- ========================================
function SerializeTable(tbl, indent)
  indent = indent or 0
  local spacing = string.rep("  ", indent)
  local result = "{\n"

  for i, item in ipairs(tbl) do
    result = result .. spacing .. "  {\n"

    -- Serialize each field
    for key, value in pairs(item) do
      local keyStr = string.format("%s    %s = ", spacing, key)

      if type(value) == "table" then
        result = result .. keyStr .. SerializeTable(value, indent + 2) .. ",\n"
      elseif type(value) == "string" then
        result = result .. keyStr .. string.format("%q", value) .. ",\n"
      elseif type(value) == "number" then
        result = result .. keyStr .. tostring(value) .. ",\n"
      elseif type(value) == "boolean" then
        result = result .. keyStr .. tostring(value) .. ",\n"
      else
        result = result .. keyStr .. "nil,\n"
      end
    end

    result = result .. spacing .. "  },\n"
  end

  result = result .. spacing .. "}"
  return result
end

-- ========================================
-- UTILITY: Error logging
-- ========================================
function LogError(message)
  local logPath = SKIN:GetVariable("CURRENTPATH") .. "..\\Logs\\errors.log"
  local file = io.open(logPath, "a")
  if file then
    file:write(string.format("[%s] Scanner: %s\n", os.date("%Y-%m-%d %H:%M:%S"), message))
    file:close()
  end
  print("ERROR: " .. message)
end
