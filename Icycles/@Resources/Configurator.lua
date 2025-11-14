-- ========================================
-- ICYCLES - Configurator
-- ========================================
-- Category and item management logic
-- Handles all CMS operations
-- ========================================

-- State management
local lastSaveTime = 0
local pendingChanges = false
local loadedCategories = {}
local currentCategory = nil

function Initialize()
  LoadAllCategories()
end

function Update()
  -- Auto-save check (debounced)
  if pendingChanges and (os.time() - lastSaveTime) >= 5 then
    SaveAllCategories()
    pendingChanges = false
  end
  return ""
end

-- ========================================
-- CATEGORY MANAGEMENT
-- ========================================

-- Load all categories from CatData folder
function LoadAllCategories()
  loadedCategories = {}

  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local masterPath = skinPath .. "Data\\Categories.ldb"

  -- Load master index
  local masterData = LoadDataFile(masterPath)

  if not masterData or not masterData.categories then
    print("Configurator: No categories found, starting fresh")
    return
  end

  -- Load each category file
  for _, categoryName in ipairs(masterData.categories) do
    local catPath = skinPath .. "CatData\\" .. categoryName .. ".ldb"
    local catData = LoadDataFile(catPath)

    if catData then
      loadedCategories[categoryName] = catData
    else
      LogError("Failed to load category: " .. categoryName)
    end
  end

  print("Configurator: Loaded " .. CountCategories() .. " categories")
end

-- Create new category
function CreateCategory(categoryName, displayName)
  if not categoryName or categoryName == "" then
    LogError("Cannot create category: name is empty")
    return false
  end

  if loadedCategories[categoryName] then
    LogError("Category already exists: " .. categoryName)
    return false
  end

  -- Create new category structure
  local newCategory = {
    metadata = {
      name = categoryName,
      displayName = displayName or categoryName:sub(1, 4):upper(),
      icon = nil,
      color = nil,
      order = CountCategories() + 1,
      created = os.time(),
      modified = os.time(),
      version = "1.0.0"
    },
    items = {}
  }

  loadedCategories[categoryName] = newCategory
  pendingChanges = true
  lastSaveTime = os.time()

  print("Configurator: Created category: " .. categoryName)
  SKIN:Bang("!UpdateMeasure", "ScriptMeasure")
  SKIN:Bang("!UpdateMeter", "*")
  SKIN:Bang("!Redraw")

  return true
end

-- Delete category
function DeleteCategory(categoryName)
  if not loadedCategories[categoryName] then
    LogError("Category not found: " .. categoryName)
    return false
  end

  loadedCategories[categoryName] = nil
  pendingChanges = true
  lastSaveTime = os.time()

  -- Delete physical file
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local catPath = skinPath .. "CatData\\" .. categoryName .. ".ldb"
  os.remove(catPath)

  print("Configurator: Deleted category: " .. categoryName)
  SKIN:Bang("!UpdateMeasure", "ScriptMeasure")
  SKIN:Bang("!UpdateMeter", "*")
  SKIN:Bang("!Redraw")

  return true
end

-- Reorder category
function MoveCategoryUp(categoryName)
  return ReorderCategory(categoryName, -1)
end

function MoveCategoryDown(categoryName)
  return ReorderCategory(categoryName, 1)
end

function MoveCategoryToTop(categoryName)
  return ReorderCategory(categoryName, "top")
end

function MoveCategoryToBottom(categoryName)
  return ReorderCategory(categoryName, "bottom")
end

