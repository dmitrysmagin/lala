; ---------------------------------------------------------------------------
;
; DirectQB 3D FUNCTIONS module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN ClipX1:WORD
EXTRN ClipX2:WORD
EXTRN ClipY1:WORD
EXTRN ClipY2:WORD
EXTRN BMapActive:BYTE
EXTRN BMapSeg:WORD
EXTRN BMapFirst:BYTE
EXTRN BMapLast:BYTE

EXTRN GetLayerSeg:FAR


.DATA
SX            DW  ?               ; Start x value for current scanline (3D)
EX            DW  ?               ; End x value for current scanline (3D)
StartX        DW  200 dup(?)      ; Start x value for each scanline (3D)
EndX          DW  200 dup(?)      ; End x value for each scanline (3D)
StartA        DW  200 dup(?)      ; ]  Additional scanline arrays for gouraud
EndA          DW  200 dup(?)      ;  | and textured triangle routines (3D)
StartB        DW  200 dup(?)      ;  | (used as color arrays by DQBgtri and
EndB          DW  200 dup(?)      ; ]  as u,v arrays by DQBttri)
FirstY        DW  ?               ; First triangle line
LastY         DW  ?               ; Last triangle line
TextureLen    DB  6               ; Texture width (in bits to shift)
TextureFix    DW  63              ; Texture fix number for texture wrapping


.CODE

; ---------------------------------------------------------------------------
; DQBtri SUB
; purpose:
;   Draws a flat shaded triangle with (x1,y1), (x2,y2) and (x3,y3) as
;   vertex, with col color, on specified layer.
; declaration:
;   DECLARE SUB DQBtri(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                      BYVAL x3,BYVAL y3,BYVAL Col)
; ---------------------------------------------------------------------------
PUBLIC DQBtri
DQBtri PROC
  ; Stack layout:
  ;
  ; 20  Layer
  ; 18  x1
  ; 16  y1
  ; 14  x2
  ; 12  y2
  ; 10  x3
  ; 08  y3
  ; 06  Col
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+20]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+16]
  MOV BX,[BP+12]
  CMP AX,BX
  JLE Swap12
  MOV [BP+16],BX
  MOV [BP+12],AX
  MOV AX,[BP+18]
  MOV BX,[BP+14]
  MOV [BP+18],BX
  MOV [BP+14],AX
Swap12:
  MOV AX,[BP+16]
  MOV BX,[BP+8]
  CMP AX,BX
  JLE Swap13
  MOV [BP+16],BX
  MOV [BP+8],AX
  MOV AX,[BP+18]
  MOV BX,[BP+10]
  MOV [BP+18],BX
  MOV [BP+10],AX
Swap13:
  MOV AX,[BP+12]
  MOV BX,[BP+8]
  CMP AX,BX
  JLE Swap23
  MOV [BP+12],BX
  MOV [BP+8],AX
  MOV AX,[BP+14]
  MOV BX,[BP+10]
  MOV [BP+14],BX
  MOV [BP+10],AX
Swap23:
  XOR SI,SI
  MOV AX,08000h
InitXtri:
  MOV StartX[SI],AX
  ADD SI,2
  CMP SI,400
  JL InitXtri
  MOV AX,ClipY1
  MOV FirstY,AX
  MOV BX,[BP+16]
  CMP BX,AX
  JL @F
  MOV FirstY,BX
@@:
  CMP BX,ClipY2
  JG EndTri
  MOV AX,ClipY2
  MOV LastY,AX
  MOV BX,[BP+8]
  CMP BX,AX
  JG @F
  MOV LastY,BX
@@:
  XOR ECX,ECX
  MOV BX,[BP+16]
  MOV CX,[BP+12]
  SUB CX,BX
  JNZ Connect12
  CMP BX,ClipY1
  JL End12
  CMP BX,ClipY2
  JG End12
  SHL BX,1
  MOV AX,[BP+18]
  MOV StartX[BX],AX
  JMP End12
Connect12:
  MOV AX,[BP+14]
  SUB AX,[BP+18]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+18]
  SHL EDX,16
  MOV BX,[BP+16]
Step12:
  CMP BX,ClipY1
  JL Next12
  CMP BX,ClipY2
  JG Next12
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
Next12:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+12]
  JLE Step12
End12:
  XOR ECX,ECX
  MOV BX,[BP+12]
  MOV CX,[BP+8]
  SUB CX,BX
  JNZ Connect23
  CMP BX,ClipY1
  JL End23
  CMP BX,ClipY2
  JG End23
  SHL BX,1
  MOV AX,[BP+14]
  MOV StartX[BX],AX
  JMP End23
Connect23:
  MOV AX,[BP+10]
  SUB AX,[BP+14]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+14]
  SHL EDX,16
  MOV BX,[BP+12]
Step23:
  CMP BX,ClipY1
  JL Next23
  CMP BX,ClipY2
  JG Next23
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
Next23:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+8]
  JLE Step23
End23:
  XOR ECX,ECX
  MOV BX,[BP+16]
  MOV CX,[BP+8]
  SUB CX,BX
  JNZ Connect13
  CMP BX,ClipY1
  JL End13
  CMP BX,ClipY2
  JG End13
  SHL BX,1
  MOV AX,[BP+18]
  MOV EndX[BX],AX
  MOV DX,StartX[BX]
  CMP DX,AX
  JL End13
  MOV StartX[BX],AX
  MOV EndX[BX],DX
  JMP End13
Connect13:
  MOV AX,[BP+10]
  SUB AX,[BP+18]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+18]
  SHL EDX,16
  MOV BX,[BP+16]
Step13:
  CMP BX,ClipY1
  JL Next13
  CMP BX,ClipY2
  JG Next13
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV EndX[SI],CX
  CMP StartX[SI],CX
  JL Next13
  MOV DI,StartX[SI]
  MOV StartX[SI],CX
  MOV EndX[SI],DI
Next13:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+8]
  JLE Step13
End13:
  MOV CX,FirstY
  MOV AX,[BP+6]
  MOV DI,CX
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
DrawTri:
  MOV SI,CX
  SHL SI,1
  CMP StartX[SI],08000h
  JE SkipTriLine
  MOV BX,StartX[SI]
  MOV DX,EndX[SI]
  CMP BX,ClipX2
  JG SkipTriLine
  CMP DX,ClipX1
  JL SkipTriLine
  CMP DX,ClipX2
  JL @F
  MOV DX,ClipX2
@@:
  CMP BX,ClipX1
  JG DrawTriLine
  MOV BX,ClipX1
DrawTriLine:
  MOV ES:[BX+DI],AL
  INC BX
  CMP BX,DX
  JLE DrawTriLine
SkipTriLine:
  ADD DI,320
  INC CX
  CMP CX,LastY
  JLE DrawTri
EndTri:
  POP BP
  RET 16
DQBtri ENDP

; ---------------------------------------------------------------------------
; DQBbtri SUB
; purpose:
;   Draws a flat shaded triangle with (x1,y1), (x2,y2) and (x3,y3) as
;   vertex, with col color, on specified layer. Triangle color is blended
;   with the background by using the current blender map.
; declaration:
;   DECLARE SUB DQBbtri(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                      BYVAL x3,BYVAL y3,BYVAL Col,BYVAL BMap)
; ---------------------------------------------------------------------------
PUBLIC DQBbtri
DQBbtri PROC
  ; Stack layout:
  ;
  ; 22  Layer
  ; 20  x1
  ; 18  y1
  ; 16  x2
  ; 14  y2
  ; 12  x3
  ; 10  y3
  ; 08  Col
  ; 06  BMap
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+6]
  DEC SI
  CMP BMapActive[SI],0
  JE EndBtri
  SHL SI,1
  MOV AX,BMapSeg[SI]
  SHR SI,1
  MOV GS,AX
  MOV BX,[BP+22]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+18]
  MOV BX,[BP+14]
  CMP AX,BX
  JLE bSwap12
  MOV [BP+18],BX
  MOV [BP+14],AX
  MOV AX,[BP+20]
  MOV BX,[BP+16]
  MOV [BP+20],BX
  MOV [BP+16],AX
bSwap12:
  MOV AX,[BP+18]
  MOV BX,[BP+10]
  CMP AX,BX
  JLE bSwap13
  MOV [BP+18],BX
  MOV [BP+10],AX
  MOV AX,[BP+20]
  MOV BX,[BP+12]
  MOV [BP+20],BX
  MOV [BP+12],AX
bSwap13:
  MOV AX,[BP+14]
  MOV BX,[BP+10]
  CMP AX,BX
  JLE bSwap23
  MOV [BP+14],BX
  MOV [BP+10],AX
  MOV AX,[BP+16]
  MOV BX,[BP+12]
  MOV [BP+16],BX
  MOV [BP+12],AX
bSwap23:
  XOR SI,SI
  MOV AX,08000h
