# victory-dedsec

A compatibility layer, written in Rust, that runs an Xbox Series title natively on Windows from
files the user supplies: its own loader for the title's executable, the console's runtime
services, Direct3D 12.X on top of the PC's Direct3D 12, and a translator from the console's
shader code (RDNA2 / GFX10 machine code) straight to DXIL.

It is built on [VIctory](https://github.com/Marvisak/VIctory) by Marvisak and its contributors,
through [fxceless/victory-fork](https://github.com/fxceless/victory-fork). Their history is kept
in this repository and their README is in [`docs/README-upstream.md`](docs/README-upstream.md).
Licensed GPL-3.0-or-later, as they are.

**This repository contains no game files, code or assets.** You need your own copy of the game.
It does nothing about encryption, DRM or licensing. It is not affiliated with or endorsed by the
game's developer or publisher.

## State (2026-11-25)

Measured on one machine: Windows Server 2025, 32-core Xeon, 123 GB RAM, NVIDIA RTX PRO 4500
(Blackwell, 32 GB; shader model 6.8, waves of 32 lanes only, mesh shader tier 1, ray tracing
tier 1.2).

| | |
|---|---|
| How far it gets | The title's opening cutscene, the first room with the player moving, and the scene after it |
| Speed | About 3 frames per second (300 to 350 ms a frame, about 5,000 draws a frame) |
| Shaders | 25,647 of the title's 25,941 distinct shader containers translate (its pack and its ray-tracing builder library); 294 do not |
| Light | Direct sunlight, fog and lamps show. Indirect light does not: what is out of the sun is a silhouette |
| Ray tracing | Off. The title's structure builder now translates whole (53 pipelines) and brings the title down when it runs |

**Not playable.** This is a record of what works, what was measured and what is known to be
wrong, not a release.

## What this project added

Each line is a commit or a few, with what was measured when it went in.

**Reading the title's data**

- A DirectStorage queue hands its requests to the workers at the title's own submit, not when
  half full. The title names a request's destination pages after enqueueing it; under the
  half-full rule, of 94,208 such requests in a run, 7 were caught writing another model's pages
  and 28 failed. After: none in seven runs.
- DirectStorage's writes into physical pages are told to the copies the GPU side keeps of title
  memory. 4,434 to 7,353 of some 80,000 such writes in a run landed in pages a copy had already
  taken and was never going to take again.
- The first room comes without its walls, floor and window grate in about half the runs. They
  are stale copies: the title keeps some 55,000 pages (3.5 GB) mapped at two addresses at once
  and the copies guard addresses. `VICTORY_GUARD_FORGET_EVERY=<seconds>` takes every copy again
  that often, which is a stopgap; the fix (guarding every address of a page) is not written.

**Translating shaders**

- *The halves of a console wave followed together.* A console wave of 64 lanes runs here as two
  host waves of 32. Three programs of the ray-tracing structure builder stopped at "a first-lane
  read where not every lane runs"; the value they read is the same in every lane of a wave, in
  a loop the lanes of a wave run all or none, so each half's own first lane gives it. Tried only
  for programs that do not translate otherwise.
- *A half of a register nobody reads.* Eight pixel programs (deferred textured surfaces and
  their mirror forms) were given up because an instruction that writes one 16-bit half of a
  register keeps the other, and the other was the leftover first half of an interpolation.
  Where nothing reads the kept half it is zero. 303 containers of the pack did not translate
  before, 295 after, none that translated before fails.
- `VICTORY_WAVE_WIDE=last`: the wave-wide form of a wave64 compute program as the last resort.
  Of the 26 compute pipelines the host refuses, 17 are accepted in that form. Off by default.
- `VICTORY_MEMORY_COPIES=<n>`: how many copies of title memory a shader can reach by address.
  The structure builder used up the 1,023 there were within three seconds.

**Tools**

- `victory precompile <pack...>`: every shader of a pack through the run's own translation into
  the run's cache, ahead of the run (26,555 containers in about 90 s on 29 threads).
- `victory pso-repro <hash...> [--path <pack>] [--dump <dir>]`: why the host refuses a pipeline,
  offline, in seconds: the device's report, the translation, the validator's answer, the
  pipeline's.
- Feature `bench`, `VICTORY_BENCH=<file.json>`: zones of self time per thread, the card's time
  by timestamp queries, one JSON per run over a fixed stretch of the scene.
- The shader cache is keyed by the translator's sources, so a rebuild that leaves the
  translator alone keeps the cache.

## Known problems

- **294 containers do not translate.** By cause: 195 are one geometry shader
  (`GS_VoxelizeGeneric`; the geometry stage is not translated at all); 80 are programs, most
  of them pixel programs, whose descriptor is chosen by control flow or read only as data (5
  of them trace shadow rays); 10 use ordered pixel shading (hair and cut-out of characters); 5
  sum doubles over a wave (water); the few that remain are single cases.
- **Compute pipelines the host refuses** for wanting 64-lane waves: 26. Those with a thread
  group of one console wave are accepted with `VICTORY_WAVE_WIDE=last`; those with several
  waves to a group need a form that does not exist yet.
- **The ray-tracing structure builder** (`VICTORY_BVH_BUILDER=1`) runs with all of its
  pipelines and the title dies about 15 s later on bad pointers. Its stages are not right yet.
- `--console series-s` loses the device at the first frame of the world.
- One loader test (`load_probe`) does not link its probe DLL with the toolchain used here.

## Building and running

Requirements: Windows 10/11 x64, a CPU with AVX2, a Direct3D 12 GPU with shader model 6.6 and
mesh shaders, Rust (pinned in `rust-toolchain.toml`). The title needs several GiB of Windows
commit at startup.

```powershell
cargo test --workspace                                   # needs no game data
cargo build --profile diag --features bench -p victory   # the build the numbers above are from
```

```powershell
# every shader into the cache first; the run then loads instead of translating
target\diag\victory.exe precompile <game dir>\shaders.rpf <game dir>\XboxBvhBuilder.dll

# the configuration measured above
$env:VICTORY_RELAY = '1'                  # copies back on another thread: 599 -> 323 ms a frame
$env:VICTORY_GUARD_FORGET_EVERY = '10'    # see "stale copies" above
target\diag\victory.exe run <game dir>\<the title's exe> --execute --console series-x -- -skipToIIS
```

`VICTORY_CACHE_DIR` and `VICTORY_DATA_DIR` choose where the caches and the profile (saves,
settings, `crashes.log`) go. The window caption shows the frame rate.

Input: XInput pads. With none connected the keyboard is a pad while the window has focus:

| Keys | Pad |
|------|-----|
| W A S D / I J K L | left / right stick |
| arrows | D-pad |
| Enter, Backspace, X, Y | A, B, X, Y |
| Q / E, Z / C | shoulders, triggers |
| F / H | stick clicks |
| Esc, Tab | Menu, View |

More commands (`inspect`, `census`, `shader-info`, `translate`, `config`), the diagnostics build
and the design are described in [`docs/README-upstream.md`](docs/README-upstream.md) and
[`docs/architecture.md`](docs/architecture.md).

## Tests at this commit

`victory-shader` 210 passed (2 ignored), `victory-gpu` 110 (1 ignored), `victory-hle` 96 and 1,
`victory-loader` 24 and 1 of its 2 integration tests (see above).

## Credits and licence

- **[VIctory](https://github.com/Marvisak/VIctory)** by Marvisak and its contributors is the
  base of everything here: the loader, the runtime services, the Direct3D 12 back end and the
  shader translator.
- **[fxceless/victory-fork](https://github.com/fxceless/victory-fork)** is the fork this work
  started from.
- **[XCL](https://github.com/ivall/xcl)** by ivall and its contributors (GPL-2.0-only) was a
  reference for how the same title behaves under another layer; nothing of it is here.
- Developed with [Claude Code](https://claude.com/claude-code).

GPL-3.0-or-later; see [`LICENSE`](LICENSE). The commit history of the projects above is part of
this repository.
