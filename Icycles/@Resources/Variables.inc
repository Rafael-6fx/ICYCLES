[Variables]
; ========================================
; ICYCLES - Design Tokens
; ========================================
; Golden ratio derived spacing system
; Minimalist color palette with single accent
; JetBrains Mono typography hierarchy
; ========================================

; === TYPOGRAPHY ===
FontFamily=JetBrains Mono
HeaderSize=18
ItemSize=10
MetaSize=9
DrawerHeaderSize=64
LabelSize=12

; Font Weights
FontRegular=400
FontMedium=500
FontBold=700
FontExtraBold=800

; === COLORS ===
; Backgrounds (RGBA format: R,G,B,A where A is 0-255)
BgColor=20,20,22,12
DrawerBgColor=20,20,22,230
CMSBgColor=20,20,22,245
ModalOverlayColor=0,0,0,180

; Text Colors
TextColor=200,200,205,255
TextSecondary=160,160,165,200
TextMeta=120,120,125,180

; Accent Colors
AccentColor=180,180,190,255
AccentHighlight=200,200,210,255

; Interactive States
HighlightBg=40,40,45,200
HoverBg=35,35,40,180
SelectedBg=50,50,55,220
DisabledColor=80,80,85,150

; Borders & Dividers
BorderColor=60,60,65,150
DividerColor=50,50,55,100

; === SPACING (Golden Ratio) ===
BaseUnit=8
Spacing1=8
Spacing2=13
Spacing3=21
Spacing4=34
Spacing5=55

; === LAYOUT ===
; Drawer Widgets
DrawerWidth=280
DrawerIconSize=48
ItemHeight=40
ItemSpacing=8
DrawerPadding=16
DrawerTitleHeight=80

; CMS Interface
CMSWidth=1200
CMSHeight=700
CMSPadding=24
ColumnGap=24
ColumnAWidth=360
ColumnBWidth=280
ColumnCWidth=480

; UI Elements
PillHeight=30
PillPadding=12
PillSpacing=8
ButtonHeight=36
ButtonPadding=16
InputHeight=32

; Modal
ModalWidth=480
ModalPadding=24

; === ANIMATION ===
DrawerExpandDelay=200
HoverTransition=150
DebounceTime=500
AutoSaveInterval=5000

; === DATA PATHS ===
; These are relative to skin root
DataPath=#@#..\Data\
CatDataPath=#@#..\CatData\
DrawersPath=#@#..\Drawers\
BackupsPath=#@#..\Backups\
LogsPath=#@#..\Logs\
CustomisationPath=#@#..\CatData\Customisation\

; === PAGINATION ===
ItemsPerPage=50
MaxCategoriesVisible=10

; === VERSION ===
SchemaVersion=1.0.0
IcyclesVersion=1.0.0

; === SYSTEM ===
CharWidth=7
MonoCharWidth=7.2
