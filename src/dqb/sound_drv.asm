; ---------------------------------------------------------------------------
;
; DirectQB SOUND ENGINE module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN EMShdl:WORD
EXTRN EMSseg:WORD
EXTRN EMSpage:WORD
EXTRN EMSallocated:WORD
EXTRN Buffer:BYTE
EXTRN SoundActive:BYTE
EXTRN SoundPage:WORD
EXTRN VolActive:BYTE
EXTRN VolSeg:WORD
EXTRN NumSounds:BYTE
EXTRN BaseAddr:WORD
EXTRN IRQ:BYTE
EXTRN PicORmask:BYTE
EXTRN OldIRQseg:WORD
EXTRN OldIRQoff:WORD
EXTRN SoundLen:WORD

EXTRN MapEMS:FAR
EXTRN ReadBuffer:FAR
EXTRN HookInt24:FAR
EXTRN UnhookInt24:FAR


.DATA
Blaster       DB  'BLASTER='      ; BLASTER environmental variable
DMA           DB  1               ; SB DMA channel
PicANDmask    DB  ?               ; AND pic mask to clear IRQ
DMA_Page      DW  ?               ; DMA page register
DMA_Base      DW  ?               ; DMA base address
DMA_Count     DW  ?               ; DMA count register
SamplingRate  DW  22050           ; Sampling rate (default = 22050 Hz)
Playing       DB  0               ; Number of sounds currently playing
PauseSound    DB  0               ; Sound pause flag
Channels      DW  8               ; Number of channels used for sample mixing

SamplePtr     DW  32 dup(0)       ; Pointer to sample
LowCount      DW  32 dup(0)       ; Fractional counter (for CF addition)
HighCount     DW  32 dup(0)       ; Integer part of CF-based counter
Counter       DW  32 dup(0)       ; Counter delta
VoiceSound    DW  32 dup(0)       ; Sound number being played on each voice
VoiceLoop     DW  32 dup(0)       ; Voice loop flags
VoiceVol      DW  32 dup(63)      ; Volume of each voice
VoiceLoopEnd  DW  32 dup(0)       ; Loop end point
VoiceLoopLen  DW  32 dup(0)       ; Loop length

; ***************************************************************************
BUFFERLEN     EQU 512             ; ****     Buffer length in bytes     *****
; ***************************************************************************

MixPtr        DW  0               ; Pointer to actual mixer buffer position
MixBuffer     DW  (BUFFERLEN/2) dup(0)      ; Mixing sound buffer
SoundBuffer   DB  BUFFERLEN dup(?)      ; Output sound buffer


.CODE

; ---------------------------------------------------------------------------
; WAITWRITEDSP macro
; purpose:
;   Waits the DSP until it's ready to receive data
; calling:
;   DX  Write wait port (BaseAddr+0Ch)
; changes:
;   AL
; ---------------------------------------------------------------------------
EVEN
WAITWRITEDSP MACRO
LOCAL WaitWrite,EndWriteDSP
  PUSH CX
  XOR CX,CX
WaitWrite:
  DEC CX
  JZ EndWriteDSP
  IN AL,DX
  OR AL,AL
  JS WaitWrite
EndWriteDSP:
  POP CX
ENDM

; ---------------------------------------------------------------------------
; WAITREADDSP macro
; purpose:
;   Waits the DSP until it's ready to send data
; calling:
;   DX  Read wait port (BaseAddr+0Eh)
; changes:
;   AL
; ---------------------------------------------------------------------------
EVEN
WAITREADDSP MACRO
LOCAL WaitRead,EndReadDSP
  PUSH CX
  XOR CX,CX
WaitRead:
  DEC CX
  JZ EndReadDSP
  IN AL,DX
  OR AL,AL
  JNS WaitRead
EndReadDSP:
  POP CX
ENDM

; ---------------------------------------------------------------------------
; SETUPDMA macro
; purpose:
;   Sets up the DMA chip for the transfer
; ---------------------------------------------------------------------------
EVEN
SETUPDMA MACRO
LOCAL NoOverRide
  MOV SI,OFFSET SoundBuffer
  MOV CX,(BUFFERLEN-1)
  MOV AX,@DATA
  ROL AX,4
  MOV BL,AL
  AND BL,00Fh
  AND AL,0F0h
  ADD SI,AX
  ADC BL,0
  NEG SI
  CMP SI,CX
  JA NoOverRide
  NEG SI
  ADD SI,CX
  INC SI
  INC BL
  NEG SI
