; ---------------------------------------------------------------------------
;
; DirectQB SPRITE HANDLING module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN EMShdl:WORD
EXTRN EMSseg:WORD
EXTRN EMSpage:WORD
EXTRN PutMode:WORD
EXTRN ClipX1:WORD
EXTRN ClipX2:WORD
EXTRN ClipY1:WORD
EXTRN ClipY2:WORD
EXTRN BaseLayer:WORD

EXTRN GetLayerSeg:FAR

.DATA
SinTable    DW 256,256,256,255,255,254,253,252,251,250,248,247,245,243,241,239,237,234,231,229,226,223,220,216,213,209,206,202,198,194,190,185
            DW 181,177,172,167,162,157,152,147,142,137,132,126,121,115,109,104,98,92,86,80,74,68,62,56,50,44,38,31,25,19,13,6
            DW 0,-6,-13,-19,-25,-31,-38,-44,-50,-56,-62,-68,-74,-80,-86,-92,-98,-104,-109,-115,-121,-126,-132,-137,-142,-147,-152,-157,-162,-167,-172,-177
            DW -181,-185,-190,-194,-198,-202,-206,-209,-213,-216,-220,-223,-226,-229,-231,-234,-237,-239,-241,-243,-245,-247,-248,-250,-251,-252,-253,-254,-255,-255,-256,-256
            DW -256,-256,-256,-255,-255,-254,-253,-252,-251,-250,-248,-247,-245,-243,-241,-239,-237,-234,-231,-229,-226,-223,-220,-216,-213,-209,-206,-202,-198,-194,-190,-185
            DW -181,-177,-172,-167,-162,-157,-152,-147,-142,-137,-132,-126,-121,-115,-109,-104,-98,-92,-86,-80,-74,-68,-62,-56,-50,-44,-38,-31,-25,-19,-13,-6
            DW 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115,121,126,132,137,142,147,152,157,162,167,172,177
            DW 181,185,190,194,198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243,245,247,248,250,251,252,253,254,255,255,256,256
ColMethod   DB  0               ; Collision detection method: 0=box, 1=pixel)

.CODE

; ---------------------------------------------------------------------------
; DQBsize FUNCTION
; purpose:
;   Returns the amount of bytes needed to store the graphics contained into
;   a specified box. This value can be used to declare arrays and to use them
;   with the DQBget and DQBput routines.
; declaration:
;   DECLARE FUNCTION DQBsize(BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsize
DQBsize PROC
  ; Stack layout:
  ;
  ; 12  x1
  ; 10  y1
  ; 08  x2
  ; 06  y2
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]     ; Gets the x2 value into BX
  SUB AX,[BP+12]    ; Subtract x1 to x2...
  INC AX            ; ...and increase the result by 1
  MOV DX,[BP+6]     ; Gets the y2 value into DX
  SUB DX,[BP+10]    ; Subtract y1 to y2...
  INC DX            ; ...and increase the result by 1
  MUL DX            ; Let's find the area in pixels
  ADD AX,4          ; Add 4 bytes of sprite header
  POP BP
  RET 8
DQBsize ENDP

; ---------------------------------------------------------------------------
; DQBsetClipBox SUB
; purpose:
;   Sets the actual clipping box used by the graphical functions.
; declaration:
;   DECLARE SUB DQBsetClipBox(BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetClipBox
DQBsetClipBox PROC
  ; Stack layout
  ;
  ; 12  x1
  ; 10  y1
  ; 08  x2
  ; 06  y2
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+12]
  MOV BX,[BP+8]
  CMP BX,AX         ; Is x1>x2?
  JG CheckOther
  XCHG AX,BX        ; Yes: exchange them
CheckOther:
  MOV ClipX1,AX
  MOV ClipX2,BX
  MOV AX,[BP+10]
  MOV BX,[BP+6]
  CMP BX,AX         ; Is y1>y1?
  JG EndSetClipBox
  XCHG AX,BX        ; Yes: exchange them
EndSetClipBox:
  MOV ClipY1,AX
  MOV ClipY2,BX
  POP BP
  RET 8
DQBsetClipBox ENDP

; ---------------------------------------------------------------------------
; DQBsPut SUB
; purpose:
;   Draws a given sprite at specified coordinates on the given layer, scaled
;   to the specified new width and height. This sub works almost the same as
;   DQBput, including the support for clipping and transparency.
; declaration:
;   DECLARE SUB DQBsPut(BYVAL Layer,BYVAL x,BYVAL y,BYVAL BufferSeg,
;                       BYVAL BufferOff,BYVAL NewWidth,BYVAL NewHeight)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsPut
DQBsPut PROC
  ; Stack layout
  ;
  ; 40  Layer
  ; 38  x
  ; 36  y
  ; 34  Buffer segment
  ; 32  Buffer offset
  ; 30  NewWidth
  ; 28  NewHeight
  ; 26  Basic return segment
  ; 24  Basic return offset
  ; 22  DS
  ; 20  BP
  ; 18  PutMode
  ; 16  ClipX1
  ; 14  ClipX2
  ; 12  ClipY1
  ; 10  ClipY2
  ; 08  xi
  ; 06  yi
  ; 04  yadd
  ; 02  original width
  ; 00  original height
  PUSH DS
  PUSH BP
  MOV AX,PutMode
  PUSH AX
  MOV AX,ClipX1
  PUSH AX
  MOV AX,ClipX2
  PUSH AX
  MOV AX,ClipY1
  PUSH AX
  MOV AX,ClipY2
  PUSH AX
  SUB SP,6          ; Keep stack space for extra variables
  MOV BP,SP
  MOV BX,[BP+36]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+30]
  MOV DS,AX
  MOV SI,[BP+28]
  MOV AX,[SI]
  SHR AX,3
  PUSH AX
  MOV AX,[SI+2]
  PUSH AX
  MOV BP,SP
  SHL AX,7          ; 9.7 fixed point math used to allow sprites of up to
  MOV BX,[BP+28]    ; 511x511 pixels
  XOR DX,DX
  DIV BX
  MOV [BP+6],AX     ; yi stored
  MOV AX,[BP+2]
  SHL AX,7          ; Fixed point math used (9.7)
  MOV BX,[BP+30]
  XOR DX,DX
  DIV BX
  MOV [BP+8],AX     ; xi stored
  XOR CX,CX
  MOV [BP+4],CX
  MOV SI,[BP+32]
  ADD SI,4          ; SI holds the actual sprite offset position
  MOV AX,[BP+18]
  CMP AX,0
  JNE SolidScaledYloop
ScaledYloop:
  MOV DI,[BP+36]
  ADD DI,CX
  CMP DI,[BP+12]
  JL SkipScaledLine
  CMP DI,[BP+10]
  JG SkipScaledLine
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+38]
  PUSH CX
  XOR CX,CX
  XOR DX,DX
  XOR BX,BX
ScaledXloop:
  MOV AX,[BP+38]
  ADD AX,CX
  CMP AX,[BP+16]
  JL SkipScaledPixel
  CMP AX,[BP+14]
  JG SkipScaledPixel
  MOV AL,[SI+BX]
  CMP AL,0
  JE SkipScaledPixel
  STOSB
  ADD DX,[BP+8]
  MOV BX,DX
  SHR BX,7
  INC CX
  CMP CX,[BP+30]
  JL ScaledXloop
  POP CX
  JMP SkipScaledLine
SkipScaledPixel:
  INC DI
  ADD DX,[BP+8]
  MOV BX,DX
  SHR BX,7
  INC CX
  CMP CX,[BP+30]
  JL ScaledXloop
  POP CX
