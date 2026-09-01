# V8 JavaScript engine — pre-built no-ICU monolith static library.
#
# This BUILD file is the build_file for the @v8_bin repo the v8_binaries
# extension creates. The downloaded tarball (after strip_prefix) contains:
#   include/   — public headers (v8*.h, cppgc/, libplatform/) plus the
#                generated v8-gn.h build-config header
#   lib/       — libv8_monolith.a static library
#   lic/       — upstream LICENSE files
#
# V8_GN_HEADER makes v8config.h include v8-gn.h, so consumer TUs compile
# against the exact defines the .a was built with (pointer compression on,
# sandbox off, no ICU). The define propagates to every dependent target.

load("@rules_cc//cc:cc_import.bzl", "cc_import")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_import(
    name = "v8_import",
    hdrs = glob(["include/**"]),
    static_library = "lib/libv8_monolith.a",
)

cc_library(
    name = "v8",
    defines = ["V8_GN_HEADER"],
    includes = ["include"],
    linkopts = select({
        "@platforms//os:linux": [
            "-ldl",
            "-lpthread",
        ],
        "//conditions:default": [],
    }),
    visibility = ["//visibility:public"],
    deps = [":v8_import"],
)
