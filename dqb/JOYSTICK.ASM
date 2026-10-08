; ---------------------------------------------------------------------------
;
; DirectQB JOYSTICK HANDLING module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN JoyDetected:BYTE
EXTRN JoySens:WORD
EXTRN JoyX:WORD
EXTRN JoyY:WORD
EXTRN JoyCX:WORD
EXTRN JoyCY:WORD
EXTRN JoyButA:BYTE
EXTRN JoyButB:BYTE
EXTRN JoyMask:BYTE

EXTRN ResetJoy:FAR

.CODE

; ---------------------------------------------------------------------------
; DQBjoyDetected FUNCTION
; purpose:
;   Returns 1 if specified joystick has been detected, otherwise 0
; declaration:
;   DECLARE FUNCTION DQBjoyDetected(BYVAL JoyNum)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBjoyDetected
DQBjoyDetected PROC
  PUSH BP
  MOV BP,SP
  XOR AH,AH
  MOV SI,[BP+6]
  CMP SI,2
  JNE NotGamePad1
  XOR SI,SI
NotGamePad1:
  MOV AL,JoyDetected[SI]
  NEG AX
  POP BP
  RET 2
DQBjoyDetected ENDP

; ---------------------------------------------------------------------------
; DQBpollJoy SUB
; purpose:
;   Updates the internal joystick variables for later use
; declaration:
;   DECLARE SUB DQBpollJoy(BYVAL JoyNum)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBpollJoy
DQBpollJoy PROC
  PUSH BP
  MOV BP,SP
  XOR BH,BH
  CLI
  MOV DX,201h
  OUT DX,AL
  IN AL,DX
  MOV DI,[BP+6]
  CMP DI,2
  JE PollGamePad
  MOV SI,DI
  SHL DI,2
  TEST AL,JoyMask[DI+2]
  SETZ JoyButA[SI]
  TEST AL,JoyMask[DI+3]
  SETZ JoyButB[SI]
  MOV BL,JoyMask[DI]
  ADD BL,JoyMask[DI+1]
  XOR CX,CX
  OUT DX,AL
  JMP JoyLoop
PollGamePad:
  XOR SI,SI
  XOR DI,DI
  TEST AL,JoyMask[2]
  SETZ JoyButA[0]
  TEST AL,JoyMask[3]
  SETZ JoyButB[0]
  TEST AL,JoyMask[6]
  SETZ JoyButA[1]
  TEST AL,JoyMask[7]
  SETZ JoyButB[1]
  MOV BL,JoyMask[0]
  ADD BL,JoyMask[1]
  XOR CX,CX
  OUT DX,AL
JoyLoop:
  IN AL,DX
  TEST AL,JoyMask[DI]
  JZ SkipXsave
  MOV JoyX[SI],CX
SkipXsave:
  TEST AL,JoyMask[DI+1]
  JZ SkipYsave
  MOV JoyY[SI],CX
SkipYsave:
  INC CX
  CMP CX,65535
  JE EndPollJoy
  TEST AL,BL
  JNZ JoyLoop
EndPollJoy:
  STI
  POP BP
  RET 2
DQBpollJoy ENDP

; ---------------------------------------------------------------------------
; DQBjoyMove FUNCTION
; purpose:
;   Returns true if specified joystick points to the given direction
; declaration:
;   DECLARE FUNCTION DQBjoy(BYVAL JoyNum,BYVAL Direction)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBjoyMove
DQBjoyMove PROC
  PUSH BP
  MOV BP,SP
  MOV DI,[BP+8]
  CMP DI,2
  JNE NotGamePad
  XOR DI,DI
NotGamePad:
  MOV BX,[BP+6]
  XOR AH,AH
  CMP BX,0
  JE JoyUp
  CMP BX,1
  JE JoyDown
  CMP BX,2
  JE JoyLeft
  MOV DX,JoyX[DI]
  MOV CX,JoyCX[DI]
  ADD CX,JoySens
  CMP DX,CX
  SETGE AL
  NEG AX
  POP BP
  RET 4
