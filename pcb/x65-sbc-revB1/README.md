X65-SBC-rev.B1
================

X65 Single-Board Computer, schematic & PCB revision B1.

![3D render view of the X65-SBC rev.A1 (Kicad)](pictures/sbc-render-1.png)

![Schematic (PDF)](x65-sbc-revB1.pdf)

![Interactive BOM](bom/ibom.html)


!! WORK IN PROGRESS !!
=======================

I restarted changes to revB1 on 04/2024 with the following goals:
* fix remaining issues (SDC power, ESD, see below)
* optimize for machine assembly


To-Be-Done changes from rev.A1 to rev.B1
-------------------------------------------
* add power switch for SDC +3.3V, add digital lines disconnect
    - probably AP2191D ?
* change ESD protection
* change decoupling caps
* move speaker connector
* ...??? see pdf


Implemented changes from rev.A1 to rev.B1
-------------------------------------------
* change green LED resistors to 2k7 (although this depends on LED).
* Remove D504 (USB ESD): the SP0503 is not suitable!
* Add 5V and +3.3V pins to J601 internal mem.bus connector.
* Changed AURA FPGA footprint to the smaller EP pad (now the footprint is the same as VERA)
