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
-- PROCESS FILE ENTRY: Convert parsed temp file entry to item
-- ========================================
function ProcessFileEntry(fileEntry, desktopPath)
  local filename = fileEntry.filename
  local shortName = fileEntry.shortName
  local ext = (fileEntry.ext or ""):lower()
  local fileType = fileEntry.type

  -- Skip system files (case-insensitive)
  local filenameLower = filename:lower()
  local isSystemFile =
    filenameLower:match("^desktop%.ini$") or
    filenameLower:match("^thumbs%.db$") or
    filenameLower:match("%.tmp$") or
    filenameLower:match("^%.") or
    filenameLower:match("^~%$") or
    filenameLower:match("^~.*%.tmp$")

  if isSystemFile then
    return nil  -- Skip this file
  end

  -- Parse filename to get name without extension
  local itemName = filename
  if ext ~= "" then
    itemName = filename:match("^(.+)%." .. ext .. "$") or filename
  end

  -- Build paths
  local fullPath = desktopPath .. "\\" .. filename  -- Display path with UTF8
  local shortPath = desktopPath .. "\\" .. shortName  -- ASCII path for io.open()

  -- Base item data
  local item = {
    name = itemName,
    fullName = filename,
    path = fullPath,
    ext = ext,
    type = fileType
  }

  -- Process based on type
  if fileType == "url" then
    -- Extract URL from content
    local url, iconFile = ExtractUrlFromContent(fileEntry.urlContent)
    item.target = url
    item.icon = iconFile or fullPath

  elseif fileType == "lnk" then
    -- Parse .lnk binary file using short path
    item.target = ParseLnkFile(shortPath)
    item.icon = fullPath  -- Rainmeter extracts icon from .lnk

  elseif fileType == "exe" then
    item.target = fullPath
    item.icon = fullPath  -- .exe contains its own icon

  elseif fileType == "folder" then
    item.target = fullPath
    item.icon = nil  -- Folder icon handled by Rainmeter

  else
    -- Regular file
    item.type = "file"
    item.target = fullPath
    item.icon = fullPath
  end

  return item
end

-- ========================================
-- EXTRACT URL FROM CONTENT: Parse .url file content
-- ========================================
function ExtractUrlFromContent(content)
  if not content or content == "" then
    return nil, nil
  end

  local url = nil
  local iconFile = nil

  for line in content:gmatch("[^\r\n]+") do
    if not url then
      local match = line:match("URL=(.+)")
      if match then
        url = match:gsub("%s+$", "")  -- Trim trailing whitespace
      end
    end

    if not iconFile then
      local match = line:match("IconFile=(.+)")
      if match then
        iconFile = match:gsub("%s+$", "")
      end
    end

    if url and iconFile then
      break
    end
  end

  return url, iconFile
end

