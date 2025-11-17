-- ========================================
-- ICYCLES - Desktop Scanner
-- ========================================
-- Scans Desktop directory for items
-- Outputs to Data/ListedDesktopItems.ldb
-- Uses FileView plugin controlled by this script
-- ========================================

-- Internal state
local isScanning = false
local pendingDesktopPath = ""

function Initialize()
  -- Called on skin load
  isScanning = false
  pendingDesktopPath = ""
end

function Update()
  return ""
end

-- ========================================
-- MAIN FUNCTION: Scan Desktop
-- ========================================
function ScanDesktop()
  -- Load Desktop path from UserDesktopData
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local userDataPath = skinPath .. "Data\\UserDesktopData.ldb"
  local userData = LoadDataFile(userDataPath)

  if not userData or not userData.desktopPath then
    LogError("Cannot load Desktop path from UserDesktopData.ldb")
    -- Fallback: try to get Desktop path directly
    local userProfile = SKIN:GetVariable("USERPROFILE") or "C:\\Users\\Default"
    userData = {desktopPath = userProfile .. "\\Desktop"}
  end

  local desktopPath = userData.desktopPath
  print("Scanner: Scanning Desktop at " .. desktopPath)

  -- Use FileView measure to enumerate Desktop files directly
  local items = ReadDesktopDirectly(desktopPath)

  print("Scanner: Found " .. #items .. " items")
  return items
end

-- ========================================
-- READ DESKTOP DIRECTLY: Use FileView measure
-- ========================================
function ReadDesktopDirectly(desktopPath)
  local items = {}

  print("Scanner: Reading Desktop files directly via FileView")

  -- Get the FileView measure (should already be updated by button action)
  local fileViewMeasure = SKIN:GetMeasure("MeasureDesktopFileView")
  if not fileViewMeasure then
    LogError("Cannot find MeasureDesktopFileView - FileView plugin not loaded")
    return items
  end

  -- FileView plugin: Loop through indices until we get invalid result
  -- GetStringValue() with NO parameter returns PATH
  -- GetStringValue(index) returns filename at that index (1-based)
  -- When out of range, it returns the PATH again (not nil/empty!)
  local i = 1
  local maxFiles = 200  -- Safety limit (matches Count setting in ini)

  print("Scanner: Starting FileView iteration...")

  -- DEBUG: Check what FileView returns at various indices
  print("Scanner: DEBUG - FileView GetStringValue() with no param: " .. tostring(fileViewMeasure:GetStringValue()))
  print("Scanner: DEBUG - FileView GetStringValue(0): " .. tostring(fileViewMeasure:GetStringValue(0)))
  print("Scanner: DEBUG - FileView GetStringValue(1): " .. tostring(fileViewMeasure:GetStringValue(1)))
  print("Scanner: DEBUG - FileView GetStringValue(2): " .. tostring(fileViewMeasure:GetStringValue(2)))
  print("Scanner: DEBUG - FileView GetStringValue(3): " .. tostring(fileViewMeasure:GetStringValue(3)))

  while i <= maxFiles do
    local filename = fileViewMeasure:GetStringValue(i)

    -- DEBUG: Show what we got at this index
    if i <= 5 then
      print("Scanner: DEBUG - Index " .. i .. " returned: '" .. tostring(filename) .. "'")
    end

    -- CRITICAL: FileView returns the PATH when index is out of range
    -- Check if result contains backslash or is a path (not just a filename)
    if not filename or filename == "" or filename:match("\\") or filename:match("^[A-Z]:") then
      print("Scanner: Reached end of file list at index " .. (i - 1) .. " (got: " .. tostring(filename) .. ")")
      break
    end

    print("Scanner: Processing item " .. i .. ": " .. filename)

    -- Skip system files
    if not filename:match("^desktop%.ini$") and
       not filename:match("^Thumbs%.db$") and
       not filename:match("%.tmp$") then

      local fullPath = desktopPath .. "\\" .. filename
      local itemData = ExtractItemData(fullPath, filename)

      if itemData then
        table.insert(items, itemData)
        print("Scanner: Added item: " .. itemData.name)
      end
    else
      print("Scanner: Skipped system file: " .. filename)
    end

    i = i + 1
  end

  print("Scanner: FileView iteration complete - found " .. #items .. " items")

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
    item.target = fullPath -- Will be resolved later if needed
    item.icon = fullPath  -- Rainmeter can extract icon from .lnk directly
  elseif ext:lower() == "url" then
    item.type = "url"
    item.target = ResolveURLFile(fullPath)
    item.icon = nil
  elseif ext:lower() == "exe" then
    item.type = "executable"
    item.target = fullPath
    item.icon = fullPath .. ",0"
  else
    item.type = "file"
    item.target = fullPath
    item.icon = nil
  end

  -- Get timestamp
  item.timestamp = os.time()

  return item
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
-- START SCAN: Initiate FileView scan
-- ========================================
function StartScan()
  print("Scanner: ===== START SCAN REQUESTED =====")

  if isScanning then
    print("Scanner: WARNING - Already scanning, ignoring request")
    return false
  end

  -- Load Desktop path from UserDesktopData
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local userDataPath = skinPath .. "Data\\UserDesktopData.ldb"

  print("Scanner: Loading desktop path from " .. userDataPath)
  local userData = LoadDataFile(userDataPath)

  if not userData or not userData.desktopPath or userData.desktopPath == "" then
    print("Scanner: ERROR - Cannot load Desktop path from UserDesktopData.ldb")
    print("Scanner: userData = " .. tostring(userData))
    if userData then
      print("Scanner: userData.desktopPath = " .. tostring(userData.desktopPath))
    end
    return false
  end

  local desktopPath = userData.desktopPath
  print("Scanner: Desktop path from file: " .. desktopPath)

  -- Store path for FinishScan to use
  pendingDesktopPath = desktopPath
  isScanning = true

  -- Set FileView's Path to the correct desktop path
  print("Scanner: Setting FileView Path to: " .. desktopPath)
  SKIN:Bang('!SetOption', 'MeasureDesktopFileView', 'Path', desktopPath)

  -- Trigger FileView to scan
  print("Scanner: Calling FileView Update command...")
  SKIN:Bang('!CommandMeasure', 'MeasureDesktopFileView', 'Update')

  print("Scanner: FileView scan initiated, waiting for FinishAction callback...")
  return true
end

-- ========================================
-- FINISH SCAN: Process FileView results
-- ========================================
function FinishScan()
  print("Scanner: ===== FINISH SCAN CALLBACK =====")

  if not isScanning then
    print("Scanner: WARNING - FinishScan called but not scanning (probably skin init)")
    return false
  end

  print("Scanner: Processing FileView results...")
  local success, items = pcall(ReadDesktopDirectly, pendingDesktopPath)

  if not success then
    LogError("Failed to scan Desktop: " .. tostring(items))
    isScanning = false
    pendingDesktopPath = ""
    print("Scanner: ERROR - Scan failed, state reset")
    return false
  end

  -- Wrap items in proper data structure with metadata
  local dataStructure = {
    version = "1.0.0",
    timestamp = os.time(),
    lastScan = os.date("%Y-%m-%d %H:%M:%S"),
    itemCount = #items,
    items = items
  }

  print("Scanner: Creating data structure with " .. #items .. " items")
  print("Scanner: dataStructure.items type = " .. type(dataStructure.items))
  print("Scanner: dataStructure.items length = " .. #dataStructure.items)

  local serialized = SerializeTable(dataStructure)

  -- Build file path
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local filePath = skinPath .. "Data\\ListedDesktopItems.ldb"

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
    LogError("Failed to write ListedDesktopItems.ldb: " .. tostring(err))
    return false
  end

  -- Rename temp to actual
  os.remove(filePath)
  local renameSuccess = os.rename(tempPath, filePath)

  if not renameSuccess then
    LogError("Failed to rename temp file to ListedDesktopItems.ldb")
    return false
  end

  print("Scanner: Saved " .. #items .. " items successfully")

  -- Reset state flags
  isScanning = false
  pendingDesktopPath = ""
  print("Scanner: Scan complete, state reset")

  -- Trigger UI update to refresh Desktop items display (target specific meter)
  SKIN:Bang("!UpdateMeter", "MeterItemContainerText")
  SKIN:Bang("!Redraw")

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

  -- CRITICAL: Use pairs() not ipairs() to iterate ALL keys (named + numeric)
  -- ipairs() only iterates numeric indices, missing version/timestamp/items fields
  for key, value in pairs(tbl) do
    local keyStr = type(key) == "string" and string.format("%s  %s = ", spacing, key) or string.format("%s  [%d] = ", spacing, key)

    if type(value) == "table" then
      result = result .. keyStr .. SerializeTable(value, indent + 1) .. ",\n"
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

  result = result .. spacing .. "}"
  return result
end

-- ========================================
-- UTILITY: Error logging
-- ========================================
function LogError(message)
  local logPath = SKIN:GetVariable("CURRENTPATH") .. "Logs\\errors.log"
  local file = io.open(logPath, "a")
  if file then
    file:write(string.format("[%s] Scanner: %s\n", os.date("%Y-%m-%d %H:%M:%S"), message))
    file:close()
  end
  print("ERROR: " .. message)
end