InitXbtri:
  MOV StartX[SI],AX
  ADD SI,2
  CMP SI,400
  JL InitXbtri
  MOV AX,ClipY1
  MOV FirstY,AX
  MOV BX,[BP+18]
  CMP BX,AX
  JL @F
  MOV FirstY,BX
@@:
  CMP BX,ClipY2
  JG EndbTri
  MOV AX,ClipY2
  MOV LastY,AX
  MOV BX,[BP+10]
  CMP BX,AX
  JG @F
  MOV LastY,BX
@@:
  XOR ECX,ECX
  MOV BX,[BP+18]
  MOV CX,[BP+14]
  SUB CX,BX
  JNZ bConnect12
  CMP BX,ClipY1
  JL bEnd12
  CMP BX,ClipY2
  JG bEnd12
  SHL BX,1
  MOV AX,[BP+20]
  MOV StartX[BX],AX
  JMP bEnd12
bConnect12:
  MOV AX,[BP+16]
  SUB AX,[BP+20]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+20]
  SHL EDX,16
  MOV BX,[BP+18]
bStep12:
  CMP BX,ClipY1
  JL bNext12
  CMP BX,ClipY2
  JG bNext12
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
bNext12:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+14]
  JLE bStep12
bEnd12:
  XOR ECX,ECX
  MOV BX,[BP+14]
  MOV CX,[BP+10]
  SUB CX,BX
  JNZ bConnect23
  CMP BX,ClipY1
  JL bEnd23
  CMP BX,ClipY2
  JG bEnd23
  SHL BX,1
  MOV AX,[BP+16]
  MOV StartX[BX],AX
  JMP bEnd23
bConnect23:
  MOV AX,[BP+12]
  SUB AX,[BP+16]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+16]
  SHL EDX,16
  MOV BX,[BP+14]
bStep23:
  CMP BX,ClipY1
  JL bNext23
  CMP BX,ClipY2
  JG bNext23
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
bNext23:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+10]
  JLE bStep23
bEnd23:
  XOR ECX,ECX
  MOV BX,[BP+18]
  MOV CX,[BP+10]
  SUB CX,BX
  JNZ bConnect13
  CMP BX,ClipY1
  JL bEnd13
  CMP BX,ClipY2
  JG bEnd13
  SHL BX,1
  MOV AX,[BP+20]
  MOV EndX[BX],AX
  MOV DX,StartX[BX]
  CMP DX,AX
  JL bEnd13
  MOV StartX[BX],AX
  MOV EndX[BX],DX
  JMP bEnd13
bConnect13:
  MOV AX,[BP+12]
  SUB AX,[BP+20]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+20]
  SHL EDX,16
  MOV BX,[BP+18]
bStep13:
  CMP BX,ClipY1
  JL bNext13
  CMP BX,ClipY2
  JG bNext13
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV EndX[SI],CX
  CMP StartX[SI],CX
  JL bNext13
  MOV DI,StartX[SI]
  MOV StartX[SI],CX
  MOV EndX[SI],DI
bNext13:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+10]
  JLE bStep13
bEnd13:
  MOV SI,[BP+6]
  DEC SI
  MOV AL,BMapFirst[SI]
  MOV AH,BMapLast[SI]
  PUSH AX
  MOV BP,SP
  MOV CX,FirstY
  MOV AH,BYTE PTR [BP+10]
  MOV DI,CX
  MOV SI,DI
  SHL DI,8
  SHL SI,6
  ADD DI,SI
DrawbTri:
  MOV SI,CX
  SHL SI,1
  CMP StartX[SI],08000h
  JE SkipbTriLine
  MOV BX,StartX[SI]
  MOV DX,EndX[SI]
  CMP BX,ClipX2
  JG SkipbTriLine
  CMP DX,ClipX1
  JL SkipbTriLine
  CMP DX,ClipX2
  JL @F
  MOV DX,ClipX2
@@:
  CMP BX,ClipX1
  JG @F
  MOV BX,ClipX1
@@:
  MOV EX,DX
DrawbTriLine:
  MOV DH,AH
  CMP DH,[BP]
  JB @F
  CMP DH,[BP+1]
  JA @F
  MOV DL,ES:[BX+DI]
  SUB DH,[BP]
  XCHG DX,BX
  MOV AL,GS:[BX]
  XCHG DX,BX
  MOV DH,AL
@@:
  MOV ES:[BX+DI],DH
  INC BX
  CMP BX,EX
  JLE DrawbTriLine
SkipbTriLine:
  ADD DI,320
  INC CX
  CMP CX,LastY
  JLE DrawbTri
  POP AX
EndBtri:
  POP BP
  RET 18
DQBbtri ENDP

; ---------------------------------------------------------------------------
; DQBgtri SUB
; purpose:
;   Draws a gouraud shaded triangle with (x1,y1), (x2,y2) and (x3,y3) as
;   vertex, with their own colors c1, c2 and c3, on specified layer.
; declaration:
;   DECLARE SUB DQBtri(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL c1,BYVAL x2,
;                      BYVAL y2,BYVAL c2,BYVAL x3,BYVAL y3,BYVAL c3)
; ---------------------------------------------------------------------------
PUBLIC DQBgtri
DQBgtri PROC
  ; Stack layout:
  ;
  ; 24  Layer
  ; 22  x1
  ; 20  y1
  ; 18  c1
  ; 16  x2
  ; 14  y2
  ; 12  c2
  ; 10  x3
  ; 08  y3
  ; 06  c3
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+24]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+20]
  MOV BX,[BP+14]
  CMP AX,BX
  JLE gSwap12
  MOV [BP+20],BX
  MOV [BP+14],AX
  MOV AX,[BP+22]
  MOV BX,[BP+16]
  MOV [BP+22],BX
  MOV [BP+16],AX
  MOV AX,[BP+18]
  MOV BX,[BP+12]
  MOV [BP+18],BX
  MOV [BP+12],AX
gSwap12:
  MOV AX,[BP+20]
  MOV BX,[BP+8]
  CMP AX,BX
  JLE gSwap13
  MOV [BP+20],BX
  MOV [BP+8],AX
  MOV AX,[BP+22]
  MOV BX,[BP+10]
  MOV [BP+22],BX
  MOV [BP+10],AX
  MOV AX,[BP+18]
  MOV BX,[BP+6]
  MOV [BP+18],BX
  MOV [BP+6],AX
gSwap13:
  MOV AX,[BP+14]
  MOV BX,[BP+8]
  CMP AX,BX
  JLE gSwap23
  MOV [BP+14],BX
  MOV [BP+8],AX
  MOV AX,[BP+16]
  MOV BX,[BP+10]
  MOV [BP+16],BX
  MOV [BP+10],AX
  MOV AX,[BP+12]
  MOV BX,[BP+6]
  MOV [BP+12],BX
  MOV [BP+6],AX
gSwap23:
  XOR SI,SI
  MOV AX,08000h
InitXgtri:
  MOV StartX[SI],AX
  ADD SI,2
  CMP SI,400
  JL InitXgtri
  MOV AX,ClipY1
  MOV FirstY,AX
  MOV BX,[BP+20]
  CMP BX,AX
  JL @F
  MOV FirstY,BX
@@:
  CMP BX,ClipY2
  JG EndgTri
  MOV AX,ClipY2
  MOV LastY,AX
  MOV BX,[BP+8]
  CMP BX,AX
  JG @F
  MOV LastY,BX
@@:
  XOR ECX,ECX
  MOV BX,[BP+20]
  MOV CX,[BP+14]
  SUB CX,BX
  JNZ gConnect12
  CMP BX,ClipY1
  JL gEnd12
  CMP BX,ClipY2
  JG gEnd12
  SHL BX,1
  MOV AX,[BP+22]
  MOV StartX[BX],AX
  MOV AX,[BP+18]
  MOV StartA[BX],AX
  JMP gEnd12
gConnect12:
  PUSH ECX
  MOV AX,[BP+12]
  SUB AX,[BP+18]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+18]
  SHL EDX,16
  MOV BX,[BP+20]
colStep12:
  CMP BX,0
  JL colNext12
  CMP BX,199
  JG colNext12
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartA[SI],CX
colNext12:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+14]
  JLE colStep12
  POP ECX
  MOV AX,[BP+16]
  SUB AX,[BP+22]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+22]
  SHL EDX,16
  MOV BX,[BP+20]
gStep12:
  CMP BX,ClipY1
  JL gNext12
  CMP BX,ClipY2
  JG gNext12
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
gNext12:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+14]
  JLE gStep12
gEnd12:
  XOR ECX,ECX
  MOV BX,[BP+14]
  MOV CX,[BP+8]
  SUB CX,BX
  JNZ gConnect23
  CMP BX,ClipY1
  JL gEnd23
  CMP BX,ClipY2
  JG gEnd23
  SHL BX,1
  MOV AX,[BP+16]
  MOV StartX[BX],AX
  MOV AX,[BP+12]
  MOV StartA[BX],AX
  JMP gEnd23
gConnect23:
  PUSH ECX
  MOV AX,[BP+6]
  SUB AX,[BP+12]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+12]
  SHL EDX,16
  MOV BX,[BP+14]
