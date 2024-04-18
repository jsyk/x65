
.pushseg
.zeropage

bVT_CURSOR_X = $80
bVT_CURSOR_Y = $81
wVT_CURSOR_SCR = $82
bVT_VSYNC_NR = $84
bVT_CURSOR_VISIBLE = $85            ; 0 = disabled+off, 1 = not visible, but enabled; 2 = yes, enabled.
bVT_CURSOR_LAST_VSYNC = $86

bKBD_NEXT_ASCII = $87
bKBD_FLAGS = $88
 KBG_FLAG__SHIFT    = %10000000
 KBG_FLAG__NONASCI  = %01000000
 KBG_FLAG__CTRL     = %00100000
 KBG_FLAG__ALT      = %00010000
 KBG_FLAG__CAPSL    = %00000100
 KBG_FLAG__NUML     = %00000010
 KBG_FLAG__SCROLL   = %00000001

bKBD_LAST_KEYCODE = $89

wTMP = $A0

.popseg