NoOverRide:
  NEG SI
  MOV AL,DMA
  ADD AL,4
  OUT 0Ah,AL
  OUT 0Ch,AL
  MOV AL,058h     ; DMA mode
  ADD AL,DMA
  OUT 0Bh,AL
  MOV AL,BL
  MOV DX,DMA_Page
  OUT DX,AL
  MOV AX,SI
  MOV DX,DMA_Base
  OUT DX,AL
  MOV AL,AH
  OUT DX,AL
  MOV AL,CL
  MOV DX,DMA_Count
  OUT DX,AL
  MOV AL,CH
  OUT DX,AL
  MOV AL,DMA
  OUT 0Ah,AL
  MOV DX,BaseAddr
  ADD DX,0Ch
  PUSH DX
  MOV AX,1000
  MUL AX
  MOV BX,SamplingRate
  DIV BX
  NEG AL
  MOV AH,AL
  POP DX
  WAITWRITEDSP
  MOV AL,040h
  OUT DX,AL
  WAITWRITEDSP
  MOV AL,AH
  OUT DX,AL
  WAITWRITEDSP
  MOV AL,048h
  OUT DX,AL
  MOV CX,((BUFFERLEN/2)-1)
  WAITWRITEDSP
  MOV AL,CL
  OUT DX,AL
  WAITWRITEDSP
  MOV AL,CH
  OUT DX,AL
  WAITWRITEDSP
  MOV AL,01Ch
  OUT DX,AL
ENDM

; ---------------------------------------------------------------------------
; MIXVOICES macro
; purpose:
;   Mixes sounds data into the second sound buffer and updates voices; here
;   is where the actual sound mixing and resampling is performed.
; ---------------------------------------------------------------------------
EVEN
MIXVOICES MACRO
LOCAL MixSample,MapPage2,MixIt,LoopThis,DontLoop,MixDone,ClipSample
  CLD
  MOV AX,VolSeg
  MOV FS,AX
  MOV DI,OFFSET MixBuffer
  MOV CX,(BUFFERLEN/4)
  XOR EAX,EAX     ; Writes complete silence into the sound buffer
  REP STOSD
  CMP Playing,0   ; Avoid mixing if no sounds are playing
  JE MixDone
  MOV AX,EMSseg
  MOV ES,AX
  MOV SI,-2
MixSample:
  ADD SI,2
  MOV CX,SI
  SHR CX,1
  CMP CX,Channels
  JGE MixDone
  CMP VoiceSound[SI],0
  JE MixSample
  MOV BX,VoiceSound[SI]
  DEC BX
  SHL BX,2
  ADD BX,SoundPage
  MOV DX,EMShdl
  MOV AX,04400h    ; LIM/EMS function 44h, starting with physical page 0
  INT 67h         ; Map the page!
  INC BX          ; Next logical page
  MOV AX,04401h
  INT 67h
  INC BX
  MOV AX,04402h
  INT 67h
  INC BX
  MOV AX,04403h
  INT 67h
  MOV DX,VoiceLoopEnd[SI]
  XOR CX,CX
  XOR DI,DI
MixIt:
  MOV BX,LowCount[SI]     ; LowCount depends by the sampling rate
  ADD Counter[SI],BX      ; Increase the counter
  MOV BX,SamplePtr[SI]
  ADC BX,HighCount[SI]    ; Increase high counter on overflow
  CMP BX,DX               ; Have we reached the sound length?
  JB DontLoop             ; No: don't check for sound loop
  CMP VoiceLoop[SI],1     ; Yes: let's check if the sound has to be looped
  JE LoopThis             ; Yes: loop sound
  MOV VoiceSound[SI],0    ; No: Stop any sound playing on current voice
  DEC Playing             ; Decrease the number of sounds playing
  JMP MixSample
LoopThis:
  SUB BX,VoiceLoopLen[SI]       ; Loop sample (perfect precision)
DontLoop:
  MOV SamplePtr[SI],BX    ; Update sample pointer
  XOR AH,AH
  MOV AL,ES:[BX]  ; Get sample from EMS
  CMP VolActive,0
  JE @F
  MOV BX,AX
  SHL BX,6        ; Find offset into the volume table
  ADD BX,VoiceVol[SI]
  MOV AL,FS:[BX]  ; Get softer sample byte based on the voice volume
