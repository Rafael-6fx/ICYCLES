# ICYCLES - Architecture & Technical Design

*Last Updated: 2024-11-20*

---

## Table of Contents
1. [Philosophy & Core Principles](#philosophy--core-principles)
2. [Data Model](#data-model)
3. [Desktop Scanning](#desktop-scanning)
4. [UI Design](#ui-design)
5. [Typography & Styling](#typography--styling)
6. [Implementation Status](#implementation-status)
7. [Decision Log](#decision-log)

---

## Philosophy & Core Principles

### Design Axioms
- **Form follows function** - No decorative elements, every component serves a purpose
- **User control** - Manual override for all automation, transparent data files
- **Visual efficiency** - Tag pills over scrolling lists, spatial scanning over linear search
- **Technical aesthetic** - Monospace typography, precise spacing (golden ratio), structured hierarchy

### The Icycles Paradigm: Desktop as Inbox
Desktop is **ephemeral storage** (inbox), Icycles is **source of truth** (archive).

Once an item has `keeper = true`, it doesn't need to exist on Desktop anymore. Icycles can recreate shortcuts at will. Users can safely delete Desktop clutter knowing Icycles preserves launcher data.

**Key insight:** We're not organizing Desktop files - we're building a launcher database that *happens* to import from Desktop initially.

---

## Data Model

### Overview: Denormalized References

Items live in **ItemRegistry.ldb** (canonical properties).  
Categories live in **CatData/*.ldb** (spatial ordering).

**Bidirectional references:**
- `item.categories` array → fast filtering, orphan detection
- `category.itemKeys` array → drawer rendering order

This is intentional denormalization - not duplication, but serving different concerns.

---

### ItemRegistry.ldb - Canonical Item Database

**Location:** `Data/ItemRegistry.ldb`  
**Encoding:** UTF-16LE (Rainmeter requirement)  
**Purpose:** Single source of truth for all item properties

```lua
return {
  version = "1.0.0",
  
  items = {
    ["Blender.lnk"] = {
      -- Original scan data
      originalName = "Blender.lnk",
      baseName = "Blender",
      fullName = "Blender.lnk",
      path = "C:\\Users\\Rafael\\Desktop\\Blender.lnk",
      ext = "lnk",
      target = "C:\\Program Files\\Blender Foundation\\Blender 4.3\\blender.exe",
      type = "lnk",  -- lnk | url | exe | folder | file
      
      -- User modifications (ONE per item, no per-category overrides)
      userTitle = nil,              -- Custom display name (nil = use baseName)
      categories = {"Creative", "Development"},  -- Tag array
      keeper = true,                -- Preserve if Desktop file deleted
      parameters = "--background",  -- Launch arguments appended to target
      customIcon = "Customisation/blender_custom.ico",  -- Override icon
      
      -- Metadata
      usageCount = 42,              -- Incremented on each launch
      lastUsed = 1699651200,        -- Unix timestamp
      addedAt = 1699564800,         -- When first scanned
      
      -- Extensibility hooks
      icyclesOutHook = {},          -- Array for user/dev scripts
      icyclesColourMod = nil        -- Hex color override (independent of category colors)
    },
    
    ["Photoshop.lnk"] = { ... },
  }
}
```

**Key Design Decisions:**

1. **Why UTF-16LE?**  
   Rainmeter's `dofile()` only handles UTF-16LE or ANSI. UTF-8 causes garbled Unicode filenames.

2. **Why `.ldb` extension?**  
   "Lua Database" - signals data file (not executable script), human-readable format.

3. **Why single `userTitle` (not per-category)?**  
   Items are "virtual .lnk files" - they have ONE identity, displayed consistently everywhere. Category-specific names would fragment user's mental model.

4. **Why `categories` array on item?**  
   Enables fast filtering: "Show uncategorized items", "Items in 3+ categories", "Items NOT in Gaming".

---

### CatData/*.ldb - Spatial Category Organization

**Location:** `CatData/Creative.ldb`, `CatData/Gaming.ldb`, etc.  
**Encoding:** UTF-16LE  
**Purpose:** Define drawer appearance and item ordering

```lua
return {
  metadata = {
    name = "Creative",
    displayName = "ART",      -- 3-4 char abbreviation for collapsed drawer
    color = "#FF5733",        -- Category theme color (20-color daltonist-friendly palette)
    order = 1,                -- Position in category list
    created = 1699564800,
    modified = 1699651200
  },
  
  itemKeys = {
    "Blender.lnk",      -- Array position = drawer order
    "Photoshop.lnk",
    "GIMP.lnk"
  }
}
```

**Key Design Decisions:**

1. **Why separate files per category?**  
   Spatiality belongs to the category, not the item. Blender is position #1 in Creative, but position #3 in Development. This is category-specific data.

2. **Why `itemKeys` array (not full item objects)?**  
   Avoids duplication. To render drawer: iterate `itemKeys`, lookup each in ItemRegistry, display in order. Item renames propagate automatically.

3. **Why 20-color palette?**  
   Maximizes contrast for colorblind users. Algorithm grows from 5 base colors to 20 by maximizing perceptual distance.

---

### Sync Operations & Error Prevention

**Adding item to category:**
```lua
1. Append key to category.itemKeys
2. Add category name to item.categories
3. Save both files atomically
```

**Removing item from category:**
```lua
1. Remove key from category.itemKeys
2. Remove category name from item.categories
3. Save both files
```

**Orphan detection (on load):**
```lua
if item.categories contains "Gaming" but Gaming.ldb doesn't list item:
  auto-repair: remove "Gaming" from item.categories
```

**Reverse check (on save category):**
```lua
for each key in category.itemKeys:
  if ItemRegistry[key].categories doesn't contain this category:
    add it
```

---

### ListedDesktopItems.ldb - Ephemeral Scan Output

**Location:** `Data/ListedDesktopItems.ldb`  
**Purpose:** Raw scan results from Scanner.lua (replaced on each scan)

```lua
return {
  version = "1.0.0",
  timestamp = 1699651200,
  lastScan = "2024-11-15 14:30:00",
  itemCount = 68,
  items = {
    {
      index = 1,
      name = "Blender",
      fullName = "Blender.lnk",
      path = "C:\\Users\\Rafael\\Desktop\\Blender.lnk",
      ext = "lnk",
      target = "C:\\Program Files\\...",
      type = "lnk"
    },
    -- ... all Desktop items
  }
}
```

**This is input data, not canonical storage.** Configurator merges it into ItemRegistry, preserving user modifications.

---

## Desktop Scanning

### The Unicode Problem

**Challenge:** Desktop has files with Unicode names (`Rocket League®.lnk`, `Проект.txt`).

**Lua's limitation:** `io.open()` on Windows only handles ASCII paths reliably. Unicode paths fail or get garbled.

**CMD's capability:** With `chcp 65001`, CMD outputs UTF-8 filenames correctly. It also provides "short names" (8.3 format) which are ASCII-only.

**Solution:** CMD enumerates with BOTH names, Lua uses short names for file I/O.

---

### Scanner Flow

**1. CMD generates manifest:**
```cmd
chcp 65001 >nul && cd /d "C:\Users\Rafael\Desktop" && 
(for /f "delims=" %f in ('dir /b') do @echo %f::%~nf::%~snxf::%~xf) > ScanTemp.txt
```

**Output format:** `FULLNAME::BASENAME::SHORTNAME::EXTENSION`

Example:
```
Rocket League®.lnk::Rocket League®::ROCKET~1.LNK::.lnk
Blender 4.3.lnk::Blender 4.3::BLENDE~1.LNK::.lnk
New folder::New folder::NEWFOL~1::
```

**Why this format?**
- `FULLNAME` - UTF-8 display name (for UI)
- `BASENAME` - Name without extension (CMD's `%~nf` handles multi-dot filenames correctly)
- `SHORTNAME` - ASCII 8.3 name for `io.open()` in Lua
- `EXTENSION` - For type detection

**2. Lua parses manifest:**
```lua
for line in content:gmatch("[^\r\n]+") do
  local fullName, baseName, shortName, ext = line:match("^(.-)::(.-)::(.-)::(.*)$")
  
  -- Use shortName for file I/O (ASCII-safe)
  local shortPath = desktopPath .. "\\" .. shortName
  
  if ext == "url" then
    ParseUrlFile(shortPath)  -- Read .url content with io.open()
  elseif ext == "lnk" then
    ParseLnkFile(shortPath)  -- Binary parse .lnk
  end
  
  -- Use fullName for display (UTF-8)
  item.name = baseName
  item.fullName = fullName
end
```

**3. Write UTF-16LE output:**
```lua
-- Build serialized content
local content = "return " .. SerializeTable(items)

-- Write as UTF-16LE
local file = io.open(path, "wb")
file:write(string.char(0xFF, 0xFE))  -- BOM

-- Convert each byte to 2-byte UTF-16LE
for i = 1, #content do
  local byte = content:byte(i)
  file:write(string.char(byte, 0x00))
end
```

**Why UTF-16LE conversion?**  
Rainmeter's Lua `dofile()` only reads UTF-16LE correctly. UTF-8 output gets garbled.

---

### .lnk Binary Parsing

**Challenge:** Windows `.lnk` files are binary format. We need to extract target path.

**Solution:** Pattern match for drive letters + paths in binary data:

```lua
function ParseLnkFile(lnkPath)
  local file = io.open(lnkPath, "rb")
  local content = file:read("*a")
  file:close()
  
  -- Look for "C:\..." or "D:\..." patterns
  for path in content:gmatch("([A-Za-z]:[%w%s\\%.%-%_%(%)]+)") do
    path = path:gsub("[^%w%s\\%.%-%_%(%)]+$", "")  -- Trim garbage
    if path:match("%.exe$") or path:match("\\[^\\]+$") then
      return path
    end
  end
  
  return nil
end
```

**Limitations:**  
Won't catch paths with `[]`, `&`, `'`, `,` - rare but valid Windows chars. Works for 95% of shortcuts (Program Files paths).

**Future improvement:** Use PowerShell inline (not .ps1 file) with WScript.Shell COM object for 100% accuracy.

---

## UI Design

### Pill Structure

Each Desktop item displays as a **pill meter** with 5 sections:

```
┌────┰───────────────────────────┰─────┰─────┰────┐
│ [ ]┃ Blender 3D Modeling To... ┃ LNK ┃ TAG ┃ 🔒 │
└────┸───────────────────────────┸─────┸─────┸────┘
 1        2                        3     4     5
```

**Section breakdown:**

1. **Checkbox** (`[ ]` / `[✓]`)
   - Click = select/deselect for batch operations
   - Clicking anywhere on pill = select (checkbox is visual indicator only)

2. **Label** (25 chars max)
   - Displays `item.userTitle` (if set) or `item.baseName`
   - Truncates with ellipsis: `Blender 3D Modeling To...`
   - Monospace font = predictable width calculation

3. **Extension** (3 chars, uppercase)
   - `lnk` → `LNK`
   - `json` → `JSO`
   - Always 3 chars max (truncate + uppercase)

4. **TAG** (colored rectangle)
   - Static text "TAG" (not category names)
   - Background color = category theme color
   - If item in multiple categories: first category color, or blend/gradient (TBD)
   - Purpose: Visual identification, not information density

5. **Keeper** (🔒 icon)
   - Shows if `keeper = true`
   - Hidden if `keeper = false` (or show 🔓 - TBD)
   - Indicates item preserved even if Desktop file deleted

**Rationale for pills over list:**
- **Spatial scanning** - eyes can jump directly to target vs linear scanning
- **Color coding** - TAG section provides instant visual grouping
- **Compact** - 25-char labels + extension + status in ~300px width

---

### Controls - Desktop Elements Section

**HIDE FILES** `[ ]`
- Toggle: Hide non-executable files (anything not .lnk, .url, .exe)
- Greys out (50% opacity) when off, hides completely when on
- Reduces visual noise for launcher-focused users

**COLOURED** `[ ]`
- Toggle: Enable/disable TAG section coloring
- When off: TAG is neutral grey
- When on: TAG uses category colors

**SORT** - Dual-state glued button
```
SORT [ALPHA][DATE]   [ASC][DESC]
      ^^^^            ^^^
     selected       selected
```
- Click ALPHA/DATE to switch primary sort
- Click ASC/DESC to toggle direction
- Compact alternative to dropdown (1 click instead of 2)

**FILTER** - Category multiselect
- Opens mini-pane with category pills
- Click category = toggle ON/OFF
- Logic: Show item if ANY selected category matches (OR filter)
  - Item tagged [Creative, Gaming]
  - Filter = [Creative: ON, Tools: OFF]
  - Result: VISIBLE (matches Creative)

**TOOLS** - Batch operations pane
Opens dropdown with:
- **REMOVE "- SHORTCUT"** - Strip suffix from selected items' `userTitle`
- **RENAME: ALL CAPS** - Transform to uppercase
- **RENAME: small caps** - Transform to lowercase  
- **RENAME: Typical Title** - Title Case
- **RECREATE AS NEW ICON** - Generate new .ico (implementation TBD)
- **CLEAN DESKTOP** - Remove Desktop files for items with `keeper=true` (3-layer confirmation modal)

All operations modify ItemRegistry only (not actual Desktop files), except Clean Desktop.

---

### Collapsible Sections

Each CMS column has two states:

**Expanded:**
```
┌─ DESKTOP ELEMENTS ──────────────┐
│ [pills...]                       │
│ [controls...]                    │
└──────────────────────────────────┘
```

**Collapsed:**
```
┌─ DESKTOP ELEMENTS ────────── [▶] ┐
```

Click header to toggle. Hidden state controlled by variable:
```lua
SKIN:Bang('!SetVariable', 'ColumnACollapsed', '1')
SKIN:Bang('!HideMeterGroup', 'ColumnAContent')
```

**Benefits:**
- Adaptive to screen size
- Focus on relevant section
- Keyboard shortcuts: A, B, C keys toggle sections

---

## Typography & Styling

**Font:** JetBrains Mono (Apache 2.0 licensed)  
**Rationale:** 8 weight range, technical aesthetic, excellent hinting, strong character differentiation

**Hierarchy:**
- **18px Bold** - Section headers in CMS
- **10px Medium** - Pill labels, UI text
- **9px Regular** - Metadata, secondary info
- **64px Bold** - Drawer headers (deferred for now)

**Spacing:** Golden ratio derived
- Base unit: 8px
- Multiples: 8, 13, 21, 34, 55 (φ progression)

**Color System:**
- Dark mode (primary): Charcoal bg + silver text + single accent
- Backgrounds: 4-6% opacity (barely perceptible)
- Accent colors: 20-color daltonist-friendly palette for categories

**Design tokens defined in:** `@Resources/Variables.inc`

---

## Implementation Status

### ✅ Working
- **Scanner.lua** - CMD enumeration → UTF-16LE output
- **UserDesktopInfo.lua** - Environment detection (Desktop path, screen size)
- **Data structures** - Spec finalized (ItemRegistry + CatData)

### 🚧 In Progress
- **ItemRegistry merge logic** - Scan results → preserve user mods
- **Pill UI generation** - Dynamic meter population
- **Category assignment** - Click item → click category → click ➕

### 📋 Planned (Priority Order)
1. Save ItemRegistry changes (atomic writes with backup)
2. Multi-category tagging UI
3. Controls implementation (HIDE FILES, COLOURED, SORT, FILTER, TOOLS)
4. Collapsible sections
5. Keeper flag management
6. Usage tracking (increment on launch)
7. Custom icon replacement
8. "New items" detection (diff against previous scan)
9. Clean Desktop feature

---

## Decision Log

### Why Lua-Only (No PowerShell/Batch Scripts)
**Problem:** Security concerns, user trust, antivirus false positives.

**Decision:** All logic in Lua (embedded in Rainmeter), CMD only for file enumeration (inline, not .bat file).

**Trade-offs:** 
- Lua has limited file I/O (Unicode path issues)
- Can't easily resolve .lnk shortcuts without COM automation
- **Accepted:** 95% accuracy with pattern matching, future PowerShell inline for 100%

---

### Why Flat File Structure
**Problem:** Nested folders (`Data/Generated/`, `@Resources/Scripts/`) complicate Rainmeter pathing.

**Decision:** Top-level folders only: `Data/`, `CatData/`, `Drawers/`, `@Resources/`.

**Benefits:**
- Simpler `SKIN:GetVariable("CURRENTPATH")` usage
- Easier troubleshooting (files at predictable locations)

---

### Why Denormalized References (item.categories AND category.itemKeys)
**Problem:** Need both filtering (by category membership) and spatial ordering (drawer positions).

**Decision:** Store bidirectional references:
- `item.categories` → fast filtering, orphan detection
- `category.itemKeys` → drawer rendering order

**Trade-off:** Sync complexity (must update both on add/remove).

**Mitigation:** Auto-repair on load if references mismatch.

---

### Why CMD for File Enumeration
**Problem:** Lua's `io.popen("dir")` outputs in OEM codepage (garbled Unicode).

**Decision:** Use `chcp 65001` to force UTF-8 output, plus short names for file I/O.

**Why not pure Lua?** `lfs` (LuaFileSystem) not available in Rainmeter's Lua sandbox.

---

### Why UTF-16LE Output (Not UTF-8)
**Problem:** Rainmeter's `dofile()` only handles UTF-16LE or ANSI. UTF-8 causes garbled filenames.

**Decision:** Scanner writes UTF-8 internally, converts to UTF-16LE with BOM before saving.

**Trade-off:** Extra conversion step, but necessary for Rainmeter compatibility.

---

### Why Tag Pills Over Scrolling Lists
**Problem:** 68 Desktop items in linear list = slow visual scanning.

**Decision:** Flowing pill layout (left-to-right, top-to-bottom) with pagination.

**Benefits:**
- Spatial scanning (eyes jump directly to target)
- Color coding (TAG section provides grouping)
- Expandable (hover/click for details)

**Trade-off:** Fixed pill count per page (but dynamically calculated per screen resolution).

---

### Why 20-Color Palette (Not Unlimited)
**Problem:** Too many categories = color collision, poor contrast.

**Decision:** Limit to 20 colors, algorithmically chosen for maximum perceptual distance.

**Rationale:** 
- Daltonist-friendly (works for colorblind users)
- Forces category consolidation (good UX constraint)
- Aesthetic consistency

---

### Why Single Icon/Name Per Item (Not Per-Category Overrides)
**Problem:** Should Blender show as "Blender" in Creative but "3D Tool" in Development?

**Decision:** ONE identity per item (`userTitle`, `customIcon` in ItemRegistry).

**Rationale:**
- Items are "virtual .lnk files" - have consistent identity
- Per-category names fragment user's mental model
- Simplifies data sync

---

### Why Desktop as Ephemeral (Not Canonical)
**Problem:** Users keep hundreds of files on Desktop "just in case."

**Paradigm shift:** Desktop = inbox (temporary), Icycles = archive (permanent).

**Implication:** `keeper` flag lets users delete Desktop files safely. Icycles can recreate shortcuts at will.

**Future feature:** "Clean Desktop" removes kept items from Desktop (with confirmation).

---

*End of Architecture Document*
