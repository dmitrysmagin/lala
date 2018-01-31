#!/bin/sh

CFLAGS="-std=c99 -g -Wall -Wextra -Wno-unused-parameter -Wno-unused-function `sdl-config --cflags`"
LDFLAGS="`sdl-config --libs` -lm"

gcc	src/engine.c src/fmengine.c src/lala.c src/directqb.c \
	-o lala $CFLAGS $LDFLAGS
