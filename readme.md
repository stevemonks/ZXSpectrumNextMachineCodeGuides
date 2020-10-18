# Next Machine Code Guides
A collection of short examples, each showing how to use a particular feature of the ZX Spectrum Next's hardware from Z80 assembler. The emphasis is on keeping the examples short, simple and hopefully easy to understand. All code is heavily annotated to explain what's going on at any point.

## Examples
The examples are subdivided by their complexity, currently there are only "simple" examples illustrating how to use specific hardware features in a simplistic way.

### Simple
* SimpleSprite - this simply display a single 4 bit hardware sprite.
* PlayerSprite - this expands on SimpleSprite by adding a simple two frame animation to the sprite and keyboard controls to move it around the screen.
* PlayerSprite2 - this expands on PlayerSprite by using 16 bit coordinates for the x and y position of the sprite. This allows the sprite to move all the way across the visible portion of the screen. This example also uses a 9 bit RRRGGGBBB palette, unlike the previous examples which used an 8 bit RRRGGGBB palette.
* SimpleTileMap - this example shows how to set up a 32x24 tilemap display including how to write tiles into it and how to scroll it around under keyboard control.
* SimpleTileMapWithAttr - this example shows how to set up a 32x24 tilemap display simultaneously using multiple palettes and controlling the mirror and rotation features of different tiles, it also includes how to write individual tiles into the map and how to scroll it around under keyboard control.

### Advanced
* RLECompression - this is a complete end to end example illustrating a method of how to take a tile map created in the free TileEd tool, convert it into a RLE compressed format that can be built into a Next executable then unpack and display it on the Next.

## Structure
Each example may be found in its own folder within the parent folder.

The examples are split into two types of file, .asm and .s. The .asm file is used to configure various settings for the Zeus assembler and can largely be ignored. The .s files contain actual code. More complex examples such as SimpleTileMap may include multiple .s files in order to logically group different parts of the codebase or pull external data into the assembled executable.

## Building The Examples
All examples have been built using the command line version Simon Brattel's excellent Zeus assembler (zcl.exe). They've been tested in CSpect and also on real hardware.

To build an example, open a console window, navigate to the folder of the particular example and type;

```
zcl zeus.asm
```
You will need to have ```zcl.exe``` available in you path.

Prebuilt .snx files are also included for convenience. An .snx file is basically a renamed standard .sna file. For compatibility reasons, if the Next tries to load a .sna file it will disable its enhanced hardware, so features such as sprites wont work. .snx files allow the Next to identify that it is loading a Next specific file and therefore keep the enhanced features enabled.

At the time of writing, zcl.exe can't output the preferred .nex files, however zcltest.exe can and the examples here will generate a .nex file if built with this, or later variants of zeus.

## Additional Tooling
Assets used in these examples have been created with my online sprite and tile editor NextDes. Assets created with other tooling will work with these examples, but if you wish to edit the source assets you'll need to use NextDes, which can be found [here](http://www.stevemonks.com/nextdes/).

Assets can be loaded into NextDes by dropping the source xml file onto the editor grid. Graphics can be created in 16 colours with 8 or 9 bit palettes and currently the editor supports editing images up to 128x128 pixels which can be exported as either sets of 16x16 pixel sprites, 8x8 pixel tiles or 8x8 pixel tiles grouped into 4x4 grids. Multiple frames can be added to make it easy to create and cut up large animated characters.

The editor exports in asm format (.s files) which has the advantage that labels containing frame names are generated, making it easier to identify and link in frames within a sprite or tileset.