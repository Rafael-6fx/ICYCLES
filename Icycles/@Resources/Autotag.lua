-- ========================================
-- ICYCLES - Auto-Tagging Engine
-- ========================================
-- Suggests categories for Desktop items
-- Based on keyword matching from CatDictionary.ldb
-- ========================================

function Initialize()
  -- Called on skin load
end

function Update()
  return ""
end

-- ========================================
-- MAIN FUNCTION: Generate category suggestions
-- ========================================
function GenerateSuggestions()
  -- Load Desktop items
  local itemsPath = SKIN:GetVariable("CURRENTPATH") .. "Data\\ListedDesktopItems.lua"
  local items = LoadDataFile(itemsPath)

  if not items then
    LogError("Cannot load ListedDesktopItems.lua")
    return {}
  end

  -- Load category dictionary
  local dictPath = SKIN:GetVariable("CURRENTPATH") .. "CatDictionary.ldb"
  local dictionary = LoadDataFile(dictPath)

  if not dictionary then
    LogError("Cannot load CatDictionary.ldb")
    return {}
  end

  -- Generate suggestions for each item
  local suggestions = {}

  for _, item in ipairs(items) do
    local matches = FindCategoryMatches(item, dictionary)
    if #matches > 0 then
      suggestions[item.name] = matches
    end
  end

  return suggestions
end

-- ========================================
-- FIND CATEGORY MATCHES: Match item to categories
-- ========================================
function FindCategoryMatches(item, dictionary)
  local matches = {}
  local searchText = (item.name .. " " .. (item.target or "")):lower()

  -- Check each category
  for categoryName, categoryData in pairs(dictionary) do
    local score = 0

    -- Check keywords
    for _, keyword in ipairs(categoryData.keywords) do
      if searchText:find(keyword:lower(), 1, true) then
        score = score + 10  -- Keyword match worth 10 points
      end
    end

    -- Check extensions
    if item.ext and item.ext ~= "" then
      for _, ext in ipairs(categoryData.extensions) do
        if item.ext:lower() == ext:lower() then
          score = score + 5  -- Extension match worth 5 points
        end
      end
    end

    -- If there's a match, add to results
    if score > 0 then
      table.insert(matches, {
        category = categoryName,
        score = score,
        confidence = CalculateConfidence(score)
      })
    end
  end

  -- Sort by score (highest first)
  table.sort(matches, function(a, b)
    return a.score > b.score
  end)

  return matches
end

-- ========================================
-- CALCULATE CONFIDENCE: Convert score to percentage
-- ========================================
function CalculateConfidence(score)
  -- Simple confidence calculation
  -- 10+ points = high confidence
  -- 5-9 points = medium confidence
  -- 1-4 points = low confidence
  if score >= 10 then
    return "high"
  elseif score >= 5 then
    return "medium"
  else
    return "low"
  end
end

-- ========================================
-- GET SUGGESTION FOR ITEM: Get best match
-- ========================================
function GetSuggestionForItem(itemName)
  local suggestions = GenerateSuggestions()

  if suggestions[itemName] and #suggestions[itemName] > 0 then
    -- Return the top suggestion
    return suggestions[itemName][1].category
  end

  return nil  -- No suggestion
end

-- ========================================
-- GET ALL SUGGESTIONS FOR ITEM: Get all matches
-- ========================================
function GetAllSuggestionsForItem(itemName)
  local suggestions = GenerateSuggestions()
  return suggestions[itemName] or {}
end

