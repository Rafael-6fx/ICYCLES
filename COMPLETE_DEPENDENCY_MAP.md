# ICYCLES COMPLETE DEPENDENCY MAP

## STARTUP SEQUENCE (OnRefreshAction)

**Trigger:** Rainmeter skin loads/refreshes (line 21 of Icycles.ini)
```
OnRefreshAction=[!CommandMeasure ScriptUserDesktopInfo "SaveDesktopInfo()"][!CommandMeasure ScriptConfigurator "LoadAllCategories()"]
```

### 1. UserDesktopInfo.SaveDesktopInfo()
**Purpose:** Gather environment data and save to UserDesktopData.ldb
**Flow:**
```
SaveDesktopInfo()
  → GatherDesktopInfo()
    → Collects: screen size, DPI, Desktop path, Rainmeter version
    → Returns data table
  → SerializeTable(data)
  → Writes to: Data/UserDesktopData.ldb
  → File structure:
    {
      screenWidth = X,
      screenHeight = Y,
      desktopPath = "C:\\Users\\...\\Desktop",
      version = "1.0.0",
      ...
    }
```

**CRITICAL OUTPUT:** `Data/UserDesktopData.ldb` with Desktop path

---

### 2. Configurator.LoadAllCategories()
**Purpose:** Load all category files into memory
**Flow:**
```
LoadAllCategories()
  → LoadDataFile("Data/Categories.ldb")
    → Returns: { categories = {...}, order = {...} }
  → For each category name:
    → LoadDataFile("CatData/{categoryName}.ldb")
    → Stores in: loadedCategories[categoryName]
```

**DEPENDENCIES:**
- Requires: `Data/Categories.ldb` (created by QuickSetup or Configurator)
- Requires: `CatData/{CategoryName}.ldb` files

---

## BUTTON ACTION TRIGGERS

### QUICK SETUP Button
**Trigger:** User clicks (line 144)
```
[!CommandMeasure ScriptQuickSetup "CreateDefaultCategories()"]
```

**Flow:**
```
QuickSetup.CreateDefaultCategories()
  → Creates 5 default categories:
    - Development
    - Creative
    - Gaming
    - Tools
    - Office
  → Writes Data/Categories.ldb
  → Writes CatData/Development.ldb
  → Writes CatData/Creative.ldb
  → Writes CatData/Gaming.ldb
  → Writes CatData/Tools.ldb
  → Writes CatData/Office.ldb
  → Calls: LoadAllCategories() to reload
  → Sets: SelectedCategoryIndex = 1
  → Sets: SelectedCategory = "Development"
  → Updates: MeterCategoryListText + MeterPreviewContainerText
```

---

### REBUILD LIST Button
**Trigger:** User clicks (line 200)
```
[!CommandMeasure MeasureScanDesktop "Run"]
```

**Flow:**
```
MeasureScanDesktop (RunCommand plugin)
  → Executes: ScanDesktop.bat
  → Bat file runs: dir "%USERPROFILE%\Desktop" /B
  → Outputs to: Data/TempFileList.txt
  → FinishAction (line 82): [!CommandMeasure ScriptScanner "SaveScannedItems()"]
```

**Then:**
```
Scanner.SaveScannedItems()
  → ScanDesktop()
    → LoadDataFile("Data/UserDesktopData.ldb") ← READS DESKTOP PATH
    → desktopPath = userData.desktopPath
    → ReadFileList("Data/TempFileList.txt", desktopPath)
      → For each file in temp list:
        → ExtractItemData(fullPath, filename)
          → If .lnk: Extract icon, target
          → If .url: Extract URL via ResolveURLFile()
          → If .exe: Extract icon
        → Returns item table: { name, type, path, icon, ... }
    → Returns items array
  → Wraps in data structure:
    {
      version = "1.0.0",
      timestamp = os.time(),
      itemCount = #items,
      items = items  ← ARRAY OF ITEM OBJECTS
    }
  → SerializeTable(dataStructure)
  → Writes to: Data/ListedDesktopItems.ldb
  → Updates: MeterItemContainerText
```

**CRITICAL DEPENDENCY:**
- **MUST have UserDesktopData.ldb** to know Desktop path
- Scanner.lua line 23: `local userDataPath = skinPath .. "Data\\UserDesktopData.ldb"`
- Scanner.lua line 24: `local userData = LoadDataFile(userDataPath)`
- Scanner.lua line 30: `local desktopPath = userData.desktopPath`

