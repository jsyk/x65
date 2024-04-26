.P816

.include "common.inc"
.include "vt.inc"

.import _kbd_put_char, _kbd_deadkey, _kbd_switch_xlock, _kbd_put_special, _kbd_put_unused
.export kbd_map

.rodata

.proc kbd_map
; IBM Key No.	Set 1 Make/Break	Set 2 Make/Break	Set 3 Make/Break	Base Case	 Upper Case
; 0 no key
    .word _kbd_put_unused
    .byte 0, 0
; 1	 29/A9	 0E/F0 0E	 0E/F0 0E	 `	 ~
    .word _kbd_put_char
    .byte '`', '~'
; 2	 02/82	 16/F0 16	 16/F0 16	1	 !
    .word _kbd_put_char
    .byte '1', '!'
; 3	 03/83	 1E/F0 1E	 1E/F0 1E	2	 @
    .word _kbd_put_char
    .byte '2', '@'
; 4	 04/84	 26/F0 26	 26/F0 26	3	 #
    .word _kbd_put_char
    .byte '3', '#'
; 5	 05/85	 25/F0 25	 25/F0 25	4	 $
    .word _kbd_put_char
    .byte '4', '$'
; 6	 06/86	 2E/F0 2E	 2E/F0 2E	5	 %
    .word _kbd_put_char
    .byte '5', '%'
; 7	 07/87	 36/F0 36	 36/F0 36	6	 ^
    .word _kbd_put_char
    .byte '6', '^'
; 8	 08/88	 3D/F0 3D	 3D/F0 3D	7	 &
    .word _kbd_put_char
    .byte '7', '&'
; 9	 09/89	 3E/F0 3E	 3E/F0 3E	8	 *
    .word _kbd_put_char
    .byte '8', '*'
; 10	 0A/8A	 46/F0 46	 46/F0 46	9	 (
    .word _kbd_put_char
    .byte '9', '('
; 11	 0B/8B	 45/F0 45	 45/F0 45	0	 )
    .word _kbd_put_char
    .byte '0', ')'
; 12	 0C/8C	 4E/F0 4E	 4E/F0 4E	 -	 _
    .word _kbd_put_char
    .byte '-', '_'
; 13	 0D/8D	 55/F0 55	 55/F0 55	 =	 +
    .word _kbd_put_char
    .byte '=', '+'
; 14	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 15	 0E/8E	 66/F0 66	 66/F0 66	 Backspace	
    .word _kbd_put_char
    .byte 8, 8
; 16	 0F/8F	 0D/F0 0D	 0D/F0 0D	 Tab	 
    .word _kbd_put_char
    .byte 9, 9
; 17	 10/90	 15/F0 15	 15/F0 15	 q	 Q
    .word _kbd_put_char
    .byte 'q', 'Q'
; 18	 11/91	 1D/F0 1D	 1D/F0 1D	 w	 W
    .word _kbd_put_char
    .byte 'w', 'W'
; 19	 12/92	 24/F0 24	 24/F0 24	 e	 E
    .word _kbd_put_char
    .byte 'e', 'E'
; 20	 13/93	 2D/F0 2D	 2D/F0 2D	 r	 R
    .word _kbd_put_char
    .byte 'r', 'R'
; 21	 14/94	 2C/F0 2C	 2C/F0 2C	 t	 T
    .word _kbd_put_char
    .byte 't', 'T'
; 22	 15/95	 35/F0 35	 35/F0 35	 y	 Y
    .word _kbd_put_char
    .byte 'y', 'Y'
; 23	 16/96	 3C/F0 3C	 3C/F0 3C	 u	 U
    .word _kbd_put_char
    .byte 'u', 'U'
; 24	 17/97	 43/F0 43	 43/F0 43	 i	 I
    .word _kbd_put_char
    .byte 'i', 'I'
; 25	 18/98	 44/F0 44	 44/F0 44	 o	 O
    .word _kbd_put_char
    .byte 'o', 'O'
; 26	 19/99	 4D/F0 4D	 4D/F0 4D	 p	 P
    .word _kbd_put_char
    .byte 'p', 'P'
; 27	 1A/9A	 54/F0 54	 54/F0 54	 [	 {
    .word _kbd_put_char
    .byte '[', '{'
; 28	 1B/9B	 5B/F0 5B	 5B/F0 5B	 ]	 }
    .word _kbd_put_char
    .byte ']', '}'
