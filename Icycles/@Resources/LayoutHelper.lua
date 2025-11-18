-- ========================================
-- LAYOUT HELPER
-- ========================================
-- Font-independent positioning system
-- Measures actual font rendering on Initialize()
-- Caches metrics in FontMetrics.ldb with datetime
-- ========================================

-- Global cache for font metrics
FontMetricsCache = nil

-- ========================================
-- INITIALIZE - Called on skin load
-- ========================================
function Initialize()
  print("LayoutHelper: Initializing font metrics system...")

  local skinPath = SKIN:GetVariable("CURRENTPATH")
  local metricsPath = skinPath .. "FontMetrics.ldb"
  local currentFont = SKIN:GetVariable("FontFamily") or "JetBrains Mono"

  -- Try to load existing metrics
  local existingMetrics = LoadFontMetrics(metricsPath)

  -- Check if we need to remeasure
  local needsRemeasure = false

  if not existingMetrics then
    print("LayoutHelper: No existing metrics found - measuring font...")
    needsRemeasure = true
  elseif existingMetrics.fontFamily ~= currentFont then
    print("LayoutHelper: Font changed from '" .. (existingMetrics.fontFamily or "unknown") ..
          "' to '" .. currentFont .. "' - remeasuring...")

    -- Backup old metrics with timestamp
    BackupFontMetrics(metricsPath, existingMetrics)
    needsRemeasure = true
  else
    print("LayoutHelper: Using cached metrics from " .. (existingMetrics.lastMeasured or "unknown date"))
    FontMetricsCache = existingMetrics
  end

  -- Measure and save if needed
  if needsRemeasure then
    FontMetricsCache = MeasureAllFonts(currentFont)
    SaveFontMetrics(metricsPath, FontMetricsCache)
  end

  print("LayoutHelper: Font metrics loaded for " .. currentFont)
end

-- ========================================
-- MEASURE ALL FONTS
-- ========================================
function MeasureAllFonts(fontFamily)
  print("LayoutHelper: Measuring font metrics for: " .. fontFamily)

  local metrics = {
    version = "1.0",
    fontFamily = fontFamily,
    lastMeasured = os.date("%Y-%m-%d %H:%M:%S"),
    sizes = {}
  }

  -- Font sizes to measure (from Variables.inc)
  local fontSizes = {9, 10, 12, 18}

  for _, fontSize in ipairs(fontSizes) do
    print("LayoutHelper: Measuring fontSize=" .. fontSize)

    -- Get meters for this font size
    local widthMeter = SKIN:GetMeter("MeterFontMetric_" .. fontSize .. "_Width")
    local descMeter = SKIN:GetMeter("MeterFontMetric_" .. fontSize .. "_Descenders")
    local ascMeter = SKIN:GetMeter("MeterFontMetric_" .. fontSize .. "_Ascenders")
    local heightMeter = SKIN:GetMeter("MeterFontMetric_" .. fontSize .. "_Height")

    if not widthMeter or not heightMeter then
      print("LayoutHelper: ERROR - Missing meters for fontSize=" .. fontSize)
      -- Fallback estimation
      metrics.sizes[fontSize] = {
        width_M = math.ceil(fontSize * 0.6),
        ascenders = math.ceil(fontSize * 0.8),
        descenders = math.ceil(fontSize * 0.2),
        totalHeight = math.ceil(fontSize * 1.5)
      }
    else
      -- Query actual rendered dimensions
      metrics.sizes[fontSize] = {
        width_M = widthMeter:GetW() or math.ceil(fontSize * 0.6),
        ascenders = ascMeter:GetH() or math.ceil(fontSize * 0.8),
        descenders = descMeter:GetH() or math.ceil(fontSize * 0.2),
        totalHeight = heightMeter:GetH() or math.ceil(fontSize * 1.5)
      }

      print("LayoutHelper:   - width_M=" .. metrics.sizes[fontSize].width_M .. "px")
      print("LayoutHelper:   - totalHeight=" .. metrics.sizes[fontSize].totalHeight .. "px")
    end
  end

  return metrics