**IF UserDesktopData.ldb MISSING OR userData.desktopPath IS NIL:**
- **ScanDesktop() RETURNS EMPTY ARRAY**
- **SaveScannedItems() WRITES:**
  ```
  {
    version = "1.0.0",
    itemCount = 0,
    items = {}  ← EMPTY ARRAY
  }
  ```

---

### CATEGORY SELECTION
**Trigger:** User clicks category text (line 346)
```
[!CommandMeasure ScriptConfigurator "HandleCategoryClick($MouseY$)"]
```

**Flow:**
```
Configurator.HandleCategoryClick(mouseY)
  → Calculates index from Y position
  → Calls: SelectCategory(index)
    → Sets: SelectedCategoryIndex variable
    → Sets: SelectedCategory variable
    → Updates: MeterCategoryListText
    → Updates: MeterPreviewContainerText
```

---

## INLINE LUA FUNCTION CALLS

### Column A: Desktop Items Display
**Meter:** MeterItemContainerText (line 254)
```
Text=[&ScriptConfigurator:GetDesktopItemsDisplay()]
```

**Flow:**
```
Configurator.GetDesktopItemsDisplay()
  → LoadDataFile("Data/ListedDesktopItems.ldb")
  → Expects structure:
    {
      items = { {name="...", ...}, ... }
    }
  → Returns formatted string with item names
```

---

### Column B: Category List
**Meter:** MeterCategoryListText (line 345)
```
Text=[&ScriptConfigurator:GetCategoryListString()]
```

**Flow:**
```
Configurator.GetCategoryListString()
  → GetCategoriesSorted()
    → Returns sorted array from loadedCategories
  → For each category:
    → CountItemsInCategory(categoryName)
      → LoadCategoryData(categoryName)
  → Returns formatted string: "CategoryName (X items)"
```

---

### Column C: Selected Category Items
**Meter:** MeterPreviewContainerText (line 530)
```
Text=[&ScriptConfigurator:GetSelectedCategoryItems()]
```

**Flow:**
```
Configurator.GetSelectedCategoryItems()
  → Gets: SelectedCategoryIndex variable
  → GetCategoryByIndex(selectedIndex)
  → LoadCategoryData(categoryName)
  → Returns formatted string with item names
```

---

## FILE DEPENDENCIES

### Data Files (Created by scripts):
1. **Data/UserDesktopData.ldb**
   - Created by: UserDesktopInfo.SaveDesktopInfo()
   - When: OnRefreshAction (skin load)
   - Contains: Desktop path, screen info
   - **CRITICAL FOR: Scanner.ScanDesktop()**

2. **Data/TempFileList.txt**
   - Created by: ScanDesktop.bat
   - When: REBUILD LIST clicked
   - Contains: List of Desktop filenames
   - **CRITICAL FOR: Scanner.ReadFileList()**

3. **Data/ListedDesktopItems.ldb**
   - Created by: Scanner.SaveScannedItems()
   - When: After ScanDesktop.bat finishes
   - Contains: { items = [...] }
   - **CRITICAL FOR: Configurator.GetDesktopItemsDisplay()**

4. **Data/Categories.ldb**
   - Created by: QuickSetup.CreateDefaultCategories()
   - When: QUICK SETUP clicked
   - Contains: { categories = [...], order = [...] }
   - **CRITICAL FOR: Configurator.LoadAllCategories()**

5. **CatData/{CategoryName}.ldb**
   - Created by: QuickSetup (initial), Configurator (CRUD)
   - Contains: { name = "...", items = [...], metadata = {...} }
   - **CRITICAL FOR: Category operations**

---

## CRITICAL BUGS IDENTIFIED

### BUG #1: Scanner Dependency on UserDesktopData.ldb
**Problem:** Scanner.ScanDesktop() REQUIRES UserDesktopData.ldb
**Location:** Scanner.lua lines 22-30
```lua
local userData = LoadDataFile(userDataPath)
if not userData or not userData.desktopPath then
  LogError("Cannot determine Desktop path")
  return {}  -- RETURNS EMPTY ARRAY
end
local desktopPath = userData.desktopPath
```

