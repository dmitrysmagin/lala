; ---------------------------------------------------------------------------
;
; DirectQB DRAWING PRIMITIVES module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN EMSseg:WORD
EXTRN EMShdl:WORD
EXTRN EMSpage:WORD
EXTRN PutMode:WORD
EXTRN ClipX1:WORD
EXTRN ClipX2:WORD
EXTRN ClipY1:WORD
EXTRN ClipY2:WORD

EXTRN MapEMS:FAR
EXTRN GetLayerSeg:FAR

.DATA
deltax        DW  ?               ; ]
deltay        DW  ?               ;  |
d             DW  ?               ;  |
dinc1         DW  ?               ;  |
dinc2         DW  ?               ;   - Bresenham's line algorithm variables
xinc1         DW  ?               ;  |
xinc2         DW  ?               ;  |
yinc1         DW  ?               ;  |
yinc2         DW  ?               ; ]
PixData       DW  2558 dup(?)     ; pixels data for DQBpaint
FirstEntry    DW  ?
LastEntry     DW  ?
fx            DW  ?
fy            DW  ?

.CODE

; ---------------------------------------------------------------------------
; EPIXEL macro
; purpose:
;   Draws a pixel for the DQBellipse routine
; calling:
;   DX  x
;   BX  y
; ---------------------------------------------------------------------------
EVEN
EPIXEL MACRO
LOCAL SkipcPixel
  CMP DX,ClipX1
  JL SkipcPixel
  CMP DX,ClipX2
  JG SkipcPixel
  CMP BX,ClipY1
  JL SkipcPixel
  CMP BX,ClipY2
  JG SkipcPixel
  MOV DI,BX
  SHL BX,8
  SHL DI,6
  ADD DI,BX
  ADD DI,DX
  MOV ES:[DI],AL
SkipcPixel:
ENDM

; ---------------------------------------------------------------------------
; GETPIXEL macro
; purpose:
;   Returns pixel at (DX,BX) in AL
; calling:
;   DX  x
;   BX  y
; ---------------------------------------------------------------------------
EVEN
GETPIXEL MACRO
LOCAL SkipgPixel
  MOV AX,-1
  CMP BX,ClipY1
  JL SkipgPixel
  CMP BX,ClipY2
  JG SkipgPixel
  CMP DX,ClipX1
  JL SkipgPixel
  CMP DX,ClipX2
  JG SkipgPixel
  MOV DI,BX
  MOV SI,BX
  SHL SI,8
  SHL DI,6
  ADD DI,SI
  ADD DI,DX
  XOR AH,AH
  MOV AL,ES:[DI]
SkipgPixel:
ENDM

; ---------------------------------------------------------------------------
; DQBcopyTransLayer SUB
; purpose:
;   Copies a layer onto another one. Pixels with color 0 on source layer are
;   skipped, allowing a transparency effect; this can be useful to create
;   parallax scrolling effects.
; declaration:
;   DECLARE SUB DQBcopyTransLayer(BYVAL SourceLayer,BYVAL DestLayer)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBcopyTransLayer
DQBcopyTransLayer PROC
  ; Stack layout:
  ;
  ; 10  SourceLayer
  ; 08  DestLayer
  ; 06  Basic segment
  ; 04  Basic offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+10]  ; BX holds the source layer number
  MOV DX,[BP+8]   ; DX holds the destination layer number
  CMP BX,DX       ; Are we processing the same layers?
  JE EndCopy1     ; Yes: exits function
  CMP BX,0
  JLE OneInRAM1   ; Is source layer on video?
  CMP DX,0
  JLE OneInRAM1   ; Is destination layer on video?
  MOV DX,EMShdl   ; Both source and destination layer are on EMS
  MOV AX,EMSseg
  MOV DS,AX       ; ]
  MOV ES,AX       ; |- Both DS and ES points to the EMS pageframe segment
  DEC BX
  SHL BX,2
  MOV AX,4400h
  INT 67h
  MOV AX,4401h
  INC BX
  INT 67h
  MOV BX,[BP+8]
  DEC BX
  SHL BX,2
  MOV AX,4402h
  INT 67h
  MOV AX,4403h    ; At the end the first two physical pages are mapped to the    
  INC BX          ; first half of the source layer, and the third and fourth
  INT 67h         ; pages points to the first half of the destination layer
  MOV SI,0
  MOV DI,8000h
  MOV CX,4000h    ; Copies half the screen
CopyTrans1:
  LODSW
  CMP AX,0
  JNE CopyPixel1
  ADD DI,2
  DEC CX
  JNZ CopyTrans1
  JMP EndCopyTrans1
CopyPixel1:
  CMP AL,0
  JNE CopyLowPixel1
  XCHG AL,AH
  INC DI
  STOSB
  DEC CX
  JNZ CopyTrans1
  JMP EndCopyTrans1
CopyLowPixel1:
  CMP AH,0
  JNE CopyHighPixel1
  STOSB
  INC DI
  DEC CX
  JNZ CopyTrans1
  JMP EndCopyTrans1
CopyHighPixel1:
  STOSW
  DEC CX
  JNZ CopyTrans1
EndCopyTrans1:
  MOV AX,4400h
  MOV BX,[BP+10]
  DEC BX
  SHL BX,2
  ADD BX,2
  INT 67h
  MOV AX,4401h
  INC BX
  INT 67h
  MOV BX,[BP+8]
  DEC BX
  SHL BX,2
  ADD BX,2
  MOV AX,4402h
  INT 67h
  MOV AX,4403h
  INC BX
  INT 67h
  MOV SI,0
  MOV DI,8000h
  MOV CX,4000h    ; Copies the second half of the screen
CopyTrans2:
  LODSW
  CMP AX,0
  JNE CopyPixel2
  ADD DI,2
  DEC CX
  JNZ CopyTrans2
  JMP EndCopyTrans2
CopyPixel2:
  CMP AL,0
  JNE CopyLowPixel2
  XCHG AL,AH
  INC DI
  STOSB
  DEC CX
  JNZ CopyTrans2
  JMP EndCopyTrans2
