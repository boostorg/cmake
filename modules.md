# C++20 modules in Boost

This document is for users who want to consume Boost as C++20 modules,
and for library authors who want to add module support to their libraries.

## Goals

* **Backwards-compatibility**. Code should be usable as a module (`import boost.xyz`) and as headers.
  Existing code must not break.
* **Feature-completeness**. When consuming a library as a module, the entire
  library should be usable and work correctly.
* **Compile time improvements**. Consuming Boost as a module should reduce compile times
  as much as possible.
* **Isolation**. Importing a library should only bring in its public identifiers.
* **Maintainability**. Modular bindings add clutter to the code. We aim at
  keeping it to a minimum.
* Ease of use with **CMake**. Users should be able to consume Boost with
  C++20 modules as easily as they do without them today. No manual building
  of `.cppm` files should be necessary.

Non-goals:

* Mixing including and importing Boost. If you need this, just use headers.
* Supporting toolchains with partial module support.
  The latest toolchain versions still contain bugs that need workarounds.
  We aim to remove these workarounds once the tools improve.
* Supporting toolchains with modules but no `import std`. This feature
  is crucial for build performance. We only support configurations
  that allow importing `std`.

## User interface

Users need to consume Boost via CMake, enabling module support by
specifying `-DBOOST_USE_MODULES=1`. Boost can be consumed either
directly using `add_subdirectory`, or loaded with `find_package` after
building and installing it.

Each Boost library gets its own C++20 module. For example, Boost.Mp11
can be consumed with `import boost.mp11`. Libraries that export mainly
macros, like Boost.Config, remain as headers.

When consuming a Boost distribution built with modules, all public
Boost headers are translated into their corresponding `import`, plus
any documented macro definitions. This is done using preprocessor logic
and the `BOOST_USE_MODULES` macro.
We call these "compatibility headers".

## Modularizing header-only libraries

At this point, modularizing a library requires modularizing its
dependencies first. This restriction can probably be lifted, but
hasn't been researched yet (and dependency order yields better
build-time performance).