**IF UserDesktopData.ldb doesn't exist:**
- Scanner returns empty items array
- SaveScannedItems() writes `{ items = {} }`
- GetDesktopItemsDisplay() sees empty array
- **Symptom:** "Items file loaded but no items table found"

**Root Cause Check:**
- Is SaveDesktopInfo() being called on startup? ✓ YES (line 21)
- Is it creating UserDesktopData.ldb successfully? **NEED TO VERIFY**

---

### BUG #2: Category Click Not Working
**Problem:** HandleCategoryClick() not being triggered
**Meter:** MeterCategoryListText (line 346)
```
LeftMouseUpAction=[!CommandMeasure ScriptConfigurator "HandleCategoryClick($MouseY$)"]
UpdateDivider=999999
```

**Potential Issues:**
1. UpdateDivider=999999 might prevent mouse actions?
2. Meter might be behind another meter
3. Meter might have no text (empty categories list)
4. $MouseY$ might not work with DynamicVariables=1

---

## MISSING PIECES

### QUESTION 1: Does UserDesktopData.ldb exist?
**Check:** `C:\Users\Firewood\Documents\Rainmeter\Skins\Icycles\Data\UserDesktopData.ldb`

**If NO:**
- SaveDesktopInfo() failed silently
- Scanner has no Desktop path
- Scanner returns empty items

**If YES but userData.desktopPath is nil:**
- GatherDesktopInfo() failed to get Desktop path
- Check os.getenv("USERPROFILE") result

---

### QUESTION 2: Does TempFileList.txt get created?
**Check:** `C:\Users\Firewood\Documents\Rainmeter\Skins\Icycles\Data\TempFileList.txt`

**If NO:**
- ScanDesktop.bat failed to run
- RunCommand plugin not working

**If YES but empty:**
- Desktop folder actually empty
- Permission issue accessing Desktop

---

### QUESTION 3: What's in ListedDesktopItems.ldb?
**Current error:** "Items file loaded but no items table found"

**This means:**
- File loads successfully (pcall succeeds)
- itemsData is not nil
- **BUT itemsData.items IS nil**

**Possible causes:**
1. Old file from before data structure fix
2. Scanner wrote empty items: `{ items = {} }` due to missing Desktop path
3. Serialization bug: `items` field not written

---

## DIAGNOSTIC COMMANDS FOR USER

Run these checks and report results:

1. **Check if UserDesktopData.ldb exists:**
   ```
   dir "C:\Users\Firewood\Documents\Rainmeter\Skins\Icycles\Data\UserDesktopData.ldb"
   ```

2. **Check if it has Desktop path:**
   ```
   type "C:\Users\Firewood\Documents\Rainmeter\Skins\Icycles\Data\UserDesktopData.ldb"
   ```
   Look for: `desktopPath = "C:\\Users\\Firewood\\Desktop"`

3. **Check Scanner temp file:**
   ```
   type "C:\Users\Firewood\Documents\Rainmeter\Skins\Icycles\Data\TempFileList.txt"
   ```
   Should list Desktop files

4. **Check ListedDesktopItems.ldb structure:**
   ```
   type "C:\Users\Firewood\Documents\Rainmeter\Skins\Icycles\Data\ListedDesktopItems.ldb"
   ```
   Look for: `items = {`

5. **Check Rainmeter log for UserDesktopInfo:**
   ```
   Search for: "UserDesktopInfo: Saved successfully"
   ```

---

## HYPOTHESIS

**Most likely cause of "no items table found":**

Scanner.ScanDesktop() is returning empty array because:
1. UserDesktopData.ldb is missing, OR
2. UserDesktopData.ldb.desktopPath is nil/wrong

**Then:**
- SaveScannedItems() wraps empty array: `{ items = {} }`
- File is written with `items = {}` (empty array, not nil)
- Configurator loads file successfully
- `itemsData.items` exists but is empty array `{}`
- Check `if not itemsData.items` FAILS (empty table is truthy in Lua)
- **BUG:** Should check `if not itemsData.items or #itemsData.items == 0`

**Fix needed:**
```lua
if not itemsData or not itemsData.items or #itemsData.items == 0 then
  print("Configurator: No items found in file")
  return "No Desktop items scanned yet\nClick REBUILD LIST to scan Desktop"
end
```
