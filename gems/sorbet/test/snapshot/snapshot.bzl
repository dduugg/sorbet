load("@gems//tools/build_defs:gemfile.bzl", _parse_gemfile_lock = "parse_gemfile_lock")

def snapshot_tests(test_paths):
    """
    Define a bunch of snapshot tests all at once. The paths must all conform to
    the format expected by snapshot_test.
    """

    test_names = []

    for test_path in test_paths:
        test_names.append(snapshot_test(test_path))

    return test_names

def snapshot_test(test_path):
    """
    test_path is of the form `total/test` or `partial/test`.
    """

    test_name = "test_{}".format(test_path)

    native.sh_test(
        name = test_name,
        srcs = ["test_one_bazel.sh"],
        data = [
            "//main:sorbet",
            "//gems/sorbet:sorbet",
            "@ruby_2_4_3//:ruby",
            "@gems//gems",
            "@gems//bundler:bundle",
            "@gems//bundler:bundler",
            "@gems//bundler:bundle-env",

            # TODO: how do we ask for the environment of the c compiler here?

            # this will force a check on the presence of the src directory
            "{}/src/Gemfile.lock".format(test_path),
        ] + native.glob([
            "{}/**/*".format(test_path)
            ],
            exclude = [
                "{}/src/Gemfile.lock".format(test_path),
            ]),
        deps = [
            ":logging",
        ],
        args = [
            "ruby_2_4_3",
            test_path,
        ],
        timeout = "moderate",
    )

    return test_name