@@:
  SUB AX,080h             ; Make the sample signed...
  ADD MixBuffer[DI],AX    ; ...and sum it to the mixing buffer
  ADD DI,2
  INC CX
  CMP CX,(BUFFERLEN/2)    ; Mix next sample byte
  JB MixIt
  JMP MixSample
MixDone:
  MOV AX,@DATA
  MOV ES,AX
  MOV SI,OFFSET MixBuffer
  MOV DI,OFFSET SoundBuffer
  ADD DI,MixPtr
  MOV CX,(BUFFERLEN/2)      ; Here an unrolled loop would be better, but it would also
ClipSample:       ; increase the sound module size a lot... So let's avoid it
  LODSW           ; It's also better to do it this way with two jumps per
  ADD AX,080h     ; loop, because making a look-up table would take up too
  CMP AX,255      ; much memory!
  JLE @F          ; Higher clipping
  OR AX,0FFh
@@:
  CMP AX,0
  JGE @F          ; Lower clipping
  XOR AX,AX
@@:
  STOSB
  DEC CX
  JNZ ClipSample
  XOR MixPtr,(BUFFERLEN/2)
ENDM

; ---------------------------------------------------------------------------
; DQBinstallSB FUNCTION
; purpose:
;   Initialized the SB and starts the realtime mixing. Returns 0 on successful
;   otherwise an error code.
; declaration:
;   DECLARE FUNCTION DQBinstallSB(BYVAL VolActive,BYVAL Channels,BYVAL Freq,
;                                 BYVAL BaseAddr,BYVAL IRQ,BYVAL DMA)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBinstallSB
DQBinstallSB PROC
  ; Stack layout:
  ;
  ; 16  VolActive
  ; 14  Channels
  ; 12  Freq
  ; 10  BaseAddr
  ; 08  IRQ
  ; 06  DMA
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP EMSallocated,0
  JG CheckSounds
  MOV AX,1          ; Error 1: No sounds were initialized
  MOV LastError,12
  POP BP
  RET 12
CheckSounds:
  CMP NumSounds,0
  JG InstallSB
  MOV AX,1          ; Error 1 again
  MOV LastError,12
  POP BP
  RET 12
InstallSB:
  CMP SoundActive,0
  JE NotInstalled
  XOR AX,AX
  POP BP
  RET 12
NotInstalled:
  MOV AH,062h
  INT 21h
  MOV ES,BX         ; Get PSP segment
  MOV AX,ES:[02Ch]
  MOV ES,AX         ; Get environment segment from PSP
  MOV SI,OFFSET Blaster
  XOR DI,DI
@@:
  PUSH SI
  PUSH DI
  MOV CX,8
  REPE CMPSB        ; Search for the BLASTER environmental variable
  JE ScanA          ; Found! Let's scan it for A, I and D settings
  POP DI
  POP SI
  INC DI
  CMP DI,1000       ; Let's scan 1000 bytes of environmental table
  JB @B             ; (that should be enough)
  JMP BLASTERdone
ScanA:
  POP DI
  POP SI
  ADD DI,8
  MOV DX,DI
  MOV SI,30
  XOR AL,AL
  MOV CX,SI
  REPNE SCASB
  JNE @F
  SUB DI,DX
  MOV SI,DI
@@:
  MOV DI,DX
  MOV AL,'A'
  MOV CX,SI         ; Let's scan environmental variable settings
  REPNE SCASB
  JE @F
  MOV DI,DX
  MOV AL,'a'
  MOV CX,SI
  REPNE SCASB
  JNE ScanI
@@:
  MOV AL,ES:[DI]
  SUB AL,'0'
  CBW
  SHL AX,8
  MOV BX,AX
  MOV AL,ES:[DI+1]
  SUB AL,'0'
  CBW
  SHL AX,4
  ADD BX,AX
  MOV AL,ES:[DI+2]
  SUB AL,'0'
  CBW
  ADD BX,AX
  MOV AX,[BP+10]
  CMP AX,0FFFFh
  JNE ScanI
  MOV [BP+10],BX
ScanI:
  MOV DI,DX
  MOV AL,'I'
  MOV CX,SI
  REPNE SCASB
  JE @F
  MOV DI,DX
  MOV AL,'i'
  MOV CX,SI
  REPNE SCASB
  JNE ScanD
@@:
  MOV AL,ES:[DI]
  SUB AL,'0'
  XOR AH,AH
  MOV BX,[BP+8]
  CMP BX,0FFFFh
  JNE ScanD
  MOV [BP+8],AX
