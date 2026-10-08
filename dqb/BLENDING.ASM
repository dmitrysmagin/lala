; ---------------------------------------------------------------------------
;
; DirectQB BLENDING ROUTINE module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN PutMode:WORD
EXTRN ClipX1:WORD
EXTRN ClipX2:WORD
EXTRN ClipY1:WORD
EXTRN ClipY2:WORD
EXTRN EMShdl:WORD
EXTRN EMSseg:WORD
EXTRN EMSpage:WORD

EXTRN BMapActive:BYTE
EXTRN BMapSeg:WORD
EXTRN BMapFirst:BYTE
EXTRN BMapLast:BYTE

EXTRN MapEMS:FAR
EXTRN GetLayerSeg:FAR
EXTRN HookInt24:FAR
EXTRN UnhookInt24:FAR

BMapHeaderType STRUC
  BMapID      DD  ?
  First       DB  ?
  Last        DB  ?
BMapHeaderType ENDS

.DATA

BMapHeader    BMapHeaderType <>   ; Blender map file header


.CODE

; ---------------------------------------------------------------------------
; DQBfilterBox SUB
; purpose:
;   Draws a translucent full box with x1,y1 and x2,y2 as the opposite corners
;   with a given color. Please note that must be x1<x2 and y1<y2; no checks
;   are done and clipping is not supported to speed things up.
; declaration:
;   DECLARE SUB DQBfilterBox(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,BYVAL y2,
;                       BYVAL Col,BYVAL BMap)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBfilterBox
DQBfilterBox PROC
  ; Stack layout:
  ;
  ; 18  Layer
  ; 16  x1
  ; 14  y1
  ; 12  x2
  ; 10  y2
  ; 08  Col
  ; 06  BMap
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+18]
  CALL GetLayerSeg
  MOV ES,CX
  MOV DI,[BP+14]
  MOV BX,DI
  SHL DI,8
  SHL BX,6
  ADD DI,BX
  ADD DI,[BP+16]
  MOV DX,[BP+10]
  SUB DX,[BP+14]
  INC DX
  MOV SI,[BP+6]
  DEC SI
  CMP BMapActive[SI],0
  JE EndFilterBox
  SHL SI,1
  MOV AX,BMapSeg[SI]
  SHR SI,1
  MOV FS,AX
fBoxYloop:
  MOV CX,[BP+12]
  SUB CX,[BP+16]
  INC CX
  PUSH DX
fBoxXloop:
  MOV AX,[BP+8]
  MOV BH,AL
  CMP BH,BMapFirst[SI]
  JB @F
  CMP BH,BMapLast[SI]
  JA @F
  SUB BH,BMapFirst[SI]
  MOV BL,ES:[DI]
  MOV AL,FS:[BX]
@@:
  STOSB
  DEC CX
  JNZ fBoxXloop
  POP DX
  ADD DI,320
  SUB DI,[BP+12]
  ADD DI,[BP+16]
  DEC DI
  DEC DX
  JNZ fBoxYloop
EndFilterBox:
  POP BP
  RET 14
DQBfilterBox ENDP

; ---------------------------------------------------------------------------
; DQBbPut SUB
; purpose:
;   Draws a sprite onto given layer, blending colors using the specified
;   blender map previously built by calling the DQBsetBlenderMap function.
;   This function supports clipping and transparency.
; declaration:
;   DECLARE SUB DQBbPut(BYVAL Layer,BYVAL x,BYVAL y,BYVAL BufferSeg,
;                       BYVAL BufferOff,BYVAL BMap)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBbPut
DQBbPut PROC
  ; Stack layout
  ;
  ; 18  Layer
  ; 16  x
  ; 14  y
  ; 12  Buffer segment
  ; 10  Buffer offset
  ; 08  BMap
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+8]
  DEC SI
  CMP BMapActive[SI],0
  JE EndBPut1
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
  MOV SI,[BP+8]
  DEC SI
  MOV AL,BMapFirst[SI]
  MOV AH,BMapLast[SI]
  PUSH AX
  SHL SI,1
  MOV AX,BMapSeg[SI]
  MOV GS,AX
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
  MOV BX,[BP+28]    ; BX holds the value y-1
  DEC BX
  ADD DI,[BP]
  CMP [BP+12],AL    ; Are we in solid put mode?
  JNE bSolidYloop   ; Yes: jump to the solid put loop
