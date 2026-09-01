# v8-builds

Artifact factory and wrapper Bazel module for [V8](https://v8.dev), as
consumed by the kitten3d engine's script runtime. The factory's second
customer after dawn-builds. Nobody in the ecosystem serves a current,
no-ICU, gn-monolithic static V8 for gcc/libstdc++ **and**
AppleClang/libc++ — this repo builds both from the Node LTS tag archive's
`deps/v8` (the depot_tools-free route) and serves them as a single
platform-neutral Bazel module named `v8`.

## How the pieces fit

1. **`.github/workflows/build-v8.yml`** — the artifact factory. Dispatched
   with no inputs it builds the newest Node LTS release (explicit
   `node_version`/`node_sha256` inputs override); it extracts `deps/v8`, derives
   every auxiliary pin (chromium `build.git`, `gn`, icu `config.gni`) from
   the DEPS manifest *inside* the verified archive, builds the no-ICU
   `v8_monolith` on `ubuntu-latest` (gcc) and `macos-latest` (AppleClang),
   gates the result (d8 runs, `v8-gn.h` config matches the intended args,
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

1. **Dispatch** `build-v8` with no inputs: it resolves the newest Node LTS
   release, computes the tag-archive sha256, and publishes both platform
   tarballs with every sha256 in the run summary. Pass `node_version` (and
   optionally `node_sha256` to pin the archive up front) to build a
   specific release instead.
2. **Update `module/`**: set `V8_VERSION`/`V8_TAG` and both `_SHA256S`
   entries in `extensions.bzl`, bump `version` in `module/MODULE.bazel`.
3. **Package**: `tools/package-module.sh`, upload `v8-module-<version>.tar.gz`
   to the same release, copy the printed SRI integrity.
4. **Registry**: add `modules/v8/<version>/` (copy of `MODULE.bazel` +
   `source.json` with the new URL and integrity), append the version to
   `metadata.json`.
5. **Engine**: bump `bazel_dep(name = "v8", ...)`, `bazel test //:tests`.

Expected churn: ~zero source edits per bump — V8's embedder surface is
deprecation-managed (`V8_DEPRECATED` → one-branch grace → removal), and a
~450-line test embedder compiled unmodified across the twelve milestones
from 12.4 to 13.6.

## Standing notes (accepted risks)

- **R1**: `use_custom_libcxx=false` is upstream-deprecated with stated intent
  to remove, no date. The Node-vendored build path every distro ships is
  insulated; if it ever dies, the engine's script firewall makes a QuickJS
  swap module-internal (QuickJS has a proven source-only registry lane).
- **R2**: this factory owns V8 freshness alone — nobody upstreamable tracks
  stable. The cadence above is the mitigation; scripts are first-party
  content only. If scripts ever become user content, the threat model
  inverts (sandbox back on) — that day forces a fresh decision, not a
  footnote here.
- The icu `config.gni` fetch is one pinned file from the DEPS-named icu
  revision; with `v8_enable_i18n_support=false` + `icu_use_data_file=false`
  nothing else of ICU is referenced.