ScanD:
  MOV DI,DX
  MOV AL,'D'
  MOV CX,SI
  REPNE SCASB
  JE @F
  MOV DI,DX
  MOV AL,'d'
  MOV CX,SI
  REPNE SCASB
  JNE BLASTERdone
@@:
  MOV AL,ES:[DI]
  SUB AL,'0'
  XOR AH,AH
  MOV BX,[BP+6]
  CMP BX,0FFFFh
  JNE BLASTERdone
  MOV [BP+6],AX
BLASTERdone:
  MOV AX,[BP+10]
  CMP AX,0FFFFh
  JE Error_BLASTER
  MOV AX,[BP+8]
  CMP AX,0FFFFh
  JE Error_BLASTER
  MOV AX,[BP+6]
  CMP AX,0FFFFh
  JE Error_BLASTER
  JMP SettingsOk
Error_BLASTER:
  MOV AX,5
  MOV LastError,23
  POP BP
  RET 12
SettingsOk:
  MOV VolActive,0
  MOV AX,[BP+16]
  OR AX,AX
  JZ VolumeDone
  MOV AH,48h
  MOV BX,1024
  INT 21h
  JNC MemOk
  MOV AX,7          ; Error 7: Not enough memory to create volume table
  MOV LastError,7
  POP BP
  RET 12
MemOk:
  MOV VolSeg,AX
  MOV ES,AX
  XOR CX,CX
  XOR DI,DI
ComputeSample:
  XOR BX,BX
ComputeVol:
  MOV AX,CX
  SUB AX,128
  IMUL BX
  MOV SI,64
  IDIV SI
  ADD AX,128
  MOV ES:[DI],AL
  INC DI
  INC BX
  CMP BX,64
  JL ComputeVol
  INC CX
  CMP CX,256
  JL ComputeSample
  MOV VolActive,1
VolumeDone:
  MOV Playing,0
  MOV AX,[BP+10]
  MOV BaseAddr,AX
  MOV CX,[BP+8]
  MOV IRQ,CL
  MOV BL,1
  SHL BL,CL
  MOV PicORmask,BL
  XOR BL,0FFh
  MOV PicANDmask,BL
  MOV AX,[BP+6]
  MOV DMA,AL
  CMP AL,0
  JNE TestDMA1
  MOV DMA_Page,087h
  MOV DMA_Base,0
  MOV DMA_Count,1
  JMP DMAdone
TestDMA1:
  CMP AL,1
  JNE TestDMA2
  MOV DMA_Page,083h
  MOV DMA_Base,2
  MOV DMA_Count,3
  JMP DMAdone
TestDMA2:
  CMP AL,2
  JNE TestDMA3
  MOV DMA_Page,081h
  MOV DMA_Base,4
  MOV DMA_Count,5
  JMP DMAdone
TestDMA3:
  CMP AL,3
  JNE DMAerror
  MOV DMA_Page,082h
  MOV DMA_Base,6
  MOV DMA_Count,7
  JMP DMAdone
DMAerror:
  MOV AX,4          ; Error 4: only DMA channels 0-3 are supported
  MOV LastError,13
  POP BP
  RET 12
DMAdone:
  MOV CX,300
@@:
  MOV DX,BaseAddr
  ADD DX,06h
  MOV AL,1
  OUT DX,AL
  IN AL,DX
  IN AL,DX
  IN AL,DX
  IN AL,DX
  IN AL,DX
  IN AL,DX
  XOR AL,AL
  OUT DX,AL
  ADD DX,08h
  WAITREADDSP
  SUB DX,04h
  IN AL,DX
  CMP AL,0AAh       ; Has the DSP reset successfully?
  JE resetOk
  DEC CX
  JNZ @B
  MOV AX,2          ; Error 2: DSP failed to reset
  MOV LastError,14
  POP BP
  RET 12
resetOk:            ; All ok: installs our new IRQ
  MOV DX,[BP+14]
  MOV Channels,DX
  MOV DX,[BP+12]
  CMP DX,23000
  JBE rateOk
  MOV AX,6          ; Error 6: High mixing speed not supported
  MOV LastError,15
  POP BP
  RET 12
