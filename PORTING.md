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

- Root `makefile`: `wmake` builds `bin\lala.exe` (**`-0 -mm`**);
  `wmake dqblib` rebuilds `dqb/dqb.lib` from `dqb/*.ASM`
  (`wasm -fpi87`: real 8087 opcodes, no FP-emulation helper).
- **Memory model is `-mm` (medium), like QB 4.5 itself and DQB's
  `.MODEL medium`.** `-ml` was tried and abandoned: near/far scatter
  across SS≠DS breaks wlink fixups (see quirks).
- DOSBox conf needs `ems=true` (`DQBinit(5,11,0)` allocates 64 EMS
  pages; with `ems=false` init fails). Fixed in `lala.conf`.
- `SETMEM(-513)` in `LALA.BAS` → **DONE (Phase 4)**: replaced by the
  makefile's `wcl -k16384` stack directive. QB pre-allocated its far
  heap at startup, so `SETMEM` had to hand memory around explicitly;
  Watcom's medium model pulls far memory from DOS on demand
  (`_fmalloc` → INT 21h), so the far-heap half needs no directive and
  the only static memory to pin is the program stack.
- Keep `build.sh`/SDL files untouched; the Watcom path is
  `makefile` → `bin\`.
- Ongoing constraint: single 64K code group + absolute-addressed DQB
  data fixups ⇒ keep (CODE + early DGROUP) under ~64K (currently
  ~57K with engtest; the shipped game without engtest is smaller).

## 3. `directqb.h/.c` binding layer — DONE (wrappers removed)

- `src/directqb.h` declares every used entry point directly with
  `extern __far __pascal` in CamelCase. `__pascal` uppercases the
  symbol, so e.g. `DQBinit` here IS `DQBINIT` in the lib (proven at
  obj level via `wdis`: `call DQBINIT`). No wrappers, no pragmas.
- Only two thin wrappers stay in `src/directqb.c` (real added value):
  `DQBloadImage` stages stack int locals through DGROUP statics
  (`xDQBloadImage` stores imgW/imgH through DS), and `DQBprint`
  supplies `style = 0`. Call sites using old wrapper names
  (`DQBloadFont/Sound/BMap/SetPal/Inkey`) were renamed to the lib's
  `xDQB…` names.
- Far-pointer params take literals/DGROUP buffers straight through:
  the compiler materializes near→far with `push ds` + DGROUP offset.
- Verified: `lala.exe test` → **ENGTEST: PASS 121/121** with zero
  wrappers in the render path; normal binary reaches the title demo
  loop; `spike/` still passes.

## 4. Port `LALA.BAS` + `ENGINE.BAS` — DONE

- `src/engine.c`: all of ENGINE.BAS translated 1:1 (init/loader/calc/
  detect/move/draw/DoGame loop); `src/lala.c`: main loop, showTitle,
  showEnding (DATA → static array). Globals replace QB SHARED/params.
- File loaders replace hardcoded tables (`qbReadInt` mirrors INPUT#).
  This fixed two latent bugs: `numSprites` is 21, not 20 (SPRPROP has
  21 lines; sprite 20 would have read NULL), and spriteset needs a real
  768B dummy pal (NULL would scribble the IVT).
- QB→C rules: `REDIM/ERASE` → `_fcalloc/_ffree` (note: `_fmemset`, not
  `memset`, for far buffers — `W112` caught one truncation crash);
  `AND/OR/NOT` → bitwise on -1/0 truth; `RND` → `rand() >> 5`;
  `LTRIM$(STR$)` → `sprintf %0*d`; `DQBkey(&H..)` scancodes unchanged.
- DQB-string params must be DGROUP: asset paths via a static staging
  buffer, `prCh`/`statBuf`/title `pal` statics (documented in headers).
  All asset paths normalized to DOS `\` (were `/`, `//`).
  `DQBerror$` skipped (BC-compiled, in `CALLS.OBJ` — plain messages).
- Verified: `lala.exe test` runs 121-check `tests/engtest.c` headless in
  DOSBox — loaders (hand-verified values), collision/keyhole/frames,
  8-frame physics smoke (matches hand computation), full render path
  (init/font/PCX/puts/print/layers/palette/VGA calls) — **ENGTEST:
  PASS**. Normal binary reaches the title demo loop (timeout-kill =
  still running).

## 5. Port `FMENGINE.BAS` — DONE

- `src/fmengine.{h,c}`: full Bisqwit player port (~700 lines C):
  types/structs 1:1, all 16 BI functions. Verified `lala.exe` init
  flow + title demo run with live music (G66A/DESORUIN).
