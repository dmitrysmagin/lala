; ---------------------------------------------------------------------------
;
; DirectQB PALETTE HANDLING module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE

.DATA
COLOR      DB  ?               ; FINDCOL VARIABLE
VALUE      DB  ?             ; FINDCOL VARIABLE

.CODE

; ---------------------------------------------------------------------------
; DQBsetCol SUB
; purpose:
;   Sets the palette for a specified color
; declaration:
;   DECLARE SUB DQBsetCol(BYVAL ColorIndex,BYVAL r,BYVAL g,BYVAL b)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetCol
DQBsetCol PROC
  ; Stack layout:
  ;
  ; 12  Color index
  ; 10  r
  ; 08  g
  ; 06  b
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV DX,3C8h       ; Port 3C8h: write palette
  MOV AL,[BP+12]
  OUT DX,AL         ; Sets the color
  MOV DX,3C9h
  MOV AL,[BP+10]
  OUT DX,AL         ; Outs the red value
  MOV AL,[BP+8]
  OUT DX,AL         ; Outs the green value
  MOV AL,[BP+6]
  OUT DX,AL         ; Outs the blue value
  POP BP
  RET 8
DQBsetCol ENDP

; ---------------------------------------------------------------------------
; DQBgetCol SUB
; purpose:
;   Gets the hues of a given color index
; declaration:
;   DECLARE SUB DQBgetCol(BYVAL ColorIndex,r,g,b)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBgetCol
DQBgetCol PROC
  ; Stack layout:
  ;
  ; 12  Color index
  ; 10  r (address)
  ; 08  g (address)
  ; 06  b (address)
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV DX,3C7h       ; Port 3C7h: read palette
  MOV AL,[BP+12]
  OUT DX,AL         ; Sets the color
  MOV DX,3C9h
  IN AL,DX          ; Gets the red value...
  MOV [BP+10],AL
  IN AL,DX          ; Gets the green value...
  MOV [BP+8],AL
  IN AL,DX          ; Gets the blue value...
  MOV [BP+6],AL
  POP BP
  RET 8
DQBgetCol ENDP

; ---------------------------------------------------------------------------
; DQBfindCol FUNCTION
; purpose:
;   Returns the color index that is nearest to the specified hues, by
;   searching into the current palette entries.
; declaration:
;   DECLARE FUNCTION DQBfindCol(BYVAL Red,BYVAL Green,BYVAL Blue)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBfindCol
DQBfindCol PROC
  ; Stack layout:
  ;
  ; 10  Red
  ; 08  Green 
  ; 06  Blue 
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV COLOR,0
  MOV VALUE,255
  MOV AH,-1
  MOV BL,[BP+10]
  MOV BH,[BP+8]
  MOV CL,[BP+6]
  MOV DX,3C7h
  MOV AL,0
  OUT DX,AL
  MOV DX,3C9h

;BE SURE THAT HUES ARE BETWEEN 0 & 63
R:
  CMP BL,64
  JL G
  SUB BL,64
  JMP R
G:
  CMP BH,64
  JL B
  SUB BH,64
  JMP G
B:
  CMP CL,64
  JL R2
  SUB CL,64
  JMP B
R2:
  CMP BL,-1
  JG G2
  ADD BL,64
  JMP R2
G2:
  CMP BH,-1
  JG B2
  ADD BH,64
  JMP G2
B2:
  CMP CL,-1
  JG FINLOOP
  ADD CL,64
  JMP B2
;END BOUNDS CHECK

FINLOOP:
  INC AH
  IN AL,DX
  SUB AL,BL
  JNS POS1
  NEG AL
POS1:
  MOV CH,AL
  IN AL,DX
  SUB AL,BH
  JNS POS2
  NEG AL
POS2:
  ADD CH,AL
  IN AL,DX
  SUB AL,CL
  JNS POS3
  NEG AL
POS3:
  ADD CH,AL
  JZ DONE
  CMP CH,VALUE
  JAE FINTEST
  MOV COLOR,AH
  MOV VALUE,CH
FINTEST:
  CMP AH,255
  JB FINLOOP
  XOR AH,AH
  MOV AL,COLOR
  POP BP
  RET 6
DONE:
  MOV AL,AH
  XOR AH,AH
  POP BP
  RET 6
DQBfindCol ENDP

