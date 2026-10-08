; ---------------------------------------------------------------------------
;
; DirectQB: a game programming library for QuickBasic 4.5
;                                 (but it could be easily adapted to your
;                                  own programming language!)
;
;       MAIN MODULE
;
; version 1.61 - June, the 1st 1999
; by Angelo Mottola - Enhanced Creations 1998-99
;
;
; For a complete list of the new features, read the file DIRECTQB.DOC provided
; with this new DirectQB distribuition.
;
; Comments, hints, bomb-mails or anything else are to be sent to:
;
; Angelo Mottola
; angelillo@bigfoot.com
;
; Or you can contact me via ICQ
;
; My ICQ number: 24084401
; ICQ Pager: 24084401@pager.mirabilis.com
;
; Check out the latest DirectQB updates at
;
; The QuickBasic Enhanced Programming Homepage
; http://ec.quickbasic.com
;
; I cannot check my mail everyday; this means that you must wait for a reply,
; so don't get angry if you don't get it soon. Anyway I'll try to answer to
; all your questions! To get a quick answer, contact me via ICQ or, if you
; haven't ICQ (download it now!), send a normal e-mail message to my ICQ pager
; address. This message will arrive to my ICQ client and I'll be able to see
; it while online; just remember that messages sent via the ICQ pager must
; not be longer than 450 characters!
; 
; Thanks again for using DirectQB!!
;
; ***************************************************************************

; Let's use a medium memory model...
.MODEL medium,basic

; ...and 386 instructions!
.386

; 256 bytes of stack are enough for us!
.STACK 100h

EMSmoveStruc STRUC
  len         DD  ?
  sourceType  DB  ?
  sourceHdl   DW  ?
  sourceOff   DW  ?
  sourceSegPg DW  ?
  destType    DB  ?
  destHdl     DW  ?
  destOff     DW  ?
  destSegPg   DW  ?
EMSmoveStruc ENDS


; *** Data ***
.DATA

; Global variables
PUBLIC LibVersion,EMMid,EMSseg,EMShdl,EMSpage,EMSallocated,BaseLayer,BaseSet
PUBLIC PutMode,ClipX1,ClipX2,ClipY1,ClipY2,FontBuffer,CharLen,BMapActive
PUBLIC BMapSeg,BMapFirst,BMapLast,Buffer,KeyActive,OldInt9seg,OldInt9off
PUBLIC KeyFlags,KeyStatus,JoyDetected,JoySens,JoyX,JoyY,JoyCX,JoyCY,JoyButA
PUBLIC JoyButB,JoyMask,MouseDetected,MouseOn,MouseX,MouseY,MouseBut,MouseShape
PUBLIC SoundActive,SoundPage,NumSounds,SoundLen,VolActive,VolSeg,BaseAddr,IRQ
PUBLIC PicORmask,OldIRQseg,OldIRQoff,OldInt24seg,OldInt24off,LastError
PUBLIC FLIactive,FLIfile,FLIbufSeg,PackActive,PackFile


LibVersion    DW  0013Dh          ; DirectQB library version
LibActive     DB  0               ; Has the library been initialized?
EMMid         DB  'EMMXXXX0'      ; EMM id string
EMSseg        DW  ?               ; EMS pageframe segment
EMShdl        DW  ?               ; EMS handle being used by the library
EMSpage       DW  ?               ; Current EMS page
EMSallocated  DW  ?               ; Amount of allocated EMS memory
EMSmove       EMSmoveStruc <>     ; Data moving structure
DataPage      DW  ?               ; Starting data EMS logical page
BaseLayer     DW  10 dup(0)       ; segments of 10 extra layers in base memory
BaseSet       DB  10 dup(0)       ; base layers used flags
VGAon         DB  0               ; Are we in VGA mode?
PutMode       DW  0               ; Sprite put mode (0:transparent, 1:solid)
ClipX1        DW  0               ; Left clipping border
ClipX2        DW  319             ; Right clipping border
ClipY1        DW  0               ; Upper clipping border
ClipY2        DW  199             ; Lower clipping border
FontBuffer    DB  2048 dup (?)    ; Internal font buffer
CharLen       DB  257 dup(8)      ; Internal characters length buffer
BMapActive    DB  10 dup(0)       ; Are the blender maps active?
BMapSeg       DW  10 dup(?)       ; Blender maps segment
BMapFirst     DB  10 dup(?)       ; First mapped foreground color
BMapLast      DB  10 dup(?)       ; Last mapped foreground color
Buffer        DB  ?               ; File I/O byte buffer
FLIactive     DB  0               ; Is a FLI file already opened?
FLIfile       DW  ?               ; Current FLI file handle
FLIbufSeg     DW  ?               ; FLI internal chunk decoding buffer
KeyActive     DB  0               ; Is the keyboard handler already active?
OldInt9seg    DW  ?               ; Original int 9h segment
OldInt9off    DW  ?               ; Original int 9h offset
KeyFlags      DB  ?               ; Original keyboard flags status
KeyStatus     DB  128 dup(0)      ; Status of each key (0:released, 1:pressed)
JoyDetected   DB  2 dup(0)        ; Have the joysticks been detected?
JoySens       DW  40              ; Default joystick sensibility
JoyX          DW  2 dup(0)        ; Joysticks last x position
JoyY          DW  2 dup(0)        ; Joysticks last y position
JoyCX         DW  2 dup(0)        ; Joysticks center x position
JoyCY         DW  2 dup(0)        ; Joysticks center y position
JoyButA       DB  2 dup(0)        ; Joysticks A button
JoyButB       DB  2 dup(0)        ; Joysticks B button
JoyMask       DB  00000001b       ; Joystick 1 x coordinate mask
              DB  00000010b       ; Joystick 1 y coordinate mask
              DB  00010000b       ; Joystick 1 button A mask
              DB  00100000b       ; Joystick 1 button B mask
              DB  00000100b       ; Joystick 2 x coordinate mask
              DB  00001000b       ; Joystick 2 y coordinate mask
              DB  01000000b       ; Joystick 2 button A mask
              DB  10000000b       ; Joystick 2 button B mask
