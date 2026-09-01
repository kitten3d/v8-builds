# v8-builds

Artifact factory and wrapper Bazel module for [V8](https://v8.dev), as
consumed by the kitten3d engine (phase-5 scripting runtime, D-P5.5). The
factory's second customer after dawn-builds. Nobody in the ecosystem serves a
current, no-ICU, gn-monolithic static V8 for gcc/libstdc++ **and**
AppleClang/libc++ — this repo builds both from the Node LTS tag archive's
`deps/v8` (the depot_tools-free route) and serves them as a single
platform-neutral Bazel module named `v8`.

Ratified evidence: `kitten/plans/script-language-weighing.md` (§3.2 the
recipe, §8 the lane + accepted risks R1–R3).

## How the pieces fit

1. **`.github/workflows/build-v8.yml`** — the artifact factory. Dispatched
   with a Node version + its archive sha256, it extracts `deps/v8`, derives
   every auxiliary pin (chromium `build.git`, `gn`, icu `config.gni`) from
   the DEPS manifest *inside* the verified archive, builds the no-ICU
   `v8_monolith` on `ubuntu-latest` (gcc) and `macos-latest` (AppleClang),
   gates the result (d8 runs, `v8-gn.h` config matches the ratified args,
   stdlib ABI check, size, tarball prefix), and publishes
   `V8-<version>-<platform>-Release.tar.gz` release assets with both sha256s
   in one step summary.
2. **`module/`** — the `v8` wrapper module. `extensions.bzl` picks the right
   per-platform prebuilt at repo-fetch time and exposes it as `@v8_bin`;
   `//:v8` aliases `@v8_bin//:v8` so consumers write `@v8//:v8`. Both URLs
   and sha256s live in `extensions.bzl` as the single source of truth. The
   artifact ships the generated `v8-gn.h` and the BUILD sets `V8_GN_HEADER`,
   so consumer TUs compile against the exact build config of the `.a` — a
   config mismatch is a compile error, not V8's runtime startup abort.
3. **`tools/package-module.sh`** — packages `module/` into a
   byte-deterministic `v8-module-<version>.tar.gz` and prints its sha256 +
   SRI integrity. This tarball is the extra asset on the release and is what
   the registry serves. It refuses to package while `_SHA256S` is unpinned.
4. **The registry** (`kitten3d/bazel-registry`) — holds `v8`'s metadata, a
   byte-identical copy of `module/MODULE.bazel`, and a `source.json` pointing
   at the wrapper-module tarball. Consumers add one `bazel_dep(name = "v8")`.

## V8 version-bump procedure (quarterly, tracking Node LTS)

1. **Pick the Node LTS release** (`https://nodejs.org/dist/index.json`, the
   newest release of the current LTS line — its `v8` field is the version you
   get) and compute the tag-archive sha:
   `curl -sL https://github.com/nodejs/node/archive/refs/tags/v<ver>.tar.gz | sha256sum`.
2. **Dispatch** `build-v8` with that version + sha. It publishes both
   platform tarballs and prints their sha256s.
3. **Update `module/`**: set `V8_VERSION`/`V8_TAG` and both `_SHA256S`
   entries in `extensions.bzl`, bump `version` in `module/MODULE.bazel`.
4. **Package**: `tools/package-module.sh`, upload `v8-module-<version>.tar.gz`
   to the same release, copy the printed SRI integrity.
5. **Registry**: add `modules/v8/<version>/` (copy of `MODULE.bazel` +
   `source.json` with the new URL and integrity), append the version to
   `metadata.json`.
6. **Engine**: bump `bazel_dep(name = "v8", ...)`, `bazel test //:tests`.

Measured churn expectation (weighing §2): ~zero source edits per bump — a
~450-line embedder compiled unmodified across twelve V8 milestones.

## Standing notes (accepted risks, ratified 2026-09-01)

- **R1**: `use_custom_libcxx=false` is upstream-deprecated with stated intent
  to remove, no date. The Node-vendored build path every distro ships is
  insulated; if it ever dies, the engine's script firewall makes a QuickJS
  swap module-internal (weighing §3.1 proved that lane end-to-end).
- **R2**: this factory owns V8 freshness alone — nobody upstreamable tracks
  stable. The cadence above is the mitigation; scripts are first-party
  content only. If scripts ever become user content, the threat model
  inverts (sandbox back on) — that day is a new grill.
- The icu `config.gni` fetch is one pinned file from the DEPS-named icu
  revision; with `v8_enable_i18n_support=false` + `icu_use_data_file=false`
  nothing else of ICU is referenced.