SkipScaledLine:
  MOV SI,[BP+32]
  ADD SI,4
  MOV DX,[BP+6]
  ADD [BP+4],DX
  MOV AX,[BP+4]
  SHR AX,7
  MOV BX,[BP+2]
  XOR DX,DX
  MUL BX
  ADD SI,AX
  INC CX
  CMP CX,[BP+28]
  JL ScaledYloop
  ADD SP,20
  POP BP
  POP DS
  RET 14
SolidScaledYloop:
  MOV DI,[BP+36]
  ADD DI,CX
  CMP DI,[BP+12]
  JL SolidSkipScaledLine
  CMP DI,[BP+10]
  JG SolidSkipScaledLine
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+38]
  PUSH CX
  XOR CX,CX
  XOR DX,DX
  XOR BX,BX
SolidScaledXloop:
  MOV AX,[BP+38]
  ADD AX,CX
  CMP AX,[BP+16]
  JL SolidSkipScaledPixel
  CMP AX,[BP+14]
  JG SolidSkipScaledPixel
  MOV AL,[SI+BX]
  STOSB
  ADD DX,[BP+8]
  MOV BX,DX
  SHR BX,7
  INC CX
  CMP CX,[BP+30]
  JL SolidScaledXloop
  POP CX
  JMP SolidSkipScaledLine
SolidSkipScaledPixel:
  INC DI
  ADD DX,[BP+8]
  MOV BX,DX
  SHR BX,7
  INC CX
  CMP CX,[BP+30]
  JL SolidScaledXloop
  POP CX
SolidSkipScaledLine:
  MOV SI,[BP+32]
  ADD SI,4
  MOV DX,[BP+6]
  ADD [BP+4],DX
  MOV AX,[BP+4]
  SHR AX,7
  MOV BX,[BP+2]
  XOR DX,DX
  MUL BX
  ADD SI,AX
  INC CX
  CMP CX,[BP+28]
  JL SolidScaledYloop
  ADD SP,20
  POP BP
  POP DS
  RET 14
DQBsPut ENDP

; ---------------------------------------------------------------------------
; DQBrPut SUB
; purpose:
;   Draws a sprite rotated by a specified angle. The original sprite size
;   is kept, and rotated pixels that lies outside the sprite area will not be
;   drawn; this allows to use a pixel-perfect rotation, but it'll require
;   that you get your sprite into a larger area, in order to allow a rotation
;   without loosing any pixel.
; declaration:
;   DECLARE SUB DQBrPut(BYVAL Layer,BYVAL x,BYVAL y,BYVAL BufferSeg,
;                       BYVAL BufferOff,BYVAL Angle,BYVAL Zoom)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBrPut
DQBrPut PROC
  ; Stack layout
  ;
  ; 46  Layer
  ; 44  x
  ; 42  y
  ; 40  BufferSeg
  ; 38  BufferOff
  ; 36  Angle
  ; 34  Zoom
  ; 32  Basic return segment
  ; 30  Basic return offset
  ; 28  DS
  ; 26  BP
  ; 24  PutMode
  ; 22  ClipX1
  ; 20  ClipX2
  ; 18  ClipY1
  ; 16  ClipY2
  ; 14  Sprite width
  ; 12  Sprite height
  ; 10  Sprite width div 2
  ; 08  Sprite height div 2
  ; 04  -- Internal variables
  ; 00  /
  PUSH DS
  PUSH BP
  MOV AX,PutMode
  PUSH AX
  MOV AX,ClipX1
  PUSH AX
  MOV AX,ClipX2
  PUSH AX
  MOV AX,ClipY1
  PUSH AX
  MOV AX,ClipY2
  PUSH AX
  SUB SP,16
  MOV BP,SP
  MOV BX,[BP+46]
  CALL GetLayerSeg
  MOV ES,CX
  MOV DI,[BP+42]
  MOV SI,DI
  SHL DI,8
  SHL SI,6
  ADD DI,SI
  ADD DI,[BP+44]
  MOV AX,[BP+36]
  ADD AX,64
  XOR AH,AH
  MOV SI,AX
  SHL SI,1
  MOV AX,SinTable[SI]
  MOV BX,100
  IMUL BX
  SHL EDX,16
  MOV DX,AX
  MOV EAX,EDX
  CDQ
  XOR ESI,ESI
  MOV SI,[BP+34]
  IDIV ESI
  MOV [BP+4],EAX
  MOV AX,[BP+36]
  XOR AH,AH
  MOV SI,AX
  SHL SI,1
  MOV AX,SinTable[SI]
  IMUL BX
  SHL EDX,16
  MOV DX,AX
  MOV EAX,EDX
  CDQ
  XOR ESI,ESI
  MOV SI,[BP+34]
  IDIV ESI
  MOV [BP],EAX
  MOV AX,[BP+40]
  MOV DS,AX
  MOV SI,[BP+38]
  XOR EAX,EAX
  LODSW
  SHR AX,3
  MOV [BP+14],AX
  SHR AX,1
  MOV [BP+10],AX
  LODSW
  MOV [BP+12],AX
  SHR AX,1
  MOV [BP+8],AX
  MOV EDX,[BP]
  IMUL EDX
  MOV ESI,EAX
  NEG ESI
  XOR EAX,EAX
  MOV AX,256
  MOV DX,[BP+8]
  MUL DX
  ADD ESI,EAX
  XOR EAX,EAX
  MOV AX,[BP+10]
  MOV EDX,[BP+4]
  IMUL EDX
  SUB ESI,EAX
  XOR EAX,EAX
  MOV AX,[BP+10]
  MOV EDX,[BP]
  IMUL EDX
  MOV EBX,EAX
  NEG EBX
  XOR EAX,EAX
  MOV AX,256
  MOV DX,[BP+10]
  MUL DX
  ADD EBX,EAX
  XOR EAX,EAX
  MOV AX,[BP+8]
  MOV EDX,[BP+4]
  IMUL EDX
  ADD EAX,EBX
  XOR CX,CX
RotYloop:
  PUSH CX
  PUSH EAX
  PUSH ESI
  ADD DI,[BP+14]
  ADD CX,[BP+42]
  CMP CX,[BP+18]
  JL RotSkipLine
  CMP CX,[BP+16]
  JG RotSkipLine
  SUB DI,[BP+14]
  XOR CX,CX
RotXloop:
  PUSH CX
  ADD CX,[BP+44]
  CMP CX,[BP+22]
  JL RotSkip
  CMP CX,[BP+20]
  JG RotSkip
  MOV EBX,EAX
  SHR EBX,8
  MOV EDX,ESI
  SHR EDX,8
  CMP DX,0
  JL RotSkip
  CMP DX,[BP+12]
  JGE RotSkip
  CMP BX,0
  JL RotSkip
  CMP BX,[BP+14]
  JGE RotSkip
  PUSH EAX
  PUSH EDX
  MOV AX,[BP+14]
  MUL DX
  ADD BX,AX
  ADD BX,[BP+38]
  MOV BL,DS:[BX+4]
  MOV AX,[BP+24]
  CMP AX,0
  JNE SkipTest
  CMP BL,0
  JE RotSkip0
SkipTest:
  MOV ES:[DI],BL
RotSkip0:
  POP EDX
  POP EAX
RotSkip:
  POP CX
  ADD EAX,[BP]
  ADD ESI,[BP+4]
  INC DI
  INC CX
  CMP CX,[BP+14]
  JL RotXloop
