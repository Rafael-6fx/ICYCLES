# ICYCLES - Desktop Organization CMS for Rainmeter

*Crystallizing Desktop chaos into structured drawers*

## Overview

Icycles is a Rainmeter-based Content Management System for organizing Desktop shortcuts into categorized, expandable drawer widgets. It provides a visual CMS interface for categorizing items and automatically generates hover-activated drawers for your Desktop.

### Key Features

- **Desktop Scanning**: Automatically scans and catalogs Desktop shortcuts, URLs, executables, and folders
- **Auto-Tagging**: Intelligent keyword-based category suggestions
- **Visual CMS Interface**: 3-column layout for intuitive organization
- **Drawer Widgets**: Collapsible, hover-activated category drawers
- **Lua-Only Architecture**: No external dependencies, no PowerShell scripts
- **Atomic Saves**: Data integrity with automatic backups
- **Minimalist Design**: Neobrutalist aesthetic with JetBrains Mono typography

## Installation

### Prerequisites

1. **Rainmeter** (version 4.5 or higher)
   - Download from: https://www.rainmeter.net/

2. **JetBrains Mono Font** (Required for proper typography)
   - Download from: https://www.jetbrains.com/lp/mono/
   - See `@Resources/Fonts/Readme.txt` for installation instructions

### Setup

1. Copy the `Icycles` folder to your Rainmeter Skins directory:
   ```
   C:\Users\[YourName]\Documents\Rainmeter\Skins\Icycles\
   ```

2. Install JetBrains Mono font (see font installation instructions)

3. Refresh Rainmeter and load the Icycles skin

## Usage

### First-Time Setup

1. **Click the ⚙ icon** to open the CMS interface

2. **Click "REBUILD LIST"** in Column A to scan your Desktop

3. **Auto-tag items** (optional):
   - Items will be automatically suggested for categories based on keywords
   - Review and adjust suggestions manually

4. **Create categories** in Column B:
   - Click "ADD CATEGORY"
   - Enter category name (e.g., "Development", "Creative", "Gaming")

5. **Organize items**:
   - Select an item in Column A
   - Select a category in Column B
   - Click ➕ to add item to category

6. **Generate drawers**:
   - Click "GENERATE DRAWERS" at bottom-right
   - Drawers will be created and deployed to your Desktop

### CMS Interface Layout

#### Column A: Desktop Elements Selector
- Displays all Desktop items as tag pills
- Click item to select
- Controls:
  - **REBUILD LIST**: Re-scan Desktop
  - **FLIP SORT**: Toggle A-Z ↔ Z-A sorting
  - **FOLDER LISTING**: Toggle folder visibility
  - **NON-EXEC LISTING**: Toggle non-executable files

#### Column B: Category Manager
- Lists all categories
- Click category to select
- Controls:
  - **ADD CATEGORY**: Create new category
  - **REMOVE**: Delete selected category
  - **➕ / ➖**: Add/remove items from category
  - **▲ / ▼**: Reorder categories

#### Column C: Category Preview
- Shows items in selected category
- Navigate with PREV/NEXT buttons
- Per-item actions:
  - Custom icons
  - Custom names
  - Reorder items

## File Structure

```
Icycles/
├─ Icycles.ini                    # Main CMS interface
├─ README.md                      # This file
├─ @Resources/
│  ├─ Variables.inc               # Design tokens (colors, spacing, fonts)
│  ├─ Styling.ini                 # Reusable meter styles
│  ├─ UserDesktopInfo.lua         # Environment detection
│  ├─ Scanner.lua                 # Desktop scanning
│  ├─ Autotag.lua                 # Category suggestion engine
│  ├─ Configurator.lua            # Category/item management
│  ├─ Generator.lua               # Drawer widget generation
│  ├─ CatDictionary.ldb           # Keyword→category mappings
│  └─ Fonts/
│     ├─ Readme.txt               # Font installation guide
│     └─ License.txt              # Apache 2.0 license
├─ Data/
│  ├─ ListedDesktopItems.lua      # Scanned Desktop items
│  ├─ Categories.ldb              # Master category index
│  └─ UserDesktopData.ldb         # Environment cache
├─ CatData/
│  ├─ [Category].ldb              # Per-category data files
│  └─ Customisation/
│     └─ [Custom assets]          # User-uploaded icons
├─ Drawers/
│  ├─ [Category].ini              # Generated drawer widgets
│  └─ Example_Development.ini     # Example drawer
├─ Backups/
│  └─ [Timestamped backups]       # Automatic backups
└─ Logs/
   └─ errors.log                  # Error logging
```

## Customization

### Design Tokens

Edit `@Resources/Variables.inc` to customize:

- **Colors**: Background, text, accent colors
- **Typography**: Font sizes, weights
- **Spacing**: Layout dimensions, padding
- **Layout**: Column widths, drawer sizes

### Category Keywords

Edit `@Resources/CatDictionary.ldb` to customize auto-tagging:

```lua
return {
  Development = {
    keywords = {"code", "vscode", "git", "python", ...},
    extensions = {"py", "js", "lua", ...}
  },
  -- Add your own categories...
}
```

## Data Management

### Auto-Save

- Changes auto-save every 5 seconds (debounced)
- Click "SAVE" button for manual save

### Backups

- Automatic backups before each save
- Stored in `Backups/` folder
- Last 10 backups kept per category

### Data Format

All data files use Lua table format (`.ldb` extension):
- Human-readable
- Version-controlled with schema versioning
- Atomic writes prevent corruption

## Troubleshooting

### Desktop items not appearing

1. Check Desktop path in `Data/UserDesktopData.ldb`
2. Click "REBUILD LIST" to re-scan
3. Check `Logs/errors.log` for errors

### Drawers not generating

1. Ensure categories have items
2. Check file permissions in `Drawers/` folder
3. Review error log

### Font not displaying correctly

1. Confirm JetBrains Mono is installed system-wide
2. Restart Rainmeter after font installation
3. Check font name in Windows Font Settings

### Lua errors

- All errors logged to `Logs/errors.log`
- Check for file permission issues
- Verify Rainmeter has access to Desktop directory

## Design Philosophy

**Minimalist**: Barely-there backgrounds (4-6% opacity), restrained colors, no decorative elements

**Neobrutalist**: 64px Bold typography as structural element, type creates hierarchy

**Technical**: Monospace font, precise spacing (golden ratio), structured layout

**Functional**: Every element serves a purpose, no unnecessary features

**User-Controlled**: Manual override for all automation, transparent data files

## Development

### Architecture Decisions

- **Lua-Only**: No external dependencies, runs entirely within Rainmeter
- **Flat File Structure**: Simpler pathing, easier maintenance
- **Atomic Writes**: Data integrity through temp-file-then-rename pattern
- **Schema Versioning**: Future-proof with version fields in all data files
- **Modular Design**: Separate Lua scripts for each concern

### Implementation Phases

1. **Foundation**: Environment detection, scanning, data structures
2. **Tagging**: Auto-suggestions with manual override
3. **Management**: CMS interface with full CRUD operations
4. **Generation**: Drawer widget creation and deployment

## Credits

**Concept & Specification**: Rafael
**Implementation**: Claude (Anthropic)
**Font**: JetBrains Mono (Apache 2.0)
**Platform**: Rainmeter

## License

MIT License - See LICENSE file for details

JetBrains Mono font is licensed under Apache 2.0 (see `@Resources/Fonts/License.txt`)

## Version

**Icycles v1.0.0**
Initial Release - 2024

---

*"Freezing Desktop chaos into crystalline structure"*