MouseDetected DB  0               ; Has a mouse been detected?
MouseOn       DB  0               ; Is the mouse cursor visible?
MouseX        DW  0               ; Current mouse x coordinate
MouseY        DW  0               ; Current mouse y coordinate
MouseBut      DB  0               ; Current mouse buttons status
MouseShape    DB  0FFh,03Fh,0FFh,01Fh,0FFh,00Fh,0FFh,007h   ; Default mouse
              DB  0FFh,003h,0FFh,001h,0FFh,000h,07Fh,000h   ; cursor shape
              DB  03Fh,000h,07Fh,000h,0FFh,00Fh,0FFh,0BFh   ; data
              DB  0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
              DB  000h,000h,000h,040h,000h,060h,000h,070h
              DB  000h,078h,000h,07Ch,000h,07Eh,000h,07Fh
              DB  080h,07Fh,000h,070h,000h,040h,000h,000h
              DB  000h,000h,000h,000h,000h,000h,000h,000h
SoundActive   DB  0               ; Has the SB custom IRQ been installed?
SoundPage     DW  ?               ; EMS page where sounds data begins
NumSounds     DB  0               ; Number of allocated sounds
BaseAddr      DW  0220h           ; SB base address
IRQ           DB  7               ; SB IRQ
VolActive     DB  0               ; Has volume table been installed?
VolSeg        DW  0               ; Volume table segment
PicORmask     DB  ?               ; OR pic mask to set IRQ
OldIRQseg     DW  ?               ; Old IRQ interrupt segment
OldIRQoff     DW  ?               ; Old IRQ interrupt offset
SoundLen      DW  256 dup(0)      ; Sounds length (256 sounds allowed)
OldInt24seg   DW  ?               ; Original int 24h segment
OldInt24off   DW  ?               ; Original int 24h offset
TimerActive   DB  0               ; Has the custom timer ISR been installed?
TimerFlag     DB  0               ; Internal timer flag
TimerCount    DD  ?               ; Timer counter
ElapsedTicks  DD  ?               ; Number of elapsed clock ticks
OldInt8       DD  ?               ; Old timer ISR address
PackActive    DB  0               ; Is a pack file currently opened?
PackFile      DW  ?               ; Current pack file handle
LastError     DB  29              ; Last error code number
INCLUDE errors.inc                ; Error messages

; Code begins here!
.CODE


; ***************************************************************************
; Internal library procedures
; ***************************************************************************


; ---------------------------------------------------------------------------
; MapEMS internal function
; purpose:
;   Maps the 4 physical pages of the pageframe beginning from the given
;   logical one, and stores the new page index into EMSpage
; calling:
;   DX  Logical page to begin mapping with
; changes:
;   AX,BX,DX
; ---------------------------------------------------------------------------
EVEN
PUBLIC MapEMS
MapEMS PROC FAR
  MOV EMSpage,DX  ; Stores the new current page index
  MOV BX,DX
  MOV DX,EMShdl
  XOR AX,AX       ; Let's clear AX
MapPage:
  MOV AH,44h      ; LIM/EMS function 44h, starting with physical page 0
  INT 67h         ; Map the page!
  INC BX          ; Next logical page
  INC AL          ; Next physical page
  CMP AL,4        ; Map all the four physical pages
  JNE MapPage
  RET
MapEMS ENDP

; ---------------------------------------------------------------------------
; GetLayerSeg internal function
; purpose:
;   Sets CX to the current layer segment; if the layer is video, returns
;   A000h, otherwise the EMS pageframe segment.
; calling:
;   BX  layer to retrieve segment of
; changes:
;   CX,BX,DX (,AX if MAPEMS is called)
; ---------------------------------------------------------------------------
EVEN
PUBLIC GetLayerSeg
GetLayerSeg PROC FAR
  CMP BX,0              ; Is specified layer stored in EMS?
  JLE SHORT NotEMS      ; No, skip section
  DEC BX
  SHL BX,2        ; Translates the layer number into an EMS page index
  CMP BX,EMSpage  ; Do we need to change the actually mapped EMS page?
  JNE SHORT OnDifferentPage   ; Yes: map the new page
  MOV CX,EMSseg   ; Returns the EMS pageframe segment
  RET
OnDifferentPage:
  MOV EMSpage,BX  ; Stores the new current page index
  MOV DX,EMShdl
  MOV AX,4400h
  INT 67h         ; Map the page!
  INC BX          ; Next logical page
  MOV AX,4401h
  INT 67h
  INC BX
  MOV AX,4402h
  INT 67h
  INC BX
  MOV AX,4403h
  INT 67h
  MOV CX,EMSseg   ; Returns the EMS pageframe segment (restored)
  RET             ; Layer is video: returns screen segment (A000h)
NotEMS:
  JNZ SHORT NotVIDEO
  MOV CX,0A000h
  RET
