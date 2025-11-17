-- ========================================
-- ICYCLES - Desktop Scanner
-- ========================================
-- Scans Desktop directory for items
-- Outputs to Data/ListedDesktopItems.ldb
-- Uses RunCommand with CMD for lightweight scanning
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
-- PARSE .LNK FILE: Extract target from binary
-- ========================================
function ParseLnkFile(lnkPath)
  local file = io.open(lnkPath, "rb")
  if not file then
    print("Scanner: ERROR - Cannot open .lnk file: " .. lnkPath)
    return nil
  end

  local content = file:read("*a")
  file:close()

  -- Look for paths in binary data (ASCII strings)
  -- Paths contain ":\" (C:\...) or "\\" (network paths)
  -- Match path-like strings: drive letter + valid path characters until null/garbage
  for path in content:gmatch("([A-Za-z]:[%w%s\\%.%-%_%(%)]+)") do
    -- Trim trailing garbage (non-printable or weird chars)
    path = path:gsub("[^%w%s\\%.%-%_%(%)]+$", "")
    if path and (path:match("%.exe$") or path:match("%.lnk$") or path:match("%.url$") or path:match("\\[^\\]+$")) then
      -- Found a likely target path
      return path
    end
  end

  return nil
end

-- ========================================
-- PARSE .URL FILE: Extract URL and IconFile
-- ========================================
function ParseUrlFile(urlPath)
  local file = io.open(urlPath, "r")
  if not file then
    print("Scanner: ERROR - Cannot open .url file: " .. urlPath)
    return nil, nil
  end

  local url = nil
  local iconFile = nil

  for line in file:lines() do
    if not url then
      local match = line:match("URL=(.+)")
      if match then
        url = match:gsub("%s+$", "") -- Trim trailing whitespace
      end
    end

    if not iconFile then
      local match = line:match("IconFile=(.+)")
      if match then
        iconFile = match:gsub("%s+$", "")
      end
    end

    -- Stop if we found both
    if url and iconFile then
      break
    end
  end

  file:close()
  return url, iconFile
end

