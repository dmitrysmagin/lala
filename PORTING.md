# Faithful QB → C porting plan: `dqb/` recompiled with OpenWatcom, DOSBox

## 0. Ground truths

- Original = `lala-qb/LALA.BAS` (194 ln) + `lala-qb/ENGINE.BAS` (802 ln)
  + `lala-qb/FMENGINE.BAS` (879 ln), built per `lala-qb/LALA.MAK`
  against `lala-qb/DQB.LIB`.
- `dqb/*.ASM` are the DirectQB 1.61 sources (MASM-mode, TASM 4.1):
  `.MODEL medium,basic` — `FAR` procs, **UPPERCASE** publics, params
  pushed left→right, **callee cleans** (`retf n`).
- The game uses ~30 DQB entry points from 9 modules:
  `MAIN, DRAW, IMAGE, PALETTE, FONT, BLENDING, KEYBOARD, SOUND, BIT`.
- Current `src/` is SDL-stub shaped (`directqb.c` = no-ops,
  `fmengine.c` = BAS pasted in a comment). The root `makefile`
  builds `bin\lala.exe` with `wcl -0 -ml`; `run.bat` + `lala.conf`
  exist. Assets already in `bin/` (`GFX/MAP/MUSIC/SFX`).

## 1. Phase 0 — DONE: DQB recompiled with OpenWatcom, proven by spike

- All 15 compilable modules assembled with `wasm` into `dqb/obj/`,
  packed with `wlib` into **`dqb/dqb.lib`** (60 416 bytes).
  Rebuild: `wmake dqblib`. All 156 publics verified identical
  (name + case) to the shipped TASM OBJs via `wdis` comparison.
- WASM incompatibilities found (2, both semantics-preserving label
  renames marked `; WATCOM:` in source):
  - `dqb/BIT.ASM` — `DQBreadBit`'s `FindBit1`/`SkipShift1` clashed with
    `DQBresetBit`'s (TASM scopes duplicate labels per-PROC, WASM/MASM
    doesn't); renamed to `FindBitR`/`SkipShiftR`.
  - `dqb/JOYSTICK.ASM` — `DQBjoyX`'s `NotGamePad1` clashed with
    `DQBjoyP`-family's; renamed to `NotGamePadX`.
- Deliberately excluded from the lib:
  - `dqb/CALLS.OBJ` — BC-compiled BASIC (`CALLS.BAS`, no ASM source;
    string-runtime dependent). Game doesn't need its procs
    (`DQBpeek/poke/sort/angle` unused; `DQBerror$` replaced by plain
    error messages in the port).
  - `dqb/3D.ASM`, `dqb/3D3.ASM` — superseded variants exporting the
    same publics as `dqb/THREED.ASM`; only `THREED.ASM` is in the lib.
- Calling convention from C: `extern int __far __pascal DQBshiftLeft
  (int, int);` — `__pascal` matches MASM `basic` exactly (far call,
  left→right, callee cleanup, uppercase symbol), no `#pragma aux`
  needed. `wcl` links `dqb/dqb.lib` directly, `-mm` and `-ml`.
- `spike/spike.c` (13 checks: shifts incl. game-realistic
  `SL(19,10)=19456`, `SR(11264,10)=11`, plus `DQBsetBit`/`DQBreadBit`
  incl. QB `TRUE=-1`) → **`SPIKE: PASS` in DOSBox 0.74 under both
  `-mm` and `-ml`** (`spike/spike.conf` mounts `spike/` as `C:`).
  Model decision: keep `-ml` (game data exceeds 64K; DQB links fine).
- Helper for future work: `wmake dqblib` rebuilds the lib from
  sources; `spike/` is the regression test for the toolchain.

## 2. Build system

- Root `makefile`: `wmake` builds `bin\lala.exe` (`-0 -ml`);
  `wmake dqblib` rebuilds `dqb/dqb.lib` from `dqb/*.ASM`.
  Next step (Phase 2/3): link `bin\lala.exe` against `dqb/dqb.lib`
  once `src/directqb.c` becomes a real binding layer (currently stubs
  — linking now would cause duplicate symbols).
  Keep `-ml`; revisit `-0`→`-3` only if needed (DQB itself is `.386`;
  DOSBox is 386+).