NotVIDEO:
  AND BX,0111111111111111b
  CMP BaseSet[BX],0
  JE BaseNotSet
  SHL BX,1
  MOV CX,BaseLayer[BX]
  RET
BaseNotSet:
  MOV CX,0A000h   ; If specified base layer is not active, output is
  RET             ; redirected to the screen
GetLayerSeg ENDP

; ---------------------------------------------------------------------------
; WriteBuffer internal procedure
; purpose:
;   Writes the buffer to file
; ---------------------------------------------------------------------------
EVEN
PUBLIC WriteBuffer
WriteBuffer PROC FAR
  PUSH DS
  PUSH AX
  PUSH CX
  PUSH DX
  MOV DX,OFFSET Buffer
  MOV AX,@DATA
  MOV DS,AX
  MOV CX,1
  MOV AH,40h
  INT 21h
  POP DX
  POP CX
  POP AX
  POP DS
  RET
WriteBuffer ENDP

; ---------------------------------------------------------------------------
; ReadBuffer internal procedure
; purpose:
;   Reads data from file and places it into the buffer
; ---------------------------------------------------------------------------
EVEN
PUBLIC ReadBuffer
ReadBuffer PROC FAR
  PUSH DS
  PUSH AX
  PUSH CX
  PUSH DX
  MOV DX,OFFSET Buffer
  MOV AX,@DATA
  MOV DS,AX
  MOV CX,1
  MOV AH,3Fh
  INT 21h
  POP DX
  POP CX
  POP AX
  POP DS
  RET
ReadBuffer ENDP

; ---------------------------------------------------------------------------
; ResetJoy internal procedure
; purpose:
;   Detects and calibrates both joystick 1 and 2.
; ---------------------------------------------------------------------------
EVEN
PUBLIC ResetJoy
ResetJoy PROC FAR
  CLI
  MOV DX,201h
  OUT DX,AL
  IN AL,DX
  TEST AL,JoyMask[2]  ; We test also the buttons status to simulate the
  SETZ JoyButA[0]     ; exact time required to accomplish the DQBpollJoy
  TEST AL,JoyMask[3]  ; function
  SETZ JoyButB[0]
  MOV BL,JoyMask[0]
  ADD BL,JoyMask[1]
  XOR CX,CX
  OUT DX,AL
cJoyLoop1:
  IN AL,DX
  TEST AL,JoyMask[0]
  JZ cSkipXsave1
  MOV JoyCX[0],CX
cSkipXsave1:
  TEST AL,JoyMask[1]
  JZ cSkipYsave1
  MOV JoyCY[0],CX
cSkipYsave1:
  INC CX
  CMP CX,65535
  JE JoyDone1
  TEST AL,BL
  JNZ cJoyLoop1
  CMP CX,65535
  SETNZ JoyDetected[0]
JoyDone1:
  OUT DX,AL
  IN AL,DX
  TEST AL,JoyMask[6]
  SETZ JoyButA[1]
  TEST AL,JoyMask[7]
  SETZ JoyButB[1]
  MOV BL,JoyMask[4]
  ADD BL,JoyMask[5]
  XOR CX,CX
  OUT DX,AL
cJoyLoop2:
  IN AL,DX
  TEST AL,JoyMask[4]
  JZ cSkipXsave2
  MOV JoyCX[2],CX
cSkipXsave2:
  TEST AL,JoyMask[5]
  JZ cSkipYsave2
  MOV JoyCY[2],CX
cSkipYsave2:
  INC CX
  CMP CX,65535
  JE JoyDone2
  TEST AL,BL
  JNZ cJoyLoop2
  CMP CX,65535
  SETNZ JoyDetected[1]
JoyDone2:
  STI
  RET
ResetJoy ENDP

; ---------------------------------------------------------------------------
; HookInt24 internal procedure
; purpose:
;   Installs custom INT 24h handler
; ---------------------------------------------------------------------------
EVEN
PUBLIC HookInt24
HookInt24 PROC FAR
  PUSH DS
  MOV AX,3524h
  INT 21h
  MOV AX,@DATA
  MOV DS,AX
  MOV OldInt24seg,ES
  MOV OldInt24off,BX
  POP DS
  MOV AX,SEG CriticalISR
  MOV DX,OFFSET CriticalISR
  PUSH DS
  MOV DS,AX
  MOV AX,2524h
  INT 21h
  POP DS
  RET
CriticalISR:
  MOV AL,3
  IRET
HookInt24 ENDP

; ---------------------------------------------------------------------------
; UnhookInt24 internal procedure
; purpose:
;   Removes the custom int 24h handler
; ---------------------------------------------------------------------------
EVEN
PUBLIC UnhookInt24
UnhookInt24 PROC FAR
  PUSH AX
  PUSH DS
  MOV AX,@DATA
  MOV DS,AX
  MOV DX,OldInt24off
  MOV AX,OldInt24seg
  MOV DS,AX
  MOV AX,2524h
  INT 21h
  POP DS
  POP AX
  RET
UnhookInt24 ENDP


; ***************************************************************************
; Public library procedures
; ***************************************************************************