bYloop:
  ADD SI,[BP]
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  DEC AH
  JZ EndBPut         ; Last sprite line reached
  CMP BX,[BP+6]     ; Are we out of the upper clipping border?
  JL bYloop         ; Yes: increase the line counter
  CMP BX,[BP+4]     ; Are we out of the lower clipping border?
  JG EndBPut        ; Yes: exit DQBput
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+30]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
bXloop:
  LODSB             ; Gets a pixel from the buffer
  CMP AL,0
  JE bSkipPixel     ; Transparent pixel: skip it!
  CMP DX,[BP+10]
  JL bSkipPixel     ; Out of left layer border: skip it!
  CMP DX,[BP+8]
  JG bSkipPixel     ; Out of right layer border: skip it!
  CMP AL,[BP+2]
  JB @F
  CMP AL,[BP+3]
  JA @F
  PUSH BX
  MOV BL,ES:[DI]
  MOV BH,AL
  SUB BH,[BP+2]
  MOV AL,GS:[BX]
  POP BX
@@:
  STOSB             ; All checks done: writes pixel on the layer
  INC DX            ; Next pixel
  DEC CX
  JNZ bXloop       ; Repeats sprite width times
  JMP bYloop        ; Next line
bSkipPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  DEC CX
  JNZ bXloop       ; Repeats sprite width times
  JMP bYloop        ; Next line
bSolidYloop:
  ADD SI,[BP]
  ADD DI,320        ; Adds 320 to DI
  INC BX            ; Next line
  DEC AH
  JZ EndBPut        ; Last sprite line reached?
  CMP BX,[BP+6]     ; Are we out of the upper clipping border?
  JL bSolidYloop    ; Yes: increase the line counter
  CMP BX,[BP+4]     ; Are we out of the lower clipping border?
  JG EndBPut        ; Yes: exit DQBput
  SUB DI,[BP]       ; Subtracts the sprite width to DI and SI
  SUB SI,[BP]
  MOV DX,[BP+30]    ; DX holds the current x value
  MOV CX,[BP]       ; Sets CX to the sprite width
bSolidXloop:
  LODSB             ; Gets a pixel from the buffer
  CMP DX,[BP+10]
  JL bSkipSolidPixel    ; Out of left layer border: skip it!
  CMP DX,[BP+8]
  JG bSkipSolidPixel    ; Out of right layer border: skip it!
  CMP AL,[BP+2]
  JB @F
  CMP AL,[BP+3]
  JA @F
  PUSH BX
  MOV BL,ES:[DI]
  MOV BH,AL
  SUB BH,[BP+2]
  MOV AL,GS:[BX]
  POP BX
@@:
  STOSB             ; All checks done: writes pixel on the layer
  INC DX            ; Next pixel
  DEC CX
  JNZ bSolidXloop  ; Repeats sprite width times
  JMP bSolidYloop   ; Next line
bSkipSolidPixel:
  INC DI            ; Increase DI without writing pixel
  INC DX            ; Next pixel
  DEC CX
  JNZ bSolidXloop  ; Repeats sprite width times
  JMP bSolidYloop   ; Next line
EndBPut:
  ADD SP,14         ; Release stack memory
EndBPut1:
  POP BP
  POP DS
  RET 12
DQBbPut ENDP

; ---------------------------------------------------------------------------
; DQBcopyBlendLayer SUB
; purpose:
;   Blends a layer onto another one, using specified blender map
; declaration:
;   DECLARE SUB DQBblendLayer(BYVAL SrcLayer,BYVAL DestLayer,BYVAL BMap)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBcopyBlendLayer
DQBcopyBlendLayer PROC
  ; Stack layout:
  ;
  ; 12  SourceLayer
  ; 10  DestLayer
  ; 08  BMap
  ; 06  Basic segment
  ; 04  Basic offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+8]
  DEC SI
  CMP BMapActive[SI],0
  JE EndCopy
  SHL SI,1
  MOV AX,BMapSeg[SI]
  MOV FS,AX
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
  MOV SI,[BP+8]
  DEC SI
  MOV DL,CS:BMapFirst[SI]
  MOV DH,CS:BMapLast[SI]
  XOR SI,SI
  MOV DI,8000h
  MOV CX,8000h