end

-- ========================================
-- GET ACTUAL LINE HEIGHT (PUBLIC API)
-- ========================================
function GetActualLineHeight(fontSize)
  if not FontMetricsCache then
    print("LayoutHelper: WARNING - No font metrics cache, using fallback")
    return math.ceil(fontSize * 1.5)
  end

  local sizeMetrics = FontMetricsCache.sizes[fontSize]
  if not sizeMetrics then
    print("LayoutHelper: WARNING - No metrics for fontSize=" .. fontSize .. ", using fallback")
    return math.ceil(fontSize * 1.5)
  end

  return sizeMetrics.totalHeight
end

-- ========================================
-- GET CHARACTER WIDTH (PUBLIC API)
-- ========================================
function GetCharacterWidth(fontSize)
  if not FontMetricsCache then
    return math.ceil(fontSize * 0.6)
  end

  local sizeMetrics = FontMetricsCache.sizes[fontSize]
  if not sizeMetrics then
    return math.ceil(fontSize * 0.6)
  end

  return sizeMetrics.width_M
end

-- ========================================
-- CALCULATE CLICK INDEX (FONT-INDEPENDENT)
-- ========================================
function CalculateClickIndex(mouseY, listStartY, fontSize)
  local lineHeight = GetActualLineHeight(fontSize)
  local relativeY = mouseY - listStartY
  local index = math.floor(relativeY / lineHeight) + 1

  print("LayoutHelper: Click at Y=" .. mouseY .. ", listStartY=" .. listStartY ..
        ", lineHeight=" .. lineHeight .. " → index=" .. index)

  return index
end

-- ========================================
-- LOAD FONT METRICS
-- ========================================
function LoadFontMetrics(path)
  local success, result = pcall(dofile, path)
  if success and result then
    return result
  else
    return nil
  end
end

-- ========================================
-- SAVE FONT METRICS
-- ========================================
function SaveFontMetrics(path, metrics)
  local tempPath = path .. ".tmp"

  local success, err = pcall(function()
    local file = io.open(tempPath, "w")
    if not file then
      error("Cannot open file: " .. tempPath)
    end

    file:write("-- Font Metrics Cache\n")
    file:write("-- Generated: " .. metrics.lastMeasured .. "\n")
    file:write("-- Font: " .. metrics.fontFamily .. "\n\n")
    file:write("return {\n")
    file:write("  version = \"" .. metrics.version .. "\",\n")
    file:write("  fontFamily = \"" .. metrics.fontFamily .. "\",\n")
    file:write("  lastMeasured = \"" .. metrics.lastMeasured .. "\",\n")
    file:write("  sizes = {\n")

    for fontSize, sizeMetrics in pairs(metrics.sizes) do
      file:write("    [" .. fontSize .. "] = {\n")
      file:write("      width_M = " .. sizeMetrics.width_M .. ",\n")
      file:write("      ascenders = " .. sizeMetrics.ascenders .. ",\n")
      file:write("      descenders = " .. sizeMetrics.descenders .. ",\n")
      file:write("      totalHeight = " .. sizeMetrics.totalHeight .. "\n")
      file:write("    },\n")
    end

    file:write("  }\n")
    file:write("}\n")
    file:close()

    -- Atomic rename
    os.remove(path)
    os.rename(tempPath, path)

    print("LayoutHelper: Saved font metrics to " .. path)
  end)

  if not success then
    print("LayoutHelper: ERROR saving metrics - " .. tostring(err))
  end
end

-- ========================================
-- BACKUP FONT METRICS
-- ========================================
function BackupFontMetrics(path, metrics)
  if not metrics then return end

  -- Create timestamped backup filename
  local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
  local backupPath = path:gsub("%.ldb$", "") .. "_" .. timestamp .. ".ldb.bak"

  print("LayoutHelper: Backing up old metrics to " .. backupPath)

  -- Save to backup location
  SaveFontMetrics(backupPath, metrics)
end
