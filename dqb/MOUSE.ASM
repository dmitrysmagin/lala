; ---------------------------------------------------------------------------
;
; DirectQB MOUSE HANDLING module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN MouseDetected:BYTE
EXTRN MouseOn:BYTE
EXTRN MouseX:WORD
EXTRN MouseY:WORD
EXTRN MouseBut:BYTE
EXTRN MouseShape:BYTE

.CODE

; ---------------------------------------------------------------------------
; DQBmouseDetected FUNCTION
; purpose:
;   Returns true if mouse has been successfully initialized, otherwise 0
; declaration:
;   DECLARE FUNCTION DQBmouseDetected()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBmouseDetected
DQBmouseDetected PROC
  XOR AH,AH
  CMP MouseDetected,1
  SETE AL
  NEG AX
  RET
DQBmouseDetected ENDP

; ---------------------------------------------------------------------------
; DQBmouseX FUNCTION
; purpose:
;   Returns the current mouse x coordinate
; declaration:
;   DECLARE FUNCTION DQBmouseX()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBmouseX
DQBmouseX PROC
  MOV AX,MouseX
  SHR AX,1
  RET
DQBmouseX ENDP

; ---------------------------------------------------------------------------
; DQBmouseY FUNCTION
; purpose:
;   Returns the current mouse y coordinate
; declaration:
;   DECLARE FUNCTION DQBmouseY()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBmouseY
DQBmouseY PROC
  MOV AX,MouseY
  RET
DQBmouseY ENDP

; ---------------------------------------------------------------------------
; DQBmouseLB FUNCTION
; purpose:
;   Returns true if left mouse button is currently pressed
; declaration:
;   DECLARE FUNCTION DQBmouseLB()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBmouseLB
DQBmouseLB PROC
  XOR AH,AH
  TEST MouseBut,1
  SETNZ AL
  NEG AX
  RET
DQBmouseLB ENDP

; ---------------------------------------------------------------------------
; DQBmouseRB FUNCTION
; purpose:
;   Returns true if right mouse button is currently pressed
; declaration:
;   DECLARE FUNCTION DQBmouseRB()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBmouseRB
DQBmouseRB PROC
  XOR AH,AH
  TEST MouseBut,2
  SETNZ AL
  NEG AX
  RET
DQBmouseRB ENDP

; ---------------------------------------------------------------------------
; DQBsetMousePos SUB
; purpose:
;   Sets the coordinates of the mouse pointer
; declaration:
;   DECLARE SUB DQBsetMousePos(BYVAL x,BYVAL y)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetMousePos
DQBsetMousePos PROC
  PUSH BP
  MOV BP,SP
  MOV CX,[BP+8]
  SHL CX,1
  MOV MouseX,CX
  MOV DX,[BP+6]
  MOV MouseY,DX
  MOV AX,4
  INT 33h
  POP BP
  RET 4
DQBsetMousePos ENDP

; ---------------------------------------------------------------------------
; DQBmouseShow SUB
; purpose:
;   Shows the current mouse cursor on the screen
; declaration:
;   DECLARE SUB DQBmouseShow()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBmouseShow
DQBmouseShow PROC
  CMP MouseOn,1
  JE EndMouseShow
  MOV AX,1
  INT 33h
  MOV MouseOn,1
EndMouseShow:
  RET
DQBmouseShow ENDP

; ---------------------------------------------------------------------------
; DQBmouseHide SUB
; purpose:
;   Hides the mouse cursor
; declaration:
;   DECLARE SUB DQBmouseHide()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBmouseHide
DQBmouseHide PROC
  CMP MouseOn,0
  JE EndMouseHide
  MOV AX,2
  INT 33h
  MOV MouseOn,0
EndMouseHide:
  RET
DQBmouseHide ENDP

; ---------------------------------------------------------------------------
; DQBsetMouseRange SUB
; purpose:
;   Sets the mouse range box from x1,y1 to x2,y2
; declaration:
;   DECLARE SUB DQBsetMouseRange(BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetMouseRange
DQBsetMouseRange PROC
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
  CMP MouseOn,0
  JE SkipHide
  MOV AX,2
  INT 33h
SkipHide:
  MOV AX,7
  MOV CX,[BP+12]
  SHL CX,1
  MOV DX,[BP+8]
  SHL DX,1
  INT 33h
  MOV AX,8
  MOV CX,[BP+10]
  MOV DX,[BP+6]
  INT 33h
  CMP MouseOn,0
  JE SkipShow
  MOV AX,1
  INT 33h
SkipShow:
  POP BP
  RET 8
DQBsetMouseRange ENDP

; ---------------------------------------------------------------------------
; DQBsetMouseShape SUB
; purpose:
;   Sets a new mouse cursor shape
; declaration:
;   DECLARE SUB xDQBsetMouseShape(BYVAL hotX,BYVAL hotY,BYVAL ShapeSeg,
;                                 BYVAL ShapeOff)
;   DECLARE SUB DQBsetMouseShape(hotX AS INTEGER,hotY AS INTEGER,Shape AS
;                                 STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBsetMouseShape
xDQBsetMouseShape PROC
  ; Stack layout:
  ;
  ; 12  hotX
  ; 10  hotY
  ; 08  ShapeSeg
  ; 06  ShapeOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP MouseOn,0
  JE SkipHide1
  MOV AX,2
  INT 33h
SkipHide1:
  MOV BX,[BP+12]
  SHL BX,1
  MOV CX,[BP+10]
  MOV AX,[BP+8]
  MOV ES,AX
  MOV DX,[BP+6]
  MOV AX,9
  INT 33h
  CMP MouseOn,0
  JE SkipShow1
  MOV AX,1
  INT 33h
SkipShow1:
  POP BP
  RET 8
xDQBsetMouseShape ENDP

; ---------------------------------------------------------------------------
; DQBsetMouseSpeed SUB
; purpose:
;   Sets the horizontal and vertical mouse speed in mickeys/pixel
; declaration:
;   DECLARE SUB DQBsetMouseSpeed(BYVAL Hor,BYVAL Ver)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetMouseSpeed
DQBsetMouseSpeed PROC
  PUSH BP
  MOV BP,SP
  MOV CX,[BP+8]
  SHR CX,1
  MOV DX,[BP+6]
  MOV AX,0Fh
  INT 33h
  POP BP
  RET 4
DQBsetMouseSpeed ENDP

; ---------------------------------------------------------------------------
; DQBresetMouse SUB
; purpose:
;   Sets the mouse range to (0,0)-(319,199) and sets the default cursor shape
; declaration:
;   DECLARE SUB DQBresetMouse()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBresetMouse
DQBresetMouse PROC
  CMP MouseOn,0
  JE SkipHide2
  MOV AX,2
  INT 33h
SkipHide2:
  MOV AX,7
  MOV CX,0
  MOV DX,639
  INT 33h
  MOV AX,8
  MOV CX,0
  MOV DX,199
  INT 33h
  MOV BX,0
  MOV CX,0
  MOV AX,@DATA
  MOV ES,AX
  MOV DX,OFFSET MouseShape
  MOV AX,9
  INT 33h
  MOV CX,8
  MOV DX,16
  MOV AX,0Fh
  INT 33h
  CMP MouseOn,0
  JE SkipShow2
  MOV AX,1
  INT 33h
SkipShow2:
  RET
DQBresetMouse ENDP


END