; 29	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 30	 3A/BA	 58/F0 58	 58/F0 58	 Caps Lock	 
    .word _kbd_switch_xlock
    .byte KBG_FLAG__CAPSL, 0
; 31	 1E/9E	 1C/F0 1C	 1C/F0 1C	 a	 A
    .word _kbd_put_char
    .byte 'a', 'A'
; 32	 1F/9F	 1B/F0 1B	 1B/F0 1B	 s	 S
    .word _kbd_put_char
    .byte 's', 'S'
; 33	 20/A0	 23/F0 23	 23/F0 23	 d	 D
    .word _kbd_put_char
    .byte 'd', 'D'
; 34	 21/A1	 2B/F0 2B	 2B/F0 2B	 f	 F
    .word _kbd_put_char
    .byte 'f', 'F'
; 35	 22/A2	 34/F0 34	 34/F0 34	 g	 G
    .word _kbd_put_char
    .byte 'g', 'G'
; 36	 23/A3	 33/F0 33	 33/F0 33	 h	 H
    .word _kbd_put_char
    .byte 'h', 'H'
; 37	 24/A4	 3B/F0 3B	 3B/F0 3B	 j	 J
    .word _kbd_put_char
    .byte 'j', 'J'
; 38	 25/A5	 42/F0 42	 42/F0 42	 k	 K
    .word _kbd_put_char
    .byte 'k', 'K'
; 39	 26/A6	 4B/F0 4B	 4B/F0 4B	 l	 L
    .word _kbd_put_char
    .byte 'l', 'L'
; 40	 27/A7	 4C/F0 4C	 4C/F0 4C	 ;	 :
    .word _kbd_put_char
    .byte ';', ':'
; 41	 28/A8	 52/F0 52	 52/F0 52	 '	 "
    .word _kbd_put_char
    .byte '\', '"'
; 42	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 43	 1C/9C	 5A/F0 5A	 5A/F0 5A	 Enter	 Enter
    .word _kbd_put_char
    .byte 13, 10
; 44	 2A/AA	 12/F0 12	 12/F0 12	 Left Shift	 
    .word _kbd_deadkey
    .byte KBG_FLAG__SHIFT, (~KBG_FLAG__SHIFT) & $ff
; 45	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 46	 2C/AC	 1A/F0 1A	 1A/F0 1A	 z	 Z
    .word _kbd_put_char
    .byte 'z', 'Z'
; 47	 2D/AD	 22/F0 22	 22/F0 22	 x	 X
    .word _kbd_put_char
    .byte 'x', 'X'
; 48	 2E/AE	 21/F0 21	 21/F0 21	 c	 C
    .word _kbd_put_char
    .byte 'c', 'C'
; 49	 2F/AF	 2A/F0 2A	 2A/F0 2A	 v	 V
    .word _kbd_put_char
    .byte 'v', 'V'
; 50	 30/B0	 32/F0 32	 32/F0 32	 b	 B
    .word _kbd_put_char
    .byte 'b', 'B'
; 51	 31/B1	 31/F0 31	 31/F0 31	 n	 N
    .word _kbd_put_char
    .byte 'n', 'N'
; 52	 32/B2	 3A/F0 3A	 3A/F0 3A	 m	 M
    .word _kbd_put_char
    .byte 'm', 'M'
; 53	 33/B3	 41/F0 41	 41/F0 41	 ,	 <
    .word _kbd_put_char
    .byte ',', '<'
; 54	 34/B4	 49/F0 49	 49/F0 49	 .	 >
    .word _kbd_put_char
    .byte '.', '>'
; 55	 35/B5	 4A/F0 4A	 4A/F0 4A	 /	 ?
    .word _kbd_put_char
    .byte '/', '?'
; 56	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 57	 36/B6	 59/F0 59	 59/F0 59	 Right Shift	 
    .word _kbd_deadkey
    .byte KBG_FLAG__SHIFT, (~KBG_FLAG__SHIFT) & $ff
; 58	 1D/9D	 14/F0 14	 11/F0 11	 Left Ctrl	 
    .word _kbd_deadkey
    .byte KBG_FLAG__CTRL, (~KBG_FLAG__CTRL) & $ff
