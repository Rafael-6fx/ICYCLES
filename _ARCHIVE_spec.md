# Icycles - Desktop Organization CMS for Rainmeter

## Project Overview
**Name:** Icycles (frozen raindrops metaphor - catching Desktop chaos and crystallizing it into structure)  
**Purpose:** Rainmeter-based CMS for organizing Desktop shortcuts into categorized, expandable drawer widgets  
**Architecture:** Lua-only (no PowerShell), modular configuration system, visual tagging interface

---

## Data Structure Specification

### **Data/ListedDesktopItems.lua**
Raw scan output - everything found on Desktop:

```lua
return {
  {
    name = "Visual Studio Code",
    path = "C:\\Users\\Rafael\\Desktop\\Visual Studio Code.lnk",
    ext = "lnk",
    icon = "C:\\Program Files\\Microsoft VS Code\\Code.exe,0",
    type = "shortcut",  -- shortcut | url | executable | folder
    target = "C:\\Program Files\\Microsoft VS Code\\Code.exe",  -- resolved target
    timestamp = 1699564800,  -- last modified (for change detection)
  },
  {
    name = "GitHub",
    path = "C:\\Users\\Rafael\\Desktop\\GitHub.url",
    ext = "url",
    icon = nil,  -- URLs might not have icons
    type = "url",
    target = "https://github.com",
    timestamp = 1699478400,
  },
  -- ... all Desktop items
}
```

**Fields:**
- `name` (string) - Display name (filename without extension)
- `path` (string) - Full path to Desktop item
- `ext` (string) - File extension
- `icon` (string|nil) - Icon source (exe path + index, or nil)
- `type` (string) - One of: shortcut, url, executable, folder
- `target` (string) - Resolved target path/URL
- `timestamp` (number) - Last modified time for change detection

---

### **CatData/[CategoryName].ldb**
Per-category data with assigned items (single file per category):

```lua
return {
  metadata = {
    name = "Development",
    displayName = "DEV",  -- Short name for collapsed drawer (3-4 chars ideal)
    icon = nil,  -- Custom category icon (optional, path to Customisation/)
    color = nil,  -- Custom accent color override (optional, "R,G,B,A")
    order = 1,  -- Position in category list (for UP/DOWN sorting)
    created = 1699564800,
    modified = 1699651200,
    version = "1.0.0",  -- Schema version for future migrations
  },
  items = {
    {
      -- Reference to ListedDesktopItems entry
      name = "Visual Studio Code",
      path = "C:\\Users\\Rafael\\Desktop\\Visual Studio Code.lnk",
      
      -- Category-specific overrides
      customIcon = nil,  -- Path to Customisation/ if user uploaded custom icon
      customName = nil,  -- Display name override
      launchFlags = nil,  -- Additional command-line arguments
      order = 1,  -- Position within category (for item reordering)
      
      -- Metadata
      addedAt = 1699564800,
      source = "desktop",  -- "desktop" | "custom" (for non-Desktop items)
    },
    {
      name = "GitHub Desktop",
      path = "C:\\Users\\Rafael\\Desktop\\GitHub Desktop.lnk",
      customIcon = "Customisation/github_custom.png",
      customName = "Git GUI",
      launchFlags = "--open-repo",
      order = 2,
      addedAt = 1699564900,
      source = "desktop",
    },
    {
      -- Example of custom item NOT from Desktop
      name = "SSH Config Editor",
      path = "C:\\Windows\\System32\\notepad.exe",
      customIcon = "Customisation/ssh_icon.png",
      customName = nil,
      launchFlags = "C:\\Users\\Rafael\\.ssh\\config",
      order = 3,
      addedAt = 1699565000,
      source = "custom",  -- User added this manually
    },
  },
}
```

**Metadata fields:**
- `name` (string) - Full category name
- `displayName` (string) - Short version for UI
- `icon` (string|nil) - Custom icon path
- `color` (string|nil) - Custom accent color override
- `order` (number) - Sort position in category list
- `created`/`modified` (number) - Timestamps
- `version` (string) - Schema version