rateOk:
  MOV SamplingRate,DX
  MOV DX,BaseAddr
  ADD DX,0Ch
  WAITWRITEDSP
  MOV AL,0E1h       ; Get DSP version
  OUT DX,AL
  ADD DX,2
  WAITREADDSP
  SUB DX,4
  IN AL,DX
  MOV BH,AL
  ADD DX,4
  WAITREADDSP
  SUB DX,4
  IN AL,DX
  MOV BL,AL
  CMP BX,0200h
  JGE DSPok
  MOV AX,3          ; Error 3: Old soundblaster versions not supported
  MOV LastError,16
  POP BP
  RET 12
DSPok:
  ADD DX,2
  WAITWRITEDSP
  MOV AL,0D1h
  OUT DX,AL         ; Turns speakers on
  XOR AX,AX
  MOV ES,AX
  MOV AL,IRQ
  ADD AL,8
  MOV SI,AX
  SHL SI,2
  IN AL,021h
  AND AL,PicANDmask
  OUT 021h,AL       ; Disable IRQ
  MOV AX,ES:[SI]
  MOV OldIRQoff,AX
  MOV AX,OFFSET SBmix
  CLI
  MOV ES:[SI],AX
  MOV AX,ES:[SI+2]
  MOV OldIRQseg,AX
  MOV AX,SEG SBmix
  MOV ES:[SI+2],AX  ; We've changed the IRQ vector
  STI
  IN AL,021h
  AND AL,PicANDmask
  OUT 021h,AL       ; Enable IRQ
  SETUPDMA          ; Starts DMA transfers
  MOV SoundActive,1
  XOR AX,AX
  POP BP
  RET 12
SBmix:
  PUSHAD
  PUSH DS
  PUSH ES
  PUSH FS
  MOV AX,@DATA
  MOV DS,AX
  MOV ES,AX
  MOV AH,47h
  MOV DX,EMShdl
  INT 67h           ; Save EMS pageframe mapping state
  MIXVOICES         ; Mix into the second buffer while the first is playing
  MOV AH,48h
  MOV DX,EMShdl
  INT 67h           ; Restore EMS pageframe mapping state
  MOV DX,BaseAddr
  ADD DX,0Eh        ; Acknowledge SB
  IN AL,DX
  MOV AL,20h        ; Acknowledge interrupt ports
  OUT 020h,AL
  POP FS
  POP ES
  POP DS
  POPAD
  IRET
DQBinstallSB ENDP

; ---------------------------------------------------------------------------
; DQBloadSound FUNCTION
; purpose:
;   Loads a sound sample into a specified sound slot. Sounds must be 8 bit
;   mono and their sampling rate must not be greater than 22000 Hz.
; declaration:
;   DECLARE FUNCTION xDQBloadSound(BYVAL Slot,BYVAL FileSeg,BYVAL FileOff)
;   DECLARE FUNCTION DQBloadSound(Slot AS INTEGER,FileName AS STRING)
; ---------------------------------------------------------------------------
EVEN
; xDQBloadSound — C implementation in sound.c (far string ABI).
IF 0
PUBLIC xDQBloadSound
xDQBloadSound PROC
  ; Stack layout
  ;
  ; 12  Slot
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
  MOV AX,[BP+12]
  XOR BH,BH
  MOV BL,NumSounds
  CMP AX,BX
  JG Error_BadSlot
  MOV AX,[BP+10]
  MOV DS,AX
  MOV DX,[BP+8]
  MOV AX,03D00h
  INT 21h
  JC Error_OpenSound
  MOV BX,AX
  MOV AX,@DATA
  MOV DS,AX
  MOV CX,4
ReadRIFF:
  CALL ReadBuffer
  JC Error_ReadSound
  SHL EAX,8
  MOV AL,Buffer
  LOOP ReadRIFF
  CMP EAX,'RIFF'
  JNE Error_BadSound
  MOV CX,4
SkipRIFFlen:
  CALL ReadBuffer
  JC Error_ReadSound
  LOOP SkipRIFFlen
  MOV CX,4
ReadWAVE:
  CALL ReadBuffer
  JC Error_ReadSound
  SHL EAX,8
  MOV AL,Buffer
  LOOP ReadWAVE
  CMP EAX,'WAVE'
  JNE Error_BadSound
  MOV CX,8
SkipFmtLen:
  CALL ReadBuffer
  JC Error_ReadSound
  LOOP SkipFmtLen
  MOV CX,4
ReadFormat:
  CALL ReadBuffer
  JC Error_ReadSound
  SHL EAX,8
  MOV AL,Buffer
  LOOP ReadFormat
  CMP EAX,001000100h
  JNE Error_NotSupported
  MOV CX,4
