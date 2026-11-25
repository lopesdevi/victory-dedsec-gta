# VIctory fork (work in progress)

A work-in-progress fork of [VIctory](https://github.com/Marvisak/VIctory), a
compatibility layer that runs an Xbox Series title natively on Windows from
files the user supplies. This fork follows upstream
`main` and adds fixes aimed at one goal: getting the game's world to render
correctly and playably on one particular PC.

**This repository contains no game files, code or assets.** You need your own
copy of the game. It is not affiliated with or endorsed by the game's
developer or publisher.

## Credits

- **[VIctory](https://github.com/Marvisak/VIctory)** by Marvisak and its
  contributors is the base of everything here: the loader, the runtime
  services, the Direct3D 12 back end and the shader recompiler. Licensed
  GPL-3.0-or-later; so is this fork. Upstream's history is kept intact below
  the single commit that carries this fork's changes.
- **[XCL](https://github.com/ivall/xcl)** by ivall and its contributors
  (GPL-2.0-only) was used as a reference for how the same title behaves under
  another layer. Fixes inspired by it were written anew in VIctory's code.
- This fork's changes were developed with [Claude Code](https://claude.com/claude-code).

## lopesdevi/victory-dedsec: what this copy adds (2026-11-24)

A fork of [fxceless/victory-fork](https://github.com/fxceless/victory-fork), a few commits on top of its
`main` (`2119b0e`): tools and limits first (2026-11-24), then fixes to DirectStorage and one more
translation form (2026-11-25, below). The sections below this one are fxceless's and describe that
fork and its test machine.

**State on 2026-11-25, on the machine below: the prologue's cutscene and first room at 3 frames per
second (300 to 350 ms a frame, about 5,000 draws a frame, `VICTORY_RELAY=1`); 25,587 of the pack's
25,889 distinct shader containers translate, 302 do not; all 52 containers of the ray-tracing
structure builder translate (49 before), and the builder is still off: run whole, it brings the
title down. Indirect light is missing (characters out of the sun are silhouettes).**

Test machine of this copy: Windows Server 2025, 32-core Xeon, 123 GB RAM, NVIDIA RTX PRO 4500
(Blackwell, 32 GB). What the device reports (`victory pso-repro`): shader model 6.8, waves of 32
lanes only, 64-bit atomics on typed, groupshared and descriptor heap resources, native 16-bit
operations, mesh shader tier 1, ray tracing tier 1.2, a view heap capped at 1,000,000.

| Added | What it is for |
|-------|----------------|
| `victory precompile <pack>` | Every shader of a pack through the run's own translation into the run's cache: 25,587 of 25,889 distinct containers in 87 s on 29 threads |
| Shader cache keyed by the translator's sources | A rebuild that leaves `victory-shader` alone keeps the cache (the key was the whole executable) |
| `VICTORY_WIDE_THREADS`, `VICTORY_PIPELINE_WORKERS`, `VICTORY_HEAP_TEXTURE_MB`, `VICTORY_HEAP_TEXTURE_MS` | Thread and staging limits that were fixed |
| Feature `bench`, `VICTORY_BENCH=<file.json>` | Zones of self time per thread, the card's time by timestamp queries, a JSON per run |
| `victory pso-repro <hash...>` (`cargo xtask pso-repro`) | Why the host refuses a pipeline, offline, in seconds, with the device's report |

Measured on this machine, in the prologue, over the same 60 s of the scene:

| Configuration | ms per frame (mean) | fps |
|---------------|--------------------:|----:|
| default | 598.9 | 1.67 |
| `VICTORY_LATE_WAIT=1` | 619.1 | 1.62 |
| `VICTORY_RELAY=1` | 323.4 | 3.09 |
| `VICTORY_LATE_WAIT=1 VICTORY_RELAY=1 VICTORY_INPLACE=1` | 884.8 | 1.13 |

Translation of the whole pack on this device (26,084 programs): vertex and pixel 14,156 emitted of
14,247 (14,156 pipelines made); compute 2,669 of 2,682 (2,644 pipelines); mesh 8,762 of 8,765 (8,762
pipelines). Of the 25 compute pipelines the host refuses, 24 expect 64-lane waves: 17 translate for
32 lanes with `VICTORY_WAVE_WIDE=1`, 7 have thread groups of several console waves. That switch
stays off: a prologue run with it lost the device on this card too. In the prologue 710 draws and
dispatches a frame are dropped, 705 of them stages of the ray-tracing structure builder, which is off.

### 2026-11-25: DirectStorage, stale copies, the structure builder's three programs

| Change | What was measured |
|--------|-------------------|
| A DirectStorage queue hands its requests over at the title's submit, not half full | The title names a request's destination pages after enqueueing it. Under the half-full rule, of 94,208 page-destination requests in a run 4,158 were handed over by the queue itself, 3,955 of those had their page array changed afterwards, 7 were caught writing the pages named before and 28 failed; with the queue submitting by itself only when full: 0 in seven runs. Same 61.6 us a draw, 5,841 draws a frame against 4,957 |
| DirectStorage's writes into physical pages are told to the copies of title memory | The copies guard addresses, and those writes go through a view of the runtime's own: 4,434 to 7,353 of some 80,000 such writes in a run landed in pages a copy had already taken, and it was never taken again |
| `VICTORY_GUARD_FORGET=<s>,...`, `VICTORY_GUARD_FORGET_EVERY=<s>`, a count of pages mapped at two addresses | The first room comes without its walls, floor and window grate in about half the runs (also with the two fixes above). They are stale copies: in a run without them at 278 s they were there at 322 s, after every copy was taken again at 292 s. The title keeps some 55,000 pages (3.5 GB) mapped at two addresses at once, and the guards know nothing of that. The switch is a stopgap; the fix is to guard every address of a page |
| Wave64 on a host of 32: the halves of a console wave followed together | Three programs of the structure builder (`39321a95`, `77360df2`, `9fc111d3`) stopped at "a first-lane read where not every lane runs". The value read is the same in every lane of a wave, in a loop the lanes of a wave run all or none: each half's own first lane gives it. Tried only for programs that do not translate otherwise. All three now validate (`dxil.dll`) and get a pipeline on this card |
| `VICTORY_MEMORY_COPIES=<n>` | With all 53 of its pipelines the builder ran for the first time (`VICTORY_BVH_BUILDER=1`), named all 1,023 copies of title memory a shader can reach within three seconds, read zeros from there, and the title died. With 16,383 it no longer runs out, and the title still dies some 14 s after the builder's first stage: its stages are not right yet |

Still as before: `f133e35e` ("a lane mask exchanged where not every lane runs"), the five
`shadowmask:CS_TraceShadowRays_*` programs, and the rest of the 302 (195 are one geometry shader,
`GS_VoxelizeGeneric`; 80 are pixel programs whose descriptor is chosen by control flow or read only
as data; 10 use ordered pixel shading; 8 use half of an interpolation by itself; 5 need doubles).
`--console series-s` loses the device at the first frame of the world.

Tests on this machine at this commit: `victory-shader` 210 passed (2 ignored), `victory-gpu` 110
(1 ignored), `victory-hle` 96 and 1, `victory-loader` 24; its `load_probe` test fails here as it
does without these changes (the probe DLL does not link with this toolchain). Clippy reports
nothing in the files these changes touch.

## Status of this fork (2026-11-25)

**Not playable yet: 2.5 to 4 frames per second, and shadowed areas are black.**
Tested on one machine: Windows 11, Intel i7-14700KF, NVIDIA RTX 4070 12 GB,
32 GB RAM. The Series X profile is used throughout.

| Stage | State in this fork |
|-------|--------------------|
| Boot, menus, start screen | works, 30 fps (as upstream) |
| Opening cutscene | plays from start to finish, in order, lit: title cards, credits cards, night and dusk shots |
| Saves | the game autosaves a checkpoint and loads it again |
| First gameplay scene (the prologue) | renders: characters, textures, sky, sunlit exterior; HUD, pause menu and pad input work |
| Light in shadow | missing: the game's ray-traced bounce light and ray-traced lamp and sun shadows do not run yet, so anything the sun does not hit directly is black |
| Frame rate in the world | 2-4 fps: 420-450 ms per frame by default, 240-350 ms with the newer switches (`VICTORY_RELAY=2`, or `VICTORY_LATE_WAIT=3 VICTORY_WIDE_BACK=1 VICTORY_CARD_BUFFERS_MIN_MB=1 VICTORY_CARD_BUFFERS_MB=1024`); it started at 3-6 seconds per frame |
| Stability | no driver hang or device loss in normal runs (a hang introduced by the wave64 update was found and fixed: its barrier form for 64-lane programs is now off unless `VICTORY_WAVE_WIDE=1`) |

### What this fork changed (summary)

Rendering:
- Meshlet culling read its scene buffers as the wrong kind of view, so the world drew almost nothing; fixed.
- Per-draw descriptor tables could run out, after which draws used slots never made for them and the card hung; fixed.
- Light packed by the game's compute shaders was read back through empty copies (sky, probes, fog); fixed for every mip level and layer.
- The fog reconstruction, shadow-mask, hair, blend-shape skinning, fire and several material programs did not translate; fixed.
- Gathers at a named mip level (with and without an offset) read level 0; fixed.
- Implicit-level samples outside pixel shaders produced invalid DXIL in 730 compute programs; fixed.
- Rectangle lists, depth and stencil twins for depth textures written by compute, texture read-backs.
- Ray tracing, in progress and off by default: the game's own structure-builder programs translate, title memory can be read by raw address from shaders, the hardware ray/box and ray/triangle test is emulated in DXIL (checked against a reference on the GPU), and 59 of the 64 trace programs translate. Nothing is lit by it yet. See [docs/fork-ray-tracing.md](docs/fork-ray-tracing.md).

Speed and memory:
- Waits for memory values, write-watch queries and page queries no longer walk page tables per call.
- Large title buffers get a copy in card memory, with shader writes found by hashing on the card.
- Submissions can be sent ahead of the wait for the card (`VICTORY_LATE_WAIT`), with a relay thread that lands results as the card finishes (`VICTORY_RELAY`): in a first five-minute run the card's idle time behind the submitting thread fell from about 136 to 30 ms per frame.
- Title memory can be opened as a graphics heap so that buffers are used in place instead of copied (`VICTORY_INPLACE`, first stage only; a probe confirmed the approach on the test GPU).
- The bindless texture queue no longer uploads stale views; the view table no longer grows without bound; the pipeline library is mapped instead of read into memory.
- An intermittent device loss was traced to the pipeline library file being replaced while mapped; fixed.

- Translated shaders get clean-up passes over the finished module (dead code, constant folding, reuse of values, branch facts); the pack's host instruction count falls by about 43 %, worth about 20 ms of GPU time per frame on the test machine (`VICTORY_SHADER_OPT=0` turns them off).

Most of the newer speed changes sit behind environment switches that are off
by default (`VICTORY_LATE_WAIT`, `VICTORY_RELAY`, `VICTORY_WIDE_BACK`,
`VICTORY_CARD_BUFFERS_MIN_MB`, `VICTORY_INPLACE`, `VICTORY_BVH_BUILDER`, ...).
Each is described in a comment where it is read.

### Known problems

- Everything in shadow is black (see above).
- The interior of the first gameplay room is sometimes not drawn after the cutscene hands over to gameplay.
- Around 24 GB of memory is in use during play.
- A few style lints are switched off for this fork in the workspace `Cargo.toml` until the newer code is tidied.
- Many changes here are specific to this title and this GPU, and some are marked `shortcut:` in the code where they approximate what the console does.

Everything below this line is upstream VIctory's own README, unchanged; its
status section describes upstream, not this fork.

---

# VIctory

Runs the title (Xbox Series X|S) natively on Windows, from files
the user supplies.

The title's x86-64 code runs unchanged inside our process; VIctory supplies
the platform underneath it and converts the title's data, ahead of time where
it can and on first use where it must (shaders). See
[docs/architecture.md](docs/architecture.md).

## Status (2026-11-23)

**Not playable yet.** The title boots, runs its menus at its own 30 fps and
loads the world, where rendering fails.

| Stage | State |
|-------|-------|
| Boot, first-boot screens (accessibility, language, settings, legal) | works, 30 fps |
| Intro video with sound | works |
| Start screen, profile and saves | works |
| Loading into the world (about 50 s) | works |
| The world (first mission's intro) | reached and runs with indirect draws; its title card renders, the scene after it is still dark; 0.5-1.8 s per frame |

Tested on one machine: Windows 11, AMD RX 6700 XT.

> **Warning.** Entering the world on a real GPU can currently hang it, and
> Windows then resets the display driver (every monitor goes black for a
> moment). To look further, use a diagnostics build with
> `VICTORY_D3D12_WARP=1`, which renders on the software adapter.

What each part does today and what it still needs:

| Subsystem | Today | Needs |
|-----------|-------|-------|
| Loader | Runs the title's executable and its DLLs in our process; crash reports name the faulting code and are kept in `crashes.log` | – |
| Runtime services | One signed-in offline user, licences, packages, saves that survive a kill at any step, text entry dialog | Speech is silent; the dialog and relaunch are untested live |
| Network | Offline by design: the title cannot reach the network | – |
| Files and streaming | Archives and streamed data read, zlib and BCPack decoded in parallel | Loading is limited by writes into title memory |
| Input | XInput pads, keyboard, keyboard stand-in pad | Trigger rumble |
| Audio | Menu, video and loading sound; XMA voices and Opus streams decode | Reverb is silent; Opus results unverified against the title |
| GPU: menus | Draws, compute and presentation on host D3D12; only changed title memory is copied | Frame pacing drifts on one screen in release builds |
| GPU: world | Mesh pipelines, shader-written buffers, descriptor lifetimes, indirect execution (arguments clamped), pipelines made by worker threads and kept on disk | Most of the scene is still missing (untranslated shaders drop draws); frames take seconds; real queries, depth bounds, HDR and scaling are missing |
| Shaders | Console GPU code recompiled to DXIL at first use, cached on disk. Menus: all. World: mesh 8,191 of 8,506, vertex/pixel 10,617 of 12,346, compute 1,643 of 2,539 | 64-bit image atomics, merged geometry stages, the ray-tracing builder's shaders; some compute programs need a GPU with 64-lane waves |
| Textures | Console tiled layouts and detiling for the modes the title uses | Render-target metadata planes |
| Series S mode | Runs through the menus to the loading screen | The world, as above |

## Getting started

Requirements: Windows 10/11 x64, a CPU with AVX2, a Direct3D 12 GPU with
shader model 6.6 (and mesh shaders for the world), Rust (pinned in
`rust-toolchain.toml`).

The title also needs several GiB of available Windows commit at startup.
Check **Committed** under **Task Manager → Performance → Memory**. If
`crashes.log` reports Windows error 1455, close other applications or increase
the Windows paging file size, then retry.

```powershell
cargo xtask install-hooks                # asset-policy check on every commit
copy victory.example.toml victory.toml   # then set your paths (outside the repo)
cargo test --workspace                   # needs no game data
cargo run -p victory -- config           # check your paths
```

Run the title:

```powershell
cargo build --release -p victory
target\release\victory.exe run <game dir>\<the title's exe> --execute
```

The window caption shows the framerate. Saves, settings and `crashes.log`
are kept under the data folder (default `%LOCALAPPDATA%\victory\data`), derived
data under the cache folder.

Input: XInput pads. With none connected the keyboard is a pad while the
title's window has focus:

| Keys | Pad |
|------|-----|
| W A S D / I J K L | left / right stick |
| arrows | D-pad |
| Enter, Backspace, X, Y | A, B, X, Y |
| Q / E, Z / C | shoulders, triggers |
| F / H | stick clicks |
| Esc, Tab | Menu, View |

## Commands

```
victory inspect <exe|dll> [--imports] [--exports]
victory census [paths...] [--missing] [--strict]
victory lib-exports <import.lib> [--list]
victory shader-info [paths...] [--verbose] [--disasm]
victory translate [paths...] [--validate] [--pipelines] [--list] [--jobs N]
victory run <exe> [--execute] [--unimplemented trap|zero] [--strict]
            [--console series-x|series-s] [-- <title arguments>]
victory config
```

Logging: `VICTORY_LOG=victory_loader=trace,info` (a release build logs
info and above).

## Debugging

A release build has no debugging aids. Build them in with

```powershell
cargo build --profile diag -p victory --features diagnostics   # target\diag\victory.exe
```

| Variable | Effect |
|----------|--------|
| `VICTORY_LOG=<target>=debug,...` | debug and trace output |
| `VICTORY_STACKS=20,60` | every thread's stack at those seconds |
| `VICTORY_WATCH=<rva>,...` | logs a title u32 when it changes |
| `VICTORY_KEYS=30:Enter,35:X` | presses keys at those seconds, focus or not |
| `VICTORY_CRASH_SAVE=<rva>:<len>,...` | saves title memory to the cache folder on a crash |
| `VICTORY_CAPTURE=<dir>` | saves presented frames (powers of two, or `VICTORY_CAPTURE_FRAMES=<list>`) |
| `VICTORY_DUMP_TARGETS=1` | with the two above, saves every render target of those frames |
| `VICTORY_D3D12_DEBUG=1` | host debug layer |
| `VICTORY_D3D12_GBV=1` | with the above, GPU-based validation (bad descriptor use reported, not faulted; slow) |
| `VICTORY_D3D12_DRED=1` | on a GPU failure, the allocation hit and the commands in flight |
| `VICTORY_PIPELINE_WAIT_MS=24` | reduce the per-frame wait for background pipeline creation from the default of 500 ms. A draw can be omitted until its pipeline is ready |
| `VICTORY_SKIP_PIPELINES=<hash>,...` | omit draws and dispatches, including indirect ones, whose pipeline contains a listed 16-digit shader hash |
| `VICTORY_GPU_TIMING=1` | with the above, each list of a submission run and timed on its own; slow lists logged with their slowest commands |
| `VICTORY_D3D12_WARP=1` | host device on the software adapter (slow; cannot reset the driver) |
| `VICTORY_SHADER_LOOP_LIMIT=<n>` | translated shader loops stop after `n` iterations per lane instead of 2^20 (own shader cache entries); if a lower `n` makes world frames much faster, loops hitting the limit are what makes them slow |
| `VICTORY_AUDIO_CAPTURE=<file.wav>` | records what the title plays (our process only) |
| `VICTORY_XMA_DUMP=<dir>` | saves the first 32 XMA voices' context and input |

Every build appends crashes and host GPU failures to `crashes.log` in the
title's data folder.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