colStep23:
  CMP BX,0
  JL colNext23
  CMP BX,199
  JG colNext23
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartA[SI],CX
colNext23:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+8]
  JLE colStep23
  POP ECX
  MOV AX,[BP+10]
  SUB AX,[BP+16]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+16]
  SHL EDX,16
  MOV BX,[BP+14]
gStep23:
  CMP BX,ClipY1
  JL gNext23
  CMP BX,ClipY2
  JG gNext23
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
gNext23:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+8]
  JLE gStep23
gEnd23:
  XOR ECX,ECX
  MOV BX,[BP+20]
  MOV CX,[BP+8]
  SUB CX,BX
  JNZ gConnect13
  CMP BX,ClipY1
  JL gEnd13
  CMP BX,ClipY2
  JG gEnd13
  SHL BX,1
  MOV AX,[BP+18]
  MOV EndA[BX],AX
  MOV AX,[BP+22]
  MOV EndX[BX],AX
  MOV DX,StartX[BX]
  CMP DX,AX
  JL gEnd13
  MOV StartX[BX],AX
  MOV EndX[BX],DX
  MOV AX,StartA[BX]
  MOV DX,EndA[BX]
  MOV StartA[BX],DX
  MOV EndA[BX],AX
  JMP gEnd13
gConnect13:
  PUSH ECX
  MOV AX,[BP+6]
  SUB AX,[BP+18]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+18]
  SHL EDX,16
  MOV BX,[BP+20]
colStep13:
  CMP BX,0
  JL colNext13
  CMP BX,199
  JG colNext13
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV EndA[SI],CX
colNext13:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+8]
  JLE colStep13
  POP ECX
  MOV AX,[BP+10]
  SUB AX,[BP+22]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+22]
  SHL EDX,16
  MOV BX,[BP+20]
gStep13:
  CMP BX,ClipY1
  JL gNext13
  CMP BX,ClipY2
  JG gNext13
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV EndX[SI],CX
  CMP StartX[SI],CX
  JL gNext13
  MOV DI,StartX[SI]
  MOV StartX[SI],CX
  MOV EndX[SI],DI
  MOV DI,StartA[SI]
  MOV CX,EndA[SI]
  MOV StartA[SI],CX
  MOV EndA[SI],DI
gNext13:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+8]
  JLE gStep13
gEnd13:
  MOV CX,FirstY
  MOV DI,CX
  MOV SI,DI
  SHL DI,8
  SHL SI,6
  ADD DI,SI
DrawgTri:
  MOV SI,CX
  SHL SI,1
  CMP StartX[SI],08000h
  JE SkipgTriLine
  MOV BX,StartX[SI]
  MOV SX,BX
  CMP BX,ClipX2
  JG SkipgTriLine
  CMP BX,ClipX1
  JG @F
  MOV BX,ClipX1
  MOV SX,BX
@@:
  MOV BX,EndX[SI]
  MOV EX,BX
  CMP BX,ClipX1
  JL SkipgTriLine
  CMP BX,ClipX2
  JL @F
  MOV BX,ClipX2
  MOV EX,BX
@@:
  MOV BX,StartX[SI]
  PUSH CX
  XOR ECX,ECX
  MOV CX,EndX[SI]
  SUB CX,StartX[SI]
  INC CX
  MOV AX,EndA[SI]
  SUB AX,StartA[SI]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,StartA[SI]
  SHL EDX,16
DrawgTriLine:
  CMP BX,SX
  JL SkipgTriPixel
  MOV ECX,EDX
  SHR ECX,16
  MOV ES:[BX+DI],CL
SkipgTriPixel:
  ADD EDX,EAX
  INC BX
  CMP BX,EX
  JLE DrawgTriLine
  POP CX
SkipgTriLine:
  ADD DI,320
  INC CX
  CMP CX,LastY
  JLE DrawgTri
EndgTri:
  POP BP
  RET 20
DQBgtri ENDP

; ---------------------------------------------------------------------------
; DQBbgtri SUB
; purpose:
;   Draws a gouraud shaded triangle with (x1,y1), (x2,y2) and (x3,y3) as
;   vertex, with their own colors c1, c2 and c3, on specified layer. Pixels
;   are drawn using the current blender map.
; declaration:
;   DECLARE SUB DQBbgtri(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL c1,BYVAL x2,
;                        BYVAL y2,BYVAL c2,BYVAL x3,BYVAL y3,BYVAL c3,
;                        BYVAL BMap)
; ---------------------------------------------------------------------------
PUBLIC DQBbgtri
DQBbgtri PROC
  ; Stack layout:
  ;
  ; 26  Layer
  ; 24  x1
  ; 22  y1
  ; 20  c1
  ; 18  x2
  ; 16  y2
  ; 14  c2
  ; 12  x3
  ; 10  y3
  ; 08  c3
  ; 06  BMap
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  PUSH AX
  MOV BP,SP
  MOV SI,[BP+8]
  DEC SI
  CMP BMapActive[SI],0
  JE Endbgtri
  SHL SI,1
  MOV AX,BMapSeg[SI]
  MOV GS,AX
  SHR SI,1
  MOV AL,BMapFirst[SI]
  MOV AH,BMapLast[SI]
  MOV [BP],AX
  MOV BX,[BP+28]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+24]
  MOV BX,[BP+18]
  CMP AX,BX
  JLE bgSwap12
  MOV [BP+24],BX
  MOV [BP+18],AX
  MOV AX,[BP+26]
  MOV BX,[BP+20]
  MOV [BP+26],BX
  MOV [BP+20],AX
  MOV AX,[BP+22]
  MOV BX,[BP+16]
  MOV [BP+22],BX
  MOV [BP+16],AX
bgSwap12:
  MOV AX,[BP+24]
  MOV BX,[BP+12]
  CMP AX,BX
  JLE bgSwap13
  MOV [BP+24],BX
  MOV [BP+12],AX
  MOV AX,[BP+26]
  MOV BX,[BP+14]
  MOV [BP+26],BX
  MOV [BP+14],AX
  MOV AX,[BP+22]
  MOV BX,[BP+10]
  MOV [BP+22],BX
  MOV [BP+10],AX
bgSwap13:
  MOV AX,[BP+18]
  MOV BX,[BP+12]
  CMP AX,BX
  JLE bgSwap23
  MOV [BP+18],BX
  MOV [BP+12],AX
  MOV AX,[BP+20]
  MOV BX,[BP+14]
  MOV [BP+20],BX
  MOV [BP+14],AX
  MOV AX,[BP+16]
  MOV BX,[BP+10]
  MOV [BP+16],BX
  MOV [BP+10],AX
bgSwap23:
  XOR SI,SI
  MOV AX,08000h
InitXbgtri:
  MOV StartX[SI],AX
  ADD SI,2
  CMP SI,400
  JL InitXbgtri
  MOV AX,ClipY1
  MOV FirstY,AX
  MOV BX,[BP+24]
  CMP BX,AX
  JL @F
  MOV FirstY,BX
@@:
  CMP BX,ClipY2
  JG EndbgTri
  MOV AX,ClipY2
  MOV LastY,AX
  MOV BX,[BP+12]
  CMP BX,AX
  JG @F
  MOV LastY,BX
@@:
  XOR ECX,ECX
  MOV BX,[BP+24]
  MOV CX,[BP+18]
  SUB CX,BX
  JNZ bgConnect12
  CMP BX,ClipY1
  JL bgEnd12
  CMP BX,ClipY2
  JG bgEnd12
  SHL BX,1
  MOV AX,[BP+26]
  MOV StartX[BX],AX
  MOV AX,[BP+22]
  MOV StartA[BX],AX
  JMP bgEnd12
bgConnect12:
  PUSH ECX
  MOV AX,[BP+16]
  SUB AX,[BP+22]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+22]
  SHL EDX,16
  MOV BX,[BP+24]
bcolStep12:
  CMP BX,0
  JL bcolNext12
  CMP BX,199
  JG bcolNext12
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartA[SI],CX
bcolNext12:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+18]
  JLE bcolStep12
  POP ECX
  MOV AX,[BP+20]
  SUB AX,[BP+26]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+26]
  SHL EDX,16
  MOV BX,[BP+24]
bgStep12:
  CMP BX,ClipY1
  JL bgNext12
  CMP BX,ClipY2
  JG bgNext12
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
bgNext12:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+18]
  JLE bgStep12
bgEnd12:
  XOR ECX,ECX
  MOV BX,[BP+18]
  MOV CX,[BP+12]
  SUB CX,BX
  JNZ bgConnect23
  CMP BX,ClipY1
  JL bgEnd23
  CMP BX,ClipY2
  JG bgEnd23
  SHL BX,1
  MOV AX,[BP+20]
  MOV StartX[BX],AX
  MOV AX,[BP+16]
  MOV StartA[BX],AX
  JMP bgEnd23
