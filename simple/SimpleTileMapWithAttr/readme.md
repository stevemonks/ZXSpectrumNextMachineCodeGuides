# Simple Tile Map With Attr Example

## Overview
This is a bare bones example of how to set up and populate a hardware tilemap and draw tiles using attribute bytes to select multiple colour palettes on the ZX Spectrum Next.

The code is broken down into the following files;
* simpletilemapwithattr.s - this is the assembler file that configures the hardware tilemap, loads the palettes and draws some tiles into the tilemap.
* multi_palette_tiles_rg.s - pattern definitions for a small set of identical tiles, but each filled with a different palette index, from 1 on the left to 14 on the right
* multi_palette_tiles_rg_palette.s - 9 bit palette data file containing a 16 colour palette with a red and green sweep of colours.
* multi_palette_tiles_by_palette.s - 9 bit palette data file containing a 16 colour palette with a blue and yellow sweep of colours.
* multi_palette_tiles_mw_palette.s - 9 bit palette data file containing a 16 colour palette with a magenta and white sweep of colours.
* multi_palette_tiles_lgc_palette.s - 9 bit palette data file containing a 16 colour palette with a light green and cyan sweep of colours.
* zeus.asm - zeus specific file which loads the other files into their required locations in memory.

A tilemap is an area of memory that represents a display in terms of a grid of 8x8 pixel "tiles". The tilemap on the ZX Spectrum Next can be either 40x32 or 80x32 tiles in size and each tile can be represented by a single byte (literally an index into a tile set), or a pair of bytes (the aforementioned index and an extra attribute byte to set various features of the tile such as mirroring, rotation and which palette it uses).

The tiles themselves are each 8x8 squares of pixels. Each pixel can be one of 16 colours, meaning that a tile is represented in memory as 32 bytes, with each group of 4 bytes representing a row of the tile going from top to bottom. Each byte of a row represents a pair of pixels, with bits 7-4 representing the left hand pixel and bits 3-0 representing the right hand pixel of the pair.

The hardware sets certain restrictions on where in memory the tilemap and it tile patterns can be placed. Basically, they must reside in the block of memory from 16384 ($4000) to 32767 ($7fff) and both the tilemap and the tile patterns must start at an address which lies on a 256 byte boundary (e.g. $6000, $6100, $6200 and so on).

This is achieved in this example by "org" statements in zeus.asm. First, an org $6000 is used to define where the tilemap begins. $6000 is a little way after the standard Spectrum display (which begins at $4000 and runs to $5aff including the attributes) and also beyond the "system variables" used by the operating system, so it's a safe place to put the tilemap.

Space is reserved for the tilemap in zeus.asm by the use of a "ds 1280*2" directive. This reserves 2,560 bytes of memory for the tilemap, this value is arrived at by multiplying the width of the tilemap by the height by two bytes per tile (an index and an attribute byte), i.e. 40 x 32 x 32 = 2560.

The tile patterns are placed immediately after the tilemap in memory by an "include" directive in zeus.asm. As the tilemap begins on an address that is a multiple of 256 and its length is a multiple of 256 (2560 = 256 x 10), this satisfies the hardware requirement that the tile patterns must also begin at an address which is a multiple of 256.

The main advantage of a tilemap is that it is compact. With two bytes representing an 8x8 character, its palette selection and orientation flags, it doesn't take up a lot of space in memory and represents an easy load for the CPU if it needs to redraw all or part of it.