-- ========================================
-- PROCESS DESKTOP FILES: Parse file list and extract metadata
-- ========================================
function ProcessDesktopFiles(desktopPath, fileList)
  local items = {}

  print("Scanner: Processing " .. #fileList .. " files from Desktop...")

  for i, filename in ipairs(fileList) do
    -- Progress logging
    if i % 50 == 0 or i <= 20 then
      print("Scanner: Processing " .. i .. "/" .. #fileList .. ": " .. filename)
    end

    -- Skip system files (case-insensitive)
    local filenameLower = filename:lower()
    local isSystemFile =
      filenameLower:match("^desktop%.ini$") or
      filenameLower:match("^thumbs%.db$") or
      filenameLower:match("%.tmp$") or
      filenameLower:match("^%.") or
      filenameLower:match("^~%$") or
      filenameLower:match("^~.*%.tmp$")

    if not isSystemFile then
      -- Parse filename to get name and extension
      local itemName, itemExt = filename:match("^(.+)%.([^%.]+)$")
      if not itemName then
        itemName = filename
        itemExt = ""
      end
      itemExt = itemExt:lower()

      local fullPath = desktopPath .. "\\" .. filename

      -- Base item data
      local item = {
        index = i,
        name = itemName,
        fullName = filename,
        path = fullPath,
        ext = itemExt
      }

      -- Process based on extension
      if itemExt == "lnk" then
        -- .lnk shortcut file
        item.type = "shortcut"
        item.target = ParseLnkFile(fullPath)
        item.icon = fullPath  -- Rainmeter can extract icon from .lnk

      elseif itemExt == "url" then
        -- .url internet shortcut
        item.type = "url"
        local url, iconFile = ParseUrlFile(fullPath)
        item.target = url
        item.icon = iconFile or fullPath  -- Use iconFile if available

      elseif itemExt == "exe" then
        -- Executable file
        item.type = "executable"
        item.target = fullPath
        item.icon = fullPath  -- .exe contains its own icon

      elseif itemExt == "" then
        -- Folder
        item.type = "folder"
        item.target = fullPath
        item.icon = nil  -- Folder icon handled by Rainmeter

      else
        -- Regular file
        item.type = "file"
        item.target = fullPath
        item.icon = fullPath  -- File icon by extension
      end

      table.insert(items, item)
    end
  end

  print("Scanner: Processed " .. #items .. " items (skipped " .. (#fileList - #items) .. " system files)")

  -- Sort alphabetically by name
  table.sort(items, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  -- Renumber after sorting
  for i, item in ipairs(items) do
    item.index = i
  end

  return items
end

-- ========================================
-- START SCAN: Initiate CMD directory listing
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
    return false
  end

  local desktopPath = userData.desktopPath
  print("Scanner: Desktop path from file: " .. desktopPath)

  -- Store path for ParseScanOutput to use
  pendingDesktopPath = desktopPath
  isScanning = true

  -- Build CMD command to list files sorted by creation date
  -- /b = bare format (filenames only)
  -- /o:D = order by date (oldest first)
  -- /o:-D = order by date (newest first)
  -- /a:-d = files only (not directories) - removed so we get both
  local cmd = 'dir /b /o:-D "' .. desktopPath .. '"'

  print("Scanner: Running CMD: " .. cmd)

  -- Enable and configure RunCommand measure
  -- Set the ScanCommand variable (used by Parameter=#ScanCommand# with DynamicVariables=1)
  SKIN:Bang('!SetVariable', 'ScanCommand', '/c ' .. cmd)
  SKIN:Bang('!EnableMeasure', 'MeasureDesktopScan')
  SKIN:Bang('!UpdateMeasure', 'MeasureDesktopScan')
  SKIN:Bang('!CommandMeasure', 'MeasureDesktopScan', 'Run')

  print("Scanner: CMD scan initiated, waiting for FinishAction callback...")
  return true
end

-- ========================================
-- PARSE SCAN OUTPUT: Process CMD output
-- ========================================
function ParseScanOutput()
  print("Scanner: ===== PARSE SCAN OUTPUT CALLBACK =====")

  if not isScanning then
    print("Scanner: WARNING - ParseScanOutput called but not scanning")
    return false
  end

  -- Get CMD output from RunCommand measure
  local measure = SKIN:GetMeasure("MeasureDesktopScan")
  if not measure then
    print("Scanner: ERROR - Cannot find MeasureDesktopScan")
    isScanning = false
    return false
  end

  local output = measure:GetStringValue()
  print("Scanner: Got CMD output (" .. string.len(output) .. " bytes)")

  -- Parse output into file list (one filename per line)
  local fileList = {}
  for filename in output:gmatch("[^\r\n]+") do
    if filename ~= "" then
      table.insert(fileList, filename)
    end
  end

  print("Scanner: Found " .. #fileList .. " files in output")

  -- Process files to extract metadata
  local items = ProcessDesktopFiles(pendingDesktopPath, fileList)

  -- Wrap items in proper data structure with metadata
  local dataStructure = {
    version = "1.0.0",
    timestamp = os.time(),
    lastScan = os.date("%Y-%m-%d %H:%M:%S"),
    itemCount = #items,
    items = items
  }

  print("Scanner: Creating data structure with " .. #items .. " items")

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
    isScanning = false
    pendingDesktopPath = ""
    return false
  end

  -- Rename temp to actual
  os.remove(filePath)
  local renameSuccess = os.rename(tempPath, filePath)

  if not renameSuccess then
    LogError("Failed to rename temp file to ListedDesktopItems.ldb")
    isScanning = false
    pendingDesktopPath = ""
    return false
  end

  print("Scanner: Saved " .. #items .. " items successfully")

  -- Reset state flags
  isScanning = false
  pendingDesktopPath = ""
  print("Scanner: Scan complete, state reset")

  -- Disable RunCommand measure
  SKIN:Bang('!DisableMeasure', 'MeasureDesktopScan')

  -- Trigger UI update to refresh Desktop items display
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
    print("Scanner: Failed to load data file: " .. path)
    return nil
  end
end

-- ========================================
-- UTILITY: Serialize Lua table to string
-- ========================================
function SerializeTable(tbl, indent)
  indent = indent or ""
  local result = "{\n"

  for k, v in pairs(tbl) do
    local key = type(k) == "number" and ("[" .. k .. "]") or (k)
    result = result .. indent .. "  " .. key .. " = "

    if type(v) == "table" then
      result = result .. SerializeTable(v, indent .. "  ")
    elseif type(v) == "string" then
      result = result .. '"' .. v:gsub('"', '\\"') .. '"'
    elseif type(v) == "number" or type(v) == "boolean" then
      result = result .. tostring(v)
    elseif v == nil then
      result = result .. "nil"
    else
      result = result .. '"' .. tostring(v) .. '"'
    end

    result = result .. ",\n"
  end

  result = result .. indent .. "}"
  return result
end

-- ========================================
-- UTILITY: Log error
-- ========================================
function LogError(message)
  print("Scanner: ERROR - " .. message)
  SKIN:Bang('!Log', message, 'Error')
end