bgConnect23:
  PUSH ECX
  MOV AX,[BP+10]
  SUB AX,[BP+16]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+16]
  SHL EDX,16
  MOV BX,[BP+18]
bcolStep23:
  CMP BX,0
  JL bcolNext23
  CMP BX,199
  JG bcolNext23
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartA[SI],CX
bcolNext23:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+12]
  JLE bcolStep23
  POP ECX
  MOV AX,[BP+14]
  SUB AX,[BP+20]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+20]
  SHL EDX,16
  MOV BX,[BP+18]
bgStep23:
  CMP BX,ClipY1
  JL bgNext23
  CMP BX,ClipY2
  JG bgNext23
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
bgNext23:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+12]
  JLE bgStep23
bgEnd23:
  XOR ECX,ECX
  MOV BX,[BP+24]
  MOV CX,[BP+12]
  SUB CX,BX
  JNZ bgConnect13
  CMP BX,ClipY1
  JL bgEnd13
  CMP BX,ClipY2
  JG bgEnd13
  SHL BX,1
  MOV AX,[BP+22]
  MOV EndA[BX],AX
  MOV AX,[BP+26]
  MOV EndX[BX],AX
  MOV DX,StartX[BX]
  CMP DX,AX
  JL bgEnd13
  MOV StartX[BX],AX
  MOV EndX[BX],DX
  MOV AX,StartA[BX]
  MOV DX,EndA[BX]
  MOV StartA[BX],DX
  MOV EndA[BX],AX
  JMP bgEnd13
bgConnect13:
  PUSH ECX
  MOV AX,[BP+10]
  SUB AX,[BP+22]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+22]
  SHL EDX,16
  MOV BX,[BP+24]
bcolStep13:
  CMP BX,0
  JL bcolNext13
  CMP BX,199
  JG bcolNext13
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV EndA[SI],CX
bcolNext13:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+12]
  JLE bcolStep13
  POP ECX
  MOV AX,[BP+14]
  SUB AX,[BP+26]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+26]
  SHL EDX,16
  MOV BX,[BP+24]
bgStep13:
  CMP BX,ClipY1
  JL bgNext13
  CMP BX,ClipY2
  JG bgNext13
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV EndX[SI],CX
  CMP StartX[SI],CX
  JL bgNext13
  MOV DI,StartX[SI]
  MOV StartX[SI],CX
  MOV EndX[SI],DI
  MOV DI,StartA[SI]
  MOV CX,EndA[SI]
  MOV StartA[SI],CX
  MOV EndA[SI],DI
bgNext13:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+12]
  JLE bgStep13
bgEnd13:
  MOV CX,FirstY
  MOV DI,CX
  MOV SI,DI
  SHL DI,8
  SHL SI,6
  ADD DI,SI
DrawbgTri:
  MOV SI,CX
  SHL SI,1
  CMP StartX[SI],08000h
  JE SkipbgTriLine
  MOV BX,StartX[SI]
  CMP BX,ClipX2
  JG SkipbgTriLine
  CMP BX,ClipX1
  JG @F
  MOV AX,ClipX1
  MOV SX,AX
@@:
  MOV AX,EndX[SI]
  CMP AX,ClipX1
  JL SkipbgTriLine
  CMP AX,ClipX2
  JL @F
  MOV AX,ClipX2
@@:
  MOV EX,AX
  PUSH CX
  MOV BX,StartX[SI]
  XOR ECX,ECX
  MOV CX,EndX[SI]
  SUB CX,StartX[SI]
  INC CX
  MOV AX,EndA[SI]
  SUB AX,StartA[SI]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,StartA[SI]
  SHL EDX,16
DrawbgTriLine:
  CMP BX,SX
  JL SkipbgTriPixel
  MOV ECX,EDX
  SHR ECX,16
  MOV CH,CL
  CMP CH,[BP]
  JB @F
  CMP CH,[BP+1]
  JA @F
  SUB CH,[BP]
  MOV CL,ES:[BX+DI]
  PUSH BX
  MOV BX,CX
  MOV CL,GS:[BX]
  POP BX
@@:
  MOV ES:[BX+DI],CL
SkipbgTriPixel:
  ADD EDX,EAX
  INC BX
  CMP BX,EX
  JLE DrawbgTriLine
  POP CX
SkipbgTriLine:
  ADD DI,320
  INC CX
  CMP CX,LastY
  JLE DrawbgTri
Endbgtri:
  POP AX
  POP BP
  RET 22
DQBbgtri ENDP


; ---------------------------------------------------------------------------
; DQBttri SUB
; purpose:
;   Draws a textured triangle on given layer, with (x1,y1), (x2,y2) and
;   (x3,y3) as vertexes, using specified texture map. (u1,v1), (u2,v2) and
;   (u3,v3) are the coordinates on the texture of each vertex.
; declaration:
;   DECLARE SUB DQBttri(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                       BYVAL x3,BYVAL y3,BYVAL u1,BYVAL v1,BYVAL u2,BYVAL v2,
;                       BYVAL u3,BYVAL v3,BYVAL TextureSeg,BYVAL TextureOff)
; ---------------------------------------------------------------------------
PUBLIC DQBttri
DQBttri PROC
  ; Stack layout:
  ;
  ; 34  Layer
  ; 32  x1
  ; 30  y1
  ; 28  x2
  ; 26  y2
  ; 24  x3
  ; 22  y3
  ; 20  u1
  ; 18  v1
  ; 16  u2
  ; 14  v2
  ; 12  u3
  ; 10  v3
  ; 08  TextureSeg
  ; 06  TextureOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+34]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+30]
  MOV BX,[BP+26]
  CMP AX,BX
  JLE tSwap12
  MOV [BP+30],BX
  MOV [BP+26],AX
  MOV AX,[BP+32]
  MOV BX,[BP+28]
  MOV [BP+32],BX
  MOV [BP+28],AX
  MOV AX,[BP+20]
  MOV BX,[BP+16]
  MOV [BP+20],BX
  MOV [BP+16],AX
  MOV AX,[BP+18]
  MOV BX,[BP+14]
  MOV [BP+18],BX
  MOV [BP+14],AX
tSwap12:
  MOV AX,[BP+30]
  MOV BX,[BP+22]
  CMP AX,BX
  JLE tSwap13
  MOV [BP+30],BX
  MOV [BP+22],AX
  MOV AX,[BP+32]
  MOV BX,[BP+24]
  MOV [BP+32],BX
  MOV [BP+24],AX
  MOV AX,[BP+20]
  MOV BX,[BP+12]
  MOV [BP+20],BX
  MOV [BP+12],AX
  MOV AX,[BP+18]
  MOV BX,[BP+10]
  MOV [BP+18],BX
  MOV [BP+10],AX
tSwap13:
  MOV AX,[BP+26]
  MOV BX,[BP+22]
  CMP AX,BX
  JLE tSwap23
  MOV [BP+26],BX
  MOV [BP+22],AX
  MOV AX,[BP+28]
  MOV BX,[BP+24]
  MOV [BP+28],BX
  MOV [BP+24],AX
  MOV AX,[BP+16]
  MOV BX,[BP+12]
  MOV [BP+16],BX
  MOV [BP+12],AX
  MOV AX,[BP+14]
  MOV BX,[BP+10]
  MOV [BP+14],BX
  MOV [BP+10],AX
tSwap23:
  XOR SI,SI
  MOV AX,08000h
InitXttri:
  MOV StartX[SI],AX
  ADD SI,2
  CMP SI,400
  JL InitXttri
  MOV AX,ClipY1
  MOV FirstY,AX
  MOV BX,[BP+30]
  CMP BX,AX
  JL @F
  MOV FirstY,BX
@@:
  CMP BX,ClipY2
  JG tEndTri
  MOV AX,ClipY2
  MOV LastY,AX
  MOV BX,[BP+22]
  CMP BX,AX
  JG @F
  MOV LastY,BX
@@:
  XOR ECX,ECX
  MOV BX,[BP+30]
  MOV CX,[BP+26]
  SUB CX,BX
  JNZ tConnect12
  CMP BX,ClipY1
  JL tEnd12
  CMP BX,ClipY2
  JG tEnd12
  SHL BX,1
  MOV AX,[BP+32]
  MOV StartX[BX],AX
  MOV AX,[BP+20]
  MOV StartA[BX],AX
  MOV AX,[BP+18]
  MOV StartB[BX],AX
  JMP tEnd12
tConnect12:
  PUSH ECX
  MOV AX,[BP+16]
  SUB AX,[BP+20]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV EBX,EAX
  MOV DX,[BP+20]
  SHL EDX,16
  PUSH EDX
  MOV AX,[BP+14]
  SUB AX,[BP+18]
  SHL EAX,16
  CDQ
  IDIV ECX
  POP EDX
  MOV CX,[BP+18]
  SHL ECX,16
  MOV SI,[BP+30]
