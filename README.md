# ICYCLES - Desktop Organization CMS for Rainmeter

*Crystallizing Desktop chaos into structured drawers*

---

## Overview

Icycles is a Rainmeter-based Content Management System for organizing Desktop shortcuts into categorized, expandable drawer widgets. It provides a visual CMS interface for tagging items and automatically generates hover-activated drawers for your Desktop.

**Current Status:** Scanner complete, UI in development.

---

## Key Features

- ✅ **Desktop Scanning** - Automatically catalogs shortcuts, URLs, executables, and folders (Unicode support)
- ✅ **UTF-16LE Encoding** - Proper handling of international filenames
- 🚧 **Multi-Category Tagging** - Assign items to multiple categories (tags, not exclusive folders)
- 🚧 **Visual CMS Interface** - Tag pills, filters, batch operations
- 📋 **Drawer Widgets** - Collapsible, hover-activated category drawers (planned)
- 📋 **Keeper Flag** - Preserve items even if Desktop file is deleted (planned)

---

## Installation

### Prerequisites

1. **Rainmeter** (version 4.5 or higher)
   - Download from: https://www.rainmeter.net/

2. **JetBrains Mono Font** (Required for proper typography)
   - Download from: https://www.jetbrains.com/lp/mono/
   - Install all weights (Regular, Medium, Bold, ExtraBold)
   - See `@Resources/Fonts/Readme.txt` for installation instructions

### Setup

1. Copy the `Icycles` folder to your Rainmeter Skins directory:
   ```
   C:\Users\[YourName]\Documents\Rainmeter\Skins\Icycles\
   ```

2. Install JetBrains Mono font (system-wide installation required)

3. Refresh Rainmeter and load the Icycles skin

4. Click ⚙ icon to open CMS interface

5. Click **"REBUILD LIST"** to scan your Desktop

---

## Usage

### First-Time Setup

1. **Scan Desktop**  
   Click "REBUILD LIST" in Desktop Elements section. Scanner catalogs all shortcuts, URLs, and files.

2. **Create Categories** (Coming Soon)  
   Use Quick Setup to create default categories (Development, Creative, Gaming, Tools, Office).

3. **Tag Items** (Coming Soon)  
   Click item pill → select category → click ➕ to assign. Items can belong to multiple categories.

4. **Generate Drawers** (Planned)  
   Click "GENERATE DRAWERS" to create hover-activated category widgets.

---

## Current Limitations

- **No UI yet** - Scanner works, but CMS interface is under construction
- **Manual category creation** - No GUI for adding categories (use Quick Setup script)
- **No drawer generation** - Output widgets not implemented yet

See `ARCHITECTURE.md` for implementation roadmap.

---

## File Structure

```
Icycles/
├─ Icycles.ini                    # Main CMS interface (WIP)
├─ README.md                      # This file
├─ ARCHITECTURE.md                # Technical documentation
├─ @Resources/
│  ├─ Variables.inc               # Design tokens
│  ├─ Styling.ini                 # Reusable meter styles
│  ├─ Scanner.lua                 # Desktop scanning (✅ WORKING)
│  ├─ UserDesktopInfo.lua         # Environment detection (✅ WORKING)
│  ├─ Configurator.lua            # Category/item management (WIP)
│  ├─ Generator.lua               # Drawer widget generation (TODO)
│  ├─ QuickSetup.lua              # Default category creator
│  └─ Fonts/
├─ Data/
│  ├─ ListedDesktopItems.ldb      # Scanned Desktop items (✅ populated by Scanner)
│  ├─ ItemRegistry.ldb            # Canonical item database (TODO)
│  ├─ Categories.ldb              # Master category index (deprecated)
│  └─ UserDesktopData.ldb         # Environment cache
├─ CatData/                       # Per-category data files
│  └─ Customisation/              # User-uploaded icons
├─ Drawers/                       # Generated drawer widgets (empty)
├─ Backups/                       # Automatic backups
└─ Logs/
   └─ errors.log                  # Error logging
```

---

## Customization

### Design Tokens

Edit `@Resources/Variables.inc` to customize:
- Colors (background, text, accent)
- Typography (font sizes, weights)
- Spacing (layout dimensions, padding)
- Layout (column widths, pill sizes)

### Category Colors

Categories use a 20-color daltonist-friendly palette (algorithmically chosen for maximum contrast). Colors defined in category metadata.

---

## Troubleshooting

### Desktop items not appearing

1. Check `Data/UserDesktopData.ldb` for correct Desktop path
2. Click "REBUILD LIST" to re-scan
3. Check `Logs/errors.log` for errors

### Font not displaying correctly

1. Confirm JetBrains Mono is installed system-wide (not just for current user)
2. Restart Rainmeter after font installation
3. Verify font name in Windows Font Settings matches "JetBrains Mono"

### Garbled filenames

Scanner outputs UTF-16LE - if you see garbled text, file encoding may be wrong. Check `ListedDesktopItems.ldb` with a hex editor (should start with `FF FE` BOM).

### Lua errors

All errors logged to `Logs/errors.log`. Check for:
- File permission issues
- Missing data files (run Scanner first)
- Corrupted .ldb files (restore from Backups/)

---

## Design Philosophy

**Minimalist** - Barely-there backgrounds (4-6% opacity), restrained colors, no decorative elements.

**Neobrutalist** - Bold typography as structural element, type creates hierarchy.

**Technical** - Monospace font, precise spacing (golden ratio), structured layout.

**Functional** - Every element serves a purpose, no unnecessary features.

**User-Controlled** - Manual override for all automation, transparent data files.

---

## Development

### Architecture

See `ARCHITECTURE.md` for:
- Data structures (ItemRegistry, CatData formats)
- Scanner flow (CMD → UTF-16LE conversion)
- UI design (pills, controls, collapsible sections)
- Implementation phases
- Design decisions log

### Contributing

This is Rafael's personal project. For technical questions, see ARCHITECTURE.md.

---

## Credits

**Concept & Specification:** Rafael  
**Implementation:** Claude (Anthropic)  
**Font:** JetBrains Mono (Apache 2.0)  
**Platform:** Rainmeter

---

## License

MIT License - See LICENSE file for details.

JetBrains Mono font is licensed under Apache 2.0 (see `@Resources/Fonts/License.txt`).

---

## Version

**Icycles v0.2.0** - Scanner Complete, UI In Progress  
*Last Updated: 2024-11-20*

---

*"Freezing Desktop chaos into crystalline structure"*