; ---------------------------------------------------------------------------
; DQBinit FUNCTION
; purpose:
;   Initializes the library, by allocating the needed amount of EMS memory
;   to store layers (if requested). Also checks if a 386 CPU is available on
;   the system, calibrates the joysticks (where available) and sets up the
;   mouse. On success returns 0, otherwise an error code.
;   Always call this procedure before calling any of the library functions!
; declaration:
;   DECLARE FUNCTION DQBinit(BYVAL NumLayers,BYVAL NumSounds,BYVAL MemSize)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBinit
DQBinit PROC
  ; Stack layout:
  ;
  ; 10  NumLayers
  ; 08  NumSounds
  ; 06  EMSpages
  ; 04  Basic segment
  ; 02  Basic offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  PUSH DS
  CMP LibActive,1
  JE Error_AlreadyUp
  MOV AX,@DATA
  MOV ES,AX
  XOR AX,AX
  MOV CX,10
  MOV DI,OFFSET BaseSet
  REP STOSB
  MOV DI,OFFSET FontBuffer
  XOR AX,AX
  MOV DS,AX
  MOV SI,DS:[07Ch]
  MOV AX,DS:[07Eh]
  SUB SI,1024
  MOV DS,AX
  MOV CX,512
  REP MOVSD
  MOV EAX,08080808h
  MOV CX,64
  MOV DI,OFFSET CharLen
  REP STOSD
  STOSB
  POP DS
  PUSHF
  MOV CX,7000h    ; Set bits 12..15
  PUSH CX
  POPF
  PUSHF           ; Push them again...
  POP AX          ; ...and get them back
  AND AX,7000h    ; Mask bits 12..15
  SETNZ AL
  XOR AH,AH       ; Zero it
  POPF
  TEST AX,AX
  JE Error_NoCPU
  XOR AX,AX
  MOV EMSallocated,AX
  MOV DX,[BP+10]
  SHL DX,2
  MOV SoundPage,DX
  MOV BX,[BP+8]
  SHL BX,2
  ADD DX,BX
  MOV DataPage,DX
  MOV DX,[BP+8]
  MOV NumSounds,DL
  MOV DX,[BP+10]  ; Let's find out the total amount of EMS needed
  ADD DX,[BP+8]
  SHL DX,2
  MOV BX,[BP+6]
  OR BX,BX
  JZ SHORT @F
  SHR BX,4
  INC BX
  ADD DX,BX
@@:
  TEST DX,DX      ; DX holds the total number of EMS pages requested by user
  JE MemDone      ; no EMS memory is needed, so skip memory allocation
  MOV ES,AX
  MOV BX,19Eh     ; Int 67h address
  MOV AX,ES:[BX]  ; Gets the EMM segment from the Interrupts Vector Table
  MOV ES,AX       ; ES now is the segment were the EMM driver is loaded
  MOV DI,10
  MOV SI,OFFSET EMMid
  MOV CX,8        ; Compares 8 characters (EMM id length)
  REPE CMPSB
  JNE Error_NoEMS   ; Strings don't match: EMS is not installed
  MOV AH,42h
  INT 67h         ; Let's check if enough EMS is available
  MOV DX,[BP+10]  ; Let's find out again the total amount of EMS needed
  ADD DX,[BP+8]
  SHL DX,2        ; EMS needed=(NumLayers+NumSounds)*4 pages
  MOV CX,[BP+6]
  OR CX,CX
  JZ SHORT @F
  SHR CX,4
  INC CX
  ADD DX,CX
@@:
  CMP BX,DX       ; BX contains the number of available pages
  JL Error_NotEnoughEMS     ; not enough memory!
  MOV EMSallocated,DX       ; Stores amount of allocated EMS pages
  MOV AH,43h
  MOV BX,DX
  INT 67h         ; Allocates memory
  MOV EMShdl,DX   ; Stores the EMS handle
  MOV AH,41h
  INT 67h         ; Gets the EMS pageframe...
  MOV EMSseg,BX   ; ...and stores it
  MOV ES,BX
  MOV BX,[BP+8]
  TEST BX,BX
  JE CheckLayers
  MOV EAX,080808080h
  ADD BX,[BP+10]
InitSounds:
  MOV DX,BX
  DEC DX
  SHL DX,2
  PUSH AX
  PUSH BX
  PUSH DX
  CALL MapEMS
  POP DX
  POP BX
  POP AX
  XOR DI,DI
  MOV CX,16384
  REP STOSD
  DEC BX
  JNZ InitSounds
CheckLayers:
  MOV BX,[BP+10]
  TEST BX,BX
  JE MemDone
  XOR EAX,EAX
InitLayers:
  MOV DX,BX
  DEC DX
  SHL DX,2
  PUSH AX
  PUSH BX
  PUSH DX
  CALL MapEMS
  POP DX
  POP BX
  POP AX
  XOR DI,DI
  MOV CX,16384
  REP STOSD
  DEC BX
  JNZ InitLayers
  XOR DX,DX
  CALL MapEMS     ; Maps the pageframe starting from logical page 0
  XOR AX,AX       ; EMS memory initialized!
  JMP MemDone
Error_AlreadyUp:
  MOV AX,4        ; Error 4: Library already initialized
  MOV LastError,0
  JMP EndInit
Error_NoCPU:
  MOV AX,1        ; Error 1: No 386 CPU detected!
  MOV LastError,1
  JMP EndInit
Error_NoEMS:
  MOV AX,2        ; Error 2: No EMS memory manager detected!
  MOV LastError,2
  JMP EndInit
Error_NotEnoughEMS:
  MOV AX,3        ; Error 3: Not enough free EMS memory!
  MOV LastError,3
  JMP EndInit
MemDone:
  CALL ResetJoy
  XOR AX,AX
  INT 33h
  TEST AX,AX
  JE MouseDone
  MOV CX,31
  MOV AX,SEG MouseISR
  MOV ES,AX
  MOV DX,OFFSET MouseISR
  MOV AX,0Ch
  INT 33h
  MOV MouseDetected,1
  JMP MouseDone