uvStep12:
  CMP SI,0
  JL uvNext12
  CMP SI,199
  JG uvNext12
  SHL SI,1
  MOV EDI,EDX
  SHR EDI,16
  MOV StartA[SI],DI
  MOV EDI,ECX
  SHR EDI,16
  MOV StartB[SI],DI
  SHR SI,1
uvNext12:
  ADD EDX,EBX
  ADD ECX,EAX
  INC SI
  CMP SI,[BP+26]
  JLE uvStep12
  POP ECX
  MOV AX,[BP+28]
  SUB AX,[BP+32]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+32]
  SHL EDX,16
  MOV BX,[BP+30]
tStep12:
  CMP BX,ClipY1
  JL tNext12
  CMP BX,ClipY2
  JG tNext12
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
tNext12:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+26]
  JLE tStep12
tEnd12:
  XOR ECX,ECX
  MOV BX,[BP+26]
  MOV CX,[BP+22]
  SUB CX,BX
  JNZ tConnect23
  CMP BX,ClipY1
  JL tEnd23
  CMP BX,ClipY2
  JG tEnd23
  SHL BX,1
  MOV AX,[BP+28]
  MOV StartX[BX],AX
  MOV AX,[BP+16]
  MOV StartA[BX],AX
  MOV AX,[BP+14]
  MOV StartB[BX],AX
  JMP tEnd23
tConnect23:
  PUSH ECX
  MOV AX,[BP+12]
  SUB AX,[BP+16]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV EBX,EAX
  MOV DX,[BP+16]
  SHL EDX,16
  PUSH EDX
  MOV AX,[BP+10]
  SUB AX,[BP+14]
  SHL EAX,16
  CDQ
  IDIV ECX
  POP EDX
  MOV CX,[BP+14]
  SHL ECX,16
  MOV SI,[BP+26]
uvStep23:
  CMP SI,0
  JL uvNext23
  CMP SI,199
  JG uvNext23
  SHL SI,1
  MOV EDI,EDX
  SHR EDI,16
  MOV StartA[SI],DI
  MOV EDI,ECX
  SHR EDI,16
  MOV StartB[SI],DI
  SHR SI,1
uvNext23:
  ADD EDX,EBX
  ADD ECX,EAX
  INC SI
  CMP SI,[BP+22]
  JLE uvStep23
  POP ECX
  MOV AX,[BP+24]
  SUB AX,[BP+28]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+28]
  SHL EDX,16
  MOV BX,[BP+26]
tStep23:
  CMP BX,ClipY1
  JL tNext23
  CMP BX,ClipY2
  JG tNext23
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
tNext23:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+22]
  JLE tStep23
tEnd23:
  XOR ECX,ECX
  MOV BX,[BP+30]
  MOV CX,[BP+22]
  SUB CX,BX
  JNZ tConnect13
  CMP BX,ClipY1
  JL tEnd13
  CMP BX,ClipY2
  JG tEnd13
  SHL BX,1
  MOV AX,[BP+20]
  MOV EndA[BX],AX
  MOV AX,[BP+18]
  MOV EndB[BX],AX
  MOV AX,[BP+32]
  MOV EndX[BX],AX
  MOV DX,StartX[BX]
  CMP DX,AX
  JL tEnd13
  MOV StartX[BX],AX
  MOV EndX[BX],DX
  MOV AX,StartA[BX]
  MOV DX,EndA[BX]
  MOV StartA[BX],DX
  MOV EndA[BX],AX
  MOV AX,StartB[BX]
  MOV DX,EndB[BX]
  MOV StartB[BX],DX
  MOV EndB[BX],AX
  JMP tEnd13
tConnect13:
  PUSH ECX
  MOV AX,[BP+12]
  SUB AX,[BP+20]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV EBX,EAX
  MOV DX,[BP+20]
  SHL EDX,16
  PUSH EDX
  MOV AX,[BP+10]
  SUB AX,[BP+18]
  SHL EAX,16
  CDQ
  IDIV ECX
  POP EDX
  MOV CX,[BP+18]
  SHL ECX,16
  MOV SI,[BP+30]
uvStep13:
  CMP SI,0
  JL uvNext13
  CMP SI,199
  JG uvNext13
  SHL SI,1
  MOV EDI,EDX
  SHR EDI,16
  MOV EndA[SI],DI
  MOV EDI,ECX
  SHR EDI,16
  MOV EndB[SI],DI
  SHR SI,1
uvNext13:
  ADD EDX,EBX
  ADD ECX,EAX
  INC SI
  CMP SI,[BP+22]
  JLE uvStep13
  POP ECX
  MOV AX,[BP+24]
  SUB AX,[BP+32]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+32]
  SHL EDX,16
  MOV BX,[BP+30]
tStep13:
  CMP BX,ClipY1
  JL tNext13
  CMP BX,ClipY2
  JG tNext13
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV EndX[SI],CX
  CMP StartX[SI],CX
  JL tNext13
  MOV DI,StartX[SI]
  MOV StartX[SI],CX
  MOV EndX[SI],DI
  MOV DI,StartA[SI]
  MOV CX,EndA[SI]
  MOV StartA[SI],CX
  MOV EndA[SI],DI
  MOV DI,StartB[SI]
  MOV CX,EndB[SI]
  MOV StartB[SI],CX
  MOV EndB[SI],DI
tNext13:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+22]
  JLE tStep13
tEnd13:
  MOV AX,[BP+8]
  MOV FS,AX
  MOV CX,FirstY
  MOV DI,CX
  MOV SI,DI
  SHL DI,8
  SHL SI,6
  ADD DI,SI
DrawtTri:
  MOV SI,CX
  SHL SI,1
  MOV SX,0
  CMP StartX[SI],08000h
  JE SkiptTriLine
  MOV BX,StartX[SI]
  CMP BX,ClipX2
  JG SkiptTriLine
  CMP BX,ClipX1
  JG @F
  MOV AX,ClipX1
  MOV SX,AX
@@:
  MOV AX,EndX[SI]
  CMP AX,ClipX1
  JL SkiptTriLine
  CMP AX,ClipX2
  JL @F
  MOV AX,ClipX2
@@:
  MOV EX,AX
  PUSH CX
  XOR ECX,ECX
  MOV CX,EndX[SI]
  SUB CX,StartX[SI]
  INC CX
  MOV AX,EndA[SI]
  SUB AX,StartA[SI]
  SHL EAX,16
  CDQ
  IDIV ECX
  PUSH EAX
  MOV AX,EndB[SI]
  SUB AX,StartB[SI]
  SHL EAX,16
  CDQ
  IDIV ECX
  PUSH EAX
  PUSH AX
  MOV BP,SP
  MOV AX,EX
  MOV [BP],AX
  MOV DX,StartA[SI]
  SHL EDX,16
  MOV AX,StartB[SI]
  SHL EAX,16
  PUSH SI
DrawtTriLine:
  CMP BX,SX
  JL SkiptTriPixel
  MOV ESI,EAX
  SHR ESI,16
  AND SI,TextureFix
  MOV CL,TextureLen
  SHL SI,CL
  MOV ECX,EDX
  SHR ECX,16
  AND CX,TextureFix
  ADD SI,CX
  ADD SI,4
  ADD SI,[BP+18]
  MOV CL,FS:[SI]
  JZ SkiptTriPixel
  MOV ES:[BX+DI],CL
SkiptTriPixel:
  ADD EDX,[BP+6]
  ADD EAX,[BP+2]
  INC BX
  CMP BX,[BP]
  JLE DrawtTriLine
  POP SI
  POP AX
  POP EAX
  POP EAX
  POP CX
SkiptTriLine:
  ADD DI,320
  INC CX
  CMP CX,LastY
  JLE DrawtTri
tEndTri:
  POP BP
  RET 30
DQBttri ENDP

; ---------------------------------------------------------------------------
; DQBbttri SUB
; purpose:
;   Draws a textured triangle on given layer, with (x1,y1), (x2,y2) and
;   (x3,y3) as vertexes, using specified texture map. (u1,v1), (u2,v2) and
;   (u3,v3) are the coordinates on the texture of each vertex; pixels are
;   drawn using the current blender map.
; declaration:
;   DECLARE SUB DQBbttri(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                       BYVAL x3,BYVAL y3,BYVAL u1,BYVAL v1,BYVAL u2,BYVAL v2,
;                       BYVAL u3,BYVAL v3,BYVAL TextureSeg,BYVAL TextureOff,
;                       BYVAL BMap)
; ---------------------------------------------------------------------------
PUBLIC DQBbttri
DQBbttri PROC
  ; Stack layout:
  ;
  ; 36  Layer
  ; 34  x1
  ; 32  y1
  ; 30  x2
  ; 28  y2
  ; 26  x3
  ; 24  y3
  ; 22  u1
  ; 20  v1
  ; 18  u2
  ; 16  v2
  ; 14  u3
  ; 12  v3
  ; 10  TextureSeg
  ; 08  TextureOff
  ; 06  BMap
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  PUSH AX
  MOV BP,SP
  MOV SI,[BP+8]
  DEC SI
  CMP BMapActive[SI],0
  JE Endbttri
  SHL SI,1
  MOV AX,BMapSeg[SI]
  MOV GS,AX
  SHR SI,1
  MOV AL,BMapFirst[SI]
  MOV AH,BMapLast[SI]
  MOV [BP],AX
  MOV BX,[BP+38]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+34]
  MOV BX,[BP+30]
  CMP AX,BX
  JLE btSwap12
  MOV [BP+34],BX
  MOV [BP+30],AX
  MOV AX,[BP+36]
  MOV BX,[BP+32]
  MOV [BP+36],BX
  MOV [BP+32],AX
  MOV AX,[BP+24]
  MOV BX,[BP+20]
  MOV [BP+24],BX
  MOV [BP+20],AX
  MOV AX,[BP+22]
  MOV BX,[BP+18]
  MOV [BP+22],BX
  MOV [BP+18],AX