; 59	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 60	 38/B8	 11/F0 11	 19/F0 19	 Left Alt	 
    .word _kbd_deadkey
    .byte KBG_FLAG__ALT, (~KBG_FLAG__ALT) & $ff
; 61	 39/B9	 29/F0 29	 29/F0 29	 Spacebar	 
    .word _kbd_put_char
    .byte ' ', ' '
; 62	 E0 38/E0 B8	 E0 11/E0 F0 11	 39/F0 39	 Right Alt	 
    .word _kbd_deadkey
    .byte KBG_FLAG__ALT, (~KBG_FLAG__ALT) & $ff
; 63	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 64	 E0 1D/E0 9D	 E0 14/E0 F0 14	 58/F0 58	 Right Ctrl	 
    .word _kbd_deadkey
    .byte KBG_FLAG__CTRL, (~KBG_FLAG__CTRL) & $ff
; 65	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 66	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 67	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 68	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 69	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 70	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 71	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 72	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 73	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 74	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 75	 E0 52/E0 D2 (base)	 E0 70/E0 F0 70 (base)	 67/F0 67	 Insert	 
    .word _kbd_put_special
    .byte 0, 0
; 76	 E0 4B/E0 CB (base)	 E0 71/E0 F0 71 (base)	 64/F0 64	 Delete	 
    .word _kbd_put_special
    .byte 0, 0
; 77	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 78	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 79	 E0 4B/E0 CB (base)	 E0 6B/E0 F0 6B (base)	 61/F0 61	 Left Arrow	 
    .word _kbd_put_special
    .byte 0, 0
; 80	 E0 47/E0 C7 (base)	 E0 6C/E0 F0 6C (base)	 6E/F0 6E	 Home	 
    .word _kbd_put_special
    .byte 0, 0
; 81	 E0 4F/E0 CF (base)	 E0 69/E0 F0 69 (base)	 65/F0 65	 End	 
    .word _kbd_put_special
    .byte 0, 0
; 82	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 83	 E0 48/E0 C8 (base)	 E0 75/E0 F0 75 (base)	 63/F0 63	 Up Arrow	 
    .word _kbd_put_special
    .byte 0, 0
; 84	 E0 50/E0 D0 (base)	 E0 72/E0 F0 72 (base)	 60/F0 60	 Down Arrow	 
    .word _kbd_put_special
    .byte 0, 0
; 85	 E0 49/E0 C9 (base)	 E0 7D/E0 F0 7D (base)	 6F/F0 6F	 Page Up	 
    .word _kbd_put_special
    .byte 0, 0
; 86	 E0 51/E0 D1 (base)	 E0 7A/E0 F0 7A (base)	 6D/F0 6D	 Page Down	 
    .word _kbd_put_special
    .byte 0, 0
; 87	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 88	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 89	 E0 4D/E0 CD (base)	 E0 74/E0 F0 74 (base)	 6A/F0 6A	 Right Arrow	 
    .word _kbd_put_special
    .byte 0, 0
; 90	 45/C5	 77/F0 77	 76/F0 76	 Num Lock	 
    .word _kbd_switch_xlock
    .byte KBG_FLAG__NUML, 0
; 91	 47/C7	 6C/F0 6C	 6C/F0 6C	 Keypad 7	 
    .word _kbd_put_char
    .byte '7', '7'
; 92	 4B/CB	 6B/F0 6B	 6B/F0 6B	 Keypad 4	 
    .word _kbd_put_char
    .byte '4', '4'
; 93	 4F/CF	 69/F0 69	 69/F0 69	 Keypad 1	 
    .word _kbd_put_char
    .byte '1', '1'
; 94	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 95	 E0 35/E0 B5 (base)	 E0 4A/E0 F0 4A (base)	 77/F0 77	 Keypad /	 
    .word _kbd_put_char
    .byte '/', '/'
; 96	 48/C8	 75/F0 75	 75/F0 75	 Keypad 8	 
    .word _kbd_put_char
    .byte '8', '8'
; 97	 4C/CC	 73/F0 73	 73/F0 73	 Keypad 5	 
    .word _kbd_put_char
    .byte '5', '5'