The main disadvantage of a tilemap is that each tile can only be positioned at locations which are divisible by eight in both the horizontal and vertical direction, meaning smooth, pixel perfect movement around the screen is not easy to achieve (the entire screen can be moved a pixel at a time, but that's another matter), so tiles are not ideal for representing elements that need to move around smoothly such as player characters. Sprites are a much better match for that sort of application, but tilemaps are an excellent way to build a backdrop.

## Code Breakdown
As usual, simpletilemapattr.s begins by defining the addresses of any registers that the example uses. This is done more for clarity than anything else, in a real project it would be sensible to define ALL of the Next registers in a single include file, rather than dotting them around the code.

Next, again, similar to the other examples, it fills the ULA attribute memory with a set of colour bars, this is just to provide a backdrop for the tile map.

The next section of the code configures the tilemap hardware.

It starts by writing to the TILEMAP_CONTROL_PORT ($6b), this sets the format of the tilemap and enables it. Options here include a 40 or 80 column tilemap and the optional inclusion of an additional attribute byte per tile which can control rotation, mirroring and palette selection for each tile. As this is a slightly more advanced example, we're just going to use a 40 column tilemap and two bytes per tile, one for the tile index and one for the tile attributes.

As we're going to set tile attributes on a per tile basis, we don't need to set TILEMAP_ATTR_PORT ($6c) as it will be ignored by the hardware which will get each tiles attribute byte from the tilemap itself. The attribute byte sets a number of important attributes, its bits are assigned as follows;

* (7-4) - the palette set to choose (0 to 15).
* (3) - x mirror, when set the tile will be flipped horizontally.
* (2) - y mirror, when set the tile will be flipped vertically.
* (1) - rotates the tile 90 degrees clockwise. Can be used with the mirror bits to achieve rotations of 0,90,180 and 270 degrees.
* (0) - ULA over tilemap. For this example we'll be setting this to zero.

The code then sets TILEMAP_TRANSPARENCY_PORT ($4c). This port controls which palette index is transparent. The tiles used in this sample have been authored with palette index zero expected to be transparent (if you look at multi_palette_tiles_rg.s, you'll see the first tile defined is all zeros, this is an "empty" tiles, we fill the tilemap with 0 to select this tile and show the colour bars underneath).

Next, we set TILEMAP_ULA_CONTROL_PORT ($68) to 0. This sets up a number of attributes determining how the tilemap interacts with the ULA display. Setting it zero is sufficient for this example and most general cases.

The next thing we set is the tilemap "clipping". You may have noticed, the standard ULA screen is 32x24 characters in size, not 40x32 and definitely not 80x32. Clipping defines how much of the tilemap is visible at any one time. Without clipping, the tilemap would extend 4 tiles to the left, right, top and bottom of the standard Spectrum display. This may be desirable, effectively giving you a 40x32 tile/character display with less border, but for this example we want to constrain the tilemap so it exactly matches the dimensions of the standard Spectrum screen.

The clipping register actually expects four pieces of information, the left, right, top and bottom of the clip area, so we need to write to it four times in that order.

As the clipping range horizontally would be 0 to 319 (256 + "32 left" + "32 right" - 1 because coordinates start at 0, not 1) and this doesn't fit in an 8 bit register, the hardware expects the horizontal clipping values to be halved. So, the left clip, instead of being 32 (remember, four 8 pixel tiles to the left of the screen = 4 x 8 = 32), is 16 (32/2) and the right clip, instead of being 287 (32+255) is set to 143 (287/2, rounded down).

The clipping registers in the Y axis work at pixel resolution with 0 being 32 pixels above the start standard Spectrum display. The standard Spectrum display is 192 pixels high, so we need to set the top clip to 32 and the bottom clip to 32+192-1 = 223 (-1 otherwise the clip would be set one pixel below the bottom of the standard Spectrum display).

Next we tell the hardware where in memory the tilemap is located. This is set via TILEMAP_BASE_ADDR_PORT ($6e) and its simply the address of the tilemap buffer (taken from the label "tile_map_data" declared in zeus.asm) divided by 256.

Similarly we tell the hardware where in memory the patterns for the tile set begin. This is set via TILEMAP_PATTERN_BASE_ADDR_PORT ($6f) and is the address of where the tilemap patterns were included in zeus.asm (taken from the label on the line above the include statement), divided by 256.

Finally, we set up the scroll registers. For this example, we're going to scroll the tilemap horizontally to the left. As the tilemap is 320 pixels wide (40x8) and we can scroll by a single pixel, two 8 bit registers are required to hold the full value. These are TILEMAP_OFFSET_X_LSB_PORT ($30) which takes the low 8 bits of the scroll value and TILEMAP_OFFSET_X_MSB_PORT ($29) which takes the high bit required to represent values up to 319.

The tilemap can be thought of as a 320x256 pixel display. Scrolling it changes which pixel the display begins from in the top left corner of the screen. A horizontal scroll value of 8 will move the display 8 pixels to the left and the 8 pixel strip that has now been cut off on the left hand side appears at the right hand side. In other words, the tilemap "wraps". It will always be 320 pixels wide, but the horizontal scroll registers define where along a 320 pixel row the display will begin and anything to the left of that point gets appended to the right hand side of the remainder of the row.

As the unscrolled tilemap effectively begins 4 tiles to the left of the visible area we've defined with the clipping, we need to scroll it right by 4 tiles in order to see them. Because positive scroll values move the display left, we effectively want to scroll -32 pixels. However the horizontal scroll registers doesn't like negative values, so instead, given the 320 pixel scroll range, we can calculate this as 320-32 (288), so we're effectively achieving a -32 pixel scroll by scrolling to the right by 288 pixels, given the wrapping behaviour outlined above this will give us the effect we need.

Similarly the vertical scrolling is set via TILEMAP_OFFSET_Y_PORT ($31). Vertical scrolling follows the same rules as horizontal scrolling, but the range is only between 0 and 255, which fits neatly into a single register. A vertical scroll value of 8 will move the display up by 8 pixels, but we want to reveal the 4 rows of tiles that are hidden by the clip, so we effectively want to set a scroll value of -32. Because the range is 0 to 255, we can either set this to 256-32 = 224, or actually just -32, the unsigned 8 bit representation of which is 224.

With the tilemap hardware all set up, we now need to load the palette. This is done in exactly the same way as for the Simple Tile Map example, by first setting the PALETTE_CONTROL_PORT ($43) to a value which selects the start of the tilemap palette and then writing the four sets of 16 colour palettes sequentially to the port.

## Displaying Some Tiles
With all of the hardware configured it's time to fill the tilemap with some tiles. For a simple example we're going to be using the tile set defined by coloured_tiles.s. This was created using NextDes (available online [here](http://www.stevemonks.com/nextdes/)) and the source data for use with the editor can be found in the src-assets folder.

This tile set is visually laid out as follows;

<!--![the tile patterns included in this sample](tiles-overview.JPG)-->

![the tile patterns included in this sample](https://github.com/stevemonks/ZXSpectrumNextMachineCodeGuides/blob/master/simple/SimpleTileMapWithAttr/tiles-overview.JPG?raw=true)

As you can see, it's a grid of 8x2 tiles contained a set of different coloured "faces" and these are numbered from 0 on the top left, to 7 on the top right and 8 on the bottom left through to 15 on the bottom right.

The top left tile (index 0) is the "empty" tile and this is what we will fill the tilemap with to clear it.

Tiles 1 to 7 contain identical 8x8 "face" shapes, but each is filled with a different colour index from the current palette. These range from 2 on the left, to 8 on the right.

Tiles 8 to 14 are similar, but these are filled with colour index 9 on the left through to 15 on the right.

The colour palettes are laid out as follows;

The red/green palette has index 0 as its transparent colour, 1 as black, 2-8 as a red sweep and 9 to 15 as a green sweep.
![](https://github.com/stevemonks/ZXSpectrumNextMachineCodeGuides/blob/master/simple/SimpleTileMapWithAttr/palette-rg.JPG?raw=true)
<!--![the tile patterns included in this sample](palette-rg.JPG)-->

The blue/yellow palette has index 0 as its transparent colour, 1 as black, 2-8 as a blue sweep and 9 to 15 as a yellow sweep.
![](https://github.com/stevemonks/ZXSpectrumNextMachineCodeGuides/blob/master/simple/SimpleTileMapWithAttr/palette-by.JPG?raw=true)
<!--![the tile patterns included in this sample](palette-by.JPG)-->

The magenta/white palette has index 0 as its transparent colour, 1 as black, 2-8 as a magenta sweep and 9 to 15 as a white sweep.
![](https://github.com/stevemonks/ZXSpectrumNextMachineCodeGuides/blob/master/simple/SimpleTileMapWithAttr/palette-mw.JPG?raw=true)
<!--![the tile patterns included in this sample](palette-mw.JPG)-->

The light green/cyan palette has index 0 as its transparent colour, 1 as black, 2-8 as a light green sweep and 9 to 15 as a cyan sweep.
![](https://github.com/stevemonks/ZXSpectrumNextMachineCodeGuides/blob/master/simple/SimpleTileMapWithAttr/palette-lgc.JPG?raw=true)
<!--![the tile patterns included in this sample](palette-lgc.JPG)-->

The first thing the code does is fill the tilemap with zeros, in other word it fills it with empty tiles and zero attributes to ensure the colour bars on the standard Spectrum display can be seen through it.

Next it draws rectangles where each row contains tiles 14 down to 1. Each rectangle is drawn with a different attribute byte, selecting one of the four palettes we've set up and a set of flags to control rotation.

To avoid repeating the square drawing code for every colour, it's been moved into a function called DrawTileRectWithAttr that can be reused for each rectangle.

When called, DrawTileRectWithAttr expects the following registers to be set;
* a - the attribute byte to use for every tile drawn
* hl - the address in the tilemap where the top left corner of the rectangle will be.

The width and height are hard coded into the function.

Note that the first call sets hl to tile_map_data, meaning this rectangle will be drawn right at the top left corner of the tile map.

The 2nd rectangle is drawn 16 tiles to the right of this location by adding 16x2 to the address (its multiplied by two as each tile is represented by two bytes).

The 3rd rectangle is drawn 12 rows down from the top of the tilemap. As the tilemap is 40 tiles wide and each tile is represented by two bytes, this is achieved by adding 40x12x2 to the start of the tile map data (tile_map_data).

Each call passes in a different attribute value in the 'a' register. This value controls which palette the tiles will use by setting bits 4 to 7, effectively;

```palette index * 16```

It also controls the rotation and mirroring bits for the tiles to be filled. These are set by adding the predefined ROT_? labels to the palette index value, these are defined as follows;

* ROT_NONE:   equ 0         ; no x-mirror, no y-mirror, no rotation
* ROT_90:     equ %0010     ; no x-mirror, no y-mirror, rotation
* ROT_180:    equ %1100     ; no x-mirror, y-mirror, no rotation
* ROT_270:    equ %1110     ; x-mirror, y-mirror, rotation


## Scrolling Around
Having drawn four coloured rectangles into the tile map and displayed them we are now going to scroll it around under keyboard control. This is described in the code as '"game" loop'.

This takes a set of scroll declared in the memory locations ScrollPosX and ScrollPosY and passes their address (stored in the ix register) to a function called ControllScrollKeyboard which modifies the scroll values if the relevant keys have been pressed. This function is adapted from the one in PlayerSprite2.s. The only added complication here is that the horizontal scroll value has an unusual range of 0 to 319, so code has been added to make the value wrap when this range is exceeded. So, if the value reaches 320 it will jump to 0 and if the value reaches -1 it will jump to 319.

Next the scroll values are applied to hardware registers to change the displayed scroll position.

The other point of interest is the "halt" instruction at the start of "MainLoop".

The halt instruction stops the Z80 CPU from executing instructions and it will remain in this state until it is either reset or an "interrupt" occurs. 

An "interrupt" is a signal the CPU receives from the hardware, these can be used in different ways on different platforms, but in the ZX Spectrum an "interrupt" occurred every 1/50th of a second at the start of the "vertical blank".

On the CRT TV's at the time, this was essentially a signal to tell the TV to begin "refreshing" the screen again, but from a computer games perspective, it is also a good time to start updating the display as it signals a brief period of time where changes to the screen display will not cause unwanted artifacts such as flicker.

Because the "halt" instruction freezes the CPU until one of these "vertical blank interrupts" occurs, it provides a convenient way to synchronise our screen update (in this case, modifying the horizontals scroll register) with the display. If we didn't do this, then we could be updating the scroll register while the TV is part way through "refreshing" the screen, this will cause the display to "tear" at this point which we don't really want.

The other use for inserting a "halt" instruction at the start of the main loop is to moderate the speed at which we're scrolling the screen. If we didn't do this it would scroll at a ridiculously fast rate, several whole screens worth per frame. Try commenting the "halt" instruction out and rebuilding to see what effect it has.

## DrawTileRectWithAttr
The DrawTileRectWithAttr function provides an example of how you might fill a rectangular area of the tilemap with specific tiles and attributes. There are a number of ways this could be done, even using DMA for speed, but this is a reasonably simple example of how you might draw a rectangle of tiles using the CPU.