- Deliberate, documented deviations (all behavior-preserving):
  - QB `PLAY`/`ON PLAY` timer replaced by PIT channel-0 ISR at 25Hz
    (`FMisr` in fmengine.c, monospace pattern: IVT hook, EOI, PIT
    restore on `FMend`); `FOR looper = 0 TO 1` kept, so the effective
    rate is the S3M-correct 50 frames/sec. `PLAY STOP/OFF/ON` map to
    `FMstop()` (freeze) / `playing` flag.
  - Patterns preloaded to RAM at `FMload` (exact bytes); the original
    streamed them from disk inside the timer callback only to save QB
    memory — file I/O inside a hardware ISR is unsafe.
  - Integer-only math: period table + vibrato sine table precomputed
    (worst case ±1 OPL period unit on extreme highs vs QB doubles —
    inaudible); `LOG`/`EXP`/`SIN` paths feed only the disabled MPU
    branch and were dropped (MIDI state machine kept); `MPUvol`
    stubbed; C `/` truncates where QB `\` rounds (1-step vibrato
    edge, inaudible).
  - `DQBwait` is VGA-retrace-based (not tick), so freezing the BIOS
    tick (no INT 8 chaining, monospace precedent) is safe.
- Reentrancy rule (learned the hard way): never call `FMtimer`
  directly while `playing` — park the ISR with `FMstop()` first
  (stale interleavings corrupted rows/ticks nondeterministically).
  ISR does port I/O only, never DOS/file calls.
- Verified: `bin\musplay.exe` (minimal player: init/load/ISR-play/
  silence/exit) plays G66A/MC12/DESORUIN headless — rows advance at
  exactly 8 rows/sec (speed 6 @ 50fps) with continuous OPL writes,
  clean exits. `tests/engtest.c` covers headers, goldens
  (`note2period`, `VibVal` incl. BYREF reset), row-0 sounding, and
  ISR-driven progression.
- `lala.c`/`engine.c`: real `FMinit` at startup, `FMend` at exit,
  `FMstop()` + `BeSilent()` at the three `PLAY STOP` sites.

## 6. Phase 4 — Integration & acceptance (implementation DONE)

- `wmake` → `run.bat` → full loop in DOSBox 0.74 (`lala.conf` as-is):
  init messages, font, SB init, title demo game, playable game,
  ending screen, clean text-mode exit. The whole loop is wired in
  `src/lala.c` (main → showTitle → engineDoGame → showEnding →
  clean `DQBinitText`/`DQBclose`/`FMend` exit).
- Test harnesses live in `tests/` (project rule): `tests/testmain.c` +
  `tests/engtest.c` → `bin\test.exe`, `tests/musplay.c` →
  `bin\musplay.exe`. The game binary stays lean (test code would blow
  the ~64K image ceiling — see quirks appendix).
- `SETMEM(-513)` closed via `wcl -k16384` (§2).
- Byte-compare behavior, not bytes: same maps (`MAP/LALA.MAP`), same
  physics constants, same SFX slots.
- Deliberate non-goals: `DQBerror$` text fidelity, mouse/joystick/3D
  modules, SDL path changes.
- Remaining: the DOSBox playtest run itself (`build` → `run.bat`),
  then fix whatever it uncovers.

**Suggested execution order:** Phase 0 lib → Phase 1 bindings →
Phase 2 engine (this doc) → Phase 3 FMENGINE → playtest pass.

## Code style (project rule)

- `.c`/`.h` files: 4 spaces everywhere, TABS FORBIDDEN (makefiles
  keep their mandatory tabs).

## Appendix: WASM/wlink quirks found (do not regress)

- WASM defaults to FP-emulation codegen: FPU ops get `FWAIT` prefixes
  plus an `FIDRQQ` external that drags in 12KB of `emu87`. Only
  `MAIN.ASM` uses the FPU (DQBangle, unused by the game). Fix:
  `wasm -fpi87` (in makefile `WASMFLAGS`) — bare opcodes, no helper.
- The game image must keep (CODE + early DGROUP) under ~64K: some DQB
  data fixups resolve to absolute image offsets (E2083 beyond that).
  The emu87 bloat was enough to overflow it; `wmake` output size is
  worth a glance after big additions.
- `wmake`/`wcl` need DOS-style `\` paths (run via `cmd //c` from
  MSYS bash); check real exit codes, not pipe-masked ones.
- OpenWatcom 16-bit `int` is 16-bit (QB INTEGER semantics hold,
  including `-1` = true); `rand()` spans 0..32767 like QB's RND range.
- Known open issue (not blocking): bare-bones probe binaries calling
  `DQBinit` hang intermittently under DOSBox (layout/timing-sensitive,
  mechanism unknown — suspect INT 67h/33h timing; the full game binary
  inits reliably). Verify DQB-level behavior via the game binary
  (`lala.exe test`), not via mini-probes.