-- ========================================
-- AUTO-TAG ALL ITEMS: Apply suggestions to categories
-- ========================================
function AutoTagAllItems()
  -- Load items
  local itemsPath = SKIN:GetVariable("CURRENTPATH") .. "Data\\ListedDesktopItems.lua"
  local items = LoadDataFile(itemsPath)

  if not items then
    LogError("Cannot load items for auto-tagging")
    return false
  end

  -- Generate suggestions
  local suggestions = GenerateSuggestions()

  -- Create category structure
  local categories = {}

  for _, item in ipairs(items) do
    local itemSuggestions = suggestions[item.name]

    if itemSuggestions and #itemSuggestions > 0 then
      -- Use the top suggestion
      local topCategory = itemSuggestions[1].category

      -- Initialize category if needed
      if not categories[topCategory] then
        categories[topCategory] = {
          metadata = {
            name = topCategory,
            displayName = GenerateDisplayName(topCategory),
            icon = nil,
            color = nil,
            order = 0,  -- Will be set later
            created = os.time(),
            modified = os.time(),
            version = "1.0.0"
          },
          items = {}
        }
      end

      -- Add item to category
      table.insert(categories[topCategory].items, {
        name = item.name,
        path = item.path,
        customIcon = nil,
        customName = nil,
        launchFlags = nil,
        order = #categories[topCategory].items + 1,
        addedAt = os.time(),
        source = "desktop"
      })
    end
  end

  -- Save categories
  local saved = SaveCategories(categories)

  if saved then
    print("Autotag: Successfully auto-tagged " .. CountTotalItems(categories) .. " items into " .. CountCategories(categories) .. " categories")
  end

  return saved
end

-- ========================================
-- GENERATE DISPLAY NAME: Create short name
-- ========================================
function GenerateDisplayName(categoryName)
  -- Create 3-4 character abbreviation
  if categoryName == "Development" then
    return "DEV"
  elseif categoryName == "Creative" then
    return "ART"
  elseif categoryName == "Gaming" then
    return "GAME"
  elseif categoryName == "Tools" then
    return "TOOL"
  elseif categoryName == "Office" then
    return "WORK"
  else
    -- Fallback: take first 3-4 characters
    return categoryName:sub(1, 4):upper()
  end
end

-- ========================================
-- SAVE CATEGORIES: Write to CatData files
-- ========================================
function SaveCategories(categories)
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local catDataPath = skinPath .. "CatData\\"

  local categoryList = {}
  local order = 1

  for categoryName, categoryData in pairs(categories) do
    -- Set order
    categoryData.metadata.order = order
    order = order + 1

    -- Save individual category file
    local filePath = catDataPath .. categoryName .. ".ldb"
    local serialized = SerializeTable(categoryData)

    local success = WriteToFile(filePath, "return " .. serialized)
    if not success then
      LogError("Failed to save category: " .. categoryName)
      return false
    end

    table.insert(categoryList, categoryName)
  end

  -- Save master Categories.ldb
  local masterData = {
    categories = categoryList,
    order = {},
    lastGenerated = os.time(),
    version = "1.0.0"
  }

  -- Build order array
  for i = 1, #categoryList do
    masterData.order[i] = i
  end

  local masterPath = skinPath .. "Data\\Categories.ldb"
  local masterSerialized = SerializeTable(masterData)
  local masterSuccess = WriteToFile(masterPath, "return " .. masterSerialized)

  return masterSuccess
end

-- ========================================
-- UTILITY: Count total items across categories
-- ========================================
function CountTotalItems(categories)
  local count = 0
  for _, category in pairs(categories) do
    count = count + #category.items
  end
  return count
end

-- ========================================
-- UTILITY: Count categories
-- ========================================
function CountCategories(categories)
  local count = 0
  for _ in pairs(categories) do
    count = count + 1
  end
  return count
end

-- ========================================
-- UTILITY: Write to file
-- ========================================
function WriteToFile(path, content)
  local tempPath = path .. ".tmp"

  local success, err = pcall(function()
    local file = io.open(tempPath, "w")
    if not file then
      error("Cannot open file for writing: " .. tempPath)
    end
    file:write("-- Auto-generated by Autotag.lua\n")
    file:write("-- Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    file:write(content)
    file:close()
  end)

  if not success then
    LogError("Failed to write file: " .. path)
    return false
  end

  -- Rename temp to actual
  os.remove(path)
  os.rename(tempPath, path)

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
    LogError("Failed to load data file: " .. path)
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
    file:write(string.format("[%s] Autotag: %s\n", os.date("%Y-%m-%d %H:%M:%S"), message))
    file:close()
  end
  print("ERROR: " .. message)
end
