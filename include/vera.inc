.feature c_comments

;==============================================================================
/* A structure with the Video Enhanced Retro Adapter's external registers */
/* VERA registers */
VERA_ADDRESS_REG            = $9F20         ; Address for data ports (L)
VERA_ADDRESS_M_REG          = $9F21         ; Address for data ports (M)
VERA_ADDRESS_HI_REG         = $9F22         ; Address for data ports (H) 
VERA_DATA0_REG              = $9F23         ; Data port 0
VERA_DATA1_REG              = $9F24         ; Data port 1

VERA_CONTROL_REG            = $9F25         ; Control register

VERA_IRQ_ENABLE_REG         = $9F26         ; IEN (Interrupt enable bits)
VERA_IRQ_FLAGS_REG          = $9F27         ; ISR (Interrupt flags)
VERA_IRQ_RASTER_REG         = $9F28         ; IRQ raster line

; Visible when DCSEL flag = 0
VERA_VIDEO_REG              = $9F29         ; Video flags
VERA_HSCALE_REG             = $9F2A         ; Horizontal scale factor
VERA_VSCALE_REG             = $9F2B         ; Vertical scale factor
VERA_BORDER_COLOR_REG       = $9F2C         ; Border color (NTSC mode)

; Visible when DCSEL flag = 1
VERA_HSTART_REG             = $9F29         ; Horizontal start position
VERA_HSTOP_REG              = $9F2A         ; Horizontal stop position
VERA_VSTART_REG             = $9F2B         ; Vertical start position
VERA_VSTOP_REG              = $9F2C         ; Vertical stop position

; Visible when DCSEL flag = 2
VERA_FXCTRL_REG             = $9F29         ; FX control
VERA_FXTILEBASE_REG         = $9F2A         ; FX tile base
VERA_FXMAPBASE_REG          = $9F2B         ; FX map base
VERA_FXMULT_REG             = $9F2C         ; FX multiplier

; Visible when DCSEL flag = 3
VERA_FXXINCRL_REG           = $9F29         ; FX X increment low
VERA_FXXINCRH_REG           = $9F2A         ; FX X increment high
VERA_FXYINCRL_REG           = $9F2B         ; FX Y increment low
VERA_FXYINCRH_REG           = $9F2C         ; FX Y increment high

; Visible when DCSEL flag = 4
VERA_FXXPOSL_REG            = $9F29         ; FX X position low
VERA_FXXPOSH_REG            = $9F2A         ; FX X position high
VERA_FXYPOSL_REG            = $9F2B         ; FX Y position low
VERA_FXYPOSH_REG            = $9F2C         ; FX Y position high

; Visible when DCSEL flag = 5
VERA_FXXPOSS_REG            = $9F29         ; FX X position signed
VERA_FXYPOSS_REG            = $9F2A         ; FX Y position signed
VERA_FXPOLYFILLL_REG        = $9F2B         ; FX polygon fill low
VERA_FXPOLYFILLH_REG        = $9F2C         ; FX polygon fill high

; Visible when DCSEL flag = 6
VERA_FXCACHEL_REG           = $9F29         ; FX cache low
VERA_FXCACHEM_REG           = $9F2A         ; FX cache middle
VERA_FXCACHEH_REG           = $9F2B         ; FX cache high
VERA_FXCACHEU_REG           = $9F2C         ; FX cache upper

; Visible when DCSEL flag = 63
VERA_DCVER0_REG             = $9F29         ; DC version 0
VERA_DCVER1_REG             = $9F2A         ; DC version 1
VERA_DCVER2_REG             = $9F2B         ; DC version 2
VERA_DCVER3_REG             = $9F2C         ; DC version 3

VERA_LAYER0_CONFIG_REG      = $9F2D         ; Layer 0 configuration
VERA_LAYER0_MAPBASE_REG     = $9F2E         ; Layer 0 map data address
VERA_LAYER0_TILEBASE_REG    = $9F2F         ; Layer 0 tile address and geometry
VERA_LAYER0_HSCROLL_REG     = $9F30         ; Layer 0 smooth scroll horizontal offset
VERA_LAYER0_HSCROLL_H_REG   = $9F31         ; Layer 0 smooth scroll horizontal offset
VERA_LAYER0_VSCROLL_REG     = $9F32         ; Layer 0 smooth scroll vertical offset
VERA_LAYER0_VSCROLL_H_REG   = $9F33         ; Layer 0 smooth scroll vertical offset

VERA_LAYER1_CONFIG_REG      = $9F34         ; Layer 1 configuration
VERA_LAYER1_MAPBASE_REG     = $9F35         ; Layer 1 map data address
VERA_LAYER1_TILEBASE_REG    = $9F36         ; Layer 1 tile address and geometry
VERA_LAYER1_HSCROLL_REG     = $9F37         ; Layer 1 smooth scroll horizontal offset
VERA_LAYER1_HSCROLL_H_REG   = $9F38         ; Layer 1 smooth scroll horizontal offset
VERA_LAYER1_VSCROLL_REG     = $9F39         ; Layer 1 smooth scroll vertical offset
VERA_LAYER1_VSCROLL_H_REG   = $9F3A         ; Layer 1 smooth scroll vertical offset

VERA_AUDIO_CONTROL_REG      = $9F3B         ; Audio control
VERA_AUDIO_RATE_REG         = $9F3C         ; Audio sample rate
VERA_AUDIO_DATA_REG         = $9F3D         ; Audio PCM output queue

VERA_SPI_DATA_REG           = $9F3E         ; SPI data
VERA_SPI_CONTROL_REG        = $9F3F         ; SPI control



; Color defines
/*
#define COLOR_BLACK             0x00
#define COLOR_WHITE             0x01
#define COLOR_RED               0x02
#define COLOR_CYAN              0x03
#define COLOR_PURPLE            0x04
#define COLOR_GREEN             0x05
#define COLOR_BLUE              0x06
#define COLOR_YELLOW            0x07
#define COLOR_ORANGE            0x08
#define COLOR_BROWN             0x09
#define COLOR_PINK              0x0A
#define COLOR_LIGHTRED          COLOR_PINK
#define COLOR_GRAY1             0x0B
#define COLOR_GRAY2             0x0C
#define COLOR_LIGHTGREEN        0x0D
#define COLOR_LIGHTBLUE         0x0E
#define COLOR_GRAY3             0x0F
*/
COLOR_BLACK             = $00
COLOR_WHITE             = $01
COLOR_RED               = $02
COLOR_CYAN              = $03
COLOR_PURPLE            = $04
COLOR_GREEN             = $05
COLOR_BLUE              = $06
COLOR_YELLOW            = $07
COLOR_ORANGE            = $08
COLOR_BROWN             = $09
COLOR_PINK              = $0A
COLOR_LIGHTRED          = COLOR_PINK
COLOR_GRAY1             = $0B
COLOR_GRAY2             = $0C
COLOR_LIGHTGREEN        = $0D
COLOR_LIGHTBLUE         = $0E
COLOR_GRAY3             = $0F



