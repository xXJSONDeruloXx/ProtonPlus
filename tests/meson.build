test_sources = files(
  'test_launch_options.vala'
)

test_exe = executable(
  'pp-tests',
  test_sources,
  'src/utils/launch-options.vala',
  dependencies: deps,
  include_directories: globals_inc,
  vala_args: ['--pkg', 'glib-2.0']
)

test('launch_options', test_exe)