btSwap12:
  MOV AX,[BP+34]
  MOV BX,[BP+26]
  CMP AX,BX
  JLE btSwap13
  MOV [BP+34],BX
  MOV [BP+26],AX
  MOV AX,[BP+36]
  MOV BX,[BP+28]
  MOV [BP+36],BX
  MOV [BP+28],AX
  MOV AX,[BP+24]
  MOV BX,[BP+16]
  MOV [BP+24],BX
  MOV [BP+16],AX
  MOV AX,[BP+22]
  MOV BX,[BP+14]
  MOV [BP+22],BX
  MOV [BP+14],AX
btSwap13:
  MOV AX,[BP+30]
  MOV BX,[BP+26]
  CMP AX,BX
  JLE btSwap23
  MOV [BP+30],BX
  MOV [BP+26],AX
  MOV AX,[BP+32]
  MOV BX,[BP+28]
  MOV [BP+32],BX
  MOV [BP+28],AX
  MOV AX,[BP+20]
  MOV BX,[BP+16]
  MOV [BP+20],BX
  MOV [BP+16],AX
  MOV AX,[BP+18]
  MOV BX,[BP+14]
  MOV [BP+18],BX
  MOV [BP+14],AX
btSwap23:
  XOR SI,SI
  MOV AX,08000h
InitXbttri:
  MOV StartX[SI],AX
  ADD SI,2
  CMP SI,400
  JL InitXbttri
  MOV AX,ClipY1
  MOV FirstY,AX
  MOV BX,[BP+34]
  CMP BX,AX
  JL @F
  MOV FirstY,BX
@@:
  CMP BX,ClipY2
  JG Endbttri
  MOV AX,ClipY2
  MOV LastY,AX
  MOV BX,[BP+26]
  CMP BX,AX
  JG @F
  MOV LastY,BX
@@:
  XOR ECX,ECX
  MOV BX,[BP+34]
  MOV CX,[BP+30]
  SUB CX,BX
  JNZ btConnect12
  CMP BX,ClipY1
  JL btEnd12
  CMP BX,ClipY2
  JG btEnd12
  SHL BX,1
  MOV AX,[BP+36]
  MOV StartX[BX],AX
  MOV AX,[BP+24]
  MOV StartA[BX],AX
  MOV AX,[BP+22]
  MOV StartB[BX],AX
  JMP btEnd12
btConnect12:
  PUSH ECX
  MOV AX,[BP+20]
  SUB AX,[BP+24]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV EBX,EAX
  MOV DX,[BP+24]
  SHL EDX,16
  PUSH EDX
  MOV AX,[BP+18]
  SUB AX,[BP+22]
  SHL EAX,16
  CDQ
  IDIV ECX
  POP EDX
  MOV CX,[BP+22]
  SHL ECX,16
  MOV SI,[BP+34]
buvStep12:
  CMP SI,0
  JL buvNext12
  CMP SI,199
  JG buvNext12
  SHL SI,1
  MOV EDI,EDX
  SHR EDI,16
  MOV StartA[SI],DI
  MOV EDI,ECX
  SHR EDI,16
  MOV StartB[SI],DI
  SHR SI,1
buvNext12:
  ADD EDX,EBX
  ADD ECX,EAX
  INC SI
  CMP SI,[BP+30]
  JLE buvStep12
  POP ECX
  MOV AX,[BP+32]
  SUB AX,[BP+36]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+36]
  SHL EDX,16
  MOV BX,[BP+34]
btStep12:
  CMP BX,ClipY1
  JL btNext12
  CMP BX,ClipY2
  JG btNext12
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
btNext12:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+30]
  JLE btStep12
btEnd12:
  XOR ECX,ECX
  MOV BX,[BP+30]
  MOV CX,[BP+26]
  SUB CX,BX
  JNZ btConnect23
  CMP BX,ClipY1
  JL btEnd23
  CMP BX,ClipY2
  JG btEnd23
  SHL BX,1
  MOV AX,[BP+32]
  MOV StartX[BX],AX
  MOV AX,[BP+20]
  MOV StartA[BX],AX
  MOV AX,[BP+18]
  MOV StartB[BX],AX
  JMP btEnd23
btConnect23:
  PUSH ECX
  MOV AX,[BP+16]
  SUB AX,[BP+20]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV EBX,EAX
  MOV DX,[BP+20]
  SHL EDX,16
  PUSH EDX
  MOV AX,[BP+14]
  SUB AX,[BP+18]
  SHL EAX,16
  CDQ
  IDIV ECX
  POP EDX
  MOV CX,[BP+18]
  SHL ECX,16
  MOV SI,[BP+30]
buvStep23:
  CMP SI,0
  JL buvNext23
  CMP SI,199
  JG buvNext23
  SHL SI,1
  MOV EDI,EDX
  SHR EDI,16
  MOV StartA[SI],DI
  MOV EDI,ECX
  SHR EDI,16
  MOV StartB[SI],DI
  SHR SI,1
buvNext23:
  ADD EDX,EBX
  ADD ECX,EAX
  INC SI
  CMP SI,[BP+26]
  JLE buvStep23
  POP ECX
  MOV AX,[BP+28]
  SUB AX,[BP+32]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+32]
  SHL EDX,16
  MOV BX,[BP+30]
btStep23:
  CMP BX,ClipY1
  JL btNext23
  CMP BX,ClipY2
  JG btNext23
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
btNext23:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+26]
  JLE btStep23
btEnd23:
  XOR ECX,ECX
  MOV BX,[BP+34]
  MOV CX,[BP+26]
  SUB CX,BX
  JNZ btConnect13
  CMP BX,ClipY1
  JL btEnd13
  CMP BX,ClipY2
  JG btEnd13
  SHL BX,1
  MOV AX,[BP+24]
  MOV EndA[BX],AX
  MOV AX,[BP+22]
  MOV EndB[BX],AX
  MOV AX,[BP+36]
  MOV EndX[BX],AX
  MOV DX,StartX[BX]
  CMP DX,AX
  JL btEnd13
  MOV StartX[BX],AX
  MOV EndX[BX],DX
  MOV AX,StartA[BX]
  MOV DX,EndA[BX]
  MOV StartA[BX],DX
  MOV EndA[BX],AX
  MOV AX,StartB[BX]
  MOV DX,EndB[BX]
  MOV StartB[BX],DX
  MOV EndB[BX],AX
  JMP btEnd13
btConnect13:
  PUSH ECX
  MOV AX,[BP+16]
  SUB AX,[BP+24]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV EBX,EAX
  MOV DX,[BP+24]
  SHL EDX,16
  PUSH EDX
  MOV AX,[BP+14]
  SUB AX,[BP+22]
  SHL EAX,16
  CDQ
  IDIV ECX
  POP EDX
  MOV CX,[BP+22]
  SHL ECX,16
  MOV SI,[BP+34]
buvStep13:
  CMP SI,0
  JL buvNext13
  CMP SI,199
  JG buvNext13
  SHL SI,1
  MOV EDI,EDX
  SHR EDI,16
  MOV EndA[SI],DI
  MOV EDI,ECX
  SHR EDI,16
  MOV EndB[SI],DI
  SHR SI,1
buvNext13:
  ADD EDX,EBX
  ADD ECX,EAX
  INC SI
  CMP SI,[BP+26]
  JLE buvStep13
  POP ECX
  MOV AX,[BP+28]
  SUB AX,[BP+36]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+36]
  SHL EDX,16
  MOV BX,[BP+34]
btStep13:
  CMP BX,ClipY1
  JL btNext13
  CMP BX,ClipY2
  JG btNext13
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV EndX[SI],CX
  CMP StartX[SI],CX
  JL btNext13
  MOV DI,StartX[SI]
  MOV StartX[SI],CX
  MOV EndX[SI],DI
  MOV DI,StartA[SI]
  MOV CX,EndA[SI]
  MOV StartA[SI],CX
  MOV EndA[SI],DI
  MOV DI,StartB[SI]
  MOV CX,EndB[SI]
  MOV StartB[SI],CX
  MOV EndB[SI],DI
btNext13:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+26]
  JLE btStep13