CopyLowPixel2:
  CMP AH,0
  JNE CopyHighPixel2
  STOSB
  INC DI
  DEC CX
  JNZ CopyTrans2
  JMP EndCopyTrans2
CopyHighPixel2:
  STOSW
  DEC CX
  JNZ CopyTrans2
EndCopyTrans2:
  MOV AX,@DATA
  MOV DS,AX
  MOV DX,EMSpage
  CALL MapEMS
  JMP EndCopy1
OneInRAM1:
  CALL GetLayerSeg
  MOV DI,CX       ; Saves source segment into DI
  MOV BX,[BP+8]
  CALL GetLayerSeg
  MOV ES,CX       ; Sets destination segment...
  MOV DS,DI       ; ...and source segment
  MOV DI,0        ; Both source and destination offsets start as 0
  MOV SI,0
  MOV CX,32000    ; Copies 64000 bytes
CopyTrans3:
  LODSW
  CMP AX,0
  JNE CopyPixel3
  ADD DI,2
  DEC CX
  JNZ CopyTrans3
  JMP EndCopy1
CopyPixel3:
  CMP AL,0
  JNE CopyLowPixel3
  XCHG AL,AH
  INC DI
  STOSB
  DEC CX
  JNZ CopyTrans3
  JMP EndCopy1
CopyLowPixel3:
  CMP AH,0
  JNE CopyHighPixel3
  STOSB
  INC DI
  DEC CX
  JNZ CopyTrans3
  JMP EndCopy1
CopyHighPixel3:
  STOSW
  DEC CX
  JNZ CopyTrans3
EndCopy1:
  POP BP
  POP DS
  RET 4
DQBcopyTransLayer ENDP

; ---------------------------------------------------------------------------
; DQBcopyHitLayer SUB
; purpose:
;   Copies a layer onto another one, by plotting all non-zero pixels with the
;   same specified color
; declaration:
;   DECLARE SUB DQBcopyHitLayer(BYVAL SourceLayer,BYVAL DestLayer,BYVAL Col)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBcopyHitLayer
DQBcopyHitLayer PROC
  ; Stack layout:
  ;
  ; 12  SourceLayer
  ; 10  DestLayer
  ; 08  Col
  ; 06  Basic segment
  ; 04  Basic offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+12]  ; BX holds the source layer number
  MOV DX,[BP+10]   ; DX holds the destination layer number
  CMP BX,DX       ; Are we processing the same layers?
  JE EndCopy      ; Yes: exits function
  CMP BX,0
  JLE OneInRAM    ; Is source layer on RAM?
  CMP DX,0
  JLE OneInRAM    ; Is destination layer on RAM?
  MOV DX,EMShdl   ; Both source and destination layer are on EMS
  MOV AX,EMSseg
  MOV DS,AX       ; ]
  MOV ES,AX       ; |- Both DS and ES points to the EMS pageframe segment
  DEC BX
  SHL BX,2
  MOV AX,4400h
  INT 67h
  MOV AX,4401h
  INC BX
  INT 67h
  MOV BX,[BP+10]
  DEC BX
  SHL BX,2
  MOV AX,4402h
  INT 67h
  MOV AX,4403h    ; At the end the first two physical pages are mapped to the    
  INC BX          ; first half of the source layer, and the third and fourth
  INT 67h         ; pages points to the first half of the destination layer
  XOR SI,SI
  MOV DI,8000h
  MOV CX,8000h    ; Copy the DWORDs!
  XOR BX,BX
@@:
  LODSB
  OR AL,AL
  SETZ BL
  ADD BP,BX
  MOV AL,[BP+8]
  SUB BP,BX
  STOSB
  DEC CX
  JNZ @B
  MOV AX,4400h
  MOV BX,[BP+12]
  DEC BX
  SHL BX,2
  ADD BX,2
  INT 67h
  MOV AX,4401h
  INC BX
  INT 67h
  MOV BX,[BP+10]
  DEC BX
  SHL BX,2
  ADD BX,2
  MOV AX,4402h
  INT 67h
  MOV AX,4403h
  INC BX
  INT 67h
  XOR SI,SI
  MOV DI,8000h
  MOV CX,8000h
  XOR BX,BX
@@:
  LODSB
  OR AL,AL
  SETZ BL
  ADD BP,BX
  MOV AL,[BP+8]
  SUB BP,BX
  STOSB
  DEC CX
  JNZ @B
  MOV AX,@DATA
  MOV DS,AX
  MOV DX,EMSpage
  CALL MapEMS
  POP BP
  POP DS
  RET 6
OneInRAM:
  CALL GetLayerSeg
  MOV DI,CX       ; Saves source segment into DI
  MOV BX,[BP+10]
  CALL GetLayerSeg
  MOV ES,CX       ; Sets destination segment...
  MOV DS,DI       ; ...and source segment
  XOR DI,DI       ; Both source and destination offsets start as 0
  XOR SI,SI
  MOV CX,64000
  XOR BX,BX
@@:
  LODSB
  OR AL,AL
  SETZ BL
  ADD BP,BX
  MOV AL,[BP+8]
  SUB BP,BX
  STOSB
  DEC CX
  JNZ @B
EndCopy:
  POP BP
  POP DS
  RET 6
DQBcopyHitLayer ENDP

; ---------------------------------------------------------------------------
; DQBpset SUB
; purpose:
;   Writes a pixel on the given segment, assuming an offset of 0 for the first
;   pixel on the upper-left corner of the screen.
; declaration:
;   DECLARE SUB DQBpset(BYVAL Layer,BYVAL x,BYVAL y,BYVAL Col)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBpset
DQBpset PROC
  ; Stack layout:
  ; 
  ; 12  Layer
  ; 10  x
  ; 08  y
  ; 06  Color
  ; 04  Basic segment
  ; 02  Basic offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+10]
  CMP AX,ClipX1
  JL ExitPset
  CMP AX,ClipX2
  JG ExitPset
  MOV AX,[BP+8]
  CMP AX,ClipY1
  JL ExitPset
  CMP AX,ClipY2
  JG ExitPset
  MOV BX,[BP+12]    ; Gets the output layer
  CALL GetLayerSeg
  MOV ES,CX         ; Sets the appropriate segment
  MOV DI,[BP+8]    ; Calculates the offset
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+10]
  MOV AL,[BP+6]     ; Gets the pixel color...
  MOV ES:[DI],AL