; ---------------------------------------------------------------------------
; DQBfindPalCol FUNCTION
; purpose:
;   Returns the DI index that is nearest to the specified hues, by
;   searching into the specified palette entries.
; declaration:
;   DECLARE FUNCTION DQBfindCol(BYVAL PalSeg,BYVAL PalOff,BYVAL Red,
;                               BYVAL Green,BYVAL Blue)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBfindPalCol
xDQBfindPalCol PROC
  ; Stack layout
  ;
  ; 16  PalSeg
  ; 14  PalOff
  ; 12  Red
  ; 10  Green
  ; 08  Blue
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+16]
  MOV DS,AX
  MOV SI,[BP+14]
  MOV COLOR,0
  MOV VALUE,255
  MOV AH,-1
  MOV BL,[BP+12]
  MOV BH,[BP+10]
  MOV CL,[BP+8]

;BE SURE THAT HUES ARE BETWEEN 0 & 63
PR:
  CMP BL,64
  JL PG
  SUB BL,64
  JMP PR
PG:
  CMP BH,64
  JL PB
  SUB BH,64
  JMP PG
PB:
  CMP CL,64
  JL PR2
  SUB CL,64
  JMP PB
PR2:
  CMP BL,-1
  JG PG2
  ADD BL,64
  JMP PR2
PG2:
  CMP BH,-1
  JG PB2
  ADD BH,64
  JMP PG2
PB2:
  CMP CL,-1
  JG PFINLOOP
  ADD CL,64
  JMP PB2
;END BOUNDS CHECK

PFINLOOP:
  INC AH
  LODSB
  SUB AL,BL
  JNS PPOS1
  NEG AL
PPOS1:
  MOV CH,AL
  LODSB
  SUB AL,BH
  JNS PPOS2
  NEG AL
PPOS2:
  ADD CH,AL
  LODSB
  SUB AL,CL
  JNS PPOS3
  NEG AL
PPOS3:
  ADD CH,AL
  JZ PDONE
  CMP CH,VALUE
  JAE PFINTEST
  MOV COLOR,AH
  MOV VALUE,CH
PFINTEST:
  CMP AH,255
  JB PFINLOOP
  XOR AH,AH
  MOV AL,COLOR
  POP BP
  POP DS
  RET 10
PDONE:
  MOV AL,AH
  XOR AH,AH
  POP BP
  POP DS
  RET 10
xDQBfindPalCol ENDP

; ---------------------------------------------------------------------------
; DQBsetPal SUB
; purpose:
;   Sets the entire palette to the specified one, passed as a string*768,
;   containing in order the r,g and b data for each DI. A hue is a byte and
;   ranges from 0 to 63
; declaration:
;   DECLARE SUB xDQBsetPal(BYVAL PalSeg,BYVAL PalOff)
;   DECLARE SUB DQBsetPal(Pal AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBsetPal
xDQBsetPal PROC
  ; Stack layout:
  ;
  ; 10  PalSeg
  ; 08  PalOff
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+10]
  MOV DS,AX
  XOR AX,AX
  MOV DX,03C8h      ; Port 03C8h: write palette index selector
  OUT DX,AL         ; Starts with DI 0
  MOV SI,[BP+8]     ; SI holds the address of "Pal"
  MOV CX,768        ; Repeats 768 times
  MOV DX,03C9h      ; Port 03C9h: palette entry
SetPalLoop:
  LODSB
  OUT DX,AL         ; Outs the SI to the VGA port
  DEC CX
  JNZ SetPalLoop
  POP BP
  POP DS
  RET 4
xDQBsetPal ENDP

; ---------------------------------------------------------------------------
; DQBgetPal SUB
; purpose:
;   Gets the entire palette and stores it into a given string of 768 chars,
;   ready to be used with DQBsetPal
; declaration:
;   DECLARE SUB xDQBgetPal(BYVAL PalSeg,BYVAL PalOff)
;   DECLARE SUB DQBgetPal(Pal AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBgetPal
xDQBgetPal PROC
  ; Stack layout:
  ;
  ; 08  PalSeg
  ; 06  PalOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]
  MOV ES,AX
  MOV DX,03C7h      ; Port 03C7h: read palette index selector
  XOR AX,AX
  OUT DX,AL         ; Starts with DI 0
  MOV DI,[BP+6]     ; SI holds the address of "Pal"
  MOV CX,768        ; Repeats 768 times
  MOV DX,03C9h      ; Port 03C9h: palette entry
GetPalLoop:
  IN AL,DX          ; Gets a byte from the VGA port...
  STOSB             ; ...and writes it into the buffer
  DEC CX
  JNZ GetPalLoop
  POP BP
  RET 4
xDQBgetPal ENDP

