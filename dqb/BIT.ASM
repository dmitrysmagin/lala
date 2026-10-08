; ---------------------------------------------------------------------------
;
; DirectQB BIT HANDLING module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE

.CODE

; ---------------------------------------------------------------------------
; DQBsetBit FUNCTION
; purpose:
;   Sets a specified bit on a given integer value
; declaration:
;   DECLARE FUNCTION DQBsetBit(BYVAL Value,BYVAL Bit)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetBit
DQBsetBit PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]
  MOV CX,[BP+6]
  MOV BX,1
  CMP CX,0
  JE SkipShift
FindBit:
  SHL BX,1
  DEC CX
  JNZ FindBit
SkipShift:
  TEST AX,BX
  JNZ EndSetBit
  ADD AX,BX
EndSetBit:
  POP BP
  RET 4
DQBsetBit ENDP

; ---------------------------------------------------------------------------
; DQBresetBit FUNCTION
; purpose:
;   Resets a specified bit on a given integer value
; declaration:
;   DECLARE FUNCTION DQBresetBit(BYVAL Value,BYVAL Bit)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBresetBit
DQBresetBit PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]
  MOV CX,[BP+6]
  MOV BX,1
  CMP CX,0
  JE SkipShift1
FindBit1:
  SHL BX,1
  DEC CX
  JNZ FindBit1
SkipShift1:
  MOV DX,0FFFFh
  SUB DX,BX
  AND AX,DX
  POP BP
  RET 4
DQBresetBit ENDP

; ---------------------------------------------------------------------------
; DQBreadBit FUNCTION
; purpose:
;   Returns true if a specified bit is set into a given integer value
; declaration:
;   DECLARE FUNCTION DQBreadBit(BYVAL Value,BYVAL Bit)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBreadBit
DQBreadBit PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]
  MOV CX,[BP+6]
  MOV BX,1
  CMP CX,0
  JE SkipShiftR ; WATCOM: renamed from SkipShift1 (TASM scoped duplicate labels per PROC)
FindBitR: ; WATCOM: renamed from FindBit1, see above
  SHL BX,1
  DEC CX
  JNZ FindBitR
SkipShiftR:
  TEST AX,BX
  SETNZ AL
  XOR AH,AH
  NEG AX
  POP BP
  RET 4
DQBreadBit ENDP

; ---------------------------------------------------------------------------
; DQBtoggleBit FUNCTION
; purpose:
;   Toggles a given bit into a specified integer value
; declaration:
;   DECLARE FUNCTION DQBtoggleBit(BYVAL Value,BYVAL Bit)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBtoggleBit
DQBtoggleBit PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]
  MOV CX,[BP+6]
  MOV BX,1
  CMP CX,0
  JE SkipShift2
FindBit2:
  SHL BX,1
  DEC CX
  JNZ FindBit2
SkipShift2:
  TEST AX,BX
  JNZ TurnOff
  ADD AX,BX
  JMP EndToggleBit
TurnOff:
  SUB AX,BX
EndToggleBit:
  POP BP
  RET 4
DQBtoggleBit ENDP

; ---------------------------------------------------------------------------
; DQBshiftLeft FUNCTION
; purpose:
;   Shifts specified integer value a given number of bits left
; declaration:
;   DECLARE FUNCTION DQBshiftLeft(BYVAL Value,BYVAL nBits)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBshiftLeft
DQBshiftLeft PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]
  MOV CX,[BP+6]
  SHL AX,CL
  MOV CL,CH
  SHL AX,CL
  POP BP
  RET 4
DQBshiftLeft ENDP

; ---------------------------------------------------------------------------
; DQBshiftRight FUNCTION
; purpose:
;   Shifts specified integer value a given number of bits right
; declaration:
;   DECLARE FUNCTION DQBshiftRight(BYVAL Value,BYVAL nBits)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBshiftRight
DQBshiftRight PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]
  MOV CX,[BP+6]
  SHR AX,CL
  MOV CL,CH
  SHR AX,CL
  POP BP
  RET 4
DQBshiftRight ENDP


END