ExitPset:
  POP BP
  RET 8
DQBpset ENDP

; ---------------------------------------------------------------------------
; DQBpoint FUNCTION
; purpose:
;   Returns the color of the pixel at the given coordinates and on the given
;   layer.
; declaration:
;   FUNCTION DQBpoint(BYVAL Layer,BYVAL x,BYVAL y)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBpoint
DQBpoint PROC
  ; Stack layout:
  ; 
  ; 10  Layer
  ; 08  x
  ; 06  y
  ; 04  Basic segment
  ; 02  Basic offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+10]    ; Gets the output layer
  CALL GetLayerSeg
  MOV ES,CX         ; Sets the appropriate segment
  MOV SI,[BP+6]     ; Calculates the offset
  MOV BX,SI
  SHL SI,8
  SHL BX,6
  ADD SI,BX
  ADD SI,[BP+8]
  XOR AH,AH
  MOV AL,ES:[SI]
  POP BP
  RET 6
DQBpoint ENDP

; ---------------------------------------------------------------------------
; DQBline SUB
; purpose:
;   Draw a line from x1,y1 to x2,y2 on specified layer with the given color,
;   using the Bresenham's line algorithm.
; declaration:
;   DECLARE SUB DQBline(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                       BYVAL Col)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBline
DQBline PROC
  ; Stack layout:
  ;
  ; 16  Layer
  ; 14  x1
  ; 12  y1
  ; 10  x2
  ; 08  y2
  ; 06  Col
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+16]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+14]
  MOV BX,[BP+10]
  CMP AX,BX
  JG Line1
  SUB BX,AX
  MOV deltax,BX
  JMP Line2
Line1:
  SUB AX,BX
  MOV deltax,AX
Line2:
  MOV AX,[BP+12]
  MOV BX,[BP+8]
  CMP AX,BX
  JG Line3
  SUB BX,AX
  MOV deltay,BX
  JMP Line4
Line3:
  SUB AX,BX
  MOV deltay,AX
Line4:
  MOV AX,deltax
  CMP AX,deltay
  JL Line5
  MOV CX,deltax
  INC CX
  MOV BX,deltay
  SHL BX,1
  MOV dinc1,BX
  SUB BX,AX
  MOV d,BX
  MOV BX,deltay
  SUB BX,AX
  SHL BX,1
  MOV dinc2,BX
  MOV xinc1,1
  MOV xinc2,1
  MOV yinc1,0
  MOV yinc2,1
  JMP Line6
Line5:
  MOV CX,deltay
  INC CX
  MOV BX,deltax
  SHL BX,1
  MOV dinc1,BX
  SUB BX,CX
  MOV d,BX
  SUB AX,CX
  INC AX
  SHL AX,1
  MOV dinc2,AX
  MOV xinc1,0
  MOV xinc2,1
  MOV yinc1,1
  MOV yinc2,1
Line6:
  MOV AX,[BP+14]
  CMP AX,[BP+10]
  JLE Line7
  NEG xinc1
  NEG xinc2
Line7:
  MOV AX,[BP+12]
  CMP AX,[BP+8]
  JLE Line8
  NEG yinc1
  NEG yinc2
Line8:
  MOV DX,[BP+14]    ; DX holds the current x coordinate
  MOV BX,[BP+12]    ; BX holds the current y coordinate
  MOV AX,[BP+6]     ; AL holds the color
LineLoop:
  CMP DX,ClipX1
  JL SkipLinePixel
  CMP DX,ClipX2
  JG SkipLinePixel
  CMP BX,ClipY1
  JL SkipLinePixel
  CMP BX,ClipY2
  JG SkipLinePixel
  MOV DI,BX
  MOV SI,BX
  SHL DI,8
  SHL SI,6
  ADD DI,SI
  ADD DI,DX
  MOV ES:[DI],AL
SkipLinePixel:
  CMP d,0
  JL Line9
  MOV SI,d
  ADD SI,dinc2
  MOV d,SI
  ADD DX,xinc2
  ADD BX,yinc2
  JMP Line10
Line9:
  MOV SI,d
  ADD SI,dinc1
  MOV d,SI
  ADD DX,xinc1
  ADD BX,yinc1
Line10:
  DEC CX
  JNZ LineLoop
  POP BP
  RET 12
DQBline ENDP

; ---------------------------------------------------------------------------
; DQBgline SUB
; purpose:
;   Draw a line from x1,y1 to x2,y2 on specified layer, interpolating colors
;   from col1 to col2, and using the Bresenham's line algorithm.
; declaration:
;   DECLARE SUB DQBline(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                       BYVAL Col1,BYVAL Col2)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBgline
DQBgline PROC
  ; Stack layout:
  ;
  ; 18  Layer
  ; 16  x1
  ; 14  y1
  ; 12  x2
  ; 10  y2
  ; 08  Col1
  ; 06  Col2
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  XOR ECX,ECX
  MOV BX,[BP+18]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+16]
  MOV BX,[BP+12]
  CMP AX,BX
  JG gLine1
  SUB BX,AX
  MOV deltax,BX
  JMP gLine2
gLine1:
  SUB AX,BX
  MOV deltax,AX
gLine2:
  MOV AX,[BP+14]
  MOV BX,[BP+10]
  CMP AX,BX
  JG gLine3
  SUB BX,AX
  MOV deltay,BX
  JMP gLine4
gLine3:
  SUB AX,BX
  MOV deltay,AX
gLine4:
  MOV AX,deltax
  CMP AX,deltay
  JL gLine5
  MOV CX,deltax
  INC CX
  MOV BX,deltay
  SHL BX,1
  MOV dinc1,BX
  SUB BX,AX
  MOV d,BX
  MOV BX,deltay
  SUB BX,AX
  SHL BX,1
  MOV dinc2,BX
  MOV xinc1,1
  MOV xinc2,1
  MOV yinc1,0
  MOV yinc2,1
  JMP gLine6