ReadFreq:
  CALL ReadBuffer
  JC Error_ReadSound
  SHL EAX,8
  MOV AL,Buffer
  LOOP ReadFreq
  MOV DX,AX
  SHL EDX,16
  SHR EAX,16
  MOV DX,AX
  CMP EDX,23000
  JG Error_NotSupported
  MOV CX,12
SkipData:
  CALL ReadBuffer
  JC Error_ReadSound
  LOOP SkipData
  MOV CX,4
ReadLen:
  CALL ReadBuffer
  JC Error_ReadSound
  SHL EAX,8
  MOV AL,Buffer
  LOOP ReadLen
  MOV CX,4
FixLen:
  SHL EDX,8
  MOV DL,AL
  SHR EAX,8
  LOOP FixLen
  CMP EDX,0FFFFh
  JG Error_SoundTooBig
  MOV AX,DX
  MOV SI,[BP+12]
  DEC SI
  SHL SI,1
  DEC AX
  MOV SoundLen[SI],AX
  SHL SI,1
  ADD SI,SoundPage
  MOV DX,SI
  PUSH AX
  PUSH BX
  CALL MapEMS
  POP BX
  MOV AX,EMSseg
  MOV DS,AX
  XOR SI,SI
  MOV EAX,080808080h
  MOV CX,16384
ClearSound:
  MOV [SI],EAX
  ADD SI,4
  DEC CX
  JNZ ClearSound
  POP CX
  XOR DX,DX
  MOV AH,03Fh
  INT 21h
  JC Error_ReadSound
  MOV AX,03E00h
  INT 21h
  XOR AX,AX
  JMP EndLoadSound
Error_OpenSound:
  MOV AX,1          ; Error 1: Unable to open specified sound file
  MOV LastError,4
  JMP EndLoadSound
Error_ReadSound:
  MOV AX,03E00h
  INT 21h
  MOV AX,2          ; Error 2: General sound file read error
  MOV LastError,5
  JMP EndLoadSound
Error_BadSound:
  MOV AX,03E00h
  INT 21h
  MOV AX,3          ; Error 3: Bad sound file format
  MOV LastError,11
  JMP EndLoadSound
Error_NotSupported:
  MOV AX,03E00h
  INT 21h
  MOV AX,4          ; Error 4: Sound format not yet supported
  MOV LastError,17
  JMP EndLoadSound
Error_SoundTooBig:
  MOV AX,03E00h
  INT 21h
  MOV AX,5          ; Error 5: Sound file too big
  MOV LastError,18
  JMP EndLoadSound
Error_BadSlot:
  MOV AX,03E00h
  INT 21h
  MOV AX,6          ; Error 6: Sound slot does not exist
  MOV LastError,19
EndLoadSound:
  CALL UnhookInt24
  POP BP
  POP DS
  RET 6
xDQBloadSound ENDP
ENDIF

; ---------------------------------------------------------------------------
; DQBloadRawSound FUNCTION
; purpose:
;   Loads a sound sample into a specified sound slot. Sounds must be 8 bit
;   mono and their sampling rate must not be greater than 22000 Hz, although
;   this function does not check for the format to be supported.
;   DQBloadRawSound also requires the offset where the sound data begins into
;   the specified file, plus the sound length in bytes; in this way you can
;   store several sounds into the same file, and load them all using this
;   function.
; declaration:
;   DECLARE FUNCTION xDQBloadRawSound(BYVAL Slot,BYVAL FileSeg,BYVAL FileOff,
;                                     BYVAL Offset AS LONG,BYVAL Length)
;   DECLARE FUNCTION DQBloadRawSound(Slot AS INTEGER,FileName AS STRING,
;                                     Offset AS LONG,Length AS LONG)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBloadRawSound
xDQBloadRawSound PROC
  ; Stack layout
  ;
  ; 18  Slot
  ; 16  FileSeg
  ; 14  FileOff
  ; 12  HiOff
  ; 10  LoOff
  ; 08  Length
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  CALL HookInt24
  MOV AX,[BP+18]
  XOR BH,BH
  MOV BL,NumSounds
  CMP AX,BX
  JG Error_BadSlot1
  MOV AX,[BP+16]
  MOV DS,AX
  MOV DX,[BP+14]
  MOV AX,03D00h
  INT 21h
  JC Error_OpenRaw
  MOV BX,AX
  MOV AX,04200h
  MOV CX,[BP+12]
  MOV DX,[BP+10]
  INT 21h
  JC Error_ReadRaw
  MOV AX,@DATA
  MOV DS,AX
  MOV SI,[BP+18]
  DEC SI
  SHL SI,1
  MOV AX,[BP+8]
  MOV SoundLen[SI],AX
  SHL SI,1
  ADD SI,SoundPage
  MOV DX,SI
  PUSH BX
  CALL MapEMS
  POP BX
  MOV AX,EMSseg
  MOV ES,AX
  MOV DS,AX
  XOR DI,DI
  MOV EAX,080808080h
  MOV CX,16384
  REP STOSD
  MOV CX,[BP+8]
  MOV AH,03Fh
  XOR DX,DX
  INT 21h
  JC Error_ReadRaw
  CMP AX,0
  JE Error_EOF
  MOV AX,03E00h
  INT 21h
  XOR AX,AX
  JMP EndLoadRaw
