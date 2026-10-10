# Makefile for Lala Prologue — Open Watcom 16-bit DOS
# Target: 16-bit real-mode DOS, medium memory model (like QB 4.5)
#
# Usage (from cmd.exe):
#   set WATCOM=C:\Openwatcom
#   set PATH=C:\Openwatcom\binnt;%PATH%
#   set INCLUDE=C:\Openwatcom\h
#   wmake
#
# Usage (from bash/MSYS):
#   export WATCOM=C:/Openwatcom
#   export PATH="/c/Openwatcom/binnt:$PATH"
#   export INCLUDE="C:/Openwatcom/h"
#   wmake
#
# Output goes to bin\ folder (mounted as C: in DOSBox, see run.bat/lala.conf).

# Compiler: 8086 (-0), MEDIUM model (-mm, like QB 4.5 and DQB's own
# .MODEL medium: far code, single near DGROUP, SS == DS), no stack check.
# -k16384: explicit program stack. Replaces QB's `SETMEM(-513)` (LALA.BAS):
# QB managed a pre-allocated far heap + fixed stack, Watcom pulls far
# memory from DOS on demand (_fmalloc = INT 21h), so the only static
# memory to pin is the stack (PORTING.md §2).
WCL     = wcl
WASM    = wasm
# -fpi87: real 8087 opcodes, no FP-emulation helper (WASM default
# injects an FIDRQQ external that drags in 12KB of emu87; the game
# runs on a real or emulated FPU and never calls DQBangle anyway)
WASMFLAGS = -fpi87
WLIB    = wlib
CFLAGS  = -0 -mm -s -zq -w4 -k16384
# Test/harness sources live in tests\ (project rule), headers in src\ —
# quoted includes in tests\*.c need src\ on the include path.
TESTINCL = -i=src

# Output — 8.3 filenames required for DOSBox mount
TARGET  = bin\lala.exe
TESTBIN = bin\test.exe
MUSPLAY = bin\musplay.exe
PALPROBE = bin\palprobe.exe

# Source files (order matters for wcl — first .c becomes the target name).
# The game ships lean (no test code — the image has a ~64K ceiling,
# see PORTING.md); the harness builds as a separate test binary from
# tests\ (testmain.c + engtest.c) and musplay.c likewise lives there.
GAMESRCS = src\lala.c src\engine.c src\fmengine.c src\directqb.c
TESTSRCS = tests\testmain.c tests\engtest.c src\engine.c src\fmengine.c src\directqb.c
MUSPLAYSRCS = tests\musplay.c src\fmengine.c src\engine.c src\directqb.c
PALPROBESRCS = tests\palprobe.c src\directqb.c

# DirectQB library, recompiled from dqb\*.ASM with WASM (see PORTING.md).
# Excluded: dqb\CALLS.OBJ (BC-compiled BASIC, no ASM source) and the
# superseded dqb\3D.ASM / dqb\3D3.ASM variants (only THREED.ASM is used).
DQBLIB  = dqb\dqb.lib
DQBASM  = dqb\MAIN.ASM dqb\DRAW.ASM dqb\SPRITE.ASM dqb\IMAGE.ASM dqb\FONT.ASM dqb\BLENDING.ASM dqb\PALETTE.ASM dqb\BIT.ASM dqb\DISK.ASM dqb\DATAFILE.ASM dqb\SOUND.ASM dqb\KEYBOARD.ASM dqb\MOUSE.ASM dqb\JOYSTICK.ASM dqb\THREED.ASM

# --- Targets ---
all: $(TARGET) $(TESTBIN) $(MUSPLAY)

$(TARGET): $(GAMESRCS) $(DQBLIB)
	$(WCL) $(CFLAGS) -fe=$(TARGET) $(GAMESRCS) $(DQBLIB)

$(TESTBIN): $(TESTSRCS) $(DQBLIB)
	$(WCL) $(CFLAGS) $(TESTINCL) -fe=$(TESTBIN) $(TESTSRCS) $(DQBLIB)

$(MUSPLAY): $(MUSPLAYSRCS) $(DQBLIB)
	$(WCL) $(CFLAGS) $(TESTINCL) -fe=$(MUSPLAY) $(MUSPLAYSRCS) $(DQBLIB)

# One-off debug probe for the empty-palette investigation (NOT part of
# the default build): isolated loadImage call shapes vs buffer fill.
palprobe: $(PALPROBESRCS) $(DQBLIB)
	$(WCL) $(CFLAGS) $(TESTINCL) -fe=$(PALPROBE) $(PALPROBESRCS) $(DQBLIB)

# Rebuild the DirectQB import library from sources.
dqblib: $(DQBLIB)

$(DQBLIB): $(DQBASM)
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\MAIN.obj dqb\MAIN.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\DRAW.obj dqb\DRAW.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\SPRITE.obj dqb\SPRITE.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\IMAGE.obj dqb\IMAGE.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\FONT.obj dqb\FONT.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\BLENDING.obj dqb\BLENDING.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\PALETTE.obj dqb\PALETTE.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\BIT.obj dqb\BIT.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\DISK.obj dqb\DISK.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\DATAFILE.obj dqb\DATAFILE.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\SOUND.obj dqb\SOUND.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\KEYBOARD.obj dqb\KEYBOARD.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\MOUSE.obj dqb\MOUSE.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\JOYSTICK.obj dqb\JOYSTICK.ASM
	$(WASM) $(WASMFLAGS) -fo=dqb\obj\THREED.obj dqb\THREED.ASM
	$(WLIB) -n -q $(DQBLIB) +dqb\obj\MAIN.obj +dqb\obj\DRAW.obj +dqb\obj\SPRITE.obj +dqb\obj\IMAGE.obj +dqb\obj\FONT.obj +dqb\obj\BLENDING.obj +dqb\obj\PALETTE.obj +dqb\obj\BIT.obj +dqb\obj\DISK.obj +dqb\obj\DATAFILE.obj +dqb\obj\SOUND.obj +dqb\obj\KEYBOARD.obj +dqb\obj\MOUSE.obj +dqb\obj\JOYSTICK.obj +dqb\obj\THREED.obj

# --- Clean ---
clean:
	del *.obj
	del *.err
	del *.map
	del src\*.obj
	del src\*.err
	del tests\*.obj
	del tests\*.err
	del dqb\obj\*.obj
	del $(TARGET)
	del $(TESTBIN)
	del $(MUSPLAY)