; 98	 50/D0	 72/F0 72	 72/F0 72	 Keypad 2	 
    .word _kbd_put_char
    .byte '2', '2'
; 99	 52/D2	 70/F0 70	 70/F0 70	 Keypad 0	 
    .word _kbd_put_char
    .byte '0', '0'
; 100	 37/B7	 7C/F0 7C	 7E/F0 7E	 Keypad *	 
    .word _kbd_put_char
    .byte '*', '*'
; 101	 49/C9	 7D/F0 7D	 7D/F0 7D	 Keypad 9	 
    .word _kbd_put_char
    .byte '9', '9'
; 102	 4D/CD	 74/F0 74	 74/F0 74	 Keypad 6	 
    .word _kbd_put_char
    .byte '6', '6'
; 103	 51/D1	 7A/F0 7A	 7A/F0 7A	 Keypad 3	 
    .word _kbd_put_char
    .byte '3', '3'
; 104	 53/D3	 71/F0 71	 71/F0 71	 Keypad .	 
    .word _kbd_put_char
    .byte '.', '.'
; 105	 4A/CA	 7B/F0 7B	 84/F0 84	 Keypad -	 
    .word _kbd_put_char
    .byte '-', '-'
; 106	 4E/CE	 79/F0 79	 7C/F0 7C	 Keypad +	 
    .word _kbd_put_char
    .byte '+', '+'
; 107	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 108	 E0 1C/E0 9C	 E0 5A/E0 F0 5A	 79/F0 79	 Keypad Enter	 
    .word _kbd_put_char
    .byte 10, 10
; 109	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 110	 01/81	 76/F0 76	 08/F0 08	 Esc	 
    .word _kbd_put_special
    .byte 0, 0
; 111	 not used
    .word _kbd_put_unused
    .byte 0, 0
; 112	 3B/BB	 05/F0 05	 07/F0 07	 F1	 
    .word _kbd_put_special
    .byte 0, 0
; 113	 3C/BC	 06/F0 06	 0F/F0 0F	 F2	 
    .word _kbd_put_special
    .byte 0, 0
; 114	 3D/BD	 04/F0 04	 17/F0 17	 F3	 
    .word _kbd_put_special
    .byte 0, 0
; 115	 3E/BE	 0C/F0 0C	 1F/F0 1F	 F4	 
    .word _kbd_put_special
    .byte 0, 0
; 116	 3F/BF	 03/F0 03	 27/F0 27	 F5	 
    .word _kbd_put_special
    .byte 0, 0
; 117	 40/C0	 0B/F0 0B	 2F/F0 2F	 F6	 
    .word _kbd_put_special
    .byte 0, 0
; 118	 41/C1	 83/F0 83	 37/F0 37	 F7	 
    .word _kbd_put_special
    .byte 0, 0
; 119	 42/C2	 0A/F0 0A	 3F/F0 3F	 F8	 
    .word _kbd_put_special
    .byte 0, 0
; 120	 43/C3	 01/F0 01	 47/F0 47	 F9	 
    .word _kbd_put_special
    .byte 0, 0
; 121	 44/C4	 09/F0 09	 4F/F0 4F	 F10	 
    .word _kbd_put_special
    .byte 0, 0
; 122	 57/D7	 78/F0 78	 56/F0 56	 F11	 
    .word _kbd_put_special
    .byte 0, 0
; 123	 58/D8	 07/F0 07	 5E/F0 5E	 F12	 
    .word _kbd_put_special
    .byte 0, 0
; 124	 E0 2A E0 37/E0 B7 E0 AA	 E0 12 E0 7C/E0 F0 7C E0 F0 12	 57/F0 57	 Print Screen	 
    .word _kbd_put_special
    .byte 0, 0
; 125	 46/C6	 7E/F0 7E	 5F/F0 5F	 Scroll Lock	 
    .word _kbd_switch_xlock
    .byte KBG_FLAG__SCROLL, 0
; 126	 E1 1D 45/E1 9D C5	 E1 14 77 E1/F0 14 F0 77	 62/F0 62	 Pause Break	 
    .word _kbd_put_special
    .byte 0, 0
; 127 29 or 42*	 2B/AB	 5D/F0 5D	 5C/F0 5C or 53/F0 53	 \	 |
    .word _kbd_put_char
    .byte '\', '|'

.endproc