MouseISR:
  PUSH DS
  MOV AX,@DATA
  MOV DS,AX
  MOV MouseX,CX
  MOV MouseY,DX
  MOV MouseBut,BL
  POP DS
  RET
MouseDone:
  MOV LibActive,1
  XOR AX,AX
EndInit:
  POP BP
  RET 6
DQBinit ENDP

; ---------------------------------------------------------------------------
; DQBver FUNCTION
; purpose:
;   Returns the library version number in hexadecimal format; the higher byte
;   is the major release number, and the lower byte is the minor release
;   number.
; declaration:
;   DECLARE FUNCTION DQBver()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBver
DQBver PROC
  MOV AX,LibVersion
  RET
DQBver ENDP

; ---------------------------------------------------------------------------
; DQBmapLayer FUNCTION
; purpose:
;   Returns the segment of specified layer, and if layer is on EMS, also
;   maps the pageframe to it
; declaration:
;   DECLARE FUNCTION DQBmapLayer(BYVAL Layer)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBmapLayer
DQBmapLayer PROC
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+6]
  CALL GetLayerSeg
  MOV AX,CX
  POP BP
  RET 2
DQBmapLayer ENDP

; ---------------------------------------------------------------------------
; xDQBerror SUB
; purpose:
;   Returns the last error message
; declaration:
;   DECLARE SUB xDQBerror()
;   DECLARE FUNCTION DQBerror$()
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBerror
xDQBerror PROC
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+10]
  MOV ES,AX
  MOV DI,[BP+8]
  MOV AX,@DATA
  MOV DS,AX
  MOV SI,OFFSET ErrorMsg
  XOR CX,CX
  MOV CL,LastError
  SHL CX,5
  ADD SI,CX
  MOV CX,8
  REP MOVSD
  POP BP
  POP DS
  RET 4
xDQBerror ENDP

; ---------------------------------------------------------------------------
; DQBclose SUB
; purpose:
;   Deallocates previously allocated EMS memory (if it was allocated), and
;   does other closing stuff needed.
;   ALWAYS CALL THIS SUB BEFORE ENDING YOUR PROGRAMS!
; declaration:
;   DECLARE SUB DQBclose()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBclose
DQBclose PROC
  CMP LibActive,1
  JE SHORT @F
  RET
@@:
  CMP TimerActive,0
  JE NoRemoveTimer
  XOR AX,AX
  MOV ES,AX
  CLI
  MOV EAX,OldInt8
  MOV ES:[32],EAX
  STI
  MOV AL,034h
  OUT 043h,AL
  XOR AX,AX
  OUT 040h,AL
  OUT 040h,AL
  MOV TimerActive,0
NoRemoveTimer:
  CMP KeyActive,0
  JE NoRemoveKey
  PUSH DS
  MOV DX,OldInt9off
  MOV AX,OldInt9seg
  MOV DS,AX
  MOV AX,2509h
  INT 21h
  POP DS
  MOV BL,KeyFlags
  MOV AX,040h
  MOV ES,AX
  MOV SI,017h
  MOV ES:[SI],BL
  MOV KeyActive,0
NoRemoveKey:
  CMP SoundActive,0
  JE NoRemoveSB
  MOV DX,BaseAddr
  ADD DX,06h
  MOV AL,1
  OUT DX,AL
  IN AL,DX
  IN AL,DX
  IN AL,DX
  IN AL,DX
  XOR AL,AL
  OUT DX,AL
  ADD DX,08h
  XOR CX,CX
WaitRead1:
  DEC CX
  JZ EndReadDSP1
  IN AL,DX
  OR AL,AL
  JNS WaitRead1
EndReadDSP1:
  SUB DX,4
  IN AL,DX          ; SB reset
  IN AL,021h
  OR AL,PicORmask
  OUT 021h,AL
  XOR AX,AX
  MOV ES,AX
  MOV AL,IRQ
  ADD AL,8
  MOV SI,AX
  SHL SI,2
  CLI
  MOV AX,OldIRQoff
  MOV ES:[SI],AX
  MOV AX,OldIRQseg
  MOV ES:[SI+2],AX  ; Old IRQ restored
  STI
  MOV SoundActive,0
NoRemoveSB:
  CMP VolActive,0
  JE NoRemoveVol
  MOV AH,049h
  MOV BX,VolSeg
  MOV ES,BX
  INT 21h
  MOV VolActive,0
NoRemoveVol:
  CMP EMSallocated,0    ; Did we allocate EMS memory?
  JE NoDealloc      ; No EMS memory was allocated at startup!
  MOV AH,45h        ; Function 45h: release allocated EMS memory
  MOV DX,EMShdl
  INT 67h
NoDealloc:
  XOR SI,SI
DeallocBase:
  CMP BaseSet[SI],0
  JE NoDeallocBase
  MOV BX,SI
  SHL BX,1
  PUSH SI
  MOV CX,BaseLayer[BX]
  MOV ES,CX
  MOV AH,49h
  INT 21h
  POP SI
  MOV BaseSet[SI],0
NoDeallocBase:
  INC SI
  CMP SI,10
  JB DeallocBase
  XOR CX,CX
DeallocBMap:
  MOV SI,CX
  CMP BMapActive[SI],0
  JE NoFreeBMap
  MOV BMapActive[SI],0
  SHL SI,1
  MOV AH,49h
  MOV ES,BMapSeg[SI]
  INT 21h