- `SETMEM(-513)` in `LALA.BAS` → `wlink` stack/heap directives instead.
- Keep `build.sh`/SDL files untouched; the Watcom path is
  `makefile` → `bin\`.

## 3. `directqb.h/.c` becomes a binding layer, not a reimplementation

- One `extern` + `#pragma aux` per used entry point (list from
  `lala-qb/DIRECTQB.BI`, minus unused modules).
- Two helpers, derived by reading the ASM, not guessing:
  - **QB string descriptor**: `DQBloadImage/FileName$`, `Pal$`,
    `DQBloadFont/Sound/BMap`, `DQBsetPal` take string descriptors.
    Read the `IMAGE.ASM`/`FONT.ASM` prologues to get the exact layout,
    then build a `qb_str()` helper in C (length + far pointer).
    `DQBerror$` (a string *function*) — skip it; log generic errors
    instead.
  - **Buffers**: `DQBget/put` take `BYVAL BufSeg%/BufOff%` =
    `FP_SEG/FP_OFF` of our `__far` buffers. The DQB sprite format
    stays opaque — just hold bytes.
- `BIT.OBJ` shifts could be C one-liners, but link the real thing
  anyway (faithfulness + the spike already proves it).

## 4. Port `LALA.BAS` + `ENGINE.BAS` (mechanical, biggest chunk)

- Order: `engineInitVals → LoadTileProperties/Tileset/
  SpriteProperties/Spriteset/SpriteMapping → showTitle →
  engineDoGame → showEnding`.
- Type mapping 1:1 from `lala-qb/ENGINE.BI`
  (`TypePrefs/TypePlayer/TypeTileLayers/TypeEnems/TypeHotSpots` →
  same-layout structs; `STRING*12` → `char[12]`;
  `INTEGER` → `int16_t`).
- QB-isms: `REDIM/ERASE` → `farmalloc/ffree`; `RND` → `rand()`
  seeded from the BIOS tick; `DQBkey(&H4B)` scancodes pass through
  unchanged; `DATA/READ/RESTORE` (ending text) → static arrays;
  file `OPEN…GET` (`engineMapLoad`, `ENEMS.TXT`/`HOTSPOTS.TXT`) →
  `fopen/fread/fscanf`.
- Verify per-subroutine against the original `lala-qb/LALA.EXE` in
  DOSBox (title → gameplay → ending), same inputs.

## 5. Port `FMENGINE.BAS` (only genuinely hard part)

- `OUT/INP(oplbase)` → `outp/inp` (`<conio.h>`); `MPUwrite` stays
  disabled as in the original source.
- `PLAY ON / ON PLAY(1) GOSUB timercallback / PLAY "mlmbt255p64"` →
  a PIT-channel-0 ISR installed at `FMinit` rate, calling the ported
  `FMtimer()`; `PLAY STOP/OFF` → mask/unhook. (`monospace`'s `fmp.c`
  is the reference pattern for a PIT-driven player.)
- S3M parsing (`OPEN FOR BINARY`, `SEEK`, `CVI/ASC/INPUT$`) →
  `fopen/fread` on `MUSIC/*.S3M`; `LOG/EXP/SIN/CINT` → `<math.h>`.
- Verify: title music `G66A.S3M`, win music `MC12.S3M`, silence on
  exit (`BeSilent`).

## 6. Integration & acceptance

- `wmake` → `run.bat` → full loop in DOSBox 0.74 (`lala.conf` as-is):
  init messages, font, SB init, title demo game, playable game,
  ending screen, clean text-mode exit.
- Byte-compare behavior, not bytes: same maps (`MAP/LALA.MAP`), same
  physics constants, same SFX slots.
- Deliberate non-goals: `DQBerror$` text fidelity, mouse/joystick/3D
  modules, SDL path changes.

**Suggested execution order:** Phase 1 spike → Phase 2 makefile →
`BIT`+`KEYBOARD`+`MAIN` bindings → `LALA.BAS` main flow →
`ENGINE.BAS` (~802 ln, subroutine by subroutine) → `FMENGINE.BAS` →
playtest pass.