FirstHalf:
  LODSB
  OR AL,AL
  JZ SkipFirstPixel
  CMP AL,DL
  JB SkipFirstBlend
  CMP AL,DH
  JA SkipFirstBlend
  MOV BH,AL
  MOV BL,ES:[DI]
  SUB BH,DL
  MOV AL,FS:[BX]
SkipFirstBlend:
  MOV ES:[DI],AL
SkipFirstPixel:
  INC DI
  DEC CX
  JNZ FirstHalf
  MOV DX,CS:EMShdl
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
  MOV SI,[BP+8]
  DEC SI
  MOV DL,CS:BMapFirst[SI]
  MOV DH,CS:BMapLast[SI]
  XOR SI,SI
  MOV DI,8000h
  MOV CX,8000h
SecondHalf:
  LODSB
  OR AL,AL
  JZ SkipSecondPixel
  CMP AL,DL
  JB SkipSecondBlend
  CMP AL,DH
  JA SkipSecondBlend
  MOV BH,AL
  MOV BL,ES:[DI]
  SUB BH,DL
  MOV AL,FS:[BX]
SkipSecondBlend:
  MOV ES:[DI],AL
SkipSecondPixel:
  INC DI
  DEC CX
  JNZ SecondHalf
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
  MOV SI,[BP+8]
  DEC SI
  MOV DL,BMapFirst[SI]
  MOV DH,BMapLast[SI]
  MOV DS,DI       ; ...and source segment
  XOR DI,DI       ; Both source and destination offsets start as 0
  XOR SI,SI
  MOV CX,64000
BlendRAM:
  LODSB
  OR AL,AL
  JZ SkipRAMpixel
  CMP AL,DL
  JB SkipRAMblend
  CMP AL,DH
  JA SkipRAMblend
  MOV BH,AL
  MOV BL,ES:[DI]
  SUB BH,DL
  MOV AL,FS:[BX]
SkipRAMblend:
  MOV ES:[DI],AL
SkipRAMpixel:
  INC DI
  DEC CX
  JNZ BlendRAM
EndCopy:
  POP BP
  POP DS
  RET 6
DQBcopyBlendLayer ENDP

; ---------------------------------------------------------------------------
; DQBcreateBMap FUNCTION
; purpose:
;   Allocates memory for the blender map
; declaration:
;   DECLARE FUNCTION DQBcreateBMap(BYVAL BMap,BYVAL FirstCol,BYVAL LastCol)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBcreateBMap
DQBcreateBMap PROC
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+10]
  DEC SI
  CMP BMapActive[SI],1
  JE Error_AlreadyUp
  MOV AH,48h
  MOV BX,[BP+6]
  SUB BX,[BP+8]
  INC BX
  SHL BX,4
  INT 21h
  JC Error_AllocBMap
  MOV BMapActive[SI],1
  MOV DX,[BP+6]
  MOV BMapLast[SI],DL
  MOV BX,[BP+8]
  MOV BMapFirst[SI],BL
  SHL SI,1
  MOV BMapSeg[SI],AX
  MOV ES,AX
  MOV CL,DL
  SUB CL,BL
  INC CL
  XOR DI,DI
@@:
  PUSH CX
  MOV CX,256
  MOV AL,BL
  REP STOSB
  POP CX
  INC BL
  DEC CL
  JNZ @B
  XOR AX,AX
  POP BP
  RET 6
Error_AlreadyUp:
  MOV AX,2          ; Error 2: Blender map already created
  MOV LastError,6
  POP BP
  RET 6
Error_AllocBMap:
  MOV AX,1          ; Error 1: Not enough free conventional memory
  MOV LastError,7
  POP BP
  RET 6
DQBcreateBMap ENDP