NoFreeBMap:
  INC CX
  CMP CX,10
  JB DeallocBMap
  CMP FLIactive,0
  JE NoCloseFLI
  MOV BX,FLIfile
  MOV AH,3Eh
  INT 21h
  MOV AH,49h
  MOV BX,FLIbufSeg
  MOV ES,BX
  INT 21h
  MOV FLIactive,0
NoCloseFLI:
  CMP PackActive,0
  JE NoClosePack
  MOV BX,PackFile
  MOV AH,3Eh
  INT 21h
  MOV PackActive,0
NoClosePack:
  CMP VGAon,0
  JE NoTextMode
  MOV AX,03h
  INT 010h
  MOV VGAon,0
NoTextMode:
  MOV LibActive,0
  RET
DQBclose ENDP

; ---------------------------------------------------------------------------
; DQBsort FUNCTION
; purpose:
;   Sorts a given array of records, with a specified number of elements
; declaration:
;   DECLARE SUB DQBsort(BYVAL ArraySeg,BYVAL ArrayOff,BYVAL NumRecords,
;                       BYVAL RecordLen,BYVAL IndexOff)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsort
DQBsort PROC
  ; Stack layout
  ;
  ; 14  ArraySeg
  ; 12  ArrayOff
  ; 10  NumRecords
  ; 08  RecordLen
  ; 06  IndexOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+14]
  MOV ES,AX
  MOV CX,1
  CMP [BP+10],CX
  JE EndSort
  XOR CX,CX
  MOV SI,[BP+12]
  ADD SI,[BP+6]
SortArray:
  MOV BX,ES:[SI]
  PUSH CX
  INC CX
  MOV DI,SI
  ADD DI,[BP+8]
SortInner:
  CMP BX,ES:[DI]
  JL DontSwap
  MOV BX,ES:[DI]
  PUSH CX
  PUSH SI
  PUSH DI
  SUB SI,[BP+6]
  SUB DI,[BP+6]
  MOV CX,[BP+8]
@@:
  MOV AL,ES:[SI]
  MOV AH,ES:[DI]
  MOV ES:[SI],AH
  MOV ES:[DI],AL
  INC SI
  INC DI
  DEC CX
  JNZ @B
  POP DI
  POP SI
  POP CX
DontSwap:
  ADD DI,[BP+8]
  INC CX
  CMP CX,[BP+10]
  JL SortInner
  POP CX
  ADD SI,[BP+8]
  INC CX
  MOV DX,[BP+10]
  DEC DX
  CMP CX,DX
  JL SortArray
EndSort:
  POP BP
  RET 10
DQBsort ENDP

