# Next Machine Code Guides
A collection of short examples, each showing how to use a particular feature of the ZX Spectrum Next's hardware from Z80 assembler. The emphasis is on keeping the examples short, simple and hopefully easy to understand. All code is heavily annotated to explain what's going on at any point.

## Examples
* SimpleSprite - this simply display a single 4 bit hardware sprite.
* PlayerSprite - this expands on SimpleSprite by adding a simple two frame animation to the sprite and keyboard controls to move it around the screen.
* PlayerSprite2 - this expands on PlayerSprite by using 16 bit coordinates for the x and y position of the sprite. This allows the sprite to move all the way across the visible portion of the screen. This example also uses a 9 bit RRRGGGBBB palette, unlike the previous examples which used an 8 bit RRRGGGBB palette.

## Structure
Each example may be found in its own folder within the asm folder.

The examples are split into two types of file, .asm and .s. The .asm file is used to configure various settings for the Zeuss assembler and can largely be ignored. The .s files contain actual code. If I add more complex examples in the future, then these may include multiple .s files in order to logically group different parts of the codebase.

## Building The Examples
All examples have been built using the command line version Simon Brattel's excellent Zeuss assembler (zcl.exe). They've been tested in CSpect and also on real hardware.

To build an example, open a console window, navigate to the folder of the particular example and type;

```
zcl zeuss.asm
```
You will need to have ```zcl.exe``` available in you path.

Prebuilt .snx files are also included for convenience. An .snx file is basically a renamed standard .sna file. For compatibility reasons, if the Next tries to load a .sna file it will disable its enhanced hardware, so features such as sprites wont work. .snx files allow the Next to identify that it is loading a Next specific file and therefore keep the enhanced features enabled.

At the time of writing, zcl.exe can't output the preferred .nex files, however zcltest.exe can, but it doesn't appear to generate runnable code if you attempt to build .snx files with it, so it shouldn't be used with the examples presented here.