; ---------------------------------------------------------------------------
; DQBsetBMap SUB
; purpose:
;   Sets a color entry on the blender map (if active)
; declaration:
;   DECLARE SUB DQBsetBMap(BYVAL BMap,BYVAL ForeCol,BYVAL BackCol,BYVAL NewCol)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetBMap
DQBsetBMap PROC
  ; Stack layout:
  ;
  ; 12  BMap
  ; 10  ForeCol
  ; 08  BackCol
  ; 06  NewCol
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+12]
  DEC SI
  CMP BMapActive[SI],0
  JE EndSetBMap
  MOV AX,[BP+10]
  CMP AL,BMapFirst[SI]
  JB EndSetBMap
  CMP AL,BMapLast[SI]
  JA EndSetBMap
  XOR BH,BH
  SUB BH,BMapFirst[SI]
  SHL SI,1
  MOV AX,BMapSeg[SI]
  MOV ES,AX
  ADD BH,BYTE PTR [BP+10]
  MOV BL,BYTE PTR [BP+8]
  MOV AL,[BP+6]
  MOV ES:[BX],AL
EndSetBMap:
  POP BP
  RET 8
DQBsetBMap ENDP

; ---------------------------------------------------------------------------
; DQBgetBMap FUNCTION
; purpose:
;   Returns a color entry on the blender map (if active)
; declaration:
;   DECLARE FUNCTION DQBgetBMap(BYVAL BMap,BYVAL ForeCol,BYVAL BackCol)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBgetBMap
DQBgetBMap PROC
  ; Stack layout:
  ;
  ; 10  BMap
  ; 08  ForeCol
  ; 06  BackCol
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+10]
  DEC SI
  MOV AX,0FFFFh
  CMP BMapActive[SI],0
  JE EndGetBMap
  MOV DX,[BP+8]
  CMP DL,BMapFirst[SI]
  JB EndGetBMap
  CMP DL,BMapLast[SI]
  JA EndGetBMap
  XOR BH,BH
  SUB BH,BMapFirst[SI]
  SHL SI,1
  MOV AX,BMapSeg[SI]
  MOV ES,AX
  ADD BH,BYTE PTR [BP+10]
  MOV BL,BYTE PTR [BP+8]
  XOR AH,AH
  MOV AL,ES:[BX]
EndGetBMap:
  POP BP
  RET 6
DQBgetBMap ENDP