RotSkipLine:
  ADD DI,320
  SUB DI,[BP+14]
  POP ESI
  POP EAX
  SUB EAX,[BP+4]
  ADD ESI,[BP]
  POP CX
  INC CX
  CMP CX,[BP+12]
  JL RotYloop
  ADD SP,26
  POP BP
  POP DS
  RET 14
DQBrPut ENDP

; ---------------------------------------------------------------------------
; DQBfPut SUB
; purpose:
;   Puts a sprite onto specified layer, using a fast algorithm. This routine
;   skips all clipping box checks, and does not allow transparency; it just
;   copy the entire sprite block at the given coordinates.
; declaration:
;   DECLARE SUB DQBfPut(BYVAL Layer,BYVAL x,BYVAL y,BYVAL BufferSeg,
;                       BYVAL BufferOff)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBfPut
DQBfPut PROC
  ; Stack layout
  ;
  ; 16  Layer
  ; 14  x
  ; 12  y
  ; 10  Buffer segment
  ; 08  Buffer offset
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+16]
  CALL GetLayerSeg
  MOV ES,CX
  MOV DI,[BP+12]
  MOV AX,DI
  SHL AX,8
  SHL DI,6
  ADD DI,AX
  ADD DI,[BP+14]
  MOV AX,[BP+10]
  MOV DS,AX
  MOV SI,[BP+8]
  LODSW
  MOV DX,AX
  SHR DX,3          ; DX holds the sprite width
  MOV BX,320
  SUB BX,DX         ; BX holds the value "320-width" in pixels
  LODSW
  MOV CX,AX         ; CX holds the sprite height
  TEST DX,2
  JNZ FastWordCopy
  TEST DX,1
  JNZ BYTEloop
  SHR DX,2
DWORDloop:
  PUSH CX
  MOV CX,DX
  REP MOVSD
  POP CX
  ADD DI,BX
  DEC CX
  JNZ DWORDloop
  POP BP
  POP DS
  RET 10
FastWordCopy:
  TEST DX,1
  JNZ BYTEloop
  SHR DX,1
WORDloop:
  PUSH CX
  MOV CX,DX
  REP MOVSW
  POP CX
  ADD DI,BX
  DEC CX
  JNZ WORDloop
  POP BP
  POP DS
  RET 10
BYTEloop:
  PUSH CX
  MOV CX,DX
  REP MOVSB
  POP CX
  ADD DI,BX
  DEC CX
  JNZ BYTEloop
  POP BP
  POP DS
  RET 10
DQBfPut ENDP

; ---------------------------------------------------------------------------
; DQBxPut SUB
; purpose:
;   This function gets a sprite from a layer and puts it into another one,
;   without the support of external QB arrays. The bad thing is that to use
;   DQBxPut your sprites must not have a height bigger than 50 pixels. This
;   function also supports clipping and transparency.
; declaration:
;   DECLARE SUB DQBput(BYVAL SourceLayer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                      BYVAL DestLayer,BYVAL x,BYVAL y)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBxPut
DQBxPut PROC
  ; Stack layout
  ;
  ; 38  SourceLayer
  ; 36  x1
  ; 34  y1
  ; 32  x2
  ; 30  y2
  ; 28  DestLayer
  ; 26  x
  ; 24  y
  ; 22  Basic return segment
  ; 20  Basic return offset
  ; 18  DS
  ; 16  BP
  ; 14  PutMode
  ; 12  ClipX1
  ; 10  ClipX2
  ; 08  ClipY1
  ; 06  ClipY2
  ; 04  EMSseg
  ; 02  EMShdl
  ; 00  Sprite width
  PUSH DS
  PUSH BP
  MOV AX,PutMode    ; Puts the put mode and the clipping box coordinates
  PUSH AX           ; on the stack for later use
  MOV AX,ClipX1
  PUSH AX
  MOV AX,ClipX2
  PUSH AX
  MOV AX,ClipY1
  PUSH AX
  MOV AX,ClipY2
  PUSH AX
  MOV AX,EMSseg
  PUSH AX
  MOV AX,EMShdl
  PUSH AX
  PUSH AX
  MOV BP,SP
  MOV DI,[BP+24]
  MOV AX,DI
  SHL DI,8
  SHL AX,6
  ADD DI,AX
  ADD DI,[BP+26]
  MOV BX,[BP+28]
  CMP BX,0
  JG dNotVideo
  OR BX,BX
  JZ dOnVideo
  AND BX,0111111111111111b
  SHL BX,1
  MOV AX,BaseLayer[BX]
  MOV ES,AX
  JMP DestFixed
dOnVideo:
  MOV AX,0A000h
  MOV ES,AX
  JMP DestFixed
dNotVideo:
  MOV AX,[BP+4]
  MOV ES,AX
  XOR AX,AX
  MOV DX,[BP+24]
  OR DX,DX
  JS PageOk2
  JNZ @F
  MOV DX,[BP+26]
  OR DX,DX
  JS PageOk2
@@:
  MOV AX,DI
  SHR AX,14
  CMP AX,3
  JL PageOk2
  MOV AX,2
PageOk2:
  DEC BX
  SHL BX,2
  ADD BX,AX
  SHL AX,14
  SUB DI,AX
  ADD DI,08000h
  MOV DX,[BP+2]
  MOV AX,04402h
  INT 67h
  INC BX
  MOV AX,04403h
  INT 67h
DestFixed:
  MOV SI,[BP+34]
  MOV AX,SI
  SHL SI,8
  SHL AX,6
  ADD SI,AX
  ADD SI,[BP+36]
  MOV BX,[BP+38]
  CMP BX,[BP+28]
  JE EndXput
  CMP BX,0
  JG sNotVideo
  OR BX,BX
  JZ sOnVideo
  AND BX,0111111111111111b
  SHL BX,1
  MOV AX,BaseLayer[BX]
  MOV DS,AX
  JMP SourceFixed
sOnVideo:
  MOV AX,0A000h
  MOV DS,AX
  JMP SourceFixed
sNotVideo:
  MOV AX,[BP+4]
  MOV DS,AX
  MOV AX,SI
  SHR AX,14
  CMP AX,3
  JL PageOk1
  MOV AX,2
PageOk1:
  DEC BX
  SHL BX,2
  ADD BX,AX       ; Now BX holds the correct starting page
  SHL AX,14
  SUB SI,AX       ; SI is now fixed
  MOV DX,[BP+2]
  MOV AX,04400h
  INT 67h
  INC BX
  MOV AX,04401h
  INT 67h
SourceFixed:
  MOV AX,[BP+32]
  SUB AX,[BP+36]
  INC AX
  MOV [BP],AX
  MOV AX,[BP+30]
  SUB AX,[BP+34]
  MOV AH,AL         ; Sets AH to the height of the sprite
  ADD AH,2
  XOR AL,AL
  MOV BX,[BP+24]    ; BX holds the value y-1
  DEC BX
  SUB DI,320
  SUB SI,320
  ADD DI,[BP]
  ADD SI,[BP]
  CMP [BP+14],AL    ; Are we in solid put mode?
  JNE xSolidYloop    ; Yes: jump to the solid put loop
xYloop:
  ADD SI,320
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  DEC AH
  JZ EndXput        ; Last sprite line reached
  CMP BX,[BP+8]     ; Are we out of the upper clipping border?
  JL xYloop         ; Yes: increase the line counter
  CMP BX,[BP+6]     ; Are we out of the lower clipping border?
  JG EndXput        ; Yes: exit DQBxPut
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+26]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
xXloop:
  LODSB             ; Gets a pixel from the buffer
  CMP AL,0
  JE xSkipPixel     ; Transparent pixel: skip it!
  CMP DX,[BP+12]
  JL xSkipPixel     ; Out of left layer border: skip it!
  CMP DX,[BP+10]
  JG xSkipPixel     ; Out of right layer border: skip it!
  MOV ES:[DI],AL
xSkipPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  DEC CX
  JNZ xXloop       ; Repeats sprite width times
  JMP xYloop        ; Next line
xSolidYloop:
  ADD SI,320
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  DEC AH
  JZ EndXput        ; Last sprite line reached?
  CMP BX,[BP+8]     ; Are we out of the upper clipping border?
  JL xSolidYloop    ; Yes: increase the line counter
  CMP BX,[BP+6]     ; Are we out of the lower clipping border?
  JG EndXput        ; Yes: exit DQBxPut
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+26]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
xSolidXloop:
  LODSB             ; Gets a pixel from the buffer
  CMP DX,[BP+12]
  JL xSkipSolidPixel   ; Out of left layer border: skip it!
  CMP DX,[BP+10]
  JG xSkipSolidPixel   ; Out of right layer border: skip it!
  MOV ES:[DI],AL
xSkipSolidPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  DEC CX
  JNZ xSolidXloop  ; Repeats sprite width times
  JMP xSolidYloop   ; Next line
EndXput:
  ADD SP,16         ; Release stack memory
  POP BP
  POP DS
  MOV EMSpage,-1
  RET 16
DQBxPut ENDP

; ---------------------------------------------------------------------------
; DQBmPut SUB
; purpose:
;   Works exaclty like normal DQBput, but it allows the user to draw mirrored
;   sprites, by using the Flip parameter.
; declaration:
;   DECLARE SUB DQBput(BYVAL Layer,BYVAL x,BYVAL y,BYVAL BufferSeg,
;                       BYVAL BufferOff,BYVAL Flip)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBmPut
DQBmPut PROC
  ; Stack layout
  ;
  ; 18  Layer
  ; 16  x
  ; 14  y
  ; 12  Buffer segment
  ; 10  Buffer offset
  ; 08  Flip
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+10]    ; SI points to the buffer offset
  MOV BX,[BP+18]    ; Gets the layer number...
  CALL GetLayerSeg
  MOV ES,CX         ; ...and sets ES to its segment
  MOV AX,PutMode    ; Puts the put mode and the clipping box coordinates
  PUSH AX           ; on the stack for later use
  MOV AX,ClipX1
  PUSH AX
  MOV AX,ClipX2
  PUSH AX
  MOV AX,ClipY1
  PUSH AX
  MOV AX,ClipY2
  PUSH AX
  MOV BX,[BP+12]
  MOV DS,BX         ; DS points to the buffer segment
  LODSW
  SHR AX,3          ; Divide width by 8 for GET/PUT compatibility
  PUSH AX           ; Gets the sprite width and puts it onto the stack
  LODSW
  PUSH AX           ; Gets the sprite height and puts it onto the stack
  MOV BP,SP
  MOV AX,[BP+22]
  TEST AX,1
  JZ mtest
  TEST AX,2
  JNZ mirror3
  JMP mirror1
mtest:
  TEST AX,2
  JNZ mirror2
mirror0:
  MOV DI,[BP+28]
  MOV BX,DI
  MOV CX,DI
  SHL CX,8
  SHL DI,6
  ADD DI,CX
  ADD DI,[BP+30]
  MOV DX,[BP+30]
  MOV CX,[BP]
  MOV AX,[BP+12]
  OR AX,AX
  JNZ solidYLoop0
Yloop0:
  CMP BX,[BP+6]
  JL NextY0
  CMP BX,[BP+4]
  JG NextY0
  PUSH CX
  MOV CX,[BP+2]
Xloop0:
  LODSB
  CMP AL,0
  JE SkipPixel0
  CMP DX,[BP+10]
  JL SkipPixel0
  CMP DX,[BP+8]
  JG SkipPixel0
  MOV ES:[DI],AL
SkipPixel0:
  INC DI
  INC DX
  DEC CX
  JNZ Xloop0
  POP CX
  SUB DX,[BP+2]
  INC BX
  ADD DI,320
  SUB DI,[BP+2]
  DEC CX
  JNZ Yloop0
  ADD SP,14
  POP BP
  POP DS
  RET 12
NextY0:
  ADD SI,[BP+2]
  ADD DI,320
  INC BX
  DEC CX
  JNZ Yloop0
  ADD SP,14
  POP BP
  POP DS
  RET 12
solidYloop0:
  CMP BX,[BP+6]
  JL solidNextY0
  CMP BX,[BP+4]
  JG solidNextY0
  PUSH CX
  MOV CX,[BP+2]
solidXloop0:
  LODSB
  CMP DX,[BP+10]
  JL solidSkipPixel0
  CMP DX,[BP+8]
  JG solidSkipPixel0
  MOV ES:[DI],AL
solidSkipPixel0:
  INC DI
  INC DX
  DEC CX
  JNZ solidXloop0
  POP CX
  SUB DX,[BP+2]
  INC BX
  ADD DI,320
  SUB DI,[BP+2]
  DEC CX
  JNZ solidYloop0
  ADD SP,14
  POP BP
  POP DS
  RET 12
solidNextY0:
  ADD SI,[BP+2]
  ADD DI,320
  INC BX
  DEC CX
  JNZ solidYloop0
  ADD SP,14
  POP BP
  POP DS
  RET 12
mirror1:
  ADD SI,[BP+2]
  DEC SI
  MOV DI,[BP+28]
  MOV BX,DI
  MOV CX,DI
  SHL CX,8
  SHL DI,6
  ADD DI,CX
  ADD DI,[BP+30]
  MOV DX,[BP+30]
  MOV CX,[BP]
  MOV AX,[BP+12]
  OR AX,AX
  JNZ solidYLoop1
Yloop1:
  CMP BX,[BP+6]
  JL NextY1
  CMP BX,[BP+4]
  JG NextY1
  PUSH CX
  MOV CX,[BP+2]
Xloop1:
  MOV AL,[SI]
  DEC SI
  CMP AL,0
  JE SkipPixel1
  CMP DX,[BP+10]
  JL SkipPixel1
  CMP DX,[BP+8]
  JG SkipPixel1
  MOV ES:[DI],AL
SkipPixel1:
  INC DI
  INC DX
  DEC CX
  JNZ Xloop1
  POP CX
  SUB DX,[BP+2]
  INC BX
  ADD DI,320
  SUB DI,[BP+2]
  ADD SI,[BP+2]
  ADD SI,[BP+2]
  DEC CX
  JNZ Yloop1
  ADD SP,14
  POP BP
  POP DS
  RET 12
NextY1:
  ADD SI,[BP+2]
  ADD DI,320
  INC BX
  DEC CX
  JNZ Yloop1
  ADD SP,14
  POP BP
  POP DS
  RET 12
solidYloop1:
  CMP BX,[BP+6]
  JL solidNextY1
  CMP BX,[BP+4]
  JG solidNextY1
  PUSH CX
  MOV CX,[BP+2]
solidXloop1:
  MOV AL,[SI]
  DEC SI
  CMP DX,[BP+10]
  JL solidSkipPixel1
  CMP DX,[BP+8]
  JG solidSkipPixel1
  MOV ES:[DI],AL
