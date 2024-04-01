
.pushseg
.zeropage

bVT_CURSOR_X = $80
bVT_CURSOR_Y = $81
wVT_CURSOR_SCR = $82
bVT_VSYNC_NR = $84
bVT_CURSOR_VISIBLE = $85            ; 0 = disabled+off, 1 = not visible, but enabled; 2 = yes, enabled.
bVT_CURSOR_LAST_VSYNC = $86

wTMP = $A0

.popseg