; ---------------------------------------------------------------------------
; DQBloadBMap FUNCTION
; purpose:
;   Loads the blender map from a specified file
; declaration:
;   DECLARE FUNCTION xDQBloadBMap(BYVAL BMap,BYVAL FileSeg,BYVAL FileOff)
;   DECLARE FUNCTION DQBloadBMap(BMap AS INTEGER,FileName AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBloadBMap
xDQBloadBMap PROC
  ; Stack layout:
  ;
  ; 12  BMap
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
  MOV SI,[BP+12]
  DEC SI
  CMP BMapActive[SI],0
  JE Error_NoBMapLoad
  SHL SI,1
  MOV AX,BMapSeg[SI]
  SHR SI,1
  MOV ES,AX
  MOV AX,03D00h
  MOV BX,[BP+10]
  MOV DS,BX
  MOV DX,[BP+8]
  INT 21h
  JC Error_OpenBMapLoad
  MOV BX,AX
  MOV AX,@DATA
  MOV DS,AX
  MOV DX,OFFSET BMapHeader
  MOV CX,6
  MOV AH,03Fh
  INT 21h
  JC Error_ReadBMap
  CMP BMapHeader.BMapID,'paMB'
  JNE Error_BadBMap
  MOV CL,BMapLast[SI]
  SUB CL,BMapFirst[SI]
  MOV CH,BMapHeader.Last
  SUB CH,BMapHeader.First
  CMP CL,CH
  JNE Error_IncompatibleBMap
  INC CH
  XOR CL,CL
  MOV AX,ES
  MOV DS,AX
  MOV AH,03Fh
  XOR DX,DX
  INT 21h
  JC Error_ReadBMap
  MOV AH,03Eh
  INT 21h
  XOR AX,AX
  JMP EndLoadBMap
Error_NoBMapLoad:
  MOV AH,03Eh
  INT 21h
  MOV AX,1          ; Error 1: Blender map not yet created
  MOV LastError,8
  JMP EndLoadBMap
Error_OpenBMapLoad:
  MOV AH,03Eh
  INT 21h
  MOV AX,2          ; Error 2: Unable to open file or file does not exist
  MOV LastError,4
  JMP EndLoadBMap
Error_BadBMap:
  MOV AH,03Eh
  INT 21h
  MOV AX,3          ; Error 3: Bad or unknown BMap file
  MOV LastError,11
  JMP EndLoadBMap
Error_IncompatibleBMap:
  MOV AH,03Eh
  INT 21h
  MOV AX,4          ; Error 4: Incompatible BMap file
  MOV LastError,22
  JMP EndLoadBMap
Error_ReadBMap:
  MOV AH,03Eh
  INT 21h
  MOV AX,5          ; Error 5: General file read error
  MOV LastError,5
EndLoadBMap:
  CALL UnhookInt24
  POP BP
  POP DS
  RET 6
xDQBloadBMap ENDP

; ---------------------------------------------------------------------------
; DQBsaveBMap FUNCTION
; purpose:
;   Saves the blender map into a specified file
; declaration:
;   DECLARE FUNCTION xDQBsaveBMap(BYVAL BMap%,BYVAL FileSeg,BYVAL FileOff)
;   DECLARE FUNCTION DQBsaveBMap(BYVAL BMap AS INTEGER,FileName AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBsaveBMap
xDQBsaveBMap PROC
  ; Stack layout:
  ;
  ; 12  BMap
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
  MOV SI,[BP+12]
  DEC SI
  CMP BMapActive[SI],0
  JE Error_NoBMapSave
  SHL SI,1
  MOV AX,BMapSeg[SI]
  SHR SI,1
  MOV ES,AX
  MOV AH,03Ch
  MOV CX,020h
  MOV BX,[BP+10]
  MOV DS,BX
  MOV DX,[BP+8]
  INT 21h
  JC Error_OpenBMapSave
  MOV BX,AX
  MOV AX,@DATA
  MOV DS,AX
  MOV BMapHeader.BMapID,'paMB'
  MOV AL,BMapFirst[SI]
  MOV BMapHeader.First,AL
  MOV AL,BMapLast[SI]
  MOV BMapHeader.Last,AL
  MOV DX,OFFSET BMapHeader
  MOV CX,6
  MOV AH,040h
  INT 21h
  MOV CH,BMapHeader.Last
  SUB CH,BMapHeader.First
  INC CH
  XOR CL,CL
  MOV AX,ES
  MOV DS,AX
  MOV AH,040h
  XOR DX,DX
  INT 21h
  JC Error_WriteBMap
  MOV AH,03Eh
  INT 21h
  XOR AX,AX
  JMP EndSaveBMap
Error_NoBMapSave:
  MOV AH,03Eh
  INT 21h
  MOV AX,1          ; Error 1: Blender map not yet created
  MOV LastError,8
  JMP EndSaveBMap
Error_OpenBMapSave:
  MOV AH,03Eh
  INT 21h
  MOV AX,2          ; Error 2: Unable to create file
  MOV LastError,9
  JMP EndSaveBMap
Error_WriteBMap:
  MOV AH,03Eh
  INT 21h
  MOV AX,3          ; Error 3: General file write error
  MOV LastError,10
EndSaveBMap:
  CALL UnhookInt24
  POP BP
  POP DS
  RET 6
xDQBsaveBMap ENDP

; ---------------------------------------------------------------------------
; DQBremoveBMap SUB
; purpose:
;   Deallocates memory used by the blender map
; declaration:
;   DECLARE FUNCTION DQBremoveBMap(BYVAL BMap)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBremoveBMap
DQBremoveBMap PROC
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+6]
  DEC SI
  CMP BMapActive[SI],0
  JE NoFreeBMap
  MOV BMapActive[SI],0
  SHL SI,1
  MOV AH,49h
  MOV ES,BMapSeg[SI]
  INT 21h
NoFreeBMap:
  POP BP
  RET 2
DQBremoveBMap ENDP


END