btEnd13:
  MOV AX,[BP+12]
  MOV FS,AX
  MOV CX,FirstY
  MOV DI,CX
  MOV SI,DI
  SHL DI,8
  SHL SI,6
  ADD DI,SI
DrawbtTri:
  PUSH DI
  MOV SI,CX
  SHL SI,1
  CMP StartX[SI],08000h
  JE SkipbtTriLine
  MOV BX,StartX[SI]
  MOV SX,BX
  CMP BX,ClipX2
  JG SkipbtTriLine
  CMP BX,ClipX1
  JG @F
  MOV BX,ClipX1
  MOV SX,BX
@@:
  MOV BX,EndX[SI]
  MOV EX,BX
  CMP BX,ClipX1
  JL SkipbtTriLine
  CMP BX,ClipX2
  JL @F
  MOV BX,ClipX2
  MOV EX,BX
@@:
  MOV BX,StartX[SI]
  PUSH CX
  MOV BX,CX
  MOV DI,BX
  SHL BX,8
  SHL DI,6
  ADD BX,DI
  MOV DI,StartX[SI]
  XOR ECX,ECX
  MOV CX,EndX[SI]
  SUB CX,StartX[SI]
  INC CX
  MOV AX,EndA[SI]
  SUB AX,StartA[SI]
  SHL EAX,16
  CDQ
  IDIV ECX
  PUSH EAX
  MOV AX,EndB[SI]
  SUB AX,StartB[SI]
  SHL EAX,16
  CDQ
  IDIV ECX
  PUSH EAX
  PUSH AX
  MOV BP,SP
  MOV AX,EX
  MOV [BP],AX
  MOV DX,StartA[SI]
  SHL EDX,16
  MOV AX,StartB[SI]
  SHL EAX,16
  PUSH SI
DrawbtTriLine:
  CMP DI,SX
  JL SkipbtTriPixel
  MOV ESI,EAX
  SHR ESI,16
  AND SI,TextureFix
  MOV CL,TextureLen
  SHL SI,CL
  MOV ECX,EDX
  SHR ECX,16
  AND CX,TextureFix
  ADD SI,CX
  ADD SI,4
  ADD SI,[BP+24]
  MOV CL,FS:[SI]
  CMP CL,[BP+14]
  JB @F
  CMP CL,[BP+15]
  JA @F
  PUSH BX
  SUB CL,[BP+14]
  MOV BL,ES:[BX+DI]
  MOV BH,CL
  MOV CL,GS:[BX]
  POP BX
  JZ SkipbtTriPixel
@@:
  MOV ES:[BX+DI],CL
SkipbtTriPixel:
  ADD EDX,[BP+6]
  ADD EAX,[BP+2]
  INC DI
  CMP DI,[BP]
  JLE DrawbtTriLine
  POP SI
  POP AX
  POP EAX
  POP EAX
  POP CX
SkipbtTriLine:
  POP DI
  ADD DI,320
  INC CX
  CMP CX,LastY
  JLE DrawbtTri
Endbttri:
  POP AX
  POP BP
  RET 32
DQBbttri ENDP

; ---------------------------------------------------------------------------
; DQBfttri SUB
; purpose:
;   Draws a textured triangle on given layer, with (x1,y1), (x2,y2) and
;   (x3,y3) as vertexes, using specified texture map. (u1,v1), (u2,v2) and
;   (u3,v3) are the coordinates on the texture of each vertex.
; declaration:
;   DECLARE SUB DQBfttri(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                        BYVAL x3,BYVAL y3,BYVAL u1,BYVAL v1,BYVAL u2,BYVAL v2,
;                        BYVAL u3,BYVAL v3,BYVAL TextureSeg,BYVAL TextureOff)
; ---------------------------------------------------------------------------
PUBLIC DQBfttri
DQBfttri PROC
  ; Stack layout:
  ;
  ; 34  Layer
  ; 32  x1
  ; 30  y1
  ; 28  x2
  ; 26  y2
  ; 24  x3
  ; 22  y3
  ; 20  u1
  ; 18  v1
  ; 16  u2
  ; 14  v2
  ; 12  u3
  ; 10  v3
  ; 08  TextureSeg
  ; 06  TextureOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+34]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+30]
  MOV BX,[BP+26]
  CMP AX,BX
  JLE ftSwap12
  MOV [BP+30],BX
  MOV [BP+26],AX
  MOV AX,[BP+32]
  MOV BX,[BP+28]
  MOV [BP+32],BX
  MOV [BP+28],AX
  MOV AX,[BP+20]
  MOV BX,[BP+16]
  MOV [BP+20],BX
  MOV [BP+16],AX
  MOV AX,[BP+18]
  MOV BX,[BP+14]
  MOV [BP+18],BX
  MOV [BP+14],AX
ftSwap12:
  MOV AX,[BP+30]
  MOV BX,[BP+22]
  CMP AX,BX
  JLE ftSwap13
  MOV [BP+30],BX
  MOV [BP+22],AX
  MOV AX,[BP+32]
  MOV BX,[BP+24]
  MOV [BP+32],BX
  MOV [BP+24],AX
  MOV AX,[BP+20]
  MOV BX,[BP+12]
  MOV [BP+20],BX
  MOV [BP+12],AX
  MOV AX,[BP+18]
  MOV BX,[BP+10]
  MOV [BP+18],BX
  MOV [BP+10],AX
ftSwap13:
  MOV AX,[BP+26]
  MOV BX,[BP+22]
  CMP AX,BX
  JLE ftSwap23
  MOV [BP+26],BX
  MOV [BP+22],AX
  MOV AX,[BP+28]
  MOV BX,[BP+24]
  MOV [BP+28],BX
  MOV [BP+24],AX
  MOV AX,[BP+16]
  MOV BX,[BP+12]
  MOV [BP+16],BX
  MOV [BP+12],AX
  MOV AX,[BP+14]
  MOV BX,[BP+10]
  MOV [BP+14],BX
  MOV [BP+10],AX
ftSwap23:
  XOR SI,SI
  MOV AX,08000h
InitXfttri:
  MOV StartX[SI],AX
  ADD SI,2
  CMP SI,400
  JL InitXfttri
  MOV AX,ClipY1
  MOV FirstY,AX
  MOV BX,[BP+30]
  CMP BX,AX
  JL @F
  MOV FirstY,BX
@@:
  CMP BX,ClipY2
  JG EndftTri
  MOV AX,ClipY2
  MOV LastY,AX
  MOV BX,[BP+22]
  CMP BX,AX
  JG @F
  MOV LastY,BX
@@:
  XOR ECX,ECX
  MOV BX,[BP+30]
  MOV CX,[BP+26]
  SUB CX,BX
  JNZ ftConnect12
  CMP BX,ClipY1
  JL ftEnd12
  CMP BX,ClipY2
  JG ftEnd12
  SHL BX,1
  MOV AX,[BP+32]
  MOV StartX[BX],AX
  MOV AX,[BP+20]
  MOV StartA[BX],AX
  MOV AX,[BP+18]
  MOV StartB[BX],AX
  JMP ftEnd12
ftConnect12:
  PUSH ECX
  MOV AX,[BP+16]
  SUB AX,[BP+20]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV EBX,EAX
  MOV DX,[BP+20]
  SHL EDX,16
  PUSH EDX
  MOV AX,[BP+14]
  SUB AX,[BP+18]
  SHL EAX,16
  CDQ
  IDIV ECX
  POP EDX
  MOV CX,[BP+18]
  SHL ECX,16
  MOV SI,[BP+30]
fuvStep12:
  CMP SI,0
  JL fuvNext12
  CMP SI,199
  JG fuvNext12
  SHL SI,1
  MOV EDI,EDX
  SHR EDI,16
  MOV StartA[SI],DI
  MOV EDI,ECX
  SHR EDI,16
  MOV StartB[SI],DI
  SHR SI,1
fuvNext12:
  ADD EDX,EBX
  ADD ECX,EAX
  INC SI
  CMP SI,[BP+26]
  JLE fuvStep12
  POP ECX
  MOV AX,[BP+28]
  SUB AX,[BP+32]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+32]
  SHL EDX,16
  MOV BX,[BP+30]
ftStep12:
  CMP BX,ClipY1
  JL ftNext12
  CMP BX,ClipY2
  JG ftNext12
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
ftNext12:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+26]
  JLE ftStep12
ftEnd12:
  XOR ECX,ECX
  MOV BX,[BP+26]
  MOV CX,[BP+22]
  SUB CX,BX
  JNZ ftConnect23
  CMP BX,ClipY1
  JL ftEnd23
  CMP BX,ClipY2
  JG ftEnd23
  SHL BX,1
  MOV AX,[BP+28]
  MOV StartX[BX],AX
  MOV AX,[BP+16]
  MOV StartA[BX],AX
  MOV AX,[BP+14]
  MOV StartB[BX],AX
  JMP ftEnd23
