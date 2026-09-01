# V8 JavaScript engine — pre-built no-ICU monolith static library, fetched
# by the v8_binaries extension as @v8_bin. V8_GN_HEADER makes v8config.h
# include the shipped v8-gn.h, so consumer TUs compile against the exact
# defines the .a was built with (a mismatch is a compile error).

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
