; ---------------------------------------------------------------------------
;
; DirectQB KEYBOARD HANDLING module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN KeyActive:BYTE
EXTRN OldInt9seg:WORD
EXTRN OldInt9off:WORD
EXTRN KeyFlags:BYTE
EXTRN KeyStatus:BYTE

.DATA
KeyMap      DB 01Bh,031h,032h,033h,034h,035h,036h,037h,038h,039h,030h,02Dh,03Dh,008h,008h,071h,077h,065h,072h,074h,079h,075h,069h,06Fh,070h,05Bh,05Dh,00Dh,000h,061h,073h,064h
            DB 066h,067h,068h,06Ah,06Bh,06Ch,03Bh,027h,060h,000h,05Ch,07Ah,078h,063h,076h,062h,06Eh,06Dh,02Ch,02Eh,02Fh,000h,02Ah,000h,020h,000h,000h,000h,000h,000h,000h,000h
            DB 000h,000h,000h,000h,000h,000h,037h,038h,039h,02Dh,034h,035h,036h,02Bh,031h,032h,033h,030h,02Eh,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h
            DB 000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h
            DB 01Bh,021h,040h,023h,024h,025h,05Eh,026h,02Ah,028h,029h,05Fh,03Dh,008h,008h,051h,057h,045h,052h,054h,059h,055h,049h,04Fh,050h,07Bh,07Dh,00Dh,000h,041h,053h,044h
            DB 046h,047h,048h,04Ah,04Bh,04Ch,03Ah,063h,07Eh,000h,07Ch,05Ah,058h,043h,056h,042h,04Eh,04Dh,03Ch,03Eh,03Fh,000h,000h,000h,020h,000h,000h,000h,000h,000h,000h,000h
            DB 000h,000h,000h,000h,000h,000h,000h,000h,000h,02Dh,000h,035h,000h,02Bh,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h
            DB 000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h

.CODE

; ---------------------------------------------------------------------------
; DQBinstallKeyboard SUB
; purpose:
;   Installs a keyboard interrupt handler that updates the status of each key
; declaration:
;   DECLARE SUB DQBinstallKeyboard()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBinstallKeyboard
DQBinstallKeyboard PROC
  CMP KeyActive,1
  JE EndKeyInstall
  MOV AX,040h
  MOV GS,AX
  MOV SI,017h
  MOV AL,GS:[SI]
  AND AL,070h
  MOV KeyFlags,AL 
  PUSH DS
  MOV AX,3509h
  INT 21h
  POP DS
  MOV OldInt9seg,ES
  MOV OldInt9off,BX
  MOV AX,SEG KeyboardISR
  MOV DX,OFFSET KeyboardISR
  PUSH DS
  MOV DS,AX
  MOV AX,2509h
  INT 21h
  POP DS
  MOV KeyActive,1
  RET
KeyboardISR:
  PUSH AX
  PUSH BX
  PUSH SI
  PUSH DS
  MOV BL,1
  IN AL,60h
  TEST AL,80h
  JZ StoreStatus
  AND AL,7Fh
  MOV BL,0
StoreStatus:
  XOR AH,AH
  MOV SI,AX
  MOV AX,@DATA
  MOV DS,AX
  MOV KeyStatus[SI],BL
  IN AL,61h
  OR AL,80h
  OUT 61h,AL
  MOV AL,20h
  OUT 20h,AL
  POP DS
  POP SI
  POP BX
  POP AX
  IRET
EndKeyInstall:
  RET
DQBinstallKeyboard ENDP

; ---------------------------------------------------------------------------
; DQBremoveKeyboard SUB
; purpose:
;   Removes previously installed keyboard interrupt handler and restores
;   the old one
; declaration:
;   DECLARE SUB DQBremoveKeyboard()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBremoveKeyboard
DQBremoveKeyboard PROC
  CMP KeyActive,0
  JE EndKeyRemove
  PUSH DS
  MOV DX,OldInt9off
  MOV AX,OldInt9seg
  MOV DS,AX
  MOV AX,2509h
  INT 21h
  POP DS
  MOV AX,040h
  MOV ES,AX
  MOV SI,017h
  MOV AL,KeyFlags
  MOV ES:[SI],AL
  XOR SI,SI
EmptyKeyStatus:
  MOV KeyStatus[SI],0
  INC SI
  CMP SI,128
  JL EmptyKeyStatus
  MOV KeyActive,0