gLine5:
  MOV CX,deltay
  INC CX
  MOV BX,deltax
  SHL BX,1
  MOV dinc1,BX
  SUB BX,CX
  MOV d,BX
  SUB AX,CX
  INC AX
  SHL AX,1
  MOV dinc2,AX
  MOV xinc1,0
  MOV xinc2,1
  MOV yinc1,1
  MOV yinc2,1
gLine6:
  MOV AX,[BP+16]
  CMP AX,[BP+12]
  JLE gLine7
  NEG xinc1
  NEG xinc2
gLine7:
  MOV AX,[BP+14]
  CMP AX,[BP+10]
  JLE gLine8
  NEG yinc1
  NEG yinc2
gLine8:
  MOV AX,[BP+6]     ; AL holds the color
  SUB AX,[BP+8]
  INC AX
  SHL EAX,16
  CDQ
  IDIV ECX
  PUSH EAX
  XOR EAX,EAX
  PUSH EAX
  MOV DX,[BP+16]    ; DX holds the current x coordinate
  MOV BX,[BP+14]    ; BX holds the current y coordinate
gLineLoop:
  CMP DX,ClipX1
  JL SkipgLinePixel
  CMP DX,ClipX2
  JG SkipgLinePixel
  CMP BX,ClipY1
  JL SkipgLinePixel
  CMP BX,ClipY2
  JG SkipgLinePixel
  MOV DI,BX
  MOV SI,BX
  SHL DI,8
  SHL SI,6
  ADD DI,SI
  ADD DI,DX
  MOV EAX,[BP-8]
  SHR EAX,16
  ADD AX,[BP+8]
  MOV ES:[DI],AL
SkipgLinePixel:
  MOV EAX,[BP-4]
  ADD [BP-8],EAX
  CMP d,0
  JL gLine9
  MOV SI,d
  ADD SI,dinc2
  MOV d,SI
  ADD DX,xinc2
  ADD BX,yinc2
  JMP gLine10
gLine9:
  MOV SI,d
  ADD SI,dinc1
  MOV d,SI
  ADD DX,xinc1
  ADD BX,yinc1
gLine10:
  DEC CX
  JNZ gLineLoop
  POP EAX
  POP EAX
  POP BP
  RET 14
DQBgline ENDP


; ---------------------------------------------------------------------------
; DQBellipse SUB
; purpose:
;   Draws an ellipse on specified layer with center in (x,y), and rx,ry as
;   the horizontal and vertical radiuses, with col color. The function works
;   for any radiuses ranging 0-255, otherwise you'll get unwanted results.
;   DQBellipse is affected by the clipping box.
; declaration:
;   DECLARE SUB DQBellipse(BYVAL Layer,BYVAL x,BYVAL y,BYVAL rx,BYVAL ry,
;                          BYVAL col)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBellipse
DQBellipse PROC
  ; Stack layout:
  ;
  ; 28  Layer
  ; 26  x
  ; 24  y
  ; 22  rx
  ; 20  ry
  ; 18  Col
  ; 16  Basic return segment
  ; 14  Basic return offset
  ; 12  BP
  ; 10  x
  ; 08  y
  ; 06  xe
  ; 04  ye
  ; 02  e
  ; 00  c
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+16]
  CALL GetLayerSeg
  MOV ES,CX
  SUB SP,12         ; Preserve stack space for internal variables
  MOV BP,SP
  MOV AX,[BP+22]
  CMP AX,0
  JNE NotVline
  MOV AX,[BP+18]
  MOV CX,[BP+20]
  NEG CX
eVline:
  MOV DX,[BP+26]
  MOV BX,[BP+24]
  ADD BX,CX
  EPIXEL
  INC CX
  CMP CX,[BP+20]
  JLE eVline
  JMP EndEllipse
NotVline:
  MOV AX,[BP+20]
  CMP AX,0
  JNE NotHline
  MOV AX,[BP+18]
  MOV CX,[BP+22]
  NEG CX
eHline:
  MOV DX,[BP+26]
  ADD DX,CX
  MOV BX,[BP+24]
  EPIXEL
  INC CX
  CMP CX,[BP+22]
  JLE eHline
  JMP EndEllipse
NotHline:
  CMP AX,[BP+22]
  JG OtherAxis
  XOR AX,AX
  MOV [BP+10],AX
  MOV [BP+6],AX
  MOV AX,[BP+20]
  MOV [BP+8],AX
  MOV AX,[BP+22]
  MOV BX,AX
  MUL BX
  MOV [BP+4],AX
  PUSH AX
  SHR AX,1
  NEG AX
  MOV [BP+2],AX
  POP AX
  XOR DX,DX
  MOV BX,[BP+20]
  DIV BX
  MOV [BP],AX
  MOV AX,[BP+18]
Circle1:
  MOV CX,[BP+2]
  CMP CX,0
  JG Circle3
Circle2:
  MOV DX,[BP+26]
  ADD DX,[BP+10]
  MOV BX,[BP+24]
  ADD BX,[BP+8]
  EPIXEL
  MOV DX,[BP+26]
  SUB DX,[BP+10]
  MOV BX,[BP+24]
  ADD BX,[BP+8]
  EPIXEL
  MOV DX,[BP+26]
  ADD DX,[BP+10]
  MOV BX,[BP+24]
  SUB BX,[BP+8]
  EPIXEL
  MOV DX,[BP+26]
  SUB DX,[BP+10]
  MOV BX,[BP+24]
  SUB BX,[BP+8]
  EPIXEL
  MOV BX,[BP+10]
  INC BX
  MOV [BP+10],BX
  MOV BX,[BP+6]
  ADD BX,[BP+20]
  MOV [BP+6],BX
  MOV BX,[BP+2]
  ADD BX,[BP+6]
  MOV [BP+2],BX
  CMP BX,0
  JLE Circle2
  JMP Circle4
Circle3:
  MOV DX,[BP+26]
  ADD DX,[BP+10]
  MOV BX,[BP+24]
  ADD BX,[BP+8]
  EPIXEL
  MOV DX,[BP+26]
  SUB DX,[BP+10]
  MOV BX,[BP+24]
  ADD BX,[BP+8]
  EPIXEL
  MOV DX,[BP+26]
  ADD DX,[BP+10]
  MOV BX,[BP+24]
  SUB BX,[BP+8]
  EPIXEL
  MOV DX,[BP+26]
  SUB DX,[BP+10]
  MOV BX,[BP+24]
  SUB BX,[BP+8]
  EPIXEL