; ---------------------------------------------------------------------------
; DQBfadeIn SUB
; purpose:
;   Fades the current palette to a specified one
; declaration:
;   DECLARE SUB xDQBfadeIn(BYVAL PalSeg,BYVAL PalOff)
;   DECLARE SUB DQBfadeIn(Pal AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBfadeIn
xDQBfadeIn PROC
  ; Stack layout:
  ;
  ; 08  PalSeg
  ; 06  PalOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]
  MOV ES,AX
CheckAllCols:
  MOV DX,3DAh
WaitPal0:
  IN AL,DX
  AND AL,8
  JNZ WaitPal0
WaitPal:
  IN AL,DX
  AND AL,8
  JZ WaitPal
  XOR SI,SI         ; SI is 0 when all DIs are ok
  XOR CX,CX         ; CX is the DI counter
  MOV DI,[BP+6]
CheckCol:
  MOV DX,03C7h
  MOV AL,CL
  OUT DX,AL         ; Read data from DI
  MOV DX,03C9h
  IN AL,DX
  MOV BL,AL         ; BL holds the red hue
  IN AL,DX
  MOV BH,AL         ; BH holds the green hue
  IN AL,DX
  MOV AH,AL         ; AH holds the blue hue
  MOV DX,03C8h
  MOV AL,CL
  OUT DX,AL         ; Write data to DI
  MOV DX,03C9h
  MOV AL,ES:[DI]
  INC DI
  CMP BL,AL
  JG DecRed
  CMP BL,AL
  JL IncRed
  OUT DX,AL
  JMP CheckGreen
DecRed:
  INC SI
  MOV AL,BL
  DEC AL
  OUT DX,AL
  JMP CheckGreen
IncRed:
  INC SI
  MOV AL,BL
  INC AL
  OUT DX,AL
CheckGreen:
  MOV AL,ES:[DI]
  INC DI
  CMP BH,AL
  JG DecGreen
  CMP BH,AL
  JL IncGreen
  OUT DX,AL
  JMP CheckBlue
DecGreen:
  INC SI
  MOV AL,BH
  DEC AL
  OUT DX,AL
  JMP CheckBlue
IncGreen:
  INC SI
  MOV AL,BH
  INC AL
  OUT DX,AL
CheckBlue:
  MOV AL,ES:[DI]
  INC DI
  CMP AH,AL
  JG DecBlue
  CMP AH,AL
  JL IncBlue
  OUT DX,AL
  JMP NextCol
DecBlue:
  INC SI
  MOV AL,AH
  DEC AL
  OUT DX,AL
  JMP NextCol
IncBlue:
  INC SI
  MOV AL,AH
  INC AL
  OUT DX,AL
NextCol:
  INC CX
  CMP CX,256
  JL CheckCol
  CMP SI,0
  JNE CheckAllCols
  POP BP
  RET 4
xDQBfadeIn ENDP

; ---------------------------------------------------------------------------
; DQBfadeStepIn SUB
; purpose:
;   Fades the current palette to a specified one by only one step
; declaration:
;   DECLARE SUB xDQBfadeStepIn(BYVAL PalSeg,BYVAL PalOff)
;   DECLARE SUB DQBfadeStepIn(Pal AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBfadeStepIn
xDQBfadeStepIn PROC
  ; Stack layout:
  ;
  ; 08  PalSeg
  ; 06  PalOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]
  MOV ES,AX
  XOR CX,CX         ; CX is the DI counter
  MOV DI,[BP+6]
sCheckCol:
  MOV DX,03C7h
  MOV AL,CL
  OUT DX,AL         ; Read data from DI
  MOV DX,03C9h
  IN AL,DX
  MOV BL,AL         ; BL holds the red hue
  IN AL,DX
  MOV BH,AL         ; BH holds the green hue
  IN AL,DX
  MOV AH,AL         ; AH holds the blue hue
  MOV DX,03C8h
  MOV AL,CL
  OUT DX,AL         ; Write data to DI
  MOV DX,03C9h
  MOV AL,ES:[DI]
  INC DI
  CMP BL,AL
  JG sDecRed
  CMP BL,AL
  JL sIncRed
  OUT DX,AL
  JMP sCheckGreen
sDecRed:
  MOV AL,BL
  DEC AL
  OUT DX,AL
  JMP sCheckGreen
sIncRed:
  MOV AL,BL
  INC AL
  OUT DX,AL
sCheckGreen:
  MOV AL,ES:[DI]
  INC DI
  CMP BH,AL
  JG sDecGreen
  CMP BH,AL
  JL sIncGreen
  OUT DX,AL
  JMP sCheckBlue
sDecGreen:
  MOV AL,BH
  DEC AL
  OUT DX,AL
  JMP sCheckBlue
sIncGreen:
  MOV AL,BH
  INC AL
  OUT DX,AL
