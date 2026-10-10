/* directqb.h — C bindings over dqb/dqb.lib (DirectQB 1.61, WASM build).
 *
 * All functions are called DIRECTLY with __far __pascal, which matches
 * the ASM convention 1:1 (FAR, params pushed left-to-right, callee
 * cleans). __pascal uppercases the symbol, so CamelCase source names
 * link against the UPPERCASE lib publics (verified in spike/probe5) —
 * i.e. DQBinit here IS DQBINIT in the lib. No wrappers, no pragmas.
 *
 * Signatures mirror the "; Stack layout:" comments in the dqb ASM sources:
 * far-pointer params are (seg, off) word pairs; Watcom pushes far
 * pointers seg-first, and materializes near->far with DS, so string
 * literals and DGROUP buffers pass straight through (verified live
 * by the render test in tests/engtest.c).
 *
 * SEGMENT RULES (the ASM assumes them, verified against sources):
 *  - `char __far *file` params: literals and DGROUP buffers only,
 *    NOT stack buffers (the compiler supplies DS as the segment).
 *  - `void __far *` buffer params may point anywhere (layer/sprite/
 *    palette data); the segment travels explicitly.
 *  - DQBloadImage's imgW/imgH are stored through DS, so callers must
 *    pass DGROUP ints — directqb.c stages stack locals through
 *    statics so callers can keep using locals.
 */
#ifndef _DIRECTQB_H_
#define _DIRECTQB_H_

#include "dqb/dqb.h"

#endif /* _DIRECTQB_H_ */