JoyUp:
  MOV DX,JoyY[DI]
  MOV CX,JoyCY[DI]
  SUB CX,JoySens
  CMP DX,CX
  SETLE AL
  NEG AX
  POP BP
  RET 4
JoyDown:
  MOV DX,JoyY[DI]
  MOV CX,JoyCY[DI]
  ADD CX,JoySens
  CMP DX,CX
  SETGE AL
  NEG AX
  POP BP
  RET 4
JoyLeft:
  MOV DX,JoyX[DI]
  MOV CX,JoyCX[DI]
  SUB CX,JoySens
  CMP DX,CX
  SETLE AL
  NEG AX
  POP BP
  RET 4
DQBjoyMove ENDP

; ---------------------------------------------------------------------------
; DQBjoyX FUNCTION
; purpose:
;   Returns x axis position of specified joystick
; declaration:
;   DECLARE FUNCTION DQBjoyX(BYVAL JoyNum)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBjoyX
DQBjoyX PROC
  PUSH BP
  MOV BP,SP
  MOV DI,[BP+6]
  CMP DI,2
  JNE NotGamePad1
  SUB DI,2
NotGamePad1:
  SHL DI,1
  MOV AX,JoyX[DI]
  SUB AX,JoyCX[DI]
  POP BP
  RET 2
DQBjoyX ENDP

; ---------------------------------------------------------------------------
; DQBjoyY FUNCTION
; purpose:
;   Returns y axis position of specified joystick
; declaration:
;   DECLARE FUNCTION DQBjoyY(BYVAL JoyNum)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBjoyY
DQBjoyY PROC
  PUSH BP
  MOV BP,SP
  MOV DI,[BP+6]
  CMP DI,2
  JNE NotGamePad2
  SUB DI,2
NotGamePad2:
  SHL DI,1
  MOV AX,JoyY[DI]
  SUB AX,JoyCY[DI]
  POP BP
  RET 2
DQBjoyY ENDP

; ---------------------------------------------------------------------------
; DQBjoyFire FUNCTION
; purpose:
;   Returns true if specified fire button on specified joystick is pressed
; declaration:
;   DECLARE FUNCTION DQBjoyFire(BYVAL JoyNum,BYVAL Button)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBjoyFire
DQBjoyFire PROC
  PUSH BP
  MOV BP,SP
  MOV DI,[BP+8]
  MOV BX,[BP+6]
  CMP DI,2
  JE GamePadButtons
  XOR AH,AH
  CMP BX,0
  JNE NotButtonA
  CMP JoyButA[DI],0
  SETNE AL
  NEG AX
  POP BP
  RET 4
NotButtonA:
  CMP JoyButB[DI],0
  SETNE AL
  NEG AX
  POP BP
  RET 4
GamePadButtons:
  XOR AH,AH
  CMP BX,0
  JNE NotGamePadA
  CMP JoyButA[0],0
  SETNE AL
  NEG AX
  POP BP
  RET 4
NotGamePadA:
  CMP BX,1
  JNE NotGamePadB
  CMP JoyButB[0],0
  SETNE AL
  NEG AX
  POP BP
  RET 4
NotGamePadB:
  CMP BX,2
  JNE NotGamePadC
  CMP JoyButA[1],0
  SETNE AL
  NEG AX
  POP BP
  RET 4
NotGamePadC:
  CMP JoyButB[1],0
  SETNE AL
  NEG AX
  POP BP
  RET 4
DQBjoyFire ENDP

; ---------------------------------------------------------------------------
; DQBresetJoy SUB
; purpose:
;   Calibrates both joysticks
; declaration:
;   DECLARE SUB DQBresetJoy()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBresetJoy
DQBresetJoy PROC
  CALL ResetJoy
  RET
DQBresetJoy ENDP

; ---------------------------------------------------------------------------
; DQBsetJoySens SUB
; purpose:
;   Allows to change the joysticks sensibility
; declaration:
;   DECLARE SUB DQBsetJoySens(BYVAL NewSens)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetJoySens
DQBsetJoySens PROC
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+6]
  MOV JoySens,BX
  POP BP
  RET 2
DQBsetJoySens ENDP


END