Circle4:
  MOV BX,[BP+4]
  SUB BX,[BP]
  MOV [BP+4],BX
  MOV BX,[BP+2]
  SUB BX,[BP+4]
  MOV [BP+2],BX
  MOV BX,[BP+8]
  DEC BX
  MOV [BP+8],BX
  CMP BX,0
  JNZ Circle1
  MOV DX,[BP+26]
  ADD DX,[BP+10]
  MOV BX,[BP+24]
  EPIXEL
  MOV DX,[BP+26]
  SUB DX,[BP+10]
  MOV BX,[BP+24]
  EPIXEL
  JMP EndEllipse
OtherAxis:
  XOR AX,AX
  MOV [BP+10],AX
  MOV [BP+6],AX
  MOV AX,[BP+22]
  MOV [BP+8],AX
  MOV AX,[BP+20]
  MOV BX,AX
  MUL BX
  MOV [BP+4],AX
  PUSH AX
  SHR AX,1
  NEG AX
  MOV [BP+2],AX
  POP AX
  XOR DX,DX
  MOV BX,[BP+22]
  DIV BX
  MOV [BP],AX
  MOV AX,[BP+18]
Circle5:
  MOV CX,[BP+2]
  CMP CX,0
  JG Circle7
Circle6:
  MOV DX,[BP+26]
  ADD DX,[BP+8]
  MOV BX,[BP+24]
  ADD BX,[BP+10]
  EPIXEL
  MOV DX,[BP+26]
  SUB DX,[BP+8]
  MOV BX,[BP+24]
  ADD BX,[BP+10]
  EPIXEL
  MOV DX,[BP+26]
  ADD DX,[BP+8]
  MOV BX,[BP+24]
  SUB BX,[BP+10]
  EPIXEL
  MOV DX,[BP+26]
  SUB DX,[BP+8]
  MOV BX,[BP+24]
  SUB BX,[BP+10]
  EPIXEL
  MOV BX,[BP+10]
  INC BX
  MOV [BP+10],BX
  MOV BX,[BP+6]
  ADD BX,[BP+22]
  MOV [BP+6],BX
  MOV BX,[BP+2]
  ADD BX,[BP+6]
  MOV [BP+2],BX
  CMP BX,0
  JLE Circle6
  JMP Circle8
Circle7:
  MOV DX,[BP+26]
  ADD DX,[BP+8]
  MOV BX,[BP+24]
  ADD BX,[BP+10]
  EPIXEL
  MOV DX,[BP+26]
  SUB DX,[BP+8]
  MOV BX,[BP+24]
  ADD BX,[BP+10]
  EPIXEL
  MOV DX,[BP+26]
  ADD DX,[BP+8]
  MOV BX,[BP+24]
  SUB BX,[BP+10]
  EPIXEL
  MOV DX,[BP+26]
  SUB DX,[BP+8]
  MOV BX,[BP+24]
  SUB BX,[BP+10]
  EPIXEL
Circle8:
  MOV BX,[BP+4]
  SUB BX,[BP]
  MOV [BP+4],BX
  MOV BX,[BP+2]
  SUB BX,[BP+4]
  MOV [BP+2],BX
  MOV BX,[BP+8]
  DEC BX
  MOV [BP+8],BX
  CMP BX,0
  JNZ Circle5
  MOV DX,[BP+26]
  MOV BX,[BP+24]
  ADD BX,[BP+10]
  EPIXEL
  MOV DX,[BP+26]
  MOV BX,[BP+24]
  SUB BX,[BP+10]
  EPIXEL
EndEllipse:
  ADD SP,12
  POP BP
  RET 12
DQBellipse ENDP

; ---------------------------------------------------------------------------
; DQBbox SUB
; purpose:
;   Draws an empty box with x1,y1 and x2,y2 as the opposite corners with a
;   given color. Please note that must be x1<x2 and y1<y2; no checks are
;   done, and clipping is not supported to speed things up.
; declaration:
;   DECLARE SUB DQBbox(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                       BYVAL Col)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBbox
DQBbox PROC
  ; Stack layout:
  ;
  ; 16  Layer
  ; 14  x1
  ; 12  y1
  ; 10  x2
  ; 08  y2
  ; 06  Col
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+16]
  CALL GetLayerSeg
  MOV ES,CX
  MOV DI,[BP+12]
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+14]
  MOV CX,[BP+10]
  SUB CX,[BP+14]
  INC CX
  MOV AL,[BP+6]
  MOV AH,AL
  MOV DX,CX
  PUSH CX
  CMP CX,2
  JL BoxByteTest1
  SHR CX,1
  REP STOSW
BoxByteTest1:
  TEST DX,1
  JZ DrawBorders
  STOSB
DrawBorders:
  POP DX
  SUB DX,2
  MOV DI,[BP+12]
  INC DI
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+14]
  MOV CX,[BP+8]
  SUB CX,[BP+12]
  DEC CX
  PUSH CX
  CMP CX,0
  JLE LowerBorder
BorderLoop:
  STOSB
  ADD DI,DX
  STOSB
  ADD DI,318
  SUB DI,DX
  DEC CX
  JNZ BorderLoop
LowerBorder:
  POP CX
  CMP CX,0
  JL EndBox
  MOV CX,[BP+10]
  SUB CX,[BP+14]
  INC CX
  MOV DX,CX
  CMP CX,2
  JL BoxByteTest2
  SHR CX,1
  REP STOSW
BoxByteTest2:
  TEST DX,1
  JZ EndBox
  STOSB
EndBox:
  POP BP
  RET 12
DQBbox ENDP

