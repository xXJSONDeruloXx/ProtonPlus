// Basic unit-style tests for Utils.LaunchOptions.ensure_override

void assert_equal(string a, string b, string msg) {
    if (a != b) {
        stderr.printf("Assertion failed: %s\nExpected: %s\nActual:   %s\n", msg, b, a);
        Posix.exit(1);
    }
}

int main(string[] args) {
    // 1. Empty string -> creates with %command%
    string r1 = Utils.LaunchOptionsTestCopy.ensure_override("", "dxgi");
    assert(r1.index_of("WINEDLLOVERRIDES=dxgi=n,b") >= 0);
    assert(r1.index_of("%command%") >= 0);

    // 2. Existing %command% without overrides
    string r2 = Utils.LaunchOptionsTestCopy.ensure_override("PROTON_LOG=1 %command% -arg", "dxgi");
    assert(r2.contains("WINEDLLOVERRIDES=dxgi=n,b"));
    assert(r2.index_of("WINEDLLOVERRIDES") < r2.index_of("%command%"));

    // 3. Existing overrides missing injection
    string r3 = Utils.LaunchOptionsTestCopy.ensure_override("WINEDLLOVERRIDES=foo=n %command%", "dxgi");
    assert(r3.contains("WINEDLLOVERRIDES=foo=n;dxgi=n,b"));

    // 4. Existing overrides already contains injection (idempotent)
    string r4 = Utils.LaunchOptionsTestCopy.ensure_override(r3, "dxgi");
    assert_equal(r3, r4, "Idempotent addition");

    // 5. Append when no %command% and some existing content
    string r5 = Utils.LaunchOptionsTestCopy.ensure_override("PROTON_LOG=1", "dxgi");
    assert(r5.contains("PROTON_LOG=1 WINEDLLOVERRIDES=dxgi=n,b"));

    stdout.printf("All launch options tests passed.\n");
    return 0;
}
