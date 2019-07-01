def snapshot_tests(test_paths):
    """
    Define a bunch of snapshot tests all at once. The paths must all conform to
    the format expected by snapshot_test.
    """

    test_names = []

    for test_path in test_paths:
        test_names.append(snapshot_test(test_path))

    return test_names

def _run_output(test_path):
    """
    Returns the path to the output of the run step.
    """
    return "{}/actual.tar.gz".format(test_path)

def snapshot_test(test_path):
    """
    test_path is of the form `total/test` or `partial/test`.
    """

    actual = _run_output(test_path)
    actual_name = "actual_{}".format(test_path)
    test_name = "test_{}".format(test_path)

    # TODO: Why can't this find the runfiles?
    native.genrule(
        name = actual_name,
        tools = [
            ":run_one_bazel",
        ],
        srcs = [
            "@bazel_tools//tools/bash/runfiles",
            "//main:sorbet",
            "//gems/sorbet:sorbet",

            # TODO: how do we ask for the environment of the c compiler here,
            # for supporting gems with native code? (An example of this is the
            # `json` gem)

            # The minimal requirement for a test run is a Gemfile
            "{}/src/Gemfile".format(test_path),

            # TODO: do we require a Gemfile.lock for the test, or should we make
            # it a candidate for updating?
            "{}/src/Gemfile.lock".format(test_path),
        ] + native.glob(
            [
                "{}/src/**/*".format(test_path),
                "{}/expected/**/*".format(test_path),
                "{}/gems/**/*".format(test_path),
            ],
            exclude = [
                # Exclude these two as they're explicit dependencies above and
                # it's an error to mention something twice.
                "{}/src/Gemfile".format(test_path),
                "{}/src/Gemfile.lock".format(test_path),
            ],
        ),
        outs = [actual],
        cmd = """
        $(location :run_one_bazel) ruby_2_4_3 """ + test_path + """
        cp actual.tar.gz $(location """ + actual + """)
        """,
    )

    native.sh_test(
        name = test_name,
        srcs = ["check_one_bazel.sh"],
        data = [
            actual,
        ] + native.glob([
            "{}/src/**/*".format(test_path),
            "{}/expected/**/*".format(test_path),
            "{}/gems/**/*".format(test_path),
        ]),
        deps = [
            ":logging",
        ],
        args = [
            "ruby_2_4_3",
            test_path,
        ],
    )

    return test_name