**Item fields:**
- `name`/`path` - Core identity (matches ListedDesktopItems)
- `customIcon` (string|nil) - Override icon from Customisation/
- `customName` (string|nil) - Display name override
- `launchFlags` (string|nil) - Arguments to pass on launch
- `order` (number) - Position in drawer
- `addedAt` (number) - When added to category
- `source` (string) - "desktop" or "custom"

---

### **Data/Categories.ldb**
Master index of all categories (for quick loading):

```lua
return {
  categories = {
    "Development",
    "Creative",
    "Gaming",
    "Tools",
    "Office",
  },
  order = {1, 2, 3, 4, 5},  -- Explicit ordering (mirrors metadata.order)
  lastGenerated = 1699651200,  -- Last time drawers were generated
  version = "1.0.0",  -- Schema version for future migrations
}
```

---

### **Data/UserDesktopData.ldb**
Cached environment data:

```lua
return {
  desktopPath = "C:\\Users\\Rafael\\Desktop",
  screenWidth = 1920,
  screenHeight = 1080,
  workAreaWidth = 1920,  -- Excluding taskbar
  workAreaHeight = 1040,
  dpi = 96,
  lastScan = 1699651200,
  desktopItemCount = 47,
  rainmeterVersion = "4.5.18",
  skinPath = "C:\\Users\\Rafael\\Documents\\Rainmeter\\Skins\\Icycles",
  version = "1.0.0",
}
```

---

### **@Resources/CatDictionary.ldb**
Keyword matching for auto-tagging:

```lua
return {
  Development = {
    keywords = {"code", "visual studio", "vscode", "git", "github", "python", "node", "terminal", "cmd", "powershell", "bash", "jetbrains"},
    extensions = {"py", "js", "ts", "cpp", "lua", "sh"},
  },
  Creative = {
    keywords = {"photoshop", "illustrator", "blender", "maya", "substance", "figma", "sketch", "gimp", "inkscape", "3d", "render"},
    extensions = {"psd", "ai", "blend", "fig"},
  },
  Gaming = {
    keywords = {"steam", "epic", "gog", "origin", "uplay", "game", "minecraft", "valorant"},
    extensions = {"exe"},  -- Only if in specific dirs like Program Files/Steam
  },
  Tools = {
    keywords = {"chrome", "firefox", "brave", "notepad", "calculator", "explorer", "paint", "rainmeter"},
    extensions = {},
  },
  Office = {
    keywords = {"word", "excel", "powerpoint", "outlook", "teams", "onenote", "acrobat", "pdf"},
    extensions = {"docx", "xlsx", "pptx", "pdf"},
  },
}
```

---

## Data Integrity & Best Practices

### **Schema Versioning**
Every data file includes `version = "1.0.0"` field. When structure changes, migration scripts can detect old format and upgrade automatically.

### **Atomic Writes**
When saving data, write to temporary file first, then rename (atomic operation):

```lua
-- Write to temp file first
local temp = io.open(path .. ".tmp", "w")
temp:write(serialized_data)
temp:close()

-- Rename temp to actual (atomic on most filesystems)
os.rename(path .. ".tmp", path)
```

This prevents corruption if Rainmeter crashes mid-write.

### **Automatic Backups**
Before overwriting category files during save:
1. Copy current version to `Backups/[CategoryName]_[timestamp].ldb`
2. Auto-cleanup old backups (keep last 10 per category)
3. Provides rollback capability for user errors

### **Error Handling**
All file operations wrapped in `pcall()`:

```lua
local success, result = pcall(function()
  return dofile("Data/Categories.ldb")
end)

if not success then
  -- Log error to Logs/errors.log
  log_error("Failed to load Categories.ldb: " .. tostring(result))
  -- Return safe default structure
  return {categories = {}, order = {}, version = "1.0.0"}
end
```

### **Data Validation**
Before using loaded data, validate structure:

```lua
function validate_category(cat)
  if type(cat) ~= "table" then return false end
  if not cat.metadata or type(cat.metadata.name) ~= "string" then return false end
  if not cat.items or type(cat.items) ~= "table" then return false end
  return true
end
```

Prevents cascading failures from malformed data files.

### **Save Strategy**
- **Auto-save:** Every 5 seconds after last modification (debounced)
- **Manual save:** Explicit "Save" button for user control
- Both trigger same save function with backup creation

---

