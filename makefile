# Makefile for Lala Prologue — Open Watcom 16-bit DOS
# Target: 16-bit real-mode DOS, large memory model
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

# Compiler flags: 8086 (-0), large model (-ml), no stack check (-s)
WCL     = wcl
CFLAGS  = -0 -ml -s -zq -w4

# Output — 8.3 filename required for DOSBox mount
TARGET  = bin\lala.exe

# Source files (order matters for wcl — first .c becomes the target name)
SRCS    = src\lala.c src\engine.c src\fmengine.c src\directqb.c

# --- Targets ---
all: $(TARGET)

$(TARGET): $(SRCS)
	$(WCL) $(CFLAGS) -fe=$(TARGET) $(SRCS)

# --- Clean ---
clean:
	del *.obj
	del *.err
	del *.map
	del src\*.obj
	del src\*.err
	del $(TARGET)