sCheckBlue:
  MOV AL,ES:[DI]
  INC DI
  CMP AH,AL
  JG sDecBlue
  CMP AH,AL
  JL sIncBlue
  OUT DX,AL
  JMP sNextCol
sDecBlue:
  MOV AL,AH
  DEC AL
  OUT DX,AL
  JMP sNextCol
sIncBlue:
  MOV AL,AH
  INC AL
  OUT DX,AL
sNextCol:
  INC CX
  CMP CX,256
  JL sCheckCol
  POP BP
  RET 4
xDQBfadeStepIn ENDP

; ---------------------------------------------------------------------------
; DQBfadeTo SUB
; purpose:
;   Fades all the DIs of current palette to a specified DI
; declaration:
;   DECLARE SUB DQBfadeTo(BYVAL Red,BYVAL Green,BYVAL Blue)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBfadeTo
DQBfadeTo PROC
  PUSH BP
  MOV BP,SP
CheckAllCols1:
  MOV DX,3DAh
WaitPal1:
  IN AL,DX
  AND AL,8
  JNZ WaitPal1
WaitPal2:
  IN AL,DX
  AND AL,8
  JZ WaitPal2
  XOR CX,CX
  XOR SI,SI
CheckCol1:
  MOV DX,03C7h
  MOV AL,CL
  OUT DX,AL
  MOV DX,03C9h
  IN AL,DX
  MOV BL,AL         ; BL holds the current red hue
  IN AL,DX
  MOV BH,AL         ; BH holds the current green hue
  IN AL,DX
  MOV AH,AL         ; AH holds the current blue hue
  MOV DX,03C8h
  MOV AL,CL
  OUT DX,AL
  MOV DX,03C9h
  MOV AL,[BP+10]
  CMP BL,AL
  JG DecRed1
  CMP BL,AL
  JL IncRed1
  OUT DX,AL
  JMP CheckGreen1
DecRed1:
  INC SI
  MOV AL,BL
  DEC AL
  OUT DX,AL
  JMP CheckGreen1
IncRed1:
  INC SI
  MOV AL,BL
  INC AL
  OUT DX,AL
CheckGreen1:
  MOV AL,[BP+8]
  CMP BH,AL
  JG DecGreen1
  CMP BH,AL
  JL IncGreen1
  OUT DX,AL
  JMP CheckBlue1
DecGreen1:
  INC SI
  MOV AL,BH
  DEC AL
  OUT DX,AL
  JMP CheckBlue1
IncGreen1:
  INC SI
  MOV AL,BH
  INC AL
  OUT DX,AL
CheckBlue1:
  MOV AL,[BP+6]
  CMP AH,AL
  JG DecBlue1
  CMP AH,AL
  JL IncBlue1
  OUT DX,AL
  JMP NextCol1
DecBlue1:
  INC SI
  MOV AL,AH
  DEC AL
  OUT DX,AL
  JMP NextCol1
IncBlue1:
  INC SI
  MOV AL,AH
  INC AL
  OUT DX,AL
NextCol1:
  INC CX
  CMP CX,256
  JL CheckCol1
  CMP SI,0
  JNE CheckAllCols1
  POP BP
  RET 6
DQBfadeTo ENDP

; ---------------------------------------------------------------------------
; DQBfadeStepTo SUB
; purpose:
;   Fades all the DIs of current palette to a specified DI
; declaration:
;   DECLARE SUB DQBfadeStepTo(BYVAL Red,BYVAL Green,BYVAL Blue)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBfadeStepTo
DQBfadeStepTo PROC
  PUSH BP
  MOV BP,SP
  XOR CX,CX
sCheckCol1:
  MOV DX,03C7h
  MOV AL,CL
  OUT DX,AL
  MOV DX,03C9h
  IN AL,DX
  MOV BL,AL         ; BL holds the current red hue
  IN AL,DX
  MOV BH,AL         ; BH holds the current green hue
  IN AL,DX
  MOV AH,AL         ; AH holds the current blue hue
  MOV DX,03C8h
  MOV AL,CL
  OUT DX,AL
  MOV DX,03C9h
  MOV AL,[BP+10]
  CMP BL,AL
  JG sDecRed1
  CMP BL,AL
  JL sIncRed1
  OUT DX,AL
  JMP sCheckGreen1
sDecRed1:
  MOV AL,BL
  DEC AL
  OUT DX,AL
  JMP sCheckGreen1
sIncRed1:
  MOV AL,BL
  INC AL
  OUT DX,AL
