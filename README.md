# Boost CMake support infrastructure

This repository hosts the `tools/cmake` Boost submodule, containing
experimental CMake support infrastructure for Boost.

Note that the supported way to build Boost remains
[with `b2`](https://www.boost.org/more/getting_started/index.html).

## Building Boost with CMake

The first thing you need to know is that the
[official Boost releases](https://www.boost.org/users/download/)
can't be built with CMake. Even though the Boost Github repository
contains a `CMakeLists.txt` file, it's removed from the release.

That's because the file and directory layout of Boost releases,
for historical reasons, has all the Boost header files copied
into a single `boost/` directory. These headers are then removed
from the individual library `include/` directories. The CMake
support infrastructure expects the headers to remain in their
respective `libs/<libname>/include` directories, and therefore
does not work on a release archive.

To build Boost with CMake, you will need either a Git checkout
of Boost
(`git checkout --recurse-submodules https://github.com/boostorg/boost`)
or the alternative archives
[available on Github](https://github.com/boostorg/boost/releases).

Once you have cloned, or downloaded and extracted, Boost, use the
usual procedure of

```
mkdir __build
cd __build
cmake ..
cmake --build .
```

to build it with CMake. To install it, add

```
cmake --build . --target install
```

Under Windows, you can control whether Debug or Release variants
are built by adding `--config Debug` or `--config Release` to the
`cmake --build` lines. The default is Release. You can build and
install both Debug and Release at the same time, by running the
respective `cmake --build` line twice, once per `--config`.

The following variables are supported and can be set either from
the command line as `cmake -DVARIABLE=VALUE ..`, or via `ccmake`
or `cmake-gui`:

* `BOOST_INCLUDE_LIBRARIES`

  A semicolon-separated list of libraries to include into the build (and
  installation.) Defaults
  to empty, which means "all libraries". Example: `filesystem;regex`.

* `BOOST_EXCLUDE_LIBRARIES`

  A semicolon-separated list of libraries to exclude from the build (and
  installation.) This is useful if a library causes an error in the CMake
  configure phase.

* `BOOST_ENABLE_MPI`

  Set to ON if Boost libraries depending on MPI should be built.

* `BOOST_ENABLE_PYTHON`

  Set to ON if Boost libraries depending on Python should be built.

* `CMAKE_INSTALL_PREFIX`

  A standard CMake variable that determines where the headers and libraries
  should be installed. The default is `C:/Boost` under Windows, `/usr/local`
  otherwise.

* `CMAKE_INSTALL_INCLUDEDIR`

  Directory in which to install the header files. Can be relative to
  `CMAKE_INSTALL_PREFIX`. Default `include`.

* `CMAKE_INSTALL_BINDIR`

  Directory in which to install the binary artifacts (executables and Windows
  DLLs.) Can be relative to `CMAKE_INSTALL_PREFIX`. Default `bin`.

* `CMAKE_INSTALL_LIBDIR`

  Directory in which to install the compiled libraries. Can be relative to
  `CMAKE_INSTALL_PREFIX`. Default `lib`.

* `BOOST_INSTALL_CMAKEDIR`

  Directory in which to install the CMake configuration files. Default `lib/cmake`.

* `BOOST_INSTALL_LAYOUT`

  Boost installation layout. Can be one of `system`, `tagged`, or `versioned`.
  The default is `versioned` under Windows, and `system` otherwise.

  `versioned` produces library names of the form
  `libboost_timer-vc143-mt-gd-x64-1_82.lib`, containing the toolset (compiler)
  name and version, encoded build settings, and the Boost version. (The
  extension is `.lib` under Windows, `.a` or `.so` under Linux, and `.a` or
  `.dylib` under macOS.)

  `tagged` produces library names of the form `libboost_timer-mt-gd-x64.lib`;
  only the build settings are encoded in the name, the toolset and the Boost
  version are not.

  `system` produces library names of the form `libboost_timer.lib` (or
  `libboost_timer.a`, `libboost_timer.so`, `libboost_timer.dylib`.)

* `BOOST_INSTALL_INCLUDE_SUBDIR`

  When `BOOST_INSTALL_LAYOUT` is `versioned`, headers are installed in a
  subdirectory of `CMAKE_INSTALL_INCLUDEDIR` (to enable several Boost releases
  being installed at the same time.) The default for release e.g. 1.81 is
  `/boost-1_81`.)

* `BOOST_RUNTIME_LINK`

  Whether to use the static or the shared C++ runtime libraries under Microsoft
  Visual C++ and compatible compilers. (The available values are `shared` and
  `static` and the default is `shared`.)

* `BUILD_TESTING`

  A standard CMake variable; when ON, tests are configured and built. Defaults
  to OFF.

* `BUILD_SHARED_LIBS`

  A standard CMake variable that determines whether to build shared or static
  libraries. Defaults to OFF.

* `BOOST_STAGEDIR`

  The directory in which to place the build outputs. Defaults to the `stage`
  subdirectory of the current CMake binary directory.

  The standard CMake variables `CMAKE_RUNTIME_OUTPUT_DIRECTORY`,
  `CMAKE_LIBRARY_OUTPUT_DIRECTORY`, and `CMAKE_ARCHIVE_OUTPUT_DIRECTORY` are
  set by default to `${BOOST_STAGEDIR}/bin`, `${BOOST_STAGEDIR}/lib` and
  `${BOOST_STAGEDIR}/lib`, respectively.