function ReorderCategory(categoryName, direction)
  if not loadedCategories[categoryName] then
    return false
  end

  local categories = GetCategoriesSorted()
  local currentIndex = nil

  -- Find current index
  for i, cat in ipairs(categories) do
    if cat == categoryName then
      currentIndex = i
      break
    end
  end

  if not currentIndex then
    return false
  end

  -- Calculate new index
  local newIndex = currentIndex
  if direction == "top" then
    newIndex = 1
  elseif direction == "bottom" then
    newIndex = #categories
  elseif type(direction) == "number" then
    newIndex = currentIndex + direction
  end

  -- Clamp to valid range
  newIndex = math.max(1, math.min(newIndex, #categories))

  if newIndex == currentIndex then
    return false  -- No change
  end

  -- Swap orders
  local temp = loadedCategories[categories[currentIndex]].metadata.order
  loadedCategories[categories[currentIndex]].metadata.order = loadedCategories[categories[newIndex]].metadata.order
  loadedCategories[categories[newIndex]].metadata.order = temp

  pendingChanges = true
  lastSaveTime = os.time()

  SKIN:Bang("!UpdateMeasure", "ScriptMeasure")
  SKIN:Bang("!UpdateMeter", "*")
  SKIN:Bang("!Redraw")

  return true
end

-- ========================================
-- ITEM MANAGEMENT
-- ========================================

-- Add item to category
function AddItemToCategory(itemName, categoryName)
  if not loadedCategories[categoryName] then
    LogError("Category not found: " .. categoryName)
    return false
  end

  -- Check if item already in category
  for _, item in ipairs(loadedCategories[categoryName].items) do
    if item.name == itemName then
      LogError("Item already in category: " .. itemName)
      return false
    end
  end

  -- Load item data from ListedDesktopItems
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local itemsPath = skinPath .. "Data\\ListedDesktopItems.lua"
  local allItems = LoadDataFile(itemsPath)

  if not allItems then
    LogError("Cannot load Desktop items")
    return false
  end

  -- Find the item
  local itemData = nil
  for _, item in ipairs(allItems) do
    if item.name == itemName then
      itemData = item
      break
    end
  end

  if not itemData then
    LogError("Item not found: " .. itemName)
    return false
  end

  -- Add to category
  local newItem = {
    name = itemData.name,
    path = itemData.path,
    customIcon = nil,
    customName = nil,
    launchFlags = nil,
    order = #loadedCategories[categoryName].items + 1,
    addedAt = os.time(),
    source = "desktop"
  }

  table.insert(loadedCategories[categoryName].items, newItem)

  loadedCategories[categoryName].metadata.modified = os.time()
  pendingChanges = true
  lastSaveTime = os.time()

  print("Configurator: Added " .. itemName .. " to " .. categoryName)
  SKIN:Bang("!UpdateMeasure", "ScriptMeasure")
  SKIN:Bang("!UpdateMeter", "*")
  SKIN:Bang("!Redraw")

  return true
end

-- Remove item from category
function RemoveItemFromCategory(itemName, categoryName)
  if not loadedCategories[categoryName] then
    LogError("Category not found: " .. categoryName)
    return false
  end

  local items = loadedCategories[categoryName].items
  local foundIndex = nil

  for i, item in ipairs(items) do
    if item.name == itemName then
      foundIndex = i
      break
    end
  end

  if not foundIndex then
    LogError("Item not found in category: " .. itemName)
    return false
  end

  table.remove(items, foundIndex)

  -- Reorder remaining items
  for i, item in ipairs(items) do
    item.order = i
  end

  loadedCategories[categoryName].metadata.modified = os.time()
  pendingChanges = true
  lastSaveTime = os.time()

  print("Configurator: Removed " .. itemName .. " from " .. categoryName)
  SKIN:Bang("!UpdateMeasure", "ScriptMeasure")
  SKIN:Bang("!UpdateMeter", "*")
  SKIN:Bang("!Redraw")

  return true
end

-- Reorder item within category
function MoveItemUp(itemName, categoryName)
  return ReorderItem(itemName, categoryName, -1)
end

function MoveItemDown(itemName, categoryName)
  return ReorderItem(itemName, categoryName, 1)
end

function MoveItemToTop(itemName, categoryName)
  return ReorderItem(itemName, categoryName, "top")
end

function MoveItemToBottom(itemName, categoryName)
  return ReorderItem(itemName, categoryName, "bottom")
end

function ReorderItem(itemName, categoryName, direction)
  if not loadedCategories[categoryName] then
    return false
  end

  local items = loadedCategories[categoryName].items
  local currentIndex = nil

  -- Find current index
  for i, item in ipairs(items) do
    if item.name == itemName then
      currentIndex = i
      break
    end
  end

  if not currentIndex then
    return false
  end

  -- Calculate new index
  local newIndex = currentIndex
  if direction == "top" then
    newIndex = 1
  elseif direction == "bottom" then
    newIndex = #items
  elseif type(direction) == "number" then
    newIndex = currentIndex + direction
  end

  -- Clamp to valid range
  newIndex = math.max(1, math.min(newIndex, #items))

  if newIndex == currentIndex then
    return false  -- No change
  end

  -- Swap items
  items[currentIndex], items[newIndex] = items[newIndex], items[currentIndex]

  -- Update order values
  for i, item in ipairs(items) do
    item.order = i
  end

  loadedCategories[categoryName].metadata.modified = os.time()
  pendingChanges = true
  lastSaveTime = os.time()

  SKIN:Bang("!UpdateMeasure", "ScriptMeasure")
  SKIN:Bang("!UpdateMeter", "*")
  SKIN:Bang("!Redraw")

  return true
end

-- Set custom icon for item
function SetCustomIcon(itemName, categoryName, iconPath)
  if not loadedCategories[categoryName] then
    return false
  end

  for _, item in ipairs(loadedCategories[categoryName].items) do
    if item.name == itemName then
      item.customIcon = iconPath
      loadedCategories[categoryName].metadata.modified = os.time()
      pendingChanges = true
      lastSaveTime = os.time()
      return true
    end
  end

  return false
end

-- Set custom name for item
function SetCustomName(itemName, categoryName, customName)
  if not loadedCategories[categoryName] then
    return false
  end

  for _, item in ipairs(loadedCategories[categoryName].items) do
    if item.name == itemName then
      item.customName = customName
      loadedCategories[categoryName].metadata.modified = os.time()
      pendingChanges = true
      lastSaveTime = os.time()
      return true
    end
  end

  return false
end

-- ========================================
-- SAVE/LOAD FUNCTIONS
-- ========================================

function SaveAllCategories()
  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local catDataPath = skinPath .. "CatData\\"

  local categoryList = {}
  local orderList = {}

  -- Save each category file
  for categoryName, categoryData in pairs(loadedCategories) do
    local filePath = catDataPath .. categoryName .. ".ldb"
    local serialized = SerializeTable(categoryData)

    local success = WriteToFile(filePath, "return " .. serialized)
    if not success then
      LogError("Failed to save category: " .. categoryName)
      return false
    end

    table.insert(categoryList, categoryName)
    table.insert(orderList, categoryData.metadata.order)
  end

  -- Sort by order
  local sortedIndices = {}
  for i = 1, #categoryList do
    sortedIndices[i] = i
  end
  table.sort(sortedIndices, function(a, b)
    return orderList[a] < orderList[b]
  end)

  local sortedCategories = {}
  local sortedOrders = {}
  for i, idx in ipairs(sortedIndices) do
    sortedCategories[i] = categoryList[idx]
    sortedOrders[i] = i  -- Normalize orders to 1, 2, 3...
  end

  -- Save master Categories.ldb
  local masterData = {
    categories = sortedCategories,
    order = sortedOrders,
    lastGenerated = os.time(),
    version = "1.0.0"
  }

  local masterPath = skinPath .. "Data\\Categories.ldb"
  local masterSerialized = SerializeTable(masterData)
  local masterSuccess = WriteToFile(masterPath, "return " .. masterSerialized)

  if masterSuccess then
    print("Configurator: Saved all categories successfully")
  end

  return masterSuccess
end

function ManualSave()
  local success = SaveAllCategories()
  if success then
    pendingChanges = false
    print("Configurator: Manual save completed")
  end
  return success
end

-- ========================================
-- QUERY FUNCTIONS
-- ========================================

function GetCategoryList()
  local list = {}
  for name, _ in pairs(loadedCategories) do
    table.insert(list, name)
  end
  return list
end

function GetCategoriesSorted()
  local list = GetCategoryList()
  table.sort(list, function(a, b)
    return loadedCategories[a].metadata.order < loadedCategories[b].metadata.order
  end)
  return list
end

function GetCategoryData(categoryName)
  return loadedCategories[categoryName]
end

function GetCategoryItems(categoryName)
  if not loadedCategories[categoryName] then
    return {}
  end
  return loadedCategories[categoryName].items
end

function CountCategories()
  local count = 0
  for _ in pairs(loadedCategories) do
    count = count + 1
  end
  return count
end

function CountItemsInCategory(categoryName)
  if not loadedCategories[categoryName] then
    return 0
  end
  return #loadedCategories[categoryName].items
end

-- ========================================
-- UTILITY FUNCTIONS
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

function WriteToFile(path, content)
  local tempPath = path .. ".tmp"

  local success, err = pcall(function()
    local file = io.open(tempPath, "w")
    if not file then
      error("Cannot open file for writing: " .. tempPath)
    end
    file:write("-- Auto-generated by Configurator.lua\n")
    file:write("-- Saved: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    file:write(content)
    file:close()
  end)

  if not success then
    LogError("Failed to write file: " .. path)
    return false
  end

  -- Atomic rename
  os.remove(path)
  os.rename(tempPath, path)

  return true
end

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

function LogError(message)
  local logPath = SKIN:GetVariable("CURRENTPATH") .. "Logs\\errors.log"
  local file = io.open(logPath, "a")
  if file then
    file:write(string.format("[%s] Configurator: %s\n", os.date("%Y-%m-%d %H:%M:%S"), message))
    file:close()
  end
  print("ERROR: " .. message)
end