; ---------------------------------------------------------------------------
; DQBangle FUNCTION
; purpose:
;   Returns the angle between two given points (uses the FPU)
; declaration:
;   DECLARE FUNCTION DQBangle(BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBangle
DQBangle PROC
  ; Stack layout:
  ;
  ; 12  x1
  ; 10  y1
  ; 08  x2
  ; 06  y2
  ; 04  Basic segment
  ; 02  Basic offset
  ; 00  BP
  PUSH BP
  SUB SP,4        ; Preserves stack space for FPU operations
  MOV BP,SP
  XOR EAX,EAX
  XOR EBX,EBX
  MOV AX,[BP+12]
  CMP AX,[BP+16]
  JNE FindAngle
  MOV AX,[BP+14]  ; Special case: points lie on the same vertical line
  CMP AX,[BP+10]
  JGE SHORT @F
  MOV AX,127
  ADD SP,4
  POP BP
  RET 8
@@:
  XOR AX,AX
  ADD SP,4
  POP BP
  RET 8
FindAngle:
  SUB AX,[BP+16]
  CWDE
  MOV EBX,EAX     ; EBX holds (x2-x1)
  MOV AX,[BP+10]
  SUB AX,[BP+14]
  CWDE            ; EAX holds (y2-y1)
  FNINIT          ; Initializes the FPU without checking for exceptions
  MOV DWORD PTR [BP],128
  FILD DWORD PTR [BP]      ; Loads the value "128" into what'll become ST(2)
  MOV DWORD PTR [BP],EAX
  FILD DWORD PTR [BP]      ; Loads (y2-y1) into what'll become ST(1)
  MOV DWORD PTR [BP],EBX
  FILD DWORD PTR [BP]      ; Loads (x2-x1) into ST(0)
  FDIV            ; Calculates (y2-y1)/(x2-x1) as FDIV does ST(1)/ST(0)
  FLD1            ; Loads a 1.0 into ST(0) so that FPATAN calculates
  FPATAN          ; the inverse tangent of ST(1)
  FLDPI           ; Loads PI onto the top of the FPU stack
  FDIV            ; Divides the artangent result by PI and multiplies it by
  FMUL            ; 128, so we have an angle in the range 0-255. Stores
  FISTP DWORD PTR [BP]     ; integer part of result into the stack and waits
  FWAIT                    ; for the 80387 to complete operations.
  MOV EAX,DWORD PTR [BP]
  ADD AX,64
  MOV BX,[BP+12]
  CMP BX,[BP+16]
  JGE EndAngle
  ADD AX,128      ; Fix angle
EndAngle:
  AND AX,0FFh     ; Be sure to return only values in the range 0-255
  ADD SP,4
  POP BP
  RET 8  
DQBangle ENDP

; ---------------------------------------------------------------------------
; DQBsetFrameRate SUB
; purpose:
;   Basically this sets the computer timer resolution. To be used together
;   with DQBwaitFrame to achieve desired program speed
; declaration:
;   DECLARE SUB DQBsetFrameRate(BYVAL FPS)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetFrameRate
DQBsetFrameRate PROC
  PUSH BP
  MOV BP,SP
  CMP TimerActive,1
  JE TimerSet
  XOR AX,AX
  MOV ES,AX
  CLI
  MOV EAX,ES:[32]
  MOV OldInt8,EAX
  MOV AX,OFFSET TimerISR
  MOV ES:[32],AX
  MOV AX,SEG TimerISR
  MOV ES:[34],AX
  STI
  MOV TimerActive,1
TimerSet:
  MOV ElapsedTicks,0
  XOR EBX,EBX
  MOV BX,[BP+6]
  CMP BX,19
  JB SlowTimer
  MOV EAX,01234DDh
  CDQ
  DIV EBX
  MOV BX,AX
  MOV TimerCount,EAX
  MOV AL,034h
  OUT 043h,AL
  MOV AL,BL
  OUT 040h,AL
  MOV AL,BH
  OUT 040h,AL
  POP BP
  RET 2
SlowTimer:
  MOV TimerCount,10000h
  MOV AL,034h
  OUT 043h,AL
  XOR AX,AX
  OUT 040h,AL
  OUT 040h,AL
  POP BP
  RET 2
TimerISR:
  PUSH DS
  PUSH EAX
  MOV AX,@DATA
  MOV DS,AX
  MOV TimerFlag,1
  MOV EAX,TimerCount
  ADD ElapsedTicks,EAX
  CMP ElapsedTicks,10000h
  JL SHORT @F
  SUB ElapsedTicks,10000h
  PUSHF
  CALL OldInt8      ; Keep calling old timer interrupt 18.2 times per second
@@:
  POP EAX
  POP DS
  IRET
DQBsetFrameRate ENDP

; ---------------------------------------------------------------------------
; DQBframeReady SUB
; purpose:
;   Returns zero if not enough time has passed to synchronize graphics with
;   specified FPS rate set by DQBsetFrameRate, otherwise a non-zero value
; declaration:
;   DECLARE FUNCTION DQBframeReady()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBframeReady
DQBframeReady PROC
  XOR AX,AX
  CMP TimerActive,0
  JE EndWaitFrame
  CMP TimerFlag,0
  SETNE AL
  TEST AL,AL
  JE EndWaitFrame
  MOV TimerFlag,0
EndWaitFrame:
  NEG AX
  RET
DQBframeReady ENDP

; ---------------------------------------------------------------------------
; DQBInitVGA SUB
; purpose:
;   Sets VGA 320x200 with 256 colors, and initializes the mouse if found.
; declaration:
;   DECLARE SUB DQBinitVGA
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBinitVGA
DQBinitVGA PROC
  MOV AX,013h
  INT 010h
  CMP MouseDetected,1
  JNE EndInitVGA
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
EndInitVGA:
  MOV VGAon,1
  RET
DQBinitVGA ENDP

; ---------------------------------------------------------------------------
; DQBInitText SUB
; purpose:
;   Sets plain 80x25 text mode.
; declaration:
;   DECLARE SUB DQBinitText()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBinitText
DQBinitText PROC
  MOV AX,03h
  INT 010h
  MOV VGAon,0
  RET
DQBinitText ENDP

; ---------------------------------------------------------------------------
; DQBsetBaseLayer FUNCTION
; purpose:
;   Tryes to allocate conventional memory for a given base layer. On success
;   it returns the segment, otherwise 0.
; declaration:
;   DECLARE FUNCTION DQBsetBaseLayer(BYVAL Layer)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetBaseLayer
DQBsetBaseLayer PROC
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+6]
  AND SI,0111111111111111b
  CMP SI,10
  JGE ErrorBaseLayer
  CMP BaseSet[SI],0
  JNE ErrorBaseLayer
  SHL SI,1
  MOV AH,048h
  MOV BX,4000
  INT 021h
  JC ErrorBaseLayer
  MOV BaseLayer[SI],AX
  SHR SI,1
  MOV BaseSet[SI],1
  MOV ES,AX
  PUSH AX
  XOR DI,DI
  XOR EAX,EAX
  MOV CX,16000
  REP STOSD
  POP AX
  POP BP
  RET 2
ErrorBaseLayer:
  XOR AX,AX
  MOV LastError,7
  POP BP
  RET 2
DQBsetBaseLayer ENDP

; ---------------------------------------------------------------------------
; DQBcopyLayer SUB
; purpose:
;   Copies a layer onto another one.
; declaration:
;   DECLARE SUB DQBcopyLayer(BYVAL SourceLayer,BYVAL DestLayer)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBcopyLayer
DQBcopyLayer PROC
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
  TEST BX,BX
  JLE OneInRAM    ; Is source layer on RAM?
  TEST DX,DX
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
  MOV BX,[BP+8]
  DEC BX
  SHL BX,2
  MOV AX,4402h
  INT 67h
  MOV AX,4403h    ; At the end the first two physical pages are mapped to the    
  INC BX          ; first half of the source layer, and the third and fourth
  INT 67h         ; pages points to the first half of the destination layer
  XOR SI,SI
  MOV DI,8000h
  MOV CX,2000h    ; Copy the DWORDs!
  REP MOVSD
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
  XOR SI,SI
  MOV DI,8000h
  MOV CX,2000h
  REP MOVSD
  MOV AX,@DATA
  MOV DS,AX
  MOV DX,EMSpage
  CALL MapEMS
  POP BP
  POP DS
  RET 4
