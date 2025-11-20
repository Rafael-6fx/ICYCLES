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

  -- Build temp file path
  local tempFilePath = skinPath .. "Data\\ScanTemp.txt"

  -- Ultra-simple CMD: One line per file with delimiter
  -- Format: FULLNAME::BASENAME::SHORTNAME::EXTENSION
  local cmd = 'chcp 65001 >nul && cd /d "' .. desktopPath .. '" && '
    .. '(for /f "delims=" %f in (\'dir /b\') do @echo %f::%~nf::%~snxf::%~xf)'

  print("Scanner: Running CMD to generate manifest...")
  print("Scanner: Output: " .. tempFilePath)

  -- Enable and configure RunCommand measure
  SKIN:Bang('!SetVariable', 'ScanCommand', '/c ' .. cmd .. ' > "' .. tempFilePath .. '"')
  SKIN:Bang('!EnableMeasure', 'MeasureDesktopScan')
  SKIN:Bang('!UpdateMeasure', 'MeasureDesktopScan')
  SKIN:Bang('!CommandMeasure', 'MeasureDesktopScan', 'Run')

  print("Scanner: CMD scan initiated, waiting for FinishAction callback...")
  return true
end

-- ========================================
-- PARSE SCAN OUTPUT: Process CMD manifest
-- ========================================
function ParseScanOutput()
  print("Scanner: ===== PARSE SCAN OUTPUT CALLBACK =====")

  if not isScanning then
    print("Scanner: WARNING - ParseScanOutput called but not scanning")
    return false
  end

  -- Check RunCommand output for CMD errors
  local measure = SKIN:GetMeasure("MeasureDesktopScan")
  if measure then
    local cmdOutput = measure:GetStringValue()
    if cmdOutput and cmdOutput ~= "" then
      print("Scanner: CMD output: " .. cmdOutput)
    end
  end

  -- Read manifest file
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local tempFilePath = skinPath .. "Data\\ScanTemp.txt"

  local tempFile = io.open(tempFilePath, "rb")  -- Binary mode for UTF-8
  if not tempFile then
    print("Scanner: ERROR - Cannot open manifest: " .. tempFilePath)
    isScanning = false
    return false
  end

  local content = tempFile:read("*a")
  tempFile:close()

  print("Scanner: Read manifest (" .. string.len(content) .. " bytes)")

  -- Parse manifest: each line is UTF8_NAME||SHORT_NAME||EXT
  local items = {}
  local lineCount = 0

  for line in content:gmatch("[^\r\n]+") do
    lineCount = lineCount + 1
    
    -- Parse format: fullname::basename::shortname::extension
    local utf8FullName, utf8BaseName, shortName, ext = line:match("^(.-)::(.-)::(.-)::(.*)$")
    
    if utf8FullName and utf8BaseName and shortName then
      if lineCount <= 10 then
        print("Scanner: Line " .. lineCount .. ": " .. utf8FullName .. " -> " .. utf8BaseName)
      end
      
      local item = ProcessFileEntry(utf8FullName, utf8BaseName, shortName, ext, pendingDesktopPath)
      if item then  -- Skip nil (system files)
        table.insert(items, item)
      end
    else
      print("Scanner: WARNING - Failed to parse line " .. lineCount .. ": " .. line)
    end
  end

  print("Scanner: Total lines read: " .. lineCount)
  print("Scanner: Parsed " .. #items .. " valid items")

  -- Sort alphabetically by name
  table.sort(items, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  -- Renumber indices after sorting
  for i, item in ipairs(items) do
    item.index = i
  end

  -- Wrap in data structure with metadata
  local dataStructure = {
    version = "1.0.0",
    timestamp = os.time(),
    lastScan = os.date("%Y-%m-%d %H:%M:%S"),
    itemCount = #items,
    items = items
  }

  local serialized = SerializeTable(dataStructure)

  -- Write to ListedDesktopItems.ldb
  local filePath = skinPath .. "Data\\ListedDesktopItems.ldb"
  local tempPath = filePath .. ".tmp"
  
  local writeSuccess, err = pcall(function()
    local file = io.open(tempPath, "wb")
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

  -- Atomic rename
  os.remove(filePath)
  local renameSuccess = os.rename(tempPath, filePath)

  if not renameSuccess then
    LogError("Failed to rename temp file")
    isScanning = false
    pendingDesktopPath = ""
    return false
  end

  print("Scanner: Saved " .. #items .. " items successfully")

  -- Reset state
  isScanning = false
  pendingDesktopPath = ""
  print("Scanner: Scan complete, state reset")

  -- Disable RunCommand measure
  SKIN:Bang('!DisableMeasure', 'MeasureDesktopScan')

  -- Trigger UI update
  SKIN:Bang("!UpdateMeter", "MeterItemContainerText")
  SKIN:Bang("!Redraw")

  return true
end

-- ========================================
-- PROCESS FILE ENTRY: Convert manifest entry to item
-- ========================================
function ProcessFileEntry(utf8FullName, utf8BaseName, shortName, ext, desktopPath)
  -- Remove leading dot from extension and lowercase
  ext = (ext or ""):gsub("^%.", ""):lower()
  
  -- Skip system files (case-insensitive)
  local filenameLower = utf8FullName:lower()
  local isSystemFile =
    filenameLower:match("^desktop%.ini$") or
    filenameLower:match("^thumbs%.db$") or
    filenameLower:match("%.tmp$") or
    filenameLower:match("^%.") or
    filenameLower:match("^~%$") or
    filenameLower:match("^~.*%.tmp$")

  if isSystemFile then
    return nil
  end

  -- Use basename provided by CMD (already stripped of extension)
  local displayName = utf8BaseName

  -- Build paths
  local fullPath = desktopPath .. "\\" .. utf8FullName  -- UTF-8 for display
  local shortPath = desktopPath .. "\\" .. shortName    -- ASCII for io.open()

  -- Base item structure
  local item = {
    name = displayName,
    fullName = utf8FullName,
    path = fullPath,
    ext = ext
  }

  -- Type-specific processing
  if ext == "url" then
    item.type = "url"
    local url, iconFile = ParseUrlFile(shortPath)  -- Use short path for I/O
    item.target = url
    item.icon = iconFile or fullPath

  elseif ext == "lnk" then
    item.type = "lnk"
    item.target = ParseLnkFile(shortPath)  -- Use short path for binary I/O
    item.icon = fullPath

  elseif ext == "exe" then
    item.type = "exe"
    item.target = fullPath
    item.icon = fullPath

  elseif ext == "" then
    item.type = "folder"
    item.target = fullPath
    item.icon = nil

  else
    item.type = "file"
    item.target = fullPath
    item.icon = fullPath
  end

  return item
end

-- ========================================
-- PARSE URL FILE: Extract URL and icon from .url file
-- ========================================
function ParseUrlFile(shortPath)
  local file = io.open(shortPath, "r")
  if not file then
    print("Scanner: WARNING - Cannot open .url file: " .. shortPath)
    return nil, nil
  end

  local content = file:read("*a")
  file:close()

  -- Extract URL and IconFile from .url format
  local url = content:match("URL=([^\r\n]+)")
  local iconFile = content:match("IconFile=([^\r\n]+)")

  -- Trim whitespace
  if url then
    url = url:gsub("^%s+", ""):gsub("%s+$", "")
  end
  if iconFile then
    iconFile = iconFile:gsub("^%s+", ""):gsub("%s+$", "")
  end

  return url, iconFile
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
  -- Match path-like strings: drive letter + valid path characters
  for path in content:gmatch("([A-Za-z]:[%w%s\\%.%-%_%(%)]+)") do
    -- Trim trailing garbage
    path = path:gsub("[^%w%s\\%.%-%_%(%)]+$", "")
    if path and (path:match("%.exe$") or path:match("%.lnk$") or path:match("%.url$") or path:match("\\[^\\]+$")) then
      return path
    end
  end

  return nil
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
      -- Escape backslashes FIRST, then double quotes (order matters!)
      local escaped = v:gsub("\\", "\\\\"):gsub('"', '\\"')
      result = result .. '"' .. escaped .. '"'
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