Error_OpenRaw:
  MOV AX,1          ; Error 1: Unable to open specified sound file
  MOV LastError,4
  JMP EndLoadRaw
Error_ReadRaw:
  MOV AX,03E00h
  INT 21h
  MOV AX,2          ; Error 2: General sound file read error
  MOV LastError,5
  JMP EndLoadRaw
Error_EOF:
  MOV AX,03E00h
  INT 21h
  MOV AX,3          ; Error 3: Cannot read past the end of file
  MOV LastError,20
  JMP EndLoadRaw
Error_BadSlot1:
  MOV AX,4          ; Error 4: Specified sound slot does not exist
  MOV LastError,19
EndLoadRaw:
  CALL UnhookInt24
  POP BP
  POP DS
  RET 12
xDQBloadRawSound ENDP

; ---------------------------------------------------------------------------
; DQBplaySound SUB
; purpose:
;   Plays a sound previously loaded in memory
; declaration:
;   DECLARE SUB DQBplaySound(BYVAL SoundNum,BYVAL Voice,BYVAL Freq,
;                            BYVAL LoopFlag)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBplaySound
DQBplaySound PROC
  ; Stack layout
  ;
  ; 12  SoundNum
  ; 10  Voice
  ; 08  Freq
  ; 06  LoopFlag
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP SoundActive,0
  JE EndPlaySound
  MOV AX,[BP+12]
  XOR AH,AH
  CMP AL,NumSounds
  JG EndPlaySound
  MOV SI,[BP+10]
  DEC SI
  SHL SI,1
  CMP VoiceSound[SI],0
  JNE StillPlaying
  INC Playing
StillPlaying:
  MOV VoiceSound[SI],AX
  MOV DI,AX
  DEC DI
  SHL DI,1
  MOV AX,SoundLen[DI]
  MOV VoiceLoopEnd[SI],AX
  MOV VoiceLoopLen[SI],AX
  MOV AX,[BP+6]
  MOV VoiceLoop[SI],AX
  MOV SamplePtr[SI],0
  MOV AX,[BP+8]
  CWD
  MOV BX,SamplingRate
  DIV BX
  MOV HighCount[SI],AX
  SHL EDX,16
  MOV AX,SamplingRate
  CWDE
  MOV EBX,EAX
  MOV EAX,EDX
  CDQ
  DIV EBX
  MOV LowCount[SI],AX
  MOV Counter[SI],0
EndPlaySound:
  POP BP
  RET 8
DQBplaySound ENDP

; ---------------------------------------------------------------------------
; DQBinUse FUNCTION
; purpose:
;   Returns true if a sound is currently being played on specified voice,
;   otherwise false.
; declaration:
;   DECLARE FUNCTION DQBinUse(BYVAL Voice)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBinUse
DQBinUse PROC
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+6]
  DEC SI
  SHL SI,1
  XOR AX,AX
  CMP VoiceSound[SI],0
  SETNE AL
  NEG AX
  POP BP
  RET 2
DQBinUse ENDP

; ---------------------------------------------------------------------------
; DQBpauseSound SUB
; purpose:
;   Pauses the samples sound output
; declaration:
;   DECLARE SUB DQBpauseSound()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBpauseSound
DQBpauseSound PROC
  CMP PauseSound,1
  JE EndPauseSound
  CMP SoundActive,0
  JE EndPauseSound
  MOV DX,BaseAddr
  ADD DX,0Ch
  WAITWRITEDSP
  MOV AL,0D0h
  OUT DX,AL
  MOV PauseSound,1