OneInRAM:
  CALL GetLayerSeg
  MOV DI,CX       ; Saves source segment into DI
  MOV BX,[BP+8]
  CALL GetLayerSeg
  MOV ES,CX       ; Sets destination segment...
  MOV DS,DI       ; ...and source segment
  XOR DI,DI       ; Both source and destination offsets start as 0
  XOR SI,SI
  MOV CX,16000    ; Move 16000 DWORDs
  REP MOVSD
EndCopy:
  POP BP
  POP DS
  RET 4
DQBcopyLayer ENDP

; ---------------------------------------------------------------------------
; DQBclearLayer SUB
; purpose:
;   Clears the content of a given layer to black (color 0 used)
; declaration:
;   DECLARE SUB DQBclearLayer(BYVAL Layer)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBclearLayer
DQBclearLayer PROC
  ; Stack layout:
  ;
  ; 06  Layer
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+6]
  CALL GetLayerSeg
  MOV ES,CX
  MOV CX,16000
  XOR EAX,EAX
  XOR DI,DI
  REP STOSD
  POP BP
  RET 2
DQBclearLayer ENDP

; ---------------------------------------------------------------------------
; DQBwait SUB
; purpose:
;   Waits for video vertical retrace as many times as specified when called
; declaration:
;   DECLARE SUB DQBwait(BYVAL times)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBwait
DQBwait PROC
  PUSH BP
  MOV BP,SP
  MOV CX,[BP+6]
  MOV DX,3DAh       ; Vertical retrace port
Loop1:
  IN AL,DX
  AND AL,8
  JNZ Loop1
Loop2:
  IN AL,DX
  AND AL,8
  JZ Loop2
  DEC CX
  JNZ Loop1
  POP BP
  RET 2
DQBwait ENDP

; ---------------------------------------------------------------------------
; DQBpeek SUB
; purpose:
;   Reads data from EMS
; declaration:
;   DECLARE SUB DQBpeek(BYVAL DataSeg,BYVAL DataOff,BYVAL Offset&,BYVAL Length)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBpeek
DQBpeek PROC
  ; Stack layout:
  ;
  ; 14  DataSeg
  ; 12  DataOff
  ; 10  Offset (high word)
  ; 08  Offset (low word)
  ; 06  Length
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV SI,OFFSET EMSmove
  XOR EAX,EAX
  MOV AX,[BP+6]
  MOV EMSmove.len,EAX
  MOV EMSmove.destType,0
  MOV EMSmove.destHdl,0
  MOV AX,[BP+12]
  MOV EMSmove.destOff,AX
  MOV AX,[BP+14]
  MOV EMSmove.destSegPg,AX
  MOV EMSmove.sourceType,1
  MOV AX,EMShdl
  MOV EMSmove.sourceHdl,AX
  MOV AX,[BP+10]
  SHL EAX,16
  MOV AX,[BP+8]
  MOV BX,AX
  AND BX,03FFFh
  SHR EAX,14
  MOV EMSmove.sourceOff,BX
  ADD AX,DataPage
  MOV EMSmove.sourceSegPg,AX
  MOV AX,05700h
  INT 67h
  POP BP
  RET 10
DQBpeek ENDP

; ---------------------------------------------------------------------------
; DQBpoke SUB
; purpose:
;   Writes data into EMS
; declaration:
;   DECLARE SUB DQBpoke(BYVAL DataSeg,BYVAL DataOff,BYVAL Offset&,BYVAL Length)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBpoke
DQBpoke PROC
  ; Stack layout:
  ;
  ; 14  DataSeg
  ; 12  DataOff
  ; 10  Offset (high word)
  ; 08  Offset (low word)
  ; 06  Length
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV SI,OFFSET EMSmove
  XOR EAX,EAX
  MOV AX,[BP+6]
  MOV EMSmove.len,EAX
  MOV EMSmove.sourceType,0
  MOV EMSmove.sourceHdl,0
  MOV AX,[BP+12]
  MOV EMSmove.sourceOff,AX
  MOV AX,[BP+14]
  MOV EMSmove.sourceSegPg,AX
  MOV EMSmove.destType,1
  MOV AX,EMShdl
  MOV EMSmove.destHdl,AX
  MOV AX,[BP+10]
  SHL EAX,16
  MOV AX,[BP+8]
  MOV BX,AX
  AND BX,03FFFh
  SHR EAX,14
  MOV EMSmove.destOff,BX
  ADD AX,DataPage
  MOV EMSmove.destSegPg,AX
  MOV AX,05700h
  INT 67h
  POP BP
  RET 10
DQBpoke ENDP

; ---------------------------------------------------------------------------
; DQBfpu SUB
; purpose:
;   Speeds up floating point routines
; declaration:
;   DECLARE SUB DQBfpu()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBFPU
DQBFPU PROC
  PUSH DS
  MOV AX,CS
  MOV DS,AX
  MOV DX,OFFSET DQBINT3D
  MOV AX,253DH ;; (SET INTERRUPT VECTOR)
  INT 21H
  POP DS
  RET
DQBFPU ENDP

EVEN
PUBLIC DQBINT3D
DQBINT3D PROC
  PUSH BP
  MOV BP,SP
  PUSH DI
  PUSH ES
  LES DI,[BP+2] ;; ES:DI PTR TO RETURN ADDRESS
  MOV WORD PTR ES:[DI-2],0C089H ;; MOV AX, AX (FASTER THAN NOP, NOP)
  POP ES
  POP DI
  POP BP
  IRET
DQBINT3D ENDP

END

