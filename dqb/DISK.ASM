; ---------------------------------------------------------------------------
;
; DirectQB DISK AND DIRECTORY FUNCTIONS module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN HookInt24:FAR
EXTRN UnhookInt24:FAR

.DATA
DTA           DB  318 dup(?)      ; Disk transfer area for directory scan
                                  ; (also used as long filename record)
WinFind       DB  0               ; Are we handling long filenames?
FFhdl         DW  ?               ; File Find handle (Windows)

.CODE

; ---------------------------------------------------------------------------
; DQBdir$ FUNCTION
; purpose:
;   Scans directory for specified file(s), and returns it. If a file spec is
;   given, the routine performs a findfirst, otherwise a findnext.
; declaration:
;   DECLARE SUB xDQBdir(BYVAL MaskSeg,BYVAL MaskOff,BYVAL Attrib,BYVAL FileSeg,
;                       BYVAL FileOff)
;   DECLARE FUNCTION DQBdir$(Mask AS STRING,Attrib AS INTEGER)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBdir
xDQBdir PROC
  ; Stack layout:
  ;
  ; 16  MaskSeg
  ; 14  MaskOff
  ; 12  Attrib
  ; 10  FileSeg
  ; 08  FileOff
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  CALL HookInt24
  MOV AX,[BP+16]
  MOV DS,AX
  MOV SI,[BP+14]
  MOV DX,SI
  CMP BYTE PTR [SI],0
  JE FindLongNext
  MOV AX,@DATA
  MOV ES,AX
  MOV DI,OFFSET DTA
  MOV CX,[BP+12]
  MOV CH,CL
  XOR SI,SI
  MOV AX,0714Eh
  INT 21h
  JC FindError
  MOV FFhdl,AX
StoreLongEntry:
  PUSH ES
  POP DS
  MOV SI,DI
  MOV AX,[BP+10]
  MOV ES,AX
  MOV DI,[BP+8]
  ADD SI,02Ch
  MOV CX,65
  REP MOVSD
  POP BP
  POP DS
  MOV WinFind,1
  RET 10
FindLongNext:
  CMP WinFind,0
  JE DOSfind
  MOV BX,FFhdl
  XOR SI,SI
  MOV AX,@DATA
  MOV ES,AX
  MOV DI,OFFSET DTA
  MOV AX,0714Fh
  INT 21h
  JNC StoreLongEntry
  CMP AX,07100h
  JE DOSfind
  MOV AX,071A1h
  MOV BX,FFhdl
  INT 21h
  JMP DirNotFound
FindError:
  CMP AX,07100h
  JNE DirNotFound
DOSfind:
  MOV AX,@DATA
  MOV DS,AX
  MOV WinFind,0
  MOV AX,01A00h
  MOV DX,OFFSET DTA
  INT 21h
  MOV AX,[BP+16]
  MOV ES,AX
  MOV DI,[BP+14]
  XOR BL,BL
  CMP ES:[DI],BL
  JNE DirFindFirst
  MOV AX,04F00h
  JMP GetEntry
DirFindFirst:
  MOV DS,AX
  MOV DX,DI
  MOV CX,[BP+12]
  MOV AX,04E00h
GetEntry:
  INT 21h
  JC DirNotFound
  MOV AX,@DATA
  MOV DS,AX
  MOV AX,[BP+10]
  MOV ES,AX
  MOV DI,[BP+8]
  MOV SI,OFFSET DTA
  MOV AL,[SI+21]
  MOV BX,[BP+12]
  AND AL,BL
  JZ DirNotFound
  ADD SI,30
  MOV CX,13
  REP MOVSB
  CALL UnhookInt24
  POP BP
  POP DS
  RET 10
DirNotFound:
  MOV AX,[BP+10]
  MOV ES,AX
  MOV DI,[BP+8]
  XOR AL,AL
  STOSB
  CALL UnhookInt24
  POP BP
  POP DS
  RET 10
xDQBdir ENDP

; ---------------------------------------------------------------------------
; DQBdrive$ FUNCTION
; purpose:
;   Returns the letter of the current drive
; declaration:
;   DECLARE FUNCTION xDQBdrive()
;   DECLARE FUNCTION DQBdrive$()
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBdrive
xDQBdrive PROC
  PUSH BP
  MOV BP,SP
  MOV AX,01900h
  INT 21h
  XOR AH,AH
  ADD AL,65
  POP BP
  RET
xDQBdrive ENDP

; ---------------------------------------------------------------------------
; DQBpath$ FUNCTION
; purpose:
;   Returns the current drive path
; declaration:
;   DECLARE SUB xDQBpath(BYVAL PathSeg,BYVAL PathOff)
;   DECLARE FUNCTION DQBpath$()
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBpath
xDQBpath PROC
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV AX,01900h
  INT 21h
  INC AL
  XOR DH,DH
  MOV DL,AL
  MOV AX,[BP+10]
  MOV DS,AX
  MOV SI,[BP+8]
  MOV AX,07147h
  INT 21h
  POP BP
  POP DS
  RET 4
xDQBpath ENDP


; ---------------------------------------------------------------------------
; DQBnumDrives FUNCTION
; purpose:
;   Returns the total number of drives
; declaration:
;   DECLARE FUNCTION DQBnumDrives()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBnumDrives
DQBnumDrives PROC
  MOV AX,01900h
  INT 21h
  MOV DL,AL
  MOV AX,0E00h
  XOR DH,DH
  INT 21h
  MOV DI,AX
  XOR CX,CX
CheckLogical:
  MOV AX,0440Eh
  MOV BX,CX
  INC BX
  INT 21h
  JC EndNumDrives
  INC CX
  CMP CX,DI
  JL CheckLogical
EndNumDrives:
  MOV AX,CX
  RET
DQBnumDrives ENDP

; ---------------------------------------------------------------------------
; DQBsetDrive SUB
; purpose:
;   Changes the current drive to the new specified one
; declaration:
;   DECLARE FUNCTION xDQBsetDrive(BYVAL DriveCode)
;   DECLARE FUNCTION DQBsetDrive(NewDrive$)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBsetDrive
xDQBsetDrive PROC
  PUSH BP
  MOV BP,SP
  MOV AX,0E00h
  MOV DX,[BP+6]
  INT 21h
  POP BP
  RET 2
xDQBsetDrive ENDP

; ---------------------------------------------------------------------------
; DQBchDir SUB
; purpose:
;   Changes the current directory to the new specified one (Windows version)
; declaration:
;   DECLARE FUNCTION xDQBchDir(BYVAL DirSeg,BYVAL DirOff)
;   DECLARE FUNCTION DQBchDir(NewDir AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBchDir
xDQBchDir PROC
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV DX,[BP+8]
  MOV AX,[BP+10]
  MOV DS,AX
  MOV AX,0713Bh
  INT 21h
  XOR AX,AX
  SETC AL
  NEG AX
  POP BP
  POP DS
  RET 4
xDQBchDir ENDP


END