EndPauseSound:
  RET
DQBpauseSound ENDP

; ---------------------------------------------------------------------------
; DQBresumeSound SUB
; purpose:
;   Resumes the samples sound output
; declaration:
;   DECLARE SUB DQBresumeSound()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBresumeSound
DQBresumeSound PROC
  CMP PauseSound,0
  JE EndResumeSound
  CMP SoundActive,0
  JE EndResumeSound
  MOV DX,BaseAddr
  ADD DX,0Ch
  WAITWRITEDSP
  MOV AL,0D4h
  OUT DX,AL
  MOV PauseSound,0
EndResumeSound:
  RET
DQBresumeSound ENDP

; ---------------------------------------------------------------------------
; DQBstopVoice SUB
; purpose:
;   Stops sound playing on specified voice
; declaration:
;   DECLARE SUB DQBstopVoice(BYVAL Voice)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBstopVoice
DQBstopVoice PROC
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+6]
  DEC SI
  SHL SI,1
  CMP VoiceSound[SI],0
  JE EndStopVoice
  DEC Playing
  MOV VoiceSound[SI],0
EndStopVoice:
  POP BP
  RET 2
DQBstopVoice ENDP

; ---------------------------------------------------------------------------
; DQBsetVoiceVol SUB
; purpose:
;   Sets the sound output volume of a voice
; declaration:
;   DECLARE SUB DQBsetVoiceVol(BYVAL Voice,BYVAL NewVol)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetVoiceVol
DQBsetVoiceVol PROC
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+8]
  DEC SI
  SHL SI,1
  MOV AX,[BP+6]
  AND AX,03Fh
  MOV VoiceVol[SI],AX
  POP BP
  RET 4
DQBsetVoiceVol ENDP

; ---------------------------------------------------------------------------
; DQBremoveSB SUB
; purpose:
;   Turns off SB output
; declaration:
;   DECLARE SUB DQBremoveSB()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBremoveSB
DQBremoveSB PROC
  CMP SoundActive,0
  JE EndRemoveSB
  CMP VolSeg,0
  JE SkipVol
  MOV AH,049h
  MOV BX,VolSeg
  MOV ES,BX
  INT 21h
  MOV VolSeg,0
SkipVol:
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
  WAITREADDSP
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
  CMP VolActive,0
  JE EndRemoveSB
  MOV AH,049h
  MOV BX,VolSeg
  MOV ES,BX
  INT 21h
  MOV VolActive,0
EndRemoveSB:
  RET
DQBremoveSB ENDP

; ---------------------------------------------------------------------------
; DQBsetFreq SUB
; purpose:
;   Alters the sampling rate of the specified channel.
;   You may change it from 4000 to 32766 for sampling rate.
; declaration:
;   DECLARE SUB DQBsetFreq(BYVAL Voice, BYVAL SampleRate)
; ---------------------------------------------------------------------------

EVEN
PUBLIC DQBsetFreq
DQBsetFreq PROC
  PUSH BP
  MOV BP,SP
  MOV SI,[BP+8]
  DEC SI
  SHL SI,1
  MOV AX,[BP+6]
  CWD
  MOV BX,SamplingRate
  DIV BX
  MOV HighCount[SI],AX
  SHL EDX,16
  MOV AX,SamplingRate
  CWDE
  MOV EBX,EAX
  MOV EAX,EDX
  CDQ
  DIV EBX
  MOV LowCount[SI],AX
  MOV Counter[SI],0
  POP BP
  RET 4
DQBsetFreq ENDP

; ---------------------------------------------------------------------------
; DQBsetVolume SUB
; purpose:
;   Sets the master volume for sound output, in the range 0-15
; declaration:
;   DECLARE SUB DQBsetVolume(BYVAL Volume)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetVolume
DQBsetVolume PROC
  PUSH BP
  MOV BP,SP
  CMP SoundActive,0
  JE EndSetVolume
  MOV DX,BaseAddr
  ADD DX,4
  MOV AL,022h
  OUT DX,AL
  INC DX
  MOV AX,[BP+6]
  AND AL,0Fh
  MOV BL,AL
  SHL BL,4
  OR AL,BL
  OUT DX,AL
EndSetVolume:
  POP BP
  RET 2
DQBsetVolume ENDP

END