## Core Principles
- **Form follows function** - no decorative elements
- **Modular design** - styling separate from logic, data separate from presentation
- **User control** - manual tagging with intelligent auto-suggestions, not forced automation
- **Visual efficiency** - tag pills over scrolling lists, spatial scanning over linear search

---

## File Structure

```
Icycles/
├─ Icycles.ini                          # Main CMS interface
├─ @Resources/
│  ├─ Styling.ini                       # Visual design system
│  ├─ Variables.inc                     # Design tokens (colors, spacing, typography)
│  ├─ Autotag.lua                       # Keyword-based category suggestion engine
│  ├─ Configurator.lua                  # Category/item management logic
│  ├─ Scanner.lua                       # Desktop scanning (path resolution, file enumeration)
│  ├─ Generator.lua                     # Drawer widget generation from category data
│  ├─ CatDictionary.ldb                 # Predefined keyword→category mappings for autotagging
│  ├─ UserDesktopInfo.lua               # Screen size, paths, last run metadata gatherer
│  └─ Fonts/
│     ├─ Readme.txt                     # Font installation instructions (MANUAL INSTALL)
│     ├─ License.txt                    # Apache 2.0 license for JetBrains Mono
│     └─ JetBrains/                     # Bundled font files (shippable under Apache 2.0)
├─ Data/
│  ├─ ListedDesktopItems.lua            # Scanned Desktop items (Lua table format)
│  ├─ AdditionalCommands.lua            # User-defined custom commands/scripts
│  ├─ Categories.ldb                    # Category metadata and item assignments
│  └─ UserDesktopData.ldb               # Cached screen dimensions, paths, timestamps
├─ CatData/                             # Per-category data files
│  ├─ Creative.ldb
│  ├─ Gaming.ldb
│  ├─ Tools.ldb
│  ├─ Office.ldb
│  └─ Customisation/
│     ├─ [Custom icons/bitmaps]         # User-uploaded visual assets (manual saves, no automatic storage)
│     ├─ UserCommands.ldb               # Per-item custom launch flags/arguments
│     └─ UserItems.ldb                  # Custom items not from Desktop
├─ Drawers/                             # **MISSING FROM ORIGINAL - NEEDS ADDING**
│  └─ [Generated drawer widgets]        # Output .ini files for deployed drawers
├─ Backups/
│  └─ [timestamped .zip backups]        # Config snapshots before major changes
└─ Logs/
   └─ errors.log                        # Lua error logging
```

### **Key Structure Decisions:**
- Flat hierarchy (no deep nesting) for simpler Rainmeter pathing
- `.ldb` extension = "Lua database" (data files, not executable scripts)
- Capital letters everywhere (consistent naming convention)
- `Drawers/` folder for generated drawer widget output
- `Scanner.lua` lives in `@Resources/`, NOT in `Fonts/` folder
- Fonts are shipped but require manual installation (no automated installer script)

---

## Typography System

**Font:** JetBrains Mono (Apache 2.0 licensed, shippable)  
**Rationale:** 8 weight range, technical aesthetic, excellent hinting, strong character differentiation

### Hierarchy:
- **64px Bold/ExtraBold** - Category headers in drawer widgets
- **18px Bold** - CMS interface section titles
- **10-12px Regular/Medium** - Item labels, UI text
- **10px Light** - Metadata, secondary information

### Design Tokens (Variables.inc):
```ini
[Variables]
; Typography
FontFamily=JetBrains Mono
HeaderSize=18
ItemSize=10
MetaSize=9

; Colors (adjust per user preference)
BgColor=20,20,22,12              ; Barely perceptible transparency (4-6% opacity)
DrawerBgColor=20,20,22,230       ; Drawer solid background
TextColor=200,200,205,255        ; Silver/platinum (not pure white)
AccentColor=180,180,190,255      ; Subtle accent
HighlightBg=40,40,45,200         ; Hover/selected state

; Spacing (Golden ratio derived)
BaseUnit=8
Spacing1=8                        ; BaseUnit * 1
Spacing2=13                       ; BaseUnit * 1.618
Spacing3=21                       ; BaseUnit * 2.618
Spacing4=34                       ; BaseUnit * 4.236

; Layout
DrawerWidth=280
ItemHeight=40
PillHeight=30
Padding=16
```

