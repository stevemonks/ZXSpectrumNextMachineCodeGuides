# Simple Tile Map Example

## Overview
This is a bare bones example of how to set up and populate a hardware tilemap on the ZX Spectrum Next.

The code is broken down into the following files;
* simpletilemap.s - this is the assembler file that configures the hardware tilemap, loads the palette and draws some tiles into the tilemap.
* coloured_tiles.s - pattern definitions for a small tile set.
* coloured_tiles_palette.s - the palette data for the tile set.
* zeus.asm - zeus specific file which loads the other files into their required locations in memory.

A tilemap is an area of memory that represents a display in terms of a grid of 8x8 pixel "tiles". The tilemap on the ZX Spectrum Next can be either 40x32 or 80x32 tiles in size and each tile can be represented by a single byte (literally an index into a tile set), or a pair of bytes (the aforementioned index and an extra attribute byte to set various features of the tile such as mirroring, rotation and which palette it uses).

The tiles themselves are each 8x8 squares of pixels. Each pixel can be one of 16 colours, meaning that a tile is represented in memory as 32 bytes, with each group of 4 bytes representing a row of the tile going from top to bottom. Each byte of a row represents a pair of pixels, with bits 7-4 representing the left hand pixel and bits 3-0 representing the right hand pixel of the pair.

The hardware sets certain restrictions on where in memory the tilemap and it tile patterns can be placed. Basically, they must reside in the block of memory from 16384 ($4000) to 32767 ($7fff) and both the tilemap and the tile patterns must start at an address which lies on a 256 byte boundary (e.g. $6000, $6100, $6200 and so on).

This is achieved in this example by "org" statements in zeus.asm. First, an org $6000 is used to define where the tilemap begins. $6000 is a little way after the standard Spectrum display (which begins at $4000 and runs to $5aff including the attributes) and also beyond the "system variables" used by the operating system, so it's a safe place to put the tilemap.

Space is reserved for the tilemap in zeus.asm by the use of a "ds 1280" directive. This reserves 1,280 bytes of memory for the tilemap, this value is arrived at by multiplying the width of the tilemap by the height, i.e. 40 x 32 = 1280.

The tile patterns are placed immediately after the tilemap in memory by an "include" directive in zeus.asm. As the tilemap begins on an address that is a multiple of 256 and its length is a multiple of 256 (1280 = 256 x 5), this satisfies the hardware requirement that the tile patterns must also begin at an address which is a multiple of 256.

The main advantage of a tilemap is that it is compact. With a single byte representing an 8x8 character, it doesn't take up a lot of space in memory and represents an easy load for the CPU if it needs to redraw all or part of it.

The main disadvantage of a tilemap is that each tile can only be positioned at locations which are divisible by eight in both the horizontal and vertical direction, meaning smooth, pixel perfect movement around the screen is not easy to achieve (the entire screen can be moved a pixel at a time, but that's another matter), so tiles are not ideal for representing elements that need to move around smoothly such as player characters. Sprites are a much better match for that sort of application, but tilemaps are an excellent way to build a backdrop.

## Code Breakdown
As usual, simpletilemap.s begins by defining the addresses of any registers that the example uses. This is done more for clarity than anything else, in a real project it would be sensible to define ALL of the Next registers in a single include file, rather than dotting them around the code.

Next, again, similar to the other examples, it fills the ULA attribute memory with a set of colour bars, this is just to provide a backdrop for the tile map.

The next section of the code configures the tilemap hardware.

It starts by writing to the TILEMAP_CONTROL_PORT ($6b), this sets the format of the tilemap and enables it. Options here include a 40 or 80 column tilemap and the optional inclusion of an additional attribute byte per tile which can control rotation, mirroring and palette selection for each tile. As this is a simple example, we're just going to stick with a 40 column tilemap and a single byte per tile.

Next, the code sets TILEMAP_ATTR_PORT ($6c) to 0. When the tilemap hardware is configured to just use one byte per tile, then all tiles get their attribute byte from here. This port sets a number of important attributes, but by setting it to zero, the main things we are setting up are;

* no mirroring
* no rotation
* use tile palette 0

After this it sets TILEMAP_TRANSPARENCY_PORT ($4c). This port controls which palette index is transparent. The tiles used in this sample have been authored with palette index zero expected to be transparent (if you look at coloured_tiles.s, you'll see the first tile defined is all zeros, this is an "empty" tiles, we fill the tilemap with 0 to select this tile and show the colour bars underneath).

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

With the tilemap hardware all set up, we now need to load the palette. This is done in exactly the same way as for sprites, except we set the PALETTE_CONTROL_PORT ($43) to a value which selects the start of the tilemap palette.

## Displaying Some Tiles
With all of the hardware configured it's time to fill the tilemap with some tiles. For a simple example we're going to be using the tile set defined by coloured_tiles.s. This was created using NextDes (available online [here](http://www.stevemonks.com/nextdes/) and the source data for use with the editor can be found in the src-assets folder.

This tile set is visually laid out as follows;

![the tile patterns included in this sample](tiles-overview.jpg)

As you can see, it's a grid of 4x4 tiles contained a set of different coloured "gems" and some shapes that could be used to make a simple maze. The tiles are numbered 0,1,2,3 for the top row, 4,5,6,7 for the 2nd row and so on.

So tile 0 is the empty tile, tile 1 is the green tile, tile 2 is the blue tile, 3 and 4 are the yellow and red tiles respectively.

The first thing the code does is fill the tilemap with zeros, in other word it fills it with empty tiles to ensure the colour bars on the standard Spectrum display can be seen.

Next it draws squares using the coloured gems. Each square is 8x8 tiles and uses a different gem, 1,2,3 or 4 for green, blue, yellow and red.

To avoid repeating the square drawing code for every colour, it's been moved into a function called DrawTileRect that can be reused for each coloured cube.

When called, DrawTileRect expects the following registers to be set;
* a - the index of the tile to fill the rectangle with
* hl - the address in the tilemap where the top left corner of the rectangle will be.
* b - the height of the rectangle - in tiles
* c - the width of the rectangle - in tiles

Note that the first call sets hl to tile_map_data, meaning this rectangle will be drawn right at the top left corner of the tile map.

The blue rectangle is drawn 10 tiles to the right of this location by adding 10 to the address.

The yellow rectangle is drawn 10 rows down from the top of the tilemap. As the tilemap is 40 bytes wide, this is achieved by adding 40 x 10 to the start of the tile map data (tile_map_data).

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

## DrawTileRect
The DrawTileRect function provides an example of how you might fill a rectangular area of the tilemap with a specific tile. There are a number of ways this could be done, even using DMA for speed, but this is a reasonably simple example of how you might draw a rectangle of tiles using the CPU.