solidSkipPixel1:
  INC DI
  INC DX
  DEC CX
  JNZ solidXloop1
  POP CX
  SUB DX,[BP+2]
  INC BX
  ADD DI,320
  SUB DI,[BP+2]
  ADD SI,[BP+2]
  ADD SI,[BP+2]
  DEC CX
  JNZ solidYloop1
  ADD SP,14
  POP BP
  POP DS
  RET 12
solidNextY1:
  ADD SI,[BP+2]
  ADD DI,320
  INC BX
  DEC CX
  JNZ solidYloop1
  ADD SP,14
  POP BP
  POP DS
  RET 12
mirror2:
  MOV DI,[BP+28]
  ADD DI,[BP]
  DEC DI
  MOV BX,DI
  MOV CX,DI
  SHL CX,8
  SHL DI,6
  ADD DI,CX
  ADD DI,[BP+30]
  MOV DX,[BP+30]
  MOV CX,[BP]
  MOV AX,[BP+12]
  OR AX,AX
  JNZ solidYLoop2
Yloop2:
  CMP BX,[BP+6]
  JL NextY2
  CMP BX,[BP+4]
  JG NextY2
  PUSH CX
  MOV CX,[BP+2]
Xloop2:
  LODSB
  CMP AL,0
  JE SkipPixel2
  CMP DX,[BP+10]
  JL SkipPixel2
  CMP DX,[BP+8]
  JG SkipPixel2
  MOV ES:[DI],AL
SkipPixel2:
  INC DI
  INC DX
  DEC CX
  JNZ Xloop2
  POP CX
  SUB DX,[BP+2]
  DEC BX
  SUB DI,320
  SUB DI,[BP+2]
  DEC CX
  JNZ Yloop2
  ADD SP,14
  POP BP
  POP DS
  RET 12
NextY2:
  ADD SI,[BP+2]
  SUB DI,320
  DEC BX
  DEC CX
  JNZ Yloop2
  ADD SP,14
  POP BP
  POP DS
  RET 12
solidYloop2:
  CMP BX,[BP+6]
  JL solidNextY2
  CMP BX,[BP+4]
  JG solidNextY2
  PUSH CX
  MOV CX,[BP+2]
solidXloop2:
  LODSB
  CMP DX,[BP+10]
  JL solidSkipPixel2
  CMP DX,[BP+8]
  JG solidSkipPixel2
  MOV ES:[DI],AL
solidSkipPixel2:
  INC DI
  INC DX
  DEC CX
  JNZ solidXloop2
  POP CX
  SUB DX,[BP+2]
  DEC BX
  SUB DI,320
  SUB DI,[BP+2]
  DEC CX
  JNZ solidYloop2
  ADD SP,14
  POP BP
  POP DS
  RET 12
solidNextY2:
  ADD SI,[BP+2]
  SUB DI,320
  DEC BX
  DEC CX
  JNZ solidYloop2
  ADD SP,14
  POP BP
  POP DS
  RET 12
mirror3:
  ADD SI,[BP+2]
  DEC SI
  MOV DI,[BP+28]
  ADD DI,[BP]
  DEC DI
  MOV BX,DI
  MOV CX,DI
  SHL CX,8
  SHL DI,6
  ADD DI,CX
  ADD DI,[BP+30]
  MOV DX,[BP+30]
  MOV CX,[BP]
  MOV AX,[BP+12]
  OR AX,AX
  JNZ solidYLoop3
Yloop3:
  CMP BX,[BP+6]
  JL NextY3
  CMP BX,[BP+4]
  JG NextY3
  PUSH CX
  MOV CX,[BP+2]
Xloop3:
  MOV AL,[SI]
  DEC SI
  CMP AL,0
  JE SkipPixel3
  CMP DX,[BP+10]
  JL SkipPixel3
  CMP DX,[BP+8]
  JG SkipPixel3
  MOV ES:[DI],AL
SkipPixel3:
  INC DI
  INC DX
  DEC CX
  JNZ Xloop3
  POP CX
  SUB DX,[BP+2]
  DEC BX
  SUB DI,320
  SUB DI,[BP+2]
  ADD SI,[BP+2]
  ADD SI,[BP+2]
  DEC CX
  JNZ Yloop3
  ADD SP,14
  POP BP
  POP DS
  RET 12
NextY3:
  ADD SI,[BP+2]
  SUB DI,320
  DEC BX
  DEC CX
  JNZ Yloop3
  ADD SP,14
  POP BP
  POP DS
  RET 12
solidYloop3:
  CMP BX,[BP+6]
  JL solidNextY3
  CMP BX,[BP+4]
  JG solidNextY3
  PUSH CX
  MOV CX,[BP+2]
solidXloop3:
  MOV AL,[SI]
  DEC SI
  CMP DX,[BP+10]
  JL solidSkipPixel3
  CMP DX,[BP+8]
  JG solidSkipPixel3
  MOV ES:[DI],AL
solidSkipPixel3:
  INC DI
  INC DX
  DEC CX
  JNZ solidXloop3
  POP CX
  SUB DX,[BP+2]
  DEC BX
  SUB DI,320
  SUB DI,[BP+2]
  ADD SI,[BP+2]
  ADD SI,[BP+2]
  DEC CX
  JNZ solidYloop3
  ADD SP,14
  POP BP
  POP DS
  RET 12
solidNextY3:
  ADD SI,[BP+2]
  SUB DI,320
  DEC BX
  DEC CX
  JNZ solidYloop3
  ADD SP,14
  POP BP
  POP DS
  RET 12
DQBmPut ENDP

; ---------------------------------------------------------------------------
; DQBhPut SUB
; purpose:
;   Draws a sprite shape with an unique specified color; this can be useful
;   for lightning effects, or to show when an enemy has been hit... This
;   function always threats color 0 as transparent color.
; declaration:
;   DECLARE SUB DQBput(BYVAL Layer,BYVAL x,BYVAL y,BYVAL BufferSeg,
;                       BYVAL BufferOff, BYVAL Col)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBhPut
DQBhPut PROC
  ; Stack layout
  ;
  ; 18  Layer
  ; 16  x
  ; 14  y
  ; 12  Buffer segment
  ; 10  Buffer offset
  ; 08  Color
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+10]    ; SI points to the buffer offset
  MOV BX,[BP+18]    ; Gets the layer number...
  CALL GetLayerSeg
  MOV ES,CX         ; ...and sets ES to its segment
  MOV DI,[BP+14]    ; DI contains the y value
  DEC DI
  MOV AX,ClipX1
  PUSH AX
  MOV AX,ClipX2
  PUSH AX
  MOV AX,ClipY1
  PUSH AX
  MOV AX,ClipY2
  PUSH AX
  MOV BX,[BP+12]
  MOV DS,BX         ; DS points to the buffer segment
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+16]    ; DI points to (x,y-1) on specified layer
  LODSW
  SHR AX,3          ; Divide width by 8 for GET/PUT compatibility
  PUSH AX           ; Gets the sprite width and puts it onto the stack
  LODSW
  MOV AH,AL         ; Sets AH to the height of the sprite
  INC AH
  MOV BP,SP
  MOV BX,[BP+24]    ; BX holds the value y-1
  DEC BX
  ADD DI,[BP]
hYloop:
  ADD SI,[BP]
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  DEC AH
  JZ EndhPut         ; Last sprite line reached
  CMP BX,[BP+4]     ; Are we out of the upper clipping border?
  JL hYloop          ; Yes: increase the line counter
  CMP BX,[BP+2]     ; Are we out of the lower clipping border?
  JG EndhPut         ; Yes: exit DQBput
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+26]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
hXloop:
  LODSB             ; Gets a pixel from the buffer
  CMP AL,0
  JE hSkipPixel      ; Transparent pixel: skip it!
  CMP DX,[BP+8]
  JL hSkipPixel      ; Out of left layer border: skip it!
  CMP DX,[BP+6]
  JG hSkipPixel      ; Out of right layer border: skip it!
  MOV AL,[BP+18]
  MOV ES:[DI],AL
hSkipPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  DEC CX
  JNZ hXloop        ; Repeats sprite width times
  JMP hYloop         ; Next line
EndhPut:
  ADD SP,10         ; Release stack memory
  POP BP
  POP DS
  RET 12
DQBhPut ENDP

; ---------------------------------------------------------------------------
; DQBtPut SUB
; purpose:
;   Same as normal DQBput, but it also applies specified bit operation on
;   every sprite pixel.
; declaration:
;   DECLARE SUB DQBtPut(BYVAL Layer,BYVAL x,BYVAL y,BYVAL BufferSeg,
;                       BYVAL BufferOff,BYVAL BitMode)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBtPut
DQBtPut PROC
  ; Stack layout
  ;
  ; 18  Layer
  ; 16  x
  ; 14  y
  ; 12  Buffer segment
  ; 10  Buffer offset
  ; 08  BitMode
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+10]    ; SI points to the buffer offset
  MOV BX,[BP+18]    ; Gets the layer number...
  CALL GetLayerSeg
  MOV ES,CX         ; ...and sets ES to its segment
  MOV DI,[BP+14]    ; DI contains the y value
  DEC DI
  MOV AX,PutMode    ; Puts the put mode and the clipping box coordinates
  PUSH AX           ; on the stack for later use
  MOV AX,ClipX1
  PUSH AX
  MOV AX,ClipX2
  PUSH AX
  MOV AX,ClipY1
  PUSH AX
  MOV AX,ClipY2
  PUSH AX
  MOV BX,[BP+12]
  MOV DS,BX         ; DS points to the buffer segment
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+16]    ; DI points to (x,y-1) on specified layer
  LODSW
  SHR AX,3          ; Divide width by 8 for GET/PUT compatibility
  PUSH AX           ; Gets the sprite width and puts it onto the stack
  LODSW
  MOV AH,AL         ; Sets AH to the height of the sprite
  INC AH
  XOR AL,AL
  MOV BP,SP
  MOV BX,[BP+26]    ; BX holds the value y-1
  DEC BX
  ADD DI,[BP]
  CMP [BP+10],AL    ; Are we in solid put mode?
  JNE tSolidYloop    ; Yes: jump to the solid put loop
tYloop:
  ADD SI,[BP]
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  DEC AH
  JZ EndtPut         ; Last sprite line reached
  CMP BX,[BP+4]     ; Are we out of the upper clipping border?
  JL tYloop          ; Yes: increase the line counter
  CMP BX,[BP+2]     ; Are we out of the lower clipping border?
  JG EndtPut         ; Yes: exit DQBput
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+28]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
tXloop:
  LODSB             ; Gets a pixel from the buffer
  CMP AL,0
  JE tSkipPixel      ; Transparent pixel: skip it!
  CMP DX,[BP+8]
  JL tSkipPixel      ; Out of left layer border: skip it!
  CMP DX,[BP+6]
  JG tSkipPixel      ; Out of right layer border: skip it!
  CMP BYTE PTR [BP+20],1
  JNE @F
  AND ES:[DI],AL
  JMP tSkipPixel
@@:
  CMP BYTE PTR [BP+20],2
  JNE @F
  OR ES:[DI],AL
  JMP tSkipPixel
@@:
  XOR ES:[DI],AL
tSkipPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  DEC CX
  JNZ tXloop        ; Repeats sprite width times
  JMP tYloop         ; Next line
tSolidYloop:
  ADD SI,[BP]
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  DEC AH
  JZ EndtPut         ; Last sprite line reached?
  CMP BX,[BP+4]     ; Are we out of the upper clipping border?
  JL tSolidYloop     ; Yes: increase the line counter
  CMP BX,[BP+2]     ; Are we out of the lower clipping border?
  JG EndtPut         ; Yes: exit DQBput
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+28]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
tSolidXloop:
  LODSB             ; Gets a pixel from the buffer
  CMP DX,[BP+8]
  JL tSkipSolidPixel    ; Out of left layer border: skip it!
  CMP DX,[BP+6]
  JG tSkipSolidPixel    ; Out of right layer border: skip it!
  CMP BYTE PTR [BP+20],1
  JNE @F
  AND ES:[DI],AL
  JMP tSkipSolidPixel
@@:
  CMP BYTE PTR [BP+20],2
  JNE @F
  OR ES:[DI],AL
  JMP tSkipSolidPixel
@@:
  XOR ES:[DI],AL
tSkipSolidPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  DEC CX
  JNZ tSolidXloop   ; Repeats sprite width times
  JMP tSolidYloop    ; Next line
EndtPut:
  ADD SP,12         ; Release stack memory
  POP BP
  POP DS
  RET 12
DQBtPut ENDP

; ---------------------------------------------------------------------------
; DQBpPut SUB
; purpose:
;   Same as normal DQBput, but draws pixels using a specified bit pattern
; declaration:
;   DECLARE SUB DQBpPut(BYVAL Layer,BYVAL x,BYVAL y,BYVAL BufferSeg,
;                       BYVAL BufferOff,BYVAL Pattern)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBpPut
DQBpPut PROC
  ; Stack layout
  ;
  ; 18  Layer
  ; 16  x
  ; 14  y
  ; 12  Buffer segment
  ; 10  Buffer offset
  ; 08  Pattern
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+10]    ; SI points to the buffer offset
  MOV BX,[BP+18]    ; Gets the layer number...
  CALL GetLayerSeg
  MOV ES,CX         ; ...and sets ES to its segment
  MOV DI,[BP+14]    ; DI contains the y value
  DEC DI
  MOV AX,PutMode    ; Puts the put mode and the clipping box coordinates
  PUSH AX           ; on the stack for later use
  MOV AX,ClipX1
  PUSH AX
  MOV AX,ClipX2
  PUSH AX
  MOV AX,ClipY1
  PUSH AX
  MOV AX,ClipY2
  PUSH AX
  MOV BX,[BP+12]
  MOV DS,BX         ; DS points to the buffer segment
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+16]    ; DI points to (x,y-1) on specified layer
  LODSW
  SHR AX,3          ; Divide width by 8 for GET/PUT compatibility
  PUSH AX           ; Gets the sprite width and puts it onto the stack
  LODSW
  MOV AH,AL         ; Sets AH to the height of the sprite
  INC AH
  XOR AL,AL
  MOV BP,SP
  PUSH BX
  MOV BX,[BP+26]    ; BX holds the value y-1
  DEC BX
  ADD DI,[BP]
  XOR BYTE PTR [BP+20],0FFh
  CMP [BP+10],AL    ; Are we in solid put mode?
  JNE pSolidYloop    ; Yes: jump to the solid put loop
pYloop:
  ADD SI,[BP]
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  XOR BYTE PTR [BP+20],0FFh
  MOV BYTE PTR [BP-2],1
  DEC AH
  JZ EndpPut         ; Last sprite line reached
  CMP BX,[BP+4]     ; Are we out of the upper clipping border?
  JL pYloop          ; Yes: increase the line counter
  CMP BX,[BP+2]     ; Are we out of the lower clipping border?
  JG EndpPut         ; Yes: exit DQBput
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+28]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
pXloop:
  INC SI
  MOV AL,[BP-2]
  ROL BYTE PTR [BP-2],1
  TEST AL,[BP+20]
  JZ pSkipPixel
  MOV AL,[SI-1]      ; Gets a pixel from the buffer
  CMP AL,0
  JE pSkipPixel      ; Transparent pixel: skip it!
  CMP DX,[BP+8]
  JL pSkipPixel      ; Out of left layer border: skip it!
  CMP DX,[BP+6]
  JG pSkipPixel      ; Out of right layer border: skip it!
  MOV ES:[DI],AL
pSkipPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  DEC CX
  JNZ pXloop        ; Repeats sprite width times
  JMP pYloop         ; Next line
pSolidYloop:
  ADD SI,[BP]
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  XOR BYTE PTR [BP+20],0FFh
  MOV BYTE PTR [BP-2],1
  DEC AH
  JZ EndpPut         ; Last sprite line reached?
  CMP BX,[BP+4]     ; Are we out of the upper clipping border?
  JL pSolidYloop     ; Yes: increase the line counter
  CMP BX,[BP+2]     ; Are we out of the lower clipping border?
  JG EndpPut         ; Yes: exit DQBput
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+28]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
pSolidXloop:
  INC SI
  ROL BYTE PTR [BP-2],1
  TEST AL,[BP+20]
  JZ pSkipSolidPixel
  MOV AL,[SI-1]
  CMP DX,[BP+8]
  JL pSkipSolidPixel    ; Out of left layer border: skip it!
  CMP DX,[BP+6]
  JG pSkipSolidPixel    ; Out of right layer border: skip it!
  MOV ES:[DI],AL
pSkipSolidPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  DEC CX
  JNZ pSolidXloop   ; Repeats sprite width times
  JMP pSolidYloop    ; Next line
EndpPut:
  ADD SP,14         ; Release stack memory
  POP BP
  POP DS
  RET 12
DQBpPut ENDP

; ---------------------------------------------------------------------------
; DQBputOver SUB
; purpose:
;   Draws a sprite over another one. Sprite drawn is automatically clipped to
;   the dimensions of the background one; this function also supports
;   transparency.
; declaration:
;   DECLARE SUB DQBputOver(BYVAL BackSeg,BYVAL BackOff,BYVAL x,BYVAL y,
;                          BYVAL BufferSeg,BYVAL BufferOff)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBputOver
DQBputOver PROC
  ; Stack layout
  ;
  ; 28  Background segment
  ; 26  Background offset
  ; 24  x
  ; 22  y
  ; 20  Buffer segment
  ; 18  Buffer offset
  ; 16  Basic return segment
  ; 14  Basic return offset
  ; 12  DS
  ; 10  BP
  ; 08  PutMode
  ; 06  Back height
  ; 04  Back width
  ; 02  Sprite height
  ; 00  Sprite width
  PUSH DS
  PUSH BP
  SUB SP,10
  MOV BP,SP
  MOV AX,PutMode
  MOV [BP+8],AX
  MOV AX,[BP+28]
  MOV ES,AX
  MOV DI,[BP+26]
  MOV AX,[BP+20]
  MOV DS,AX
  MOV SI,[BP+18]
  LODSW
  SHR AX,3
  MOV [BP],AX
  LODSW
  MOV [BP+2],AX
  MOV AX,ES:[DI]
  SHR AX,3
  MOV [BP+4],AX
  MOV AX,ES:[DI+2]
  MOV [BP+6],AX
  ADD DI,4
  MOV BX,[BP+22]
  MOV AX,[BP+4]
  IMUL BX
  JS Decrease
  ADD DI,AX
  JMP Continue
Decrease:
  SUB DI,AX
Continue:
  ADD DI,[BP+24]
  MOV DX,[BP+24]
  MOV BX,[BP+22]
  MOV CX,[BP+2]
  MOV AX,[BP+8]
  OR AX,AX
  JNZ oSolidYloop
oYloop:
  CMP BX,0
  JL oSkipLine
  CMP BX,[BP+6]
  JGE oSkipLine
  PUSH CX
  MOV CX,[BP]
oXloop:
  LODSB
  CMP AL,0
  JE oSkipPixel
  CMP DX,0
  JL oSkipPixel
  CMP DX,[BP+4]
  JGE oSkipPixel
  MOV ES:[DI],AL
oSkipPixel:
  INC DI
  INC DX
  DEC CX
  JNZ oXloop
  POP CX
  SUB DI,[BP]
  SUB DX,[BP]
  SUB SI,[BP]
oSkipLine:
  INC BX
  ADD SI,[BP]
  ADD DI,[BP+4]
  DEC CX
  JNZ oYloop
  ADD SP,10
  POP BP
  POP DS
  RET 12
oSolidYloop:
  CMP BX,0
  JL oSolidSkipLine
  CMP BX,[BP+6]
  JGE oSolidSkipLine
  PUSH CX
  MOV CX,[BP]
oSolidXloop:
  LODSB
  CMP AL,0
  JE oSolidSkipPixel
  CMP DX,0
  JL oSolidSkipPixel
  CMP DX,[BP+4]
  JGE oSolidSkipPixel
  MOV ES:[DI],AL
oSolidSkipPixel:
  INC DI
  INC DX
  DEC CX
  JNZ oSolidXloop
  POP CX
  SUB DI,[BP]
  SUB DX,[BP]
  SUB SI,[BP]
oSolidSkipLine:
  INC BX
  ADD SI,[BP]
  ADD DI,[BP+4]
  DEC CX
  JNZ oSolidYloop
  ADD SP,10
  POP BP
  POP DS
  RET 12
DQBputOver ENDP

; ---------------------------------------------------------------------------
; DQBcollide FUNCTION
; purpose:
;   Checks if two sprites collide, using current detection method.
; declaration:
;   DECLARE FUNCTION DQBcollide(BYVAL x1,BYVAL y1,BYVAL Seg1,BYVAL Off1,
;                               BYVAL x2,BYVAL y2,BYVAL Seg2,BYVAL Off2)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBcollide
DQBcollide PROC
  ; Stack layout
  ;
  ; 36  x1
  ; 34  y1
  ; 32  Seg1
  ; 30  Off1
  ; 28  x2
  ; 26  y2
  ; 24  Seg2
  ; 22  Off2
  ; 20  Basic return segment
  ; 18  Basic return offset
  ; 16  DS
  ; 14  BP
  ; 12  method
  ; 10  width1
  ; 08  width2
  ; 06  height1
  ; 04  height2
  ; 02  w
  ; 00  h
  PUSH DS
  PUSH BP
  SUB SP,14
  MOV BP,SP
  XOR AH,AH
  MOV AL,ColMethod
  MOV [BP+12],AX
  MOV AX,[BP+32]
  MOV DS,AX
  MOV SI,[BP+30]
  LODSW
  SHR AX,3
  MOV [BP+10],AX
  LODSW
  MOV [BP+6],AX
  MOV AX,[BP+24]
  MOV ES,AX
  MOV DI,[BP+22]
  MOV AX,ES:[DI]
  SHR AX,3
  MOV [BP+8],AX
  MOV AX,ES:[DI+2]
  MOV [BP+4],AX
  MOV AX,[BP+36]
  ADD AX,[BP+10]
  CMP AX,[BP+28]
  JLE NoCollision
  MOV AX,[BP+28]
  ADD AX,[BP+8]
  CMP AX,[BP+36]
  JLE NoCollision
  MOV AX,[BP+34]
  ADD AX,[BP+6]
  CMP AX,[BP+26]
  JLE NoCollision
  MOV AX,[BP+26]
  ADD AX,[BP+4]
  CMP AX,[BP+34]
  JLE NoCollision
  MOV AX,[BP+12]
  CMP AX,0
  JNE CheckBox
  MOV AX,0FFFFh
  ADD SP,14
  POP BP
  POP DS
  RET 16