---

## Data Flow

### Startup Sequence:
1. **UserDesktopInfo.lua** runs:
   - Resolves Desktop path (from `SKINSPATH` navigate to `..\..\Desktop\`)
   - Gathers screen dimensions via Rainmeter variables
   - Records last run timestamp
   - Saves to `Data/UserDesktopData.ldb`

2. **Scanner.lua** executes:
   - Reads Desktop directory
   - Enumerates `.lnk`, `.url`, `.exe` files
   - Extracts: filename, path, icon source
   - Outputs Lua table to `Data/ListedDesktopItems.lua`
   ```lua
   return {
     {name="VS Code", path="C:\\...\\vscode.lnk", icon="...", ext="lnk"},
     {name="Chrome", path="...", icon="...", ext="url"},
     -- etc
   }
   ```

3. **Autotag.lua** suggests categories:
   - Loads `ListedDesktopItems.lua` + `@Resources/CatDictionary.ldb`
   - Matches keywords (e.g., "code" → Dev, "photoshop" → Creative)
   - Writes suggestions to `Data/Categories.ldb` (NOT final assignments)

4. **Configurator.lua** loads existing category files:
   - Reads `CatData/*.ldb` files if they exist
   - Merges with new Desktop items
   - Presents unified state to UI

5. **Icycles.ini** renders CMS interface with all data loaded

### User Interaction Flow:
1. **Column A** - User clicks item pill → `SelectedItem` variable set
2. **Column B** - User clicks category → `SelectedCategory` variable set
3. User clicks **[ ➕ ]** → `Configurator.lua` writes `SelectedItem` to `CatData/[SelectedCategory].ldb`
4. **Column C** updates to show item in preview
5. **Auto-save with debounce** (500ms after last action) → writes changes to disk

### Generation Flow:
1. User clicks **[Generate Drawers]** button (location TBD in UI)
2. **Generator.lua** executes:
   - Reads all `CatData/*.ldb` files
   - For each category, builds drawer widget `.ini` file
   - Calculates drawer height based on item count: `Height = (ItemCount × ItemHeight) + (ItemCount × Spacing) + Padding + TitleHeight`
   - Outputs to `Drawers/[CategoryName].ini`
3. User clicks **[Deploy]** → Rainmeter `[!ActivateConfig]` loads all generated skins

---

## CMS Interface (Icycles.ini)

### Layout: 3-Column Design

**Collapsed State:**
- Small icon with cog emoji ⚙️
- Click to expand full CMS modal

**Expanded State: 3 Columns**

---

#### **Column A: Desktop Elements Selector**

**Title:** "Desktop Elements Selector"

**Container:** Tag pill grid (A-Z sorted, flowing layout)
- Each pill shows: `ItemName` + `.ext` badge (smaller, secondary text)
- Click pill → highlight (selected state)
- Pills calculate width based on mono font: `Width = (CharCount × CharWidth) + Padding`

**Controls Below Container:**
- `[Rebuild List]` - re-scan Desktop
- `[Flip Sorting]` - toggle A-Z ↔ Z-A
- `[Folder Listing ON]` - toggle showing folders (changes to OFF when clicked)
- `[Non-Exec Listing ON]` - toggle showing non-executable files

**Instructional Text:**
"Use the [ ➕ ] and [ ➖ ] there→ to add and remove from the category"

**Implementation Notes:**
- Pagination IF item count exceeds `ItemsPerPage = floor(ContainerArea / PillSize)`
- Page navigation: `[← Prev]` `Page X/Y` `[Next →]`
- Toggles filter DISPLAY only (scanning always grabs everything)

---

#### **Column B: Category Manager**

**Title:** "Category Manager"

**Container:** List of categories (pills or simple text items, highlight on select)

**Controls:**
- `[Add Category]` - text input modal for new category name
- `[Remove Category]` - triggers "Are you sure you want to remove `<CategoryName>`?" modal
- `[Move UP]` `[Move DOWN]` `[Move TOP]` `[Move BOTTOM]` - reorder category priority

**Item Actions (below category list):**
- **[ ➕ ]** - Add selected item (from Column A) to selected category
- **[ ➖ ]** - Remove selected item from selected category

**Behavior:**
- If NO category selected, ➕/➖ buttons disabled OR auto-select first category
- Adding item updates Column C immediately
- Removing item from category does NOT delete Desktop shortcut (just removes from category)

---

#### **Column C: Category Preview**

**Title:** "Category Preview"

**Navigation:**
`[Previous]` `<CategoryName.ldb>` `[Next]`  
(Alternative navigation to clicking in Column B)

**Container:** List of items in selected category (ordered)
- Each item shows name + mini icon preview
- Click item to select for actions

**Per-Item Actions:**
- `[Custom Icon]` - file picker to override native icon (saves to `CatData/Customisation/`)
- `[Remove from Category]` - removes item from THIS category only

**Category-Level Actions:**
- `[Add Custom Item]` - add executable/URL/folder NOT on Desktop (file picker or text input)
- `[Move UP/DOWN/TOP/BOTTOM]` - reorder items within category

**Implementation Notes:**
- Previous/Next must sync with Column B selection
- Custom icons stored in `Customisation/` with reference in category `.ldb` file

---

## UI/UX Decisions

### **Pivot: Tag Pills Over Scrolling**
**Original Plan:** Scrollable list with manual tagging  
**Current Plan:** Tag pill grid with spatial layout  
**Rationale:** Faster visual scanning, better use of screen space, mono font makes calculations predictable

### **Pivot: Auto-tagging with Manual Override**
**Original Plan:** Pure manual tagging  
**Current Plan:** Keyword-based suggestions, user reviews/adjusts  
**Rationale:** Saves time on initial setup, reduces tedium for 100+ item Desktops

### **Pivot: Lua-Only (No PowerShell)**
**Original Plan:** PS script for scanning + Rainmeter for UI  
**Current Plan:** All Lua, internal to Rainmeter  
**Rationale:** No external dependencies, no security concerns, simpler distribution

### **Pivot: Flat File Structure**
**Original Plan:** Nested folders (`Data/Generated/`, `@Resources/Scripts/`)  
**Current Plan:** Flat hierarchy with logical top-level folders  
**Rationale:** Simpler Rainmeter pathing, less navigation complexity

---

## Resolved Decisions

1. **Save Strategy:** Auto-save every 5 seconds + manual "Save" button for explicit control
2. **Category File Format:** Single `.ldb` file per category (metadata + items together)
3. **Modal Implementation:** Overlay meters (show/hide)
4. **Target Window Size:** Design for 1080p, dynamically size based on element count (don't overfill empty space)
5. **Generate Button Placement:** At the "tail end" - brings up CMS panel
6. **Drawer Widget Positioning:** Calculated based on screen size from `UserDesktopData.ldb`
7. **Font Installation:** Ship fonts, manual install (no automated script)
8. **Color System:** Dark/light themes with single hardcoded accent color (wallpaper extraction deferred)
9. **64px Typography:** YES - neobrutalist headers remain, type as structure aesthetic preserved

---

## Drawer Widget Specification

### Visual Design:
- **Collapsed:** Small icon (48×48px) + category label (e.g., "DEV")
- **Expanded on Hover:** Drawer slides out (280px wide, auto-height based on items)
- **Background:** `BgColor` at 4-6% opacity (barely perceptible)
- **Typography:** JetBrains Mono Bold 64px for headers (currently NOT in drawer design - needs revision)

### Interaction:
- Hover over icon → drawer expands
- Each item in drawer has hover state (subtle bg highlight)
- Click item → launches app
- Mouse leaves drawer → collapses after 200ms delay

### Technical Implementation:
```ini
[Variables]
ItemCount=8
DrawerHeight=((#ItemHeight# + #ItemSpacing#) * #ItemCount# + #Padding# * 2 + 48)

[MeterDrawerBg]
Shape=Rectangle 0,0,#DrawerWidth#,#DrawerHeight# | Fill Color #DrawerBgColor#
```

---

## Typography Design Decision

**Header Treatment:** 64px slab category text was proposed for visual structure (letters as dividers). This creates strong visual hierarchy but requires careful spacing.

**Current Implementation:** Simpler 18px headers in drawers.

**Future Consideration:** If Rafael wants the "type as structure" aesthetic, integrate 64px Bold headers with em-dash rules or letter-based spacing.

---

## Notes for Implementation

### Lua Capabilities Needed:
- `io.popen()` for directory listing (Desktop scanning)
- `io.open()` for file read/write (config management)
- String manipulation for path resolution
- Table serialization for `.ldb` format
- Rainmeter variable access via `SKIN:GetVariable()`

### Rainmeter Features Used:
- `MouseOverAction` / `MouseLeaveAction` for hover states
- `LeftMouseUpAction` for clicks
- `[!ShowMeter]` / `[!HideMeter]` for modal overlays
- `[!WriteKeyValue]` for config modification
- `[!ActivateConfig]` for deploying generated skins
- `[!Refresh]` for reloading after changes

### Performance Considerations:
- Pre-calculate layout on startup (save to `UserDesktopData.ldb`)
- Debounce auto-save to reduce I/O
- Pagination if item count exceeds ~50-100 pills per page
- Cache icon extractions (don't re-extract on every render)

---

## Design Philosophy

**Minimalist:** Barely-there backgrounds (4-6% opacity), restrained color palette, geometry as punctuation not decoration  
**Neobrutalist:** 64px Bold typography as structural element, type creates hierarchy and division  
**Technical:** Mono font, precise spacing (golden ratio), structured hierarchy  
**Functional:** Every element serves purpose, no "pretty but useless" features  
**User-Controlled:** Manual override for all automation, transparent data files  

**Color System:**
- Dark mode (primary): Charcoal bg + silver text + single hardcoded accent
- Light mode (alternate): Off-white bg + ink text + adjusted accent
- Single accent color defined once in Variables.inc
- Wallpaper color extraction DEFERRED (CMS functionality > flair for now)

**Typography as Structure:**
- 64px JetBrains Mono Bold headers define category boundaries
- Em-dash repetition for texture without vector graphics
- Letterforms create rhythm and spacing
- "Type as architecture" aesthetic preserved

---

## Known Issues / Risks

1. **Pagination Required:** If Desktop has 100+ items, tag pills need pagination. Calculate `ItemsPerPage = floor(ContainerArea / PillSize)`.
2. **JetBrains Mono Hinting:** Tested and confirmed excellent. No issues expected.
3. **Rainmeter Lua Sandbox:** Environment variable access may be limited. Test `SKIN:GetVariable('USERPROFILE')` or use relative path navigation from `SKINSPATH`.
4. **Icon Extraction:** 
   - `.exe` icon extraction works natively: `ImageName=path.exe,0`
   - `.lnk` shortcut icon extraction works natively in Rainmeter
   - `.url` files may not have icons (handle gracefully with default)
5. **Modal Overlays:** "Are you sure" modals require show/hide meter logic with overlay background.
6. **64px Typography Space:** Large headers consume significant vertical space. Calculate drawer heights carefully to avoid overflow.
7. **Category File Size:** Single-file categories could grow large (50+ items). Monitor performance, optimize if needed.

---

## Implementation Order

**Critical constraint:** Data structures (#9) must be finalized BEFORE generate button (#6) implementation.

### **Phase 1: Foundation**
1. **UserDesktopInfo.lua** - Environment detection (no dependencies)
2. **Data validation functions** - Schema checking infrastructure
3. **Scanner.lua** - Desktop enumeration → `ListedDesktopItems.lua`

### **Phase 2: Tagging System**
4. **Autotag.lua** - Category suggestions (reads Scanner output)
5. **Column A UI** - Display tag pills from ListedDesktopItems
6. **Configurator.lua** - Category/item management (writes CatData files)

### **Phase 3: Category Management**
7. **Column B UI** - Category list + controls
8. **Column C UI** - Category preview + item reordering
9. **Save system** - Auto-save (5s debounce) + manual button

### **Phase 4: Generation** (Only after Phases 1-3 complete)
10. **Generator.lua** - Drawer widget creation (reads CatData)
11. **Generate button** - Triggers Generator at "tail end" of UI
12. **Drawer deployment** - `[!ActivateConfig]` for all generated skins

This sequence ensures data integrity before any generation happens. No skipping phases.

---

**End of Specification**
