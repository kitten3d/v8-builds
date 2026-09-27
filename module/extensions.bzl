"""Platform-aware downloader for pre-built V8 monolith binaries.

Single source of truth for the V8 version pin, the per-platform URLs, and
their sha256s. Every binary comes from our own kitten3d/v8-builds release:
no-ICU v8_monolithic static libraries built by the build-v8 workflow.
"""

V8_VERSION = "13.6.233.17"
V8_TAG = "v13.6.233.17"

_BASE = "https://github.com/kitten3d/v8-builds/releases/download"

_SUFFIXES = {
    "linux_x86_64": "linux-x86_64-Release",
    "linux_arm64": "linux-arm64-Release",
    "macos_arm64": "macos-arm64-Release",
}

_SHA256S = {
    "linux_x86_64": "",
    "linux_arm64": "",
    "macos_arm64": "",
}

def _os(name):
    if "mac" in name:
        return "macos"
    if "linux" in name:
        return "linux"
    return name

def _arch(arch):
    if "aarch64" in arch or "arm64" in arch:
        return "arm64"
    if "amd64" in arch or "x86_64" in arch:
        return "x86_64"
    return arch

def _v8_bin_impl(ctx):
    key = "{}_{}".format(_os(ctx.os.name.lower()), _arch(ctx.os.arch))
    if key not in _SUFFIXES:
        fail("No prebuilt V8 for {}; v8-builds ships {}.".format(
            key,
            ", ".join(sorted(_SUFFIXES.keys())),
        ))

    sha = _SHA256S[key]
    if not sha:
        fail("v8-builds: sha256 for '{}' is unpinned; run the build-v8 ".format(key) +
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