sCheckGreen1:
  MOV AL,[BP+8]
  CMP BH,AL
  JG sDecGreen1
  CMP BH,AL
  JL sIncGreen1
  OUT DX,AL
  JMP sCheckBlue1
sDecGreen1:
  MOV AL,BH
  DEC AL
  OUT DX,AL
  JMP sCheckBlue1
sIncGreen1:
  MOV AL,BH
  INC AL
  OUT DX,AL
sCheckBlue1:
  MOV AL,[BP+6]
  CMP AH,AL
  JG sDecBlue1
  CMP AH,AL
  JL sIncBlue1
  OUT DX,AL
  JMP sNextCol1
sDecBlue1:
  MOV AL,AH
  DEC AL
  OUT DX,AL
  JMP sNextCol1
sIncBlue1:
  MOV AL,AH
  INC AL
  OUT DX,AL
sNextCol1:
  INC CX
  CMP CX,256
  JL sCheckCol1
  POP BP
  RET 6
DQBfadeStepTo ENDP


; ---------------------------------------------------------------------------
; DQBpalOff SUB
; purpose:
;   Turns all the DIs in current palette to black.
; declaration:
;   DECLARE SUB DQBpalOff()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBpalOff
DQBpalOff PROC
  MOV DX,03C8h
  XOR AX,AX
  OUT DX,AL
  MOV DX,03C9h
  MOV CX,768
PalOff:
  OUT DX,AL
  DEC CX
  JNZ PalOff
  RET
DQBpalOff ENDP

; ---------------------------------------------------------------------------
; DQBpalRotate SUB
; purpose:
;   Rotates palette entries by one step in the specified direction
; declaration:
;   DECLARE SUB DQBpalRotate(BYVAL FirstCol,BYVAL LastCol,BYVAL RotateDir)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBpalRotate
DQBpalRotate PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+6]
  CMP AX,0
  JNE RotateBackward
  MOV CX,[BP+8]
  CMP CX,[BP+10]
  JE EndPalRotate
  SUB CX,[BP+10]
  MOV DX,03C7h
  MOV AL,BYTE PTR [BP+8]
  OUT DX,AL
  MOV DX,03C9h
  IN AL,DX
  ROR EAX,8
  IN AL,DX
  ROR EAX,8
  IN AL,DX
  ROR EAX,16
  PUSH EAX
@@:
  MOV AL,BYTE PTR [BP+10]
  ADD AL,CL
  PUSH AX
  DEC AL
  MOV DX,03C7h
  OUT DX,AL
  MOV DX,03C9h
  IN AL,DX
  ROR EAX,8
  IN AL,DX
  ROR EAX,8
  IN AL,DX
  ROR EAX,16
  MOV EBX,EAX
  POP AX
  MOV DX,03C8h
  OUT DX,AL
  MOV DX,03C9h
  MOV EAX,EBX
  OUT DX,AL
  SHR EAX,8
  OUT DX,AL
  SHR EAX,8
  OUT DX,AL
  DEC CX
  JNZ @B
  MOV AL,BYTE PTR [BP+10]
  MOV DX,03C8h
  OUT DX,AL
  POP EAX
  MOV DX,03C9h
  OUT DX,AL
  SHR EAX,8
  OUT DX,AL
  SHR EAX,8
  OUT DX,AL
  JMP EndPalRotate
RotateBackward:
  MOV AX,[BP+10]
  MOV DX,03C7h
  OUT DX,AL
  MOV DX,03C9h
  IN AL,DX
  ROR EAX,8
  IN AL,DX
  ROR EAX,8
  IN AL,DX
  ROR EAX,16
  PUSH EAX
  MOV CX,[BP+10]
  INC CX
@@:
  MOV AL,CL
  MOV DX,03C7h
  OUT DX,AL
  MOV DX,03C9h
  IN AL,DX
  ROR EAX,8
  IN AL,DX
  ROR EAX,8
  IN AL,DX
  ROR EAX,16
  MOV EBX,EAX
  MOV AL,CL
  DEC AL
  MOV DX,03C8h
  OUT DX,AL
  MOV EAX,EBX
  MOV DX,03C9h
  OUT DX,AL
  SHR EAX,8
  OUT DX,AL
  SHR EAX,8
  OUT DX,AL
  INC CX
  CMP CX,[BP+8]
  JBE @B
  MOV DX,03C8h
  MOV AL,BYTE PTR [BP+8]
  OUT DX,AL
  POP EAX
  MOV DX,03C9h
  OUT DX,AL
  SHR EAX,8
  OUT DX,AL
  SHR EAX,8
  OUT DX,AL
EndPalRotate:
  POP BP
  RET 6
DQBpalRotate ENDP


END