-- ========================================
-- PROCESS DESKTOP FILES: Parse file list and extract metadata (DEPRECATED)
-- ========================================
function ProcessDesktopFiles(desktopPath, fileList)
  local items = {}

  print("Scanner: Processing " .. #fileList .. " files from Desktop...")

  for i, fileEntry in ipairs(fileList) do
    -- fileEntry has {shortName, longName}
    local shortName = fileEntry.shortName  -- ASCII-only 8.3 for io.open()
    local filename = fileEntry.longName    -- UTF8 for display

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

      -- Use longName for display path, shortName for io.open() operations
      local fullPath = desktopPath .. "\\" .. filename
      local shortPath = desktopPath .. "\\" .. shortName

      -- Base item data
      local item = {
        index = i,
        name = itemName,
        fullName = filename,
        path = fullPath,  -- Display path with UTF8
        ext = itemExt
      }

      -- Process based on extension
      if itemExt == "lnk" then
        -- .lnk shortcut file
        item.type = "shortcut"
        item.target = ParseLnkFile(shortPath)  -- Use shortPath for io.open
        item.icon = fullPath  -- Rainmeter can extract icon from .lnk

      elseif itemExt == "url" then
        -- .url internet shortcut
        item.type = "url"
        local url, iconFile = ParseUrlFile(shortPath)  -- Use shortPath for io.open
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

  -- Build temp file path
  local tempFilePath = skinPath .. "Data\\ScanTemp.txt"

  -- Build CMD script to:
  -- 1. Set UTF8 codepage for unicode output
  -- 2. Change to Desktop directory
  -- 3. For each file, output structured data
  -- 4. For .url files, read content directly (CMD handles unicode paths)
  -- 5. For .lnk files, output 8.3 short name for Lua binary parsing
  local cmd = 'chcp 65001 >nul && cd /d "' .. desktopPath .. '" && ('
    .. 'for /f "delims=" %%f in (\'dir /b /o:-D\') do ('
    .. 'echo FILE::%%f'
    .. ' && for %%s in ("%%f") do echo SHORT::%%~snxs'
    .. ' && echo EXT::%%~xf'
    .. ' && if /i "%%~xf"==".url" ('
    .. 'echo TYPE::url'
    .. ' && echo URLCONTENT::'
    .. ' && type "%%f"'
    .. ' && echo ::URLCONTENT'
    .. ')'
    .. ' && if /i "%%~xf"==".lnk" echo TYPE::lnk'
    .. ' && if /i "%%~xf"==".exe" echo TYPE::exe'
    .. ' && if "%%~xf"=="" echo TYPE::folder'
    .. ' && echo ::FILE'
    .. ')'
    .. ') > "' .. tempFilePath .. '"'

  print("Scanner: Running CMD to generate temp file...")
  print("Scanner: Output: " .. tempFilePath)

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

  -- Read temp file generated by CMD
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local tempFilePath = skinPath .. "Data\\ScanTemp.txt"

  local tempFile = io.open(tempFilePath, "rb")  -- Binary mode for UTF8
  if not tempFile then
    print("Scanner: ERROR - Cannot open temp file: " .. tempFilePath)
    isScanning = false
    return false
  end

  local content = tempFile:read("*a")
  tempFile:close()

  print("Scanner: Read temp file (" .. string.len(content) .. " bytes)")

  -- Parse structured format into items
  local items = {}
  local currentFile = nil

  for line in content:gmatch("[^\r\n]+") do
    if line:match("^FILE::") then
      -- Start new file entry
      currentFile = {
        filename = line:sub(7),  -- Everything after "FILE::"
        shortName = nil,
        ext = nil,
        type = nil,
        urlContent = nil
      }

    elseif line:match("^SHORT::") and currentFile then
      currentFile.shortName = line:sub(8)

    elseif line:match("^EXT::") and currentFile then
      currentFile.ext = line:sub(6)

    elseif line:match("^TYPE::") and currentFile then
      currentFile.type = line:sub(7)

    elseif line:match("^URLCONTENT::") and currentFile then
      -- Start collecting URL content
      currentFile.urlContent = ""

    elseif line:match("^::URLCONTENT") and currentFile then
      -- End of URL content (already collected)

    elseif line:match("^::FILE") and currentFile then
      -- End of file entry, process it
      local item = ProcessFileEntry(currentFile, pendingDesktopPath)
      if item then  -- Skip nil (system files)
        table.insert(items, item)
      end
      currentFile = nil

    elseif currentFile and currentFile.urlContent ~= nil then
      -- Collecting URL content lines
      if currentFile.urlContent == "" then
        currentFile.urlContent = line
      else
        currentFile.urlContent = currentFile.urlContent .. "\n" .. line
      end
    end
  end

  print("Scanner: Parsed " .. #items .. " file entries from temp file")

  -- Sort items alphabetically by name
  table.sort(items, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  -- Renumber indices after sorting
  for i, item in ipairs(items) do
    item.index = i
  end

  print("Scanner: Sorted and indexed " .. #items .. " items")

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
    local file = io.open(tempPath, "wb")  -- Binary mode to preserve UTF8
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