The recommended approach is the [ABI breaking style](https://clang.llvm.org/docs/StandardCPlusPlusModules.html#abi-breaking-style): mark all public
entities with a `BOOST_XYZ_MODULE_EXPORT` macro that expands to
`export` when building with modules, then include all public headers
in the module purview (see [Why ABI breaking?](#why-abi-breaking)).

The rest of this section is a step-by-step guide on how to achieve this.

### Primary interface unit

Your library should contain a single module unit: the primary interface
unit. For a hypothetical Boost.Xyz, it should be named `boost_xyz.cppm`
and placed under the `modules/` directory.

A first iteration looks like this (we will add things later):

```cpp
// Global module fragment. Empty for now.
module;

// Begins the module purview
export module boost.xyz;

// Include here any dependency that your library has
import std;
import boost.core;

// We will use these macros when we get to compatibility headers
#define BOOST_XYZ_INTERFACE_UNIT
#define BOOST_IN_MODULE_PURVIEW

// Including headers with #include <> in the purview triggers warnings.
// If you're following this guide, they should be safe to ignore.
// This header disables them
#include <boost/config/disable_module_warnings.hpp>

// Include the entire library
#include <boost/xyz.hpp>
```

We're including our entire library in the module purview. The reasons
for each other line will become clear as you read on.

### CMake code

Next, we need CMake to know how to build our module. Starting from
a typical Boost `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.5...3.31)

project(boost_xyz VERSION "${BOOST_SUPERPROJECT_VERSION}" LANGUAGES CXX)

add_library(boost_xyz INTERFACE)
add_library(Boost::xyz ALIAS boost_xyz)

target_include_directories(boost_xyz INTERFACE include)

target_link_libraries(boost_xyz
  INTERFACE
    Boost::core
)
```

Module units are translation units, so when using modules, the library
is no longer an `INTERFACE` library. A small binary is generated containing only
the module initializer (see [Why a static library in CMake?](#why-a-static-library-in-cmake) for more info).
The updated CMake code:

```cmake
if (BOOST_USE_MODULES)
  add_library(boost_xyz STATIC)
  target_sources(boost_xyz PUBLIC FILE_SET CXX_MODULES BASE_DIRS modules FILES modules/boost_xyz.cppm)
  set(__scope PUBLIC)

  target_compile_features(boost_xyz PUBLIC cxx_std_23) # import std requires C++23
  set_target_properties(boost_xyz PROPERTIES CXX_MODULE_STD 1) # Enable import std
  target_compile_definitions(boost_xyz PUBLIC BOOST_USE_MODULES) # Preprocessor macro

else()
  add_library(boost_xyz INTERFACE)
  set(__scope INTERFACE)
endif()

add_library(Boost::xyz ALIAS boost_xyz)
target_include_directories(boost_xyz ${__scope} include)
target_link_libraries(boost_xyz
  ${__scope}
    Boost::core
)
```

Some notes:

* We use `STATIC` (rather than letting the user choose) because the
  binary is expected to contain almost no code. This simplifies
  deployment and makes initialization more efficient.
* We use `__scope` because using `PUBLIC` properties with an interface library is an error.
* `modules/boost_xyz.cppm` is installed alongside the produced binary
  automatically by the Boost.CMake infrastructure. This is required because binary module interfaces (BMIs) must be regenerated by
  consumers.


### Marking exported entities

By default, entities defined in the module purview are not exported and
won't be visible to importers. We need to mark public names with the
`export` keyword. To maintain compatibility, define a macro:

```cpp
// For example, in boost/xyz/detail/config.hpp
#ifdef BOOST_USE_MODULES
#  define BOOST_XYZ_MODULE_EXPORT export
#else
#  define BOOST_XYZ_MODULE_EXPORT
#endif
```

Place `BOOST_XYZ_MODULE_EXPORT` in front of every entity exported by
the library.

When dealing with templates, only the primary template should be exported, and not its specializations.
If you specialize a template from the standard library, don't export it.
The compiler makes it available to importers automatically.

### Disabling includes for dependencies

Anything included in the module purview gets attached to our `boost.xyz`
named module. Only names that belong to our library  should be attached.
Names declared by our dependencies shouldn't. This is why compilers warn when using
`#include <>` in the module purview.

While you can manually add `#ifdef` blocks for every dependency, this is
error-prone. For the standard library, Boost.Config offers compatibility
headers that become no-ops when building with modules.

For instance, if a header contains:

```cpp
#include <string>
#include <type_traits>
```

You can write:

```cpp
#include <boost/config/std/string.hpp>
#include <boost/config/std/type_traits.hpp>
```

This expands to nothing in the module purview, and is equivalent to the
original when `BOOST_USE_MODULES` is not defined.

Some standard library headers also export macros. Boost.Config's
compatibility headers don't export any. If you need the macros, include
the original header in the global module fragment:

```cpp
//
// header.hpp
//
#include <boost/config/std/cmath.hpp>

// HUGE_VAL is a macro defined in <cmath>
inline double f() { return HUGE_VAL; }

//
// boost_xyz.cppm
//
module;

#include <cmath> // make HUGE_VAL available

export module boost.xyz;
// ...

```

Most already-modularized Boost dependencies don't need any changes.
Just add the relevant import:

```cpp
//
// header.hpp
//
#include <boost/core/bit.hpp> // no modifications needed

// ...

//
// boost_xyz.cppm
//

// ...
export module boost.xyz;
import boost.core; // needed because we use <boost/core/bit.hpp>

// ...
```

Like the standard library, some Boost headers export mainly macros.
These need to be included in the global module fragment. Unlike
standard library headers, these Boost headers emit a clear error if
used in the purview without being included in the global module fragment
first. The `BOOST_IN_MODULE_PURVIEW` macro is used to detect this.

For example:

```cpp
//
// header.hpp
//
// None of these need modification here, but need to be included in the GMF
#include <boost/config.hpp>
#include <boost/assert.hpp>
#include <boost/throw_exception.hpp>

// ...

//
// boost_xyz.cppm
//
module;

#include <boost/config.hpp>
#include <boost/assert.hpp>
#include <boost/throw_exception.hpp>

export module boost.xyz;
// ...
```

Finally, for other dependencies (e.g. platform headers), you need to
ifdef them out yourself. For example, if your library includes
`<Windows.h>`:

```cpp
//
// header.hpp
//
#ifndef BOOST_USE_MODULES
#include <Windows.h>
#endif

// ...

//
// boost_xyz.cppm
//
module;

#include <Windows.h>

export module boost.xyz;
// ...
```

You can also create a small wrapper header to avoid cluttering your
code.

### Creating the compatibility headers

We now need to turn all public headers into compatibility headers.
Headers that don't export macros are simpler, so we'll cover those
first.

It is useful to consider how headers should behave in different
contexts (always with `BOOST_USE_MODULES` defined):

1. **In non-modular code**: translate to `import boost.xyz` and nothing
   else. This would happen in the `main.cpp` of an executable, for instance. The global
   module fragment has the same characteristics as non-modular code.
2. **In the purview of our own module**: leave the header as-is.
   We need all declarations intact to export them.
3. **In the purview of other modules**: translate to nothing. In
   modules, `import` must happen either in the global module fragment
   or immediately after `export module`. Using it elsewhere generates
   errors. This means that we must disable the `import` in purviews.

With this scheme, our public headers become:

```cpp
// include guards omitted

#if defined(BOOST_USE_MODULES) && !defined(BOOST_XYZ_INTERFACE_UNIT)

#ifndef BOOST_IN_MODULE_PURVIEW
import boost.core;
#endif

#else

// declarations here

#endif
```

All Boost modules define `BOOST_IN_MODULE_PURVIEW` when their purview
begins, which disables the import. If you double-check, we already
define this macro in `boost_xyz.cppm`. `BOOST_XYZ_INTERFACE_UNIT` is
only defined in `boost_xyz.cppm`, and distinguishes case 2 from the
others.

### Headers that export macros

If a header exports public macros, the compatibility header needs to
make them available. In the simplest case, the macros don't depend on
other macros. Consider a `BOOST_XYZ_VERSION` macro:

```cpp
//
// boost/xyz/version.hpp
//
// include guards omitted

// BOOST_XYZ_VERSION doesn't require including any other header.
// This header doesn't need any changes.
#define BOOST_XYZ_VERSION 1_91_0

//
// boost/xyz/header.hpp
//
// include guards omitted

#if defined(BOOST_USE_MODULES) && !defined(BOOST_XYZ_INTERFACE_UNIT)

// This header makes available BOOST_XYZ_VERSION, too
#include <boost/xyz/version.hpp> // safe to include in purviews
#ifndef BOOST_IN_MODULE_PURVIEW
import boost.core;
#endif

#else

// declarations here

#endif

```

However, there is a good chance that your macros depend on other macros.
If you need a third-party include that also declares C++ entities, your
header is no longer suitable for use in module purviews.

For example:

```cpp
//
// boost/xyz/config.hpp
//

#ifndef BOOST_XYZ_CONFIG_HPP
#define BOOST_XYZ_CONFIG_HPP

#include <cfloat> // LDBL_MANT_DIG and LDBL_MAX_EXP

// BOOST_XYZ_SUPPORTS_LONG_DOUBLE indicates a supported feature, and is a documented macro
#if LDBL_MANT_DIG == 64 && LDBL_MAX_EXP == 16384
#  define BOOST_XYZ_SUPPORTS_LONG_DOUBLE
#endif

#endif
```

This header works in non-modular code, but can't be used in purviews
because any names defined by `<cfloat>` would get attached to your
module.

The best approach is to detect misuse and issue an error:

```cpp
//
// boost/xyz/config.hpp
//

// Detect misuse
#if defined(BOOST_IN_MODULE_PURVIEW) && !defined(BOOST_XYZ_CONFIG_HPP)
#  error "Please #include <boost/xyz/config.hpp> in your module global fragment"
#endif

#ifndef BOOST_XYZ_CONFIG_HPP
#define BOOST_XYZ_CONFIG_HPP

#include <cfloat> // Stays as is - don't replace by the compatibility header!

#if LDBL_MANT_DIG == 64 && LDBL_MAX_EXP == 16384
#  define BOOST_XYZ_SUPPORTS_LONG_DOUBLE
#endif

#endif
```

Headers like `<boost/config.hpp>`, `<boost/assert.hpp>` and
`<boost/throw_exception.hpp>` use this technique.

### Making member functions inline

Member functions in non-module code are implicitly inline.
This is no longer true in module code. If you want functions to remain
inline, you need to mark them explicitly:

```cpp
// 
// File: header.hpp
//

class some_class {
public:
  inline some_class() {}
  inline int get() { return 42; }
};

```

### Running the test suite

Running a large part of the library's test suite is critical for
correctness. Module support is still clunky under some compilers, and
it is easy to forget an export macro.

Run all tests that target the library's public API. If you forgot an
export or changed a header in an unintended way, you will know.

Testing implementation details is possible but not worth the effort,
since functionality is already tested in non-modular builds.

The only change required to your tests is replacing standard library
includes with the Boost.Config compatibility headers. You can use
`BOOST_USE_MODULES` to ifdef-out tests targeting the private API.

Additionally, enable `import std` in your tests by modifying
`test/CMakeLists.txt`:

```cmake
# ...
if(BOOST_USE_MODULES)
  set(CMAKE_CXX_MODULE_STD ON)
endif()

# add your tests here
```

This is required because `CMAKE_CXX_MODULE_STD` doesn't propagate to
dependent targets.

## Compiled libraries

All the steps described above apply to compiled libraries, plus some
additional ones described here.

Most `.cpp` files need to use or implement private functionality not
exported by the module. For this to work, they need to be part of the
module. Using the preprocessor doesn't help here (see
[Why can't the preprocessor make `.cpp` files into module units?](#why-cant-the-preprocessor-make-cpp-files-into-module-units)).

We recommend creating a separate file with a different extension for
each `.cpp` file. For example, given `utils.cpp`, create `utils.cc`:


```cpp
//
// File: utils.cc
//

module;

// Place here any includes providing macros required by the cpp file
#include <cassert>
#include <cerrno>

// This is a module implementation unit
module boost.xyz;

// Import modular dependencies
import std;
import boost.core;

// We're in a purview. Compatibility headers shouldn't generate imports
#define BOOST_IN_MODULE_PURVIEW

// Include the non-modular code
#include "utils.cpp"
```

For this to work, your `.cpp` files must not include any third-party
names that might get attached to the module. Follow the same procedure
as with headers to achieve this.

Note that by the rules of C++20 modules, your `.cc` files automatically
import all names defined in the primary module interface.

Because module implementation units can't be imported, they should be
added to CMake as regular sources, rather than to the `CXX_MODULES FILE_SET`:

```cmake
# Add the regular translation units
if (BOOST_USE_MODULES)
  set(SOURCE_SUFFIX "cc")
else()
  set(SOURCE_SUFFIX "cpp")
endif()

add_library(boost_xyz
  src/utils.${SOURCE_SUFFIX}
)

# Now add the module primary interface unit
if (BOOST_USE_MODULES)
  target_sources(boost_xyz PUBLIC FILE_SET CXX_MODULES BASE_DIRS modules FILES modules/boost_xyz.cppm)
  # ...
endif()
```

### Guarding detail headers

If your `.cpp` files include any `detail/` headers directly, guard
these to avoid double definitions. The definitions are already present
in the primary module interface and shouldn't appear again in the
module implementation units.

Use an approach similar to public headers:

```cpp
//
// File boost/xyz/detail/utils.hpp
//

// Include guards omitted.
// Make the header a no-op outside the primary module interface
#if !defined(BOOST_USE_MODULES) || defined(BOOST_XYZ_INTERFACE_UNIT)

// Header contents

#endif
```

### Source-only headers

Functionality shared by several `.cpp` files is usually placed into
header files that live within `src/`. These headers are "source-only":
they don't get installed like the ones under `include/`.

To avoid redefinition errors (see [Why can't source-only headers be used directly?](#why-cant-source-only-headers-be-used-directly)),
wrap these headers into module implementation partition units (partitions
not marked with `export`). For example, given `base64.hpp`, create
`base64.cppm`:

```cpp
//
// File: base64.cppm
//
module;

// Place any macro-related includes that base64.hpp may need
#include <cassert>

// This is a partition
module boost.xyz:base64;

// We need access to all public and private functionality defined in our
// headers. Partitions don't import the primary interface unit by default.
// gcc-15 currently has a bug with this - see below for a workaround
import boost.xyz;

// Similar to BOOST_XYZ_INTERFACE_UNIT, used to guard the file
#define BOOST_XYZ_BASE64_PARTITION_UNIT

#include "base64.hpp"
```

Guard the header file so it expands to nothing when included in
`.cpp` files:

```cpp
//
// File: base64.hpp
//

// Include guards omitted.
// Make the header a no-op outside base64.cppm
#if !defined(BOOST_USE_MODULES) || defined(BOOST_XYZ_BASE64_PARTITION_UNIT)

// Header contents

#endif
```

Module units can then import the partitions. If `utils.cc` includes
`base64.hpp`:

```cpp
//
// File: utils.cc
//

module;

// Global module fragment

module boost.xyz;

import :base64; // Import the partition
import std;
import boost.core;

// Purview as before
#define BOOST_IN_MODULE_PURVIEW
#include "utils.cpp"
```

Partition units need to be compiled. Since they can be imported, they
must be in a CMake `CXX_MODULES FILE_SET`. Because they are internal
and shouldn't be installed, they should be `PRIVATE`:

```cmake
target_sources(boost_xyz
  PUBLIC FILE_SET CXX_MODULES BASE_DIRS modules FILES
    modules/boost_xyz.cppm
  PRIVATE FILE_SET source_headers TYPE CXX_MODULES BASE_DIRS src FILES
    src/base64.cppm
)
```

### Workarounds for gcc-15

GCC 15 has [a bug](https://gcc.gnu.org/bugzilla/show_bug.cgi?id=124309)
that causes errors when explicitly importing the primary module
interface from partitions.

The workaround is to place all exported functionality in a module
interface partition, making the primary interface unit a thin wrapper:

```cpp
//
// File: boost_xyz_interface.cppm
//

// Contains everything that boost_xyz.cppm used to have,
// except for the module identifier
module;

// Global module fragment
#include <cassert>

export module boost.xyz:interface; // partition

#include <boost/xyz.hpp>

//
// File: boost_xyz.cppm
//

// Re-export the partition
export module boost.xyz;
export import :interface;

//
// File: base64.cppm
//
module;

#include <cassert>

module boost.xyz:base64;

// We've replaced 'import boost.xyz' with this
import :interface;

// Rest of the file unmodified
#define BOOST_XYZ_BASE64_PARTITION_UNIT
#include "base64.hpp"
```

The new `boost_xyz_interface.cppm` should be placed in the `PUBLIC FILE_SET`
in CMake.

## Design decisions

### Why ABI breaking?

There are three main approaches to modularizing a library:

* [`export using`](https://clang.llvm.org/docs/StandardCPlusPlusModules.html#export-using-style):
  wrapping declarations in `export using`
  statements looks attractive because it's non-intrusive. However,
  it doesn't work in practice. Global module fragment discards cause
  corner cases where entities are silently dropped, changing the meaning
  of the program. For example, if you try to export `asio::awaitable` with this
  approach, `std::coroutine_traits` specializations get discarded, rendering
  the type unusable.
* [Non-ABI-breaking](https://clang.llvm.org/docs/StandardCPlusPlusModules.html#export-extern-c-style): preserves the ability to mix `#include` and
  `import`. The ABI-breaking approach makes it easier for the compiler
  to diagnose ODR violations, at the cost of not being able to mix
  including and importing.
* [ABI breaking](https://clang.llvm.org/docs/StandardCPlusPlusModules.html#abi-breaking-style) (our choice): mark entities with an export macro.
  Better ODR diagnostics and, in theory, less work for the compiler.

### Why a static library in CMake?

Module units are translation units that produce a (usually tiny)
binary containing the module initializer. This function initializes any
global variables declared in the module.

Using `STATIC` simplifies deployment and avoids the overhead of shared library machinery for
what is typically a no-op function.

Libraries may contain symbols if you forgot to add `inline` specifiers
to your class members. It's advised to check the generated binaries
to fix these cases.

### Why can't the preprocessor make `.cpp` files into module units?

The most straightforward idea would be:

```cpp

// This DOES NOT WORK, because module; and module boost.xyz; need to be the first
// declarations in the translation unit

#ifdef BOOST_USE_MODULES
module;
#endif

// Global module fragment includes
#include <cassert>
#include <cerrno>

#ifdef BOOST_USE_MODULES
module boost.xyz;
#endif

// Content of the .cpp file as is today
#include <boost/xyz/header.hpp>

int boost::xyz::f() { /* ... */ }

```

This doesn't work because module declarations must be the first
declarations in the translation unit. This limitation likely exists
to make dependency scanning more efficient.

### Why can't source-only headers be used directly?

If we include a source-only header in several translation units, we
get redefinition errors. We can't include them in the global module
fragment either, because they need access to the module's private
content. Wrapping them in partition units solves both problems.