; ---------------------------------------------------------------------------
; DQBboxf SUB
; purpose:
;   Draws an full box with x1,y1 and x2,y2 as the opposite corners with a
;   given color. Please note that must be x1<x2 and y1<y2; no checks are
;   done and clipping is not supported to speed things up.
; declaration:
;   DECLARE SUB DQBboxf(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                       BYVAL Col)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBboxf
DQBboxf PROC
  ; Stack layout:
  ;
  ; 16  Layer
  ; 14  x1
  ; 12  y1
  ; 10  x2
  ; 08  y2
  ; 06  Col
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+16]
  CALL GetLayerSeg
  MOV ES,CX
  MOV DI,[BP+12]
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+14]
  MOV CX,[BP+10]
  SUB CX,[BP+14]
  INC CX
  MOV DX,[BP+8]
  SUB DX,[BP+12]
  INC DX
  MOV AL,[BP+6]
  MOV AH,AL
BoxfLoop:
  PUSH CX
  SHR CX,1
  CMP CX,0
  JE BoxfByteTest
  REP STOSW
BoxfByteTest:
  POP CX
  TEST CX,1
  JZ NextBoxfLine
  STOSB
NextBoxfLine:
  ADD DI,320
  SUB DI,CX
  DEC DX
  JNZ BoxfLoop
  POP BP
  RET 12
DQBboxf ENDP

; ---------------------------------------------------------------------------
; DQBpaint SUB
; purpose:
;   Fills an area with Col color. Acts like PAINT, but fills every pixel until
;   it hits pixels with colors different from the one under (x,y)
; declaration:
;   DECLARE SUB DQBpaint(BYVAL Layer,BYVAL x,BYVAL y,BYVAL Col)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBpaint
DQBpaint PROC
  ; Stack layout:
  ;
  ; 12    Layer
  ; 10    x
  ; 08    y
  ; 06    Col
  ; 04    Basic return segment
  ; 02    Basic return offset
  ; 00    BP
  PUSH BP
  MOV BP,SP
  MOV CX,2559
  MOV AX,@DATA
  MOV ES,AX
  MOV DI,OFFSET PixData
  XOR AX,AX
  REP STOSW
  MOV BX,[BP+12]
  CALL GetLayerSeg
  MOV ES,CX
  MOV BX,[BP+8]
  MOV DI,BX
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+10]
  XOR CH,CH
  MOV CL,ES:[DI]    ; CX holds our background color to fill
  CMP CX,[BP+6]
  JE EndPaint
  MOV FirstEntry,0
  MOV LastEntry,1
OuterLoop:
  MOV SI,FirstEntry
  SHL SI,2
  MOV AX,PixData[SI]
  MOV fx,AX
  MOV AX,PixData[SI+2]
  MOV fy,AX
InnerLoop1:
  MOV DX,[BP+10]
  ADD DX,fx
  MOV BX,[BP+8]
  ADD BX,fy
  GETPIXEL
  CMP AX,CX
  JNE EndLoop1
  MOV AX,[BP+6]
  MOV ES:[DI],AL
  DEC BX
  GETPIXEL
  CMP AX,CX
  JNE Skip1
  MOV SI,LastEntry
  SHL SI,2
  MOV AX,fx
  MOV PixData[SI],AX
  MOV AX,fy
  DEC AX
  MOV PixData[SI+2],AX
  INC LastEntry
  CMP LastEntry,1279
  JNE Skip1
  MOV LastEntry,0
Skip1:
  ADD BX,2
  GETPIXEL
  CMP AX,CX
  JNE Skip2
  MOV SI,LastEntry
  SHL SI,2
  MOV AX,fx
  MOV PixData[SI],AX
  MOV AX,fy
  INC AX
  MOV PixData[SI+2],AX
  INC LastEntry
  CMP LastEntry,1279
  JNE Skip2
  MOV LastEntry,0
Skip2:
  INC fx
  JMP InnerLoop1
EndLoop1:
  MOV SI,FirstEntry
  SHL SI,2
  MOV AX,PixData[SI]
  DEC AX
  MOV fx,AX
  MOV AX,PixData[SI+2]
  MOV fy,AX
InnerLoop2:
  MOV DX,[BP+10]
  ADD DX,fx
  MOV BX,[BP+8]
  ADD BX,fy
  GETPIXEL
  CMP AX,CX
  JNE EndLoop2
  MOV AX,[BP+6]
  MOV ES:[DI],AL
  DEC BX
  GETPIXEL
  CMP AX,CX
  JNE Skip3
  MOV SI,LastEntry
  SHL SI,2
  MOV AX,fx
  MOV PixData[SI],AX
  MOV AX,fy
  DEC AX
  MOV PixData[SI+2],AX
  INC LastEntry
  CMP LastEntry,1279
  JNE Skip3
  MOV LastEntry,0
Skip3:
  ADD BX,2
  GETPIXEL
  CMP AX,CX
  JNE Skip4
  MOV SI,LastEntry
  SHL SI,2
  MOV AX,fx
  MOV PixData[SI],AX
  MOV AX,fy
  INC AX
  MOV PixData[SI+2],AX
  INC LastEntry
  CMP LastEntry,1279
  JNE Skip4
  MOV LastEntry,0
Skip4:
  DEC fx
  JMP InnerLoop2
EndLoop2:
  INC FirstEntry
  CMP FirstEntry,1279
  JNE Skip5
  MOV FirstEntry,0
Skip5:
  MOV AX,FirstEntry
  CMP AX,LastEntry
  JNE OuterLoop
EndPaint:
  POP BP
  RET 8
DQBpaint ENDP

; ---------------------------------------------------------------------------
; DQBscroll SUB
; purpose:
;   Scrolls specified layer with dx and dy increments. It's up to the
;   programmer to draw the layer area that should be replaced.
; declaration:
;   DECLARE SUB DQBscroll(BYVAL Layer,BYVAL dx,BYVAL dy)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBscroll
DQBscroll PROC
  ; Stack layout:
  ;
  ; 12    Layer
  ; 10    dx
  ; 08    dy
  ; 06    Basic return segment
  ; 04    Basic return offset
  ; 02    DS
  ; 00    BP
  PUSH BP
  PUSH DS
  MOV BP,SP
  MOV BX,[BP+12]
  CALL GetLayerSeg
  MOV DS,CX        ; Sets both source and destination segments to the
  MOV ES,CX        ; specified layer segment
  MOV SI,[BP+10]   ; Get Horz. scroll distance
  MOV AX,[BP+8]    ; Get Vert. scroll distance
  MOV BX,320
  IMUL BX
  ADD AX,SI
  OR AX,AX
  JNS Positive
  NEG AX
  MOV CX,64000
  SUB CX,AX
  MOV SI,AX
  XOR DI,DI
  CLD
  REP MOVSB
  POP DS
  POP BP
  RET 6