CheckBox:
  MOV AX,[BP+34]
  CMP AX,[BP+26]
  JG Y1greater
  MOV AX,[BP+36]
  CMP AX,[BP+28]
  JG X1greater
  MOV AX,[BP+26]
  SUB AX,[BP+34]
  CWD
  MOV BX,[BP+10]
  MUL BX
  ADD AX,[BP+28]
  SUB AX,[BP+36]
  MOV SI,AX
  XOR DI,DI
  MOV AX,[BP+10]
  ADD AX,[BP+36]
  SUB AX,[BP+28]
  MOV [BP+2],AX
  CMP AX,[BP+8]
  JL @F
  MOV AX,[BP+8]
  MOV [BP+2],AX
@@:
  MOV AX,[BP+6]
  ADD AX,[BP+34]
  SUB AX,[BP+26]
  MOV [BP],AX
  CMP AX,[BP+4]
  JL @F
  MOV AX,[BP+4]
  MOV [BP],AX
@@:
  JMP CheckPixel
X1greater:
  MOV AX,[BP+26]
  SUB AX,[BP+34]
  CWD
  MOV BX,[BP+10]
  MUL BX
  MOV SI,AX
  MOV DI,[BP+36]
  SUB DI,[BP+28]
  MOV AX,[BP+8]
  ADD AX,[BP+28]
  SUB AX,[BP+36]
  MOV [BP+2],AX
  CMP AX,[BP+10]
  JL @F
  MOV AX,[BP+10]
  MOV [BP+2],AX
@@:
  MOV AX,[BP+6]
  ADD AX,[BP+34]
  SUB AX,[BP+26]
  MOV [BP],AX
  CMP AX,[BP+4]
  JL @F
  MOV AX,[BP+4]
  MOV [BP],AX
@@:
  JMP CheckPixel
Y1greater:
  MOV AX,[BP+36]
  CMP AX,[BP+28]
  JG X1greater2
  MOV SI,[BP+28]
  SUB SI,[BP+36]
  MOV AX,[BP+34]
  SUB AX,[BP+26]
  CWD
  MOV BX,[BP+8]
  MUL BX
  MOV DI,AX
  MOV AX,[BP+10]
  ADD AX,[BP+36]
  SUB AX,[BP+28]
  MOV [BP+2],AX
  CMP AX,[BP+8]
  JL @F
  MOV AX,[BP+8]
  MOV [BP+2],AX
@@:
  MOV AX,[BP+4]
  ADD AX,[BP+26]
  SUB AX,[BP+34]
  MOV [BP],AX
  CMP AX,[BP+6]
  JL @F
  MOV AX,[BP+6]
  MOV [BP],AX
@@:
  JMP CheckPixel
X1greater2:
  XOR SI,SI
  MOV AX,[BP+34]
  SUB AX,[BP+26]
  CWD
  MOV BX,[BP+8]
  MUL BX
  ADD AX,[BP+36]
  SUB AX,[BP+28]
  MOV DI,AX
  MOV AX,[BP+8]
  ADD AX,[BP+28]
  SUB AX,[BP+36]
  MOV [BP+2],AX
  CMP AX,[BP+10]
  JL @F
  MOV AX,[BP+10]
  MOV [BP+2],AX
@@:
  MOV AX,[BP+4]
  ADD AX,[BP+26]
  SUB AX,[BP+34]
  MOV [BP],AX
  CMP AX,[BP+6]
  JL CheckPixel
  MOV AX,[BP+6]
  MOV [BP],AX
CheckPixel:
  ADD SI,[BP+30]
  ADD SI,4
  ADD DI,[BP+22]
  ADD DI,4
  MOV DX,[BP]
CheckY:
  MOV CX,[BP+2]
CheckX:
  MOV AL,DS:[SI]
  CMP AL,0
  JE CheckNext
  MOV AL,ES:[DI]
  CMP AL,0
  JE CheckNext
  MOV AX,0FFFFh
  ADD SP,14
  POP BP
  POP DS
  RET 16
CheckNext:
  INC SI
  INC DI
  DEC CX
  JNZ CheckX
  SUB SI,[BP+2]
  ADD SI,[BP+10]
  SUB DI,[BP+2]
  ADD DI,[BP+8]
  DEC DX
  JNZ CheckY
NoCollision:
  XOR AX,AX
  ADD SP,14
  POP BP
  POP DS
  RET 16
DQBcollide ENDP

; ---------------------------------------------------------------------------
; DQBcollideOnLayer FUNCTION
; purpose:
;   Checks whenever a specified sprite collide with objects on a specified
;   layer, and returns the overlapping pixel color, otherwise 0.
; declaration:
;   DECLARE FUNCTION DQBcollideOnLayer(BYVAL Layer,BYVAL x1,BYVAL y1,
;                                      BYVAL SpriteSeg,BYVAL SpriteOff)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBcollideOnLayer
DQBcollideOnLayer PROC
  ; Stack layout:
  ;
  ; 16  Layer
  ; 14  x1
  ; 12  y1
  ; 10  SpriteSeg
  ; 08  SpriteOff
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  ;-02  ClipX1
  ;-04  ClipY1
  ;-06  ClipX2
  ;-08  ClipY2
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+16]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,ClipX1
  PUSH AX
  MOV AX,ClipY1
  PUSH AX
  MOV AX,ClipX2
  PUSH AX
  MOV AX,ClipY2
  PUSH AX
  MOV AX,[BP+10]
  MOV DS,AX
  MOV SI,[BP+8]
  LODSW
  MOV CX,AX
  SHR CX,3
  LODSW
  XCHG AL,AH
  INC AH
  MOV DI,[BP+12]
  MOV DX,DI
  DEC DX
  MOV BX,DI
  SHL BX,6
  SHL DI,8
  ADD DI,BX
  ADD DI,[BP+14]
  XOR BH,BH
cyLoop:
  DEC AH
  JZ cOk
  INC DX
  CMP DX,[BP-4]
  JL cyLoop
  CMP DX,[BP-8]
  JG cOk
  PUSH CX
  PUSH DX
  MOV DX,[BP+14]
cxLoop:
  LODSB
  OR AL,AL
  JZ cSkip
  CMP DX,[BP-2]
  JL cSkip
  CMP DX,[BP-6]
  JG cSkip
  MOV BL,ES:[DI]
  OR BL,BL
  JNZ Collision
cSkip:
  INC DI
  INC DX
  DEC CX
  JNZ cxLoop
  POP DX
  POP CX
  ADD DI,320
  SUB DI,CX
  JMP cyLoop
cOk:
  ADD SP,8
  XOR AX,AX
  POP BP
  POP DS
  RET 10
Collision:
  ADD SP,12
  MOV AX,BX
  POP BP
  POP DS
  RET 10
DQBcollideOnLayer ENDP

; ---------------------------------------------------------------------------
; DQBsetCollideMethod SUB
; purpose:
;   Sets the method actually used by DQBcollide to check for collision
;   between two given sprites; supported methods are bounding box and pixel
;   perfect detection.
; declaration:
;   DECLARE FUNCTION DQBsetCollideMethod(BYVAL Method)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetCollideMethod
DQBsetCollideMethod PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+6]
  MOV ColMethod,AL
  POP BP
  RET 2
DQBsetCollideMethod ENDP


END
