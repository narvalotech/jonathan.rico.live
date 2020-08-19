---
title: "Modular wristwatch system"
type: "page"
cover: "img/mw_exploded.png"
useRelativeCover : "true"
---

Summary
-------

Designed as a follow-up to [Ledwatch](../ledwatch).

A modular (smart)watch system. The concept is splitting modern smartwatch functions into modular PCBs with mezzanine connectors, to be able to try different sensor/mcu/display combos without having to redesign everything from scratch each time.  

A minimum system would be 2 boards: core board + display board. This is what I have begun designing, with a nRF52-based core board and a serial RGB led display board.

But one can imagine for example:
1. Top board: Color LCD + driver, NFC transceiver + coil
2. Middle board: ARM SoC w/ BLE & secure coprocessor, IMU
3. Bottom board: Heart-rate sensor, wireless charger
4. LiPo battery

Or for a lower-power system:
1. Top board: Segment LCD
2. Middle board: MSP430 MCU, low power accelerometer
3. Lithium coin cell

The one I'm building right now:
1. Top: 24 RGB leds, 5V DCDC, ambient light sensor
2. Middle: ARM SoC w/ BLE, 3V DCDC, accelerometer, Motor driver, LiPo charger
3. LiPo battery

Specs
-----

Components:
- BLE SoC: [nRF52832](https://www.nordicsemi.com/Products/Low-power-short-range-wireless/nRF52832)
- Leds: [APA102-2020](https://www.adafruit.com/product/3341)
- Accelerometer: [LIS3DH](https://www.st.com/en/mems-and-sensors/lis3dh.html)
- Charger: [bq21040](http://www.ti.com/product/BQ21040)
- Core DCDC: [TPS62743](http://www.ti.com/product/TPS62743) (mistake in schematic it seems)
- LED DCDC: [TPS610997](http://www.ti.com/product/TPS61099) (5V fixed)
- 3-5V level shifter: [NTB0102GF,115](https://www.digikey.com/product-detail/en/nxp-usa-inc/NTB0102GF115/568-5570-1-ND/2531048)
- Tactile switches: [EVQ-P3401P](https://www3.panasonic.biz/ac/e/search_num/index.jsp?c=detail&part_no=EVQP3401P)
- Pusbuttons: [Casio F-91W](https://en.wikipedia.org/wiki/Casio_F-91W) (using just the buttons & mini o-rings)
- Ambient light sensor: [APDS-9306-065](https://www.broadcom.com/products/optical-sensors/ambient-light-photo-sensors/apds-9306-065)
- Motor driver: [LC898302AXA](https://www.onsemi.com/products/power-management/motor-drivers/motor-drivers-brushless/lc898302axa)
- Load switches: [FPF1203LUCX](https://www.onsemi.com/products/power-management/load-switches/fpf1203l)
- Battery: 125mAh LiPo
- Connector female: [513380274](https://www.digikey.com/product-detail/en/molex/0513380274/WM3353CT-ND/2405694)
- Connector male: [559090274](https://www.digikey.com/product-detail/en/molex/0559090274/WM3450CT-ND/2405679)
- Devkit & programmer/debugger: [nRF52-DK](https://www.nordicsemi.com/Software-and-Tools/Development-Kits/nRF52-DK)

Project files: (as-is, pcbs have not been built yet)

Core board:  
[Schematic PDF](pdf/rgbw.pdf)  
[Kicad project ZIP](zip/rgbw.zip)

Display board:  
[Schematic PDF](pdf/fp-rgb.pdf)  
[Kicad project ZIP](zip/fp-rgb.zip)  

Charger/Debug board:  
[Schematic PDF](pdf/chg-rgb.pdf)  
[Kicad project ZIP](zip/chg-rgb.zip)  

Board assembly:
[Exploded view PDF](pdf/assembly.pdf)


Mechanical
----------

The body was designed in SolidWorks, I tried another workflow for designing the PCB & enclosure:

1. Sketch out watch shape in [Inkscape](https://inkscape.org/)
2. Create rough component shape to test fit
3. Refine watch shape
4. Design schematic in KiCad
5. Import watch shape in KiCad layout
6. Create rough 3d models for all components
7. Place & route PCB, checking 3d view for conflicts
8. Export STEP file from KiCad layout
9. Export DXF from inkscape
10. Import STEP of the two PCBs in SolidWorks
11. Test fit of PCBs
12. Import DXF in SolidWorks, sketch a rough watch body volume
13. Align PCB models with watch body
14. Finish designing watch body

Again, printed at shapeways, and the models seems to fit quite nicely, I guess we'll see for sure when I actually build it entirely !

[Assembly STEP file](3d/watch_assembled.step)

{{< view3d model=3d/watch_assembled.glb >}}


Having the (rough) 3d models of the component was very helpful for two reasons: 
- I could verify that my footprints were correct
- It really helped for component placement.

To be able to quickly generate package models, I finally bit the bullet, learned a bit of [OpenSCAD](https://www.openscad.org/), and created basic shapes (BGA, DFN, QFN) that could be easily reprogrammed. You can download the small library I made for this project here:  
[OpenSCAD source files ZIP](3d/openscad.zip)


Core board
----------

![Core Kicad layout](img/mw_core_layout.png)

![Core pcb front](img/mw_core_front.jpg)

![Core pcb back](img/mw_core_back.jpg)

![Core pcb left](img/mw_core_side_left.jpg)

![Core pcb right](img/mw_core_side_right.jpg)

![Core pcb top](img/mw_core_side_top.jpg)

Display board
-------------

![Display KiCad layout](img/mw_disp_layout.png)

display & core connected:

![Display & Core pcbs](img/mw_pcbs.png)

Debug board
-----------

![Debug Kicad layout](img/mw_charger_layout.png)

![Debug pcb](img/mw_charger.png)


Project status (2020-01-06)
---------------------------

Due to my recent job change & relocation to Norway, I had to give away some essential tools before leaving (limited space in suitcases), and as such, this project is now on pause.

I will try to get a headstart on programming though, as it doesn't require any hardware except the dev kit which I already have.

Status update (2020-08-19)
--------------------------

A few updates:

A few months ago, my manager at Nordic offered to have the PCBs fabbed, and
that I buy the components & do the assembly.

BUT I had to do an express redesign to use the
[nRF52840](https://www.nordicsemi.com/Products/Low-power-short-range-wireless/nRF52840
) instead of the 832 (trickier because of the IC package).

I received half of the PCBs a month ago (if I remember correctly), ordered the
stencils from [Elecrow](https://www.elecrow.com/pcbstencil.html), and the
components from DigiKey.

I still haven't received the main board (with the MCU) yet, but I can still
start programming using the [nRF52 DK](https://www.nordicsemi.com/Software-and-Tools/Development-Kits/nRF52840-DK
).

Front panel
-----------

I managed to do the reflow soldering, on the ceramic cooktop (again), but had a
few issues with the smallest component (U1: 1x1.2mm, 6pads), so I had to rework
it a bit. I still haven't figured out where to buy 98% alcohol in norway yet, so
the boards were not cleaned properly.

![Applying the stencil](img/photos/fp_stencil.jpg)

![Front-panel PCB front](img/photos/fp_front.jpg)

![Front-panel PCB back](img/photos/fp_back.jpg)

Debug board
-----------

I found out that the charge and debug board had the connector mirrored, but
since no IOs were explicitely labeled and there are no components on this board
I could just connect the front-panel upside-down, like you can see in the videos.

This board is pretty handy, I can program/debug the RGB display without having to
solder wires directly to the board.

![Charge/debug PCB](img/photos/chg_front.jpg)

Videos
------

A quick test of the RGB animation: this just cycles through the colors, pretty
rapidly so I can sport if there are SPI communication issues.
***
{{< videogif location="vid/rgb_animation.mp4" >}}

A test of the bcd display code ported from the ledwatch project. I tried to slow
down the video on the animation this time.
***
{{< videogif location="vid/counter_animation.mp4" >}}

A test with the Nordic SDK BLE Blinky example, where I can trigger the animation
via the Blinky android app.
***
{{< videogif location="vid/nordic_blinky.mp4" >}}

Current project status
----------------------

Things left to do:
- Finish cradle 3d model
- Print cradle
- Reflow the main board
- Test & bring-up the core board
- Program the watch
  - Bare-bones functions w/ softdevice
  - Proper zephyr app w/ Nordic Connect SDK
- Make a small android companion app