Positive:
  MOV CX,64000
  SUB CX,AX
  MOV SI,63999
  SUB SI,AX
  MOV DI,63999
  STD
  REP MOVSB
  CLD
  POP DS
  POP BP
  RET 6
DQBscroll ENDP

; ---------------------------------------------------------------------------
; DQBscrollArea SUB
; purpose:
;   Scrolls an area on specified layer in specified direction. It's up to the
;   programmer to draw the layer area that should be replaced.
; declaration:
;   DECLARE SUB DQBscrollArea(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                             BYVAL Direction)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBscrollArea
DQBscrollArea PROC
  ; Stack layout:
  ;
  ; 18  Layer
  ; 16  x1
  ; 14  y1
  ; 12  x2
  ; 10  y2
  ; 08  Direction
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+18]
  CALL GetLayerSeg  ; ]
  MOV DS,CX         ;  |- Sets both source and destination segments to the
  MOV ES,CX         ; ]   specified layer segment
  MOV AX,[BP+8]
  CMP AX,3
  JE sRight
  CMP AX,2
  JE sLeft
  CMP AX,1
  JE sDown
  MOV DI,[BP+14]
  MOV AX,DI
  SHL DI,8
  SHL AX,6
  ADD DI,AX
  ADD DI,[BP+16]
  MOV SI,DI
  ADD SI,320
  MOV CX,[BP+12]
  SUB CX,[BP+16]
  INC CX
  MOV DX,CX
  MOV BX,[BP+14]
  INC BX
sUpLoop:
  REP MOVSB
  SUB SI,DX
  MOV DI,SI
  ADD SI,320
  MOV CX,DX
  INC BX
  CMP BX,[BP+10]
  JL sUpLoop
  POP BP
  POP DS
  RET 12
sDown:
  MOV DI,[BP+10]
  MOV AX,DI
  SHL DI,8
  SHL AX,6
  ADD DI,AX
  ADD DI,[BP+16]
  MOV SI,DI
  SUB SI,320
  MOV CX,[BP+12]
  SUB CX,[BP+16]
  INC CX
  MOV DX,CX
  MOV BX,[BP+14]
  INC BX
sDownLoop:
  REP MOVSB
  SUB SI,DX
  MOV DI,SI
  SUB SI,320
  MOV CX,DX
  INC BX
  CMP BX,[BP+10]
  JL sDownLoop
  POP BP
  POP DS
  RET 12
sLeft:
  MOV DI,[BP+14]
  MOV AX,DI
  SHL DI,8
  SHL AX,6
  ADD DI,AX
  ADD DI,[BP+16]
  MOV SI,DI
  INC SI
  MOV CX,[BP+12]
  SUB CX,[BP+16]
  MOV DX,CX
  MOV BX,[BP+14]
sLeftLoop:
  REP MOVSB
  SUB SI,DX
  ADD SI,320
  MOV DI,SI
  DEC DI
  MOV CX,DX
  INC BX
  CMP BX,[BP+10]
  JLE sLeftLoop
  POP BP
  POP DS
  RET 12
sRight:
  MOV DI,[BP+14]
  MOV AX,DI
  SHL DI,8
  SHL AX,6
  ADD DI,AX
  ADD DI,[BP+12]
  MOV SI,DI
  DEC SI
  MOV CX,[BP+12]
  SUB CX,[BP+16]
  MOV DX,CX
  MOV BX,[BP+14]
  STD
sRightLoop:
  REP MOVSB
  ADD SI,DX
  ADD SI,320
  MOV DI,SI
  INC DI
  MOV CX,DX
  INC BX
  CMP BX,[BP+10]
  JLE sRightLoop
  CLD
  POP BP
  POP DS
  RET 12
DQBscrollArea ENDP

; ---------------------------------------------------------------------------
; DQBsetTransPut SUB
; purpose:
;   Sets the transparent sprite put mode. Next DQBput calls will draw
;   transparent sprites.
; declaration:
;   DECLARE SUB DQBsetTransPut()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetTransPut
DQBsetTransPut PROC
  MOV PutMode,0
  RET
DQBsetTransPut ENDP

; ---------------------------------------------------------------------------
; DQBsetSolidPut SUB
; purpose:
;   Sets the solid sprite put mode. Next DQBput calls will draw solid sprites.
; declaration:
;   DECLARE SUB DQBsetSolidPut()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetSolidPut
DQBsetSolidPut PROC
  MOV PutMode,1
  RET
DQBsetSolidPut ENDP

