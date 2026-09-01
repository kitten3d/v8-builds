"""Platform-aware downloader for pre-built V8 monolith binaries.

Same shape as dawn-builds' extensions.bzl: one ctx.os -> platform key map,
download_and_extract with stripPrefix. This file is the single source of truth
for the V8 version pin, both per-platform URLs, and both sha256s.

Both binaries come from our own kitten3d/v8-builds release (the artifact
factory's second customer): no-ICU v8_monolithic static libraries built from
the Node LTS tag archive's deps/v8 — see the build-v8 workflow. The artifact
carries the generated v8-gn.h next to the public headers; v8_bin.BUILD defines
V8_GN_HEADER so every consumer TU compiles against the exact build config the
.a was built with (a mismatch is a compile-time error, not a startup abort).
"""

# ─── V8 version pin (bump this block for a new Node-LTS/V8 version) ──────────
V8_VERSION = "13.6.233.17"
V8_TAG = "v13.6.233.17"

# ─── URL base ────────────────────────────────────────────────────────────────
_BASE = "https://github.com/kitten3d/v8-builds/releases/download"

_SUFFIXES = {
    "linux": "ubuntu-latest-Release",
    "macos_arm64": "macos-latest-Release",
}

# ─── sha256 checksums, keyed by platform ─────────────────────────────────────
# sha256s of OUR kitten3d/v8-builds release assets, as printed by the build-v8
# workflow run that published them.
_SHA256S = {
    "linux": "",  # TODO: pin from the first build-v8 workflow run
    "macos_arm64": "",  # TODO: pin from the first build-v8 workflow run
}

def _v8_bin_impl(ctx):
    os_name = ctx.os.name.lower()
    arch = ctx.os.arch

    if "mac" in os_name and ("aarch64" in arch or "arm64" in arch):
        key = "macos_arm64"
    elif "linux" in os_name and ("amd64" in arch or "x86_64" in arch):
        key = "linux"
    else:
        fail(("No prebuilt V8 for {} {}: v8-builds ships linux x86-64 and " +
              "macos arm64 only (kitten's two platforms).").format(os_name, arch))

    sha = _SHA256S[key]
    if not sha:
        fail("v8-builds: sha256 for '{}' is unpinned — run the build-v8 ".format(key) +
             "workflow and copy the printed sha into _SHA256S.")

    prefix = "V8-{}-{}".format(V8_VERSION, _SUFFIXES[key])
    url = "{}/{}/{}.tar.gz".format(_BASE, V8_TAG, prefix)

    ctx.download_and_extract(url = url, sha256 = sha, stripPrefix = prefix)
    ctx.file("BUILD.bazel", ctx.read(ctx.path(Label("//:v8_bin.BUILD"))))

_v8_bin = repository_rule(
    implementation = _v8_bin_impl,
)

def _v8_binaries_impl(_ctx):
    _v8_bin(name = "v8_bin")

v8_binaries = module_extension(
    implementation = _v8_binaries_impl,
)
