"""Platform-aware downloader for pre-built V8 monolith binaries.

Single source of truth for the V8 version pin, both per-platform URLs, and
both sha256s. Both binaries come from our own kitten3d/v8-builds release:
no-ICU v8_monolithic static libraries built by the build-v8 workflow.
"""

V8_VERSION = "13.6.233.17"
V8_TAG = "v13.6.233.17"

_BASE = "https://github.com/kitten3d/v8-builds/releases/download"

_SUFFIXES = {
    "linux": "ubuntu-latest-Release",
    "macos_arm64": "macos-latest-Release",
}

_SHA256S = {
    "linux": "14f83641311836a264aea992cc126497ad16bbd6a7deb9b4f6fbecd7ebc5286e",
    "macos_arm64": "f022d958d9c6cb905f2ba5489931ae034bda7e66278d5dccc4b6eb65c25d7e90",
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