; ---------------------------------------------------------------------------
; DQBget SUB
; purpose:
;   Gets data for a sprite and puts the info into the given sprite array to
;   be used with DQBput. DQBget sprite format is different from the one used
;   by normal GET and PUT, so pay attention. It must be x1<x2 and y1<y2; the
;   routine is optimized if the sprite width is a multiple of 2 or 4 (better)
; declaration:
;   DECLARE SUB DQBget(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                       BYVAL BufferSeg,BYVAL BufferOff)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBget
DQBget PROC
  ; Stack layout (after startup):
  ;
  ; 20  (24)  Layer
  ; 18  (22)  x1
  ; 16  (20)  y1
  ; 14  (18)  x2
  ; 12  (16)  y2
  ; 10  (14)  Buffer segment
  ; 08  (12)  Buffer offset
  ; 06  (10)  Basic return segment
  ; 04  (08)  Basic return offset
  ; 02  (06)  DS
  ; 00  (04)  BP
  ;     (02)  Height
  ;     (00)  Width
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+14]
  SUB AX,[BP+18]
  INC AX            ; AX holds the width
  MOV BX,[BP+12]
  SUB BX,[BP+16]
  INC BX            ; BX holds the height
  PUSH BX           ; Pushes the height onto the stack
  PUSH AX           ; Pushes the width onto the stack
  MOV BP,SP         ; Gets the new stack pointer
  MOV BX,[BP+24]
  CALL GetLayerSeg
  MOV DS,CX         ; Sets the source segment as the specified layer segment
  MOV SI,[BP+20]
  MOV BX,SI
  SHL SI,8
  SHL BX,6
  ADD SI,BX
  ADD SI,[BP+22]    ; SI now points to (x1,y1) onto the layer
  MOV BX,[BP+14]
  MOV ES,BX
  MOV DI,[BP+12]    ; ES:DI points to the buffer
  MOV DX,[BP+2]     ; DX holds the height of the sprite...
  MOV BX,[BP]       ; ...and BX its width
  SHL BX,3          ; Multiply width by 8 for GET PUT compatibility
  MOV ES:[DI],BX    ; Stores the width and the height into the sprite buffer
  MOV ES:[DI+2],DX  ; for later use with DQBput
  ADD DI,4
  MOV BX,[BP]
  AND BX,3
  CMP BX,0
  JE DWordGetLoop   ; Width is multiple of 4: DWORDs can be used (really fast)
  MOV BX,[BP]
  AND BX,1
  CMP BX,0
  JE WordGetLoop    ; Width is multiple of 2: let's use WORDs (fast)
ByteGetLoop:
  MOV CX,[BP]       ; No optimization is possible: using bytes copy (slow)
  REP MOVSB         ; Copies "width" bytes
  SUB SI,[BP]
  ADD SI,320
  DEC DX
  JNZ ByteGetLoop
  JMP EndGet
WordGetLoop:
  MOV CX,[BP]
  SHR CX,1
  REP MOVSW         ; Copies "width]2" words
  SUB SI,[BP]
  ADD SI,320
  DEC DX
  JNZ WordGetLoop
  JMP EndGet
DWordGetLoop:
  MOV CX,[BP]
  SHR CX,2
  REP MOVSD         ; Copies "width 4" dwords
  SUB SI,[BP]
  ADD SI,320
  DEC DX
  JNZ DWordGetLoop
EndGet:
  POP BX
  POP BX
  POP BP
  POP DS
  RET 14
DQBget ENDP

; ---------------------------------------------------------------------------
; DQBput SUB
; purpose:
;   Draws a given sprite at specified coordinates on the given layer. If the
;   PutMode internal variable is 0, black pixels (color 0 assumed) are
;   skipped, allowing a transparent sprite drawing. The sprite automatically
;   clips when it reaches the actual clipping box borders; any x and y value
;   are accepted, as long as they're INTEGERs. The sprite can have been
;   stored into an array with DQBget as well as with GET, as the data format
;   is the same.
; declaration:
;   DECLARE SUB DQBput(BYVAL Layer,BYVAL x,BYVAL y,BYVAL BufferSeg,
;                       BYVAL BufferOff)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBput
DQBput PROC
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
  MOV SI,[BP+08]    ; SI points to the buffer offset
  MOV BX,[BP+16]    ; Gets the layer number...
  CALL GetLayerSeg
  MOV ES,CX         ; ...and sets ES to its segment
  MOV DI,[BP+12]    ; DI contains the y value
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
  MOV BX,[BP+10]
  MOV DS,BX         ; DS points to the buffer segment
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+14]    ; DI points to (x,y-1) on specified layer
  LODSW
  SHR AX,3          ; Divide width by 8 for GET PUT compatibility
  PUSH AX           ; Gets the sprite width and puts it onto the stack
  LODSW
  MOV AH,AL         ; Sets AH to the height of the sprite
  INC AH
  XOR AL,AL
  MOV BP,SP
  MOV BX,[BP+24]    ; BX holds the value y-1
  DEC BX
  ADD DI,[BP]
  CMP [BP+10],AL    ; Are we in solid put mode?
  JNE SolidYloop    ; Yes: jump to the solid put loop
Yloop:
  ADD SI,[BP]
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  DEC AH
  JZ EndPut         ; Last sprite line reached
  CMP BX,[BP+4]     ; Are we out of the upper clipping border?
  JL Yloop          ; Yes: increase the line counter
  CMP BX,[BP+2]     ; Are we out of the lower clipping border?
  JG EndPut         ; Yes: exit DQBput
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+26]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
Xloop:
  LODSB             ; Gets a pixel from the buffer
  CMP AL,0
  JE SkipPixel      ; Transparent pixel: skip it!
  CMP DX,[BP+8]
  JL SkipPixel      ; Out of left layer border: skip it!
  CMP DX,[BP+6]
  JG SkipPixel      ; Out of right layer border: skip it!
  STOSB             ; All checks done: writes pixel on the layer
  INC DX            ; Next pixel
  LOOP Xloop        ; Repeats sprite width times
  JMP Yloop         ; Next line
SkipPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  LOOP Xloop        ; Repeats sprite width times
  JMP Yloop         ; Next line
SolidYloop:
  ADD SI,[BP]
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  DEC AH
  JZ EndPut         ; Last sprite line reached?
  CMP BX,[BP+4]     ; Are we out of the upper clipping border?
  JL SolidYloop     ; Yes: increase the line counter
  CMP BX,[BP+2]     ; Are we out of the lower clipping border?
  JG EndPut         ; Yes: exit DQBput
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+26]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
SolidXloop:
  LODSB             ; Gets a pixel from the buffer
  CMP DX,[BP+8]
  JL SkipSolidPixel    ; Out of left layer border: skip it!
  CMP DX,[BP+6]
  JG SkipSolidPixel    ; Out of right layer border: skip it!
  STOSB             ; All checks done: writes pixel on the layer
  INC DX            ; Next pixel
  LOOP SolidXloop   ; Repeats sprite width times
  JMP SolidYloop    ; Next line
SkipSolidPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  LOOP SolidXloop   ; Repeats sprite width times
  JMP SolidYloop    ; Next line
EndPut:
  POP BX
  POP BX
  POP BX
  POP BX
  POP BX
  POP BX
  POP BP
  POP DS
  RET 10
DQBput ENDP


END