EndKeyRemove:
  RET
DQBremoveKeyboard ENDP

; ---------------------------------------------------------------------------
; DQBkey FUNCTION
; purpose:
;   Returns the current status of a given key
; declaration:
;   DECLARE FUNCTION DQBkey(BYVAL ScanCode)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBkey
DQBkey PROC
  ; Stack layout:
  ;
  ; 06  ScanCode
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00 BP
  PUSH BP
  MOV BP,SP
  XOR AH,AH
  MOV SI,[BP+6]
  CMP KeyStatus[SI],1
  SETE AL
  NEG AX
  POP BP
  RET 2
DQBkey ENDP

; ---------------------------------------------------------------------------
; DQBreadKey FUNCTION
; purpose:
;   Wait for the user to press a key and returns its scancode. If the keyboard
;   interrupt handler has not been installed by calling DQBinstallKeyboard,
;   returns -1.
; declaration:
;   DECLARE FUNCTION DQBreadKey()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBreadKey
DQBreadKey PROC
  MOV AX,0FFFFh
  CMP KeyActive,0
  JE EndReadKey
  XOR AX,AX
  XOR SI,SI
ReadKeyLoop:
  CMP KeyStatus[SI],1
  JE ReadFound
  INC SI
  CMP SI,128
  JL ReadKeyLoop
  XOR SI,SI
  JMP ReadKeyLoop
ReadFound:
  CMP KeyStatus[SI],1
  JE ReadFound
  MOV AX,SI
EndReadKey:
  RET
DQBreadKey ENDP

; ---------------------------------------------------------------------------
; DQBwaitKey SUB
; purpose:
;   Wait for the user to press a specified key. If the keyboard interrupt
;   handler has not been installed by calling DQBinstallKeyboard, returns
;   without waiting.
; declaration:
;   DECLARE SUB DQBwaitKey(BYVAL ScanCode)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBwaitKey
DQBwaitKey PROC
  PUSH BP
  MOV BP,SP
  CMP KeyActive,0
  JE EndWaitKey
  MOV BX,[BP+6]
  CMP BX,0FFFFh
  JE WaitAnyKeyLoop
WaitKeyLoop:
  CMP KeyStatus[BX],1
  JE WaitFound
  JMP WaitKeyLoop
WaitAnyKeyLoop:
  XOR BX,BX
@@:
  CMP KeyStatus[BX],1
  JE WaitFound
  INC BX
  CMP BX,128
  JL @B
  JMP WaitAnyKeyLoop
WaitFound:
  CMP KeyStatus[BX],1
  JE WaitFound
EndWaitKey:
  POP BP
  RET 2
DQBwaitKey ENDP

; ---------------------------------------------------------------------------
; DQBasc FUNCTION
; purpose:
;   Returns the ascii code of the given scancode. Since often more than a
;   character is associated to the same scancode, the ShiftFlag tells from
;   which table to extract the key
; declaration:
;   DECLARE FUNCTION DQBasc(BYVAL ScanCode,BYVAL ShiftFlag)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBasc
DQBasc PROC
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+8]
  XOR SI,SI
  CMP [BP+6],SI
  JE NotExtended
  ADD SI,128
NotExtended:
  XOR AX,AX
  MOV AL,KeyMap[SI+BX-1]
  POP BP
  RET 4
DQBasc ENDP

; ---------------------------------------------------------------------------
; DQBinkey$ FUNCTION
; purpose:
;   Works almost like the Basic INKEY$ function: if the user presses a key,
;   this function returns the actual character pressed, otherwise it returns
;   a null string.
; declaration:
;   DECLARE FUNCTION xDQBinkey()
;   DECLARE FUNCTION DQBinkey$()
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBinkey
xDQBinkey PROC
  XOR SI,SI
  XOR AX,AX
LookForKey:
  CMP SI,42
  JE SkipKey
  CMP SI,54
  JE SkipKey
  CMP KeyStatus[SI],1
  JE KeyFound
SkipKey:
  INC SI
  CMP SI,128
  JL LookForKey
  RET
KeyFound:
  XOR BH,BH
  MOV BL,KeyStatus[42]
  OR BL,KeyStatus[54]
  SHL BL,7
WaitRelease:
  CMP KeyStatus[SI],1
  JE WaitRelease
  XOR AH,AH
  MOV AL,KeyMap[BX+SI-1]
  RET  
xDQBinkey ENDP


END
