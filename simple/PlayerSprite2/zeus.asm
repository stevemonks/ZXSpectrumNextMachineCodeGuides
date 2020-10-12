; This is a basic template file for writing Spectrum code.
; It configures the assembler and jumps to the code.

AppFilename             equ "playersprite"              ; What we're called (for file generation)

AppFirst                equ $8000                       ; First byte of code (uncontended memory)

                        zeusemulate "Next","RAW"        ; Set the model


; Start planting code here. (When generating a tape file we start saving from here)

                        org AppFirst                    ; Start of application

AppEntry                nop

                        include "playersprite2.s"

                        jp AppEntry


; Stop planting code after this. (When generating a tape file we save bytes below here)
AppLast                 equ *-1                         ; The last used byte's address

; Generate some useful debugging commands

                        profile AppFirst,AppLast-AppFirst+1     ; Enable profiling for all the code

; Setup the emulation registers, so Zeus can emulate this code correctly

Zeus_PC                 equ AppEntry                            ; Tell the emulator where to start
Zeus_SP                 equ $FF40                               ; Tell the emulator where to put the stack

; These generate some output files


; Output an snx file. This is essentially a SNA or Snapshot file, a standard Spectrum archive format.
; Attempting to load one of these on a ZX Spectrum Next disables all of the enhanced Next hardware
; to aid with compatibility, but using the SNX extension enables the Next's advanced hardware.
                        output_sna AppFilename+".snx"