ftConnect23:
  PUSH ECX
  MOV AX,[BP+12]
  SUB AX,[BP+16]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV EBX,EAX
  MOV DX,[BP+16]
  SHL EDX,16
  PUSH EDX
  MOV AX,[BP+10]
  SUB AX,[BP+14]
  SHL EAX,16
  CDQ
  IDIV ECX
  POP EDX
  MOV CX,[BP+14]
  SHL ECX,16
  MOV SI,[BP+26]
fuvStep23:
  CMP SI,0
  JL fuvNext23
  CMP SI,199
  JG fuvNext23
  SHL SI,1
  MOV EDI,EDX
  SHR EDI,16
  MOV StartA[SI],DI
  MOV EDI,ECX
  SHR EDI,16
  MOV StartB[SI],DI
  SHR SI,1
fuvNext23:
  ADD EDX,EBX
  ADD ECX,EAX
  INC SI
  CMP SI,[BP+22]
  JLE fuvStep23
  POP ECX
  MOV AX,[BP+24]
  SUB AX,[BP+28]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+28]
  SHL EDX,16
  MOV BX,[BP+26]
ftStep23:
  CMP BX,ClipY1
  JL ftNext23
  CMP BX,ClipY2
  JG ftNext23
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV StartX[SI],CX
ftNext23:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+22]
  JLE ftStep23
ftEnd23:
  XOR ECX,ECX
  MOV BX,[BP+30]
  MOV CX,[BP+22]
  SUB CX,BX
  JNZ ftConnect13
  CMP BX,ClipY1
  JL ftEnd13
  CMP BX,ClipY2
  JG ftEnd13
  SHL BX,1
  MOV AX,[BP+20]
  MOV EndA[BX],AX
  MOV AX,[BP+18]
  MOV EndB[BX],AX
  MOV AX,[BP+32]
  MOV EndX[BX],AX
  MOV DX,StartX[BX]
  CMP DX,AX
  JL ftEnd13
  MOV StartX[BX],AX
  MOV EndX[BX],DX
  MOV AX,StartA[BX]
  MOV DX,EndA[BX]
  MOV StartA[BX],DX
  MOV EndA[BX],AX
  MOV AX,StartB[BX]
  MOV DX,EndB[BX]
  MOV StartB[BX],DX
  MOV EndB[BX],AX
  JMP ftEnd13
ftConnect13:
  PUSH ECX
  MOV AX,[BP+12]
  SUB AX,[BP+20]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV EBX,EAX
  MOV DX,[BP+20]
  SHL EDX,16
  PUSH EDX
  MOV AX,[BP+10]
  SUB AX,[BP+18]
  SHL EAX,16
  CDQ
  IDIV ECX
  POP EDX
  MOV CX,[BP+18]
  SHL ECX,16
  MOV SI,[BP+30]
fuvStep13:
  CMP SI,0
  JL fuvNext13
  CMP SI,199
  JG fuvNext13
  SHL SI,1
  MOV EDI,EDX
  SHR EDI,16
  MOV EndA[SI],DI
  MOV EDI,ECX
  SHR EDI,16
  MOV EndB[SI],DI
  SHR SI,1
fuvNext13:
  ADD EDX,EBX
  ADD ECX,EAX
  INC SI
  CMP SI,[BP+22]
  JLE fuvStep13
  POP ECX
  MOV AX,[BP+24]
  SUB AX,[BP+32]
  SHL EAX,16
  CDQ
  IDIV ECX
  MOV DX,[BP+32]
  SHL EDX,16
  MOV BX,[BP+30]
ftStep13:
  CMP BX,ClipY1
  JL ftNext13
  CMP BX,ClipY2
  JG ftNext13
  MOV SI,BX
  SHL SI,1
  MOV ECX,EDX
  SHR ECX,16
  MOV EndX[SI],CX
  CMP StartX[SI],CX
  JL ftNext13
  MOV DI,StartX[SI]
  MOV StartX[SI],CX
  MOV EndX[SI],DI
  MOV DI,StartA[SI]
  MOV CX,EndA[SI]
  MOV StartA[SI],CX
  MOV EndA[SI],DI
  MOV DI,StartB[SI]
  MOV CX,EndB[SI]
  MOV StartB[SI],CX
  MOV EndB[SI],DI
ftNext13:
  ADD EDX,EAX
  INC BX
  CMP BX,[BP+22]
  JLE ftStep13
ftEnd13:
  MOV AX,[BP+8]
  MOV FS,AX
  MOV CX,FirstY
  MOV DI,CX
  MOV SI,DI
  SHL DI,8
  SHL SI,6
  ADD DI,SI
DrawftTri:
  MOV SI,CX
  SHL SI,1
  CMP StartX[SI],08000h
  JE SkipftTriLine
  MOV BX,StartX[SI]
  MOV SX,BX
  CMP BX,ClipX2
  JG SkipftTriLine
  CMP BX,ClipX1
  JG @F
  MOV BX,ClipX1
  MOV SX,BX
@@:
  MOV BX,EndX[SI]
  MOV EX,BX
  CMP BX,ClipX1
  JL SkipftTriLine
  CMP BX,ClipX2
  JL @F
  MOV BX,ClipX2
  MOV EX,BX
@@:
  MOV BX,StartX[SI]
  PUSH CX
  MOV BX,StartX[SI]
  XOR ECX,ECX
  MOV CX,EndX[SI]
  SUB CX,StartX[SI]
  INC CX
  MOV AX,EndA[SI]
  SUB AX,StartA[SI]
  SHL EAX,16
  CDQ
  IDIV ECX
  PUSH EAX
  MOV AX,EndB[SI]
  SUB AX,StartB[SI]
  SHL EAX,16
  CDQ
  IDIV ECX
  PUSH EAX
  PUSH AX
  MOV BP,SP
  MOV AX,EX
  MOV [BP],AX
  MOV DX,StartA[SI]
  SHL EDX,16
  MOV AX,StartB[SI]
  SHL EAX,16
  PUSH SI
DrawftTriLine:
  CMP BX,SX
  JL SkipftTriPixel
  MOV ESI,EAX
  OR SI,SI
  JNZ @F
  INC SI          ; This is to avoid "holes"
@@:
  PUSH SI         ; [BP-4] = dy
  SHR ESI,16
  AND SI,TextureFix
  MOV CL,TextureLen
  SHL SI,CL
  MOV ECX,EDX
  OR CX,CX
  JNZ @F
  INC CX          ; Again, this is to avoid "holes"
@@:
  PUSH CX         ; [BP-6] = dx
  SHR ECX,16
  AND CX,TextureFix
  ADD SI,CX
  ADD SI,4
  ADD SI,[BP+18]
  PUSH AX
  PUSH DX
  PUSH DI
  MOV AL,FS:[SI+1]
  XOR AH,AH
  MUL WORD PTR [BP-6]
  MOV AX,DX
  MOV CX,[BP-4]
  NEG CX
  MUL CX
  MOV DI,DX
  MOV AL,FS:[SI]
  XOR AH,AH
  MOV CX,[BP-4]
  NEG CX
  MUL CX
  MOV AX,DX
  MOV CX,[BP-6]
  NEG CX
  MUL CX
  ADD DI,DX
  ADD SI,TextureFix
  MOV AL,FS:[SI+2]
  XOR AH,AH
  MUL WORD PTR [BP-4]
  MOV AX,DX
  MUL WORD PTR [BP-6]
  ADD DI,DX
  MOV AL,FS:[SI+1]
  XOR AH,AH
  MUL WORD PTR [BP-4]
  MOV AX,DX
  MOV CX,[BP-6]
  NEG CX
  MUL CX
  MOV CX,DX
  ADD CX,DI
  POP DI
  POP DX
  POP AX
  ADD SP,4
  OR CL,CL
  JZ SkipftTriPixel
  MOV ES:[BX+DI],CL
SkipftTriPixel:
  ADD EDX,[BP+6]
  ADD EAX,[BP+2]
  INC BX
  CMP BX,[BP]
  JLE DrawftTriLine
  POP SI
  POP AX
  POP EAX
  POP EAX
  POP CX
SkipftTriLine:
  ADD DI,320
  INC CX
  CMP CX,LastY
  JLE DrawftTri
EndftTri:
  POP BP
  RET 30
DQBfttri ENDP

; ---------------------------------------------------------------------------
; DQBsetTextureSize SUB
; purpose:
;   Sets the current texture width in pixels
; declaration:
;   DECLARE SUB DQBsetTextureSize(BYVAL Size)
; ---------------------------------------------------------------------------
PUBLIC DQBsetTextureSize
DQBsetTextureSize PROC
  PUSH BP
  MOV BP,SP
  MOV AX,128
  MOV BX,[BP+6]
  MOV CX,8
FindSize:
  TEST BL,AL
  JNZ SizeFound
  SHR AX,1
  DEC CX
  JNZ FindSize
SizeFound:
  DEC AX
  MOV TextureFix,AX
  DEC CL
  MOV TextureLen,CL
  POP BP
  RET 2
DQBsetTextureSize ENDP


END
