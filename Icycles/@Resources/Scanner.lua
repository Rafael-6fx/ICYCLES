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
-- READ DESKTOP DIRECTLY: Read FileView children
-- ========================================
function ReadDesktopDirectly(desktopPath)
  local items = {}
  local maxFiles = 9999  -- Matches Count and children count
  local consecutiveEmpties = 0

  -- Ensure output directories exist
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  EnsureDirectoriesExist(skinPath)

  print("Scanner: Reading from FileView children (max " .. maxFiles .. ")...")

  -- Helper function: Check if string is a path (not a filename)
  local function IsPath(str)
    if not str or str == "" then
      return true
    end
    -- Paths contain : or \ which are invalid in Windows filenames
    return str:find(":") ~= nil or str:find("\\") ~= nil
  end

  -- Read from all 6 child measure types simultaneously
  for i = 1, maxFiles do
    -- Get child measures for this index
    local childName = SKIN:GetMeasure("MeasureFileViewChild_FileName" .. i)
    local childSize = SKIN:GetMeasure("MeasureFileViewChild_FileSize" .. i)
    local childDate = SKIN:GetMeasure("MeasureFileViewChild_FileDate" .. i)
    local childPath = SKIN:GetMeasure("MeasureFileViewChild_FilePath" .. i)
    local childType = SKIN:GetMeasure("MeasureFileViewChild_FileType" .. i)
    local childIcon = SKIN:GetMeasure("MeasureFileViewChild_Icon" .. i)

    if not childName then
      print("Scanner: ERROR - Cannot find child measure at index " .. i)
      break
    end

    -- Read values from children
    local filename = childName:GetStringValue()
    local filesize = childSize:GetStringValue()
    local filedate = childDate:GetStringValue()
    local filepath = childPath:GetStringValue()
    local filetype = childType:GetStringValue()
    local iconpath = childIcon:GetStringValue()

    -- Check if we hit PATH (end of files) or empty
    if IsPath(filename) then
      consecutiveEmpties = consecutiveEmpties + 1
      if consecutiveEmpties >= 2 then
        -- Stop at 2 consecutive empties, DON'T include them
        print("Scanner: Reached end at index " .. (i - 2) .. " (2 consecutive empties detected)")
        break
      end
    else
      -- Valid filename - reset empty counter
      consecutiveEmpties = 0

      -- Progress logging
      if i % 100 == 0 or i <= 20 then
        print("Scanner: Processing " .. i .. ": " .. filename)
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

        -- Base item data
        local item = {
          name = itemName,
          fullName = filename,
          size = tonumber(filesize) or 0,
          date = filedate,
          path = filepath,
          ext = itemExt,
          iconPath = iconpath  -- FileView extracted icon path
        }

        -- Process based on extension
        if itemExt == "lnk" then
          -- .lnk shortcut file
          item.type = "shortcut"
          item.target = ParseLnkFile(filepath)
          -- Copy to DesktopShortcuts
          local destPath = skinPath .. "Data\\DesktopShortcuts\\" .. filename
          os.execute('copy /Y "' .. filepath .. '" "' .. destPath .. '" >nul 2>&1')
          item.localCopy = destPath

        elseif itemExt == "url" then
          -- .url internet shortcut
          item.type = "url"
          local url, iconFile = ParseUrlFile(filepath)
          item.target = url
          item.urlIconFile = iconFile
          -- Copy to DesktopShortcuts
          local destPath = skinPath .. "Data\\DesktopShortcuts\\" .. filename
          os.execute('copy /Y "' .. filepath .. '" "' .. destPath .. '" >nul 2>&1')
          item.localCopy = destPath
          -- Copy icon if found
          if iconFile and iconFile ~= "" then
            local iconDest = skinPath .. "Data\\DesktopIcons\\" .. itemName .. ".ico"
            os.execute('copy /Y "' .. iconFile .. '" "' .. iconDest .. '" >nul 2>&1')
          end

        elseif itemExt == "exe" then
          -- Executable file - create shortcut for it
          item.type = "executable"
          item.target = filepath
          -- TODO: Create .lnk for .exe (requires COM/VBS or external tool)
          -- For now, just reference the .exe directly

        elseif itemExt == "" then
          -- Folder
          item.type = "folder"
          item.target = filepath

        else
          -- Regular file
          item.type = "file"
          item.target = filepath
        end

        table.insert(items, item)
      end
    end
  end

  print("Scanner: Scan complete - found " .. #items .. " items")

  -- Sort alphabetically by name
  table.sort(items, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  return items
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
  for path in content:gmatch("([A-Za-z]:[^\0]+)") do
    -- Clean up: remove null bytes and trailing garbage
    path = path:match("([^\0]+)")
    if path and (path:match("%.exe") or path:match("%.lnk") or path:match("%.") or path:match("\\[^\\]+$")) then
      -- Found a likely target path
      print("Scanner: .lnk target found: " .. path)
      return path
    end
  end

  print("Scanner: WARNING - Could not extract target from .lnk: " .. lnkPath)
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

  if url then
    print("Scanner: .url target found: " .. url)
  end
  if iconFile then
    print("Scanner: .url icon location: " .. iconFile)
  end

  return url, iconFile
end

-- ========================================
-- ENSURE DIRECTORIES EXIST
-- ========================================
function EnsureDirectoriesExist(skinPath)
  local iconsPath = skinPath .. "Data\\DesktopIcons"
  local shortcutsPath = skinPath .. "Data\\DesktopShortcuts"

  -- Create directories using os.execute with mkdir
  os.execute('mkdir "' .. iconsPath .. '" 2>nul')
  os.execute('mkdir "' .. shortcutsPath .. '" 2>nul')

  print("Scanner: Ensured directories exist: DesktopIcons, DesktopShortcuts")
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

  -- Enable the parent measure (starts disabled to prevent init scan)
  print("Scanner: Enabling FileView parent measure...")
  SKIN:Bang('!EnableMeasure', 'MeasureDesktopFileView')

  -- Set FileView's Path to the correct desktop path
  print("Scanner: Setting FileView Path to: " .. desktopPath)
  SKIN:Bang('!SetOption', 'MeasureDesktopFileView', 'Path', desktopPath)

  -- Update the measure to apply the new Path option
  print("Scanner: Applying Path change with UpdateMeasure...")
  SKIN:Bang('!UpdateMeasure', 'MeasureDesktopFileView')

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

  print("Scanner: Processing FileView results from: " .. pendingDesktopPath)
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

  -- Disable FileView parent to prevent accidental rescans
  print("Scanner: Disabling FileView parent measure...")
  SKIN:Bang('!DisableMeasure', 'MeasureDesktopFileView')

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
