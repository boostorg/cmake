# C++20 modules in Boost

Audience: users that want to consume Boost as C++20 modules.
Library authors that want to support C++20 modules in their libraries.

Guidelines to add C++20 module support for existing Boost libraries.


## Goals

* Code should be usable as a module ('import boost.xyz') and as headers.
  Existing code should not break.
* Feature-completeness. When consuming a library as a module, the entire
  library should be usable and work correctly.
* Focus on compile times. Consuming Boost as a module should be able to reduce
  compile times as much as possible.
* Isolation. Importing a library should pour only bring in the public identifiers.
* Maintainability. Modular bindings add clutter to the code. We aim at getting
  as less clutter as possible.
* Ease of use with CMake. Users need to be able to consume Boost with C++20 modules
  with CMake with the same easiness as they do without modules.
  No manual building of .ixx files should happen.

Non-goals

* Mixing including and importing Boost. Boost will still work regularly using
  headers. If you encounter this need, just use headers.
* Supporting toolchains with partial modular support.
  We're currently targeting the latest toolchain versions, and these still contain
  bugs.
* Supporting toolchains with modules but no import std. Import std is crucial
  for builds performance. We only support configurations that allow importing std.

## User interface

* To use Boost with modules, users need to build it with CMake, enabling support for it explicitly.
  This is done by specifying the `-DBOOST_USE_MODULES=1` CMake option when building Boost.
* Users can consume this built version of Boost either by using `add_subdirectory`,
  or by installing it and then using `find_package`.
* Each Boost library gets its own C++20 module. For example, Boost.Mp11 can be consumed with `import boost.mp11`. 
* When consuming a Boost distribution that uses modules, all public Boost headers are translated into their
  corresponding import, plus any documented macro definition.
  This is done using the preprocessor and defining the `BOOST_USE_MODULES`, which happens automatically when using CMake.
  We call this "compatibility headers".

## Modularizing header-only libraries

At this point in time, modularizing a library requires modularizing its dependencies.
This can probably be lifted, but has not been researched yet (and order gives better build-time performance results).

The recommended approach is the "ABI breaking" style. The idea is marking all the library public entities with
a `BOOST_XYZ_MODULE_EXPORT` macro that expands to `export` when building with modules, then include
all the library public headers in the module purview.

The rest of this section is a step-by-step guide on how to create the modular interface.

### Primary interface unit

Your library should contain a single module unit, and it should be a primary interface unit.
For an hypothetical Boost.Xyz, it should be named `boost_xyz.cppm` and placed under the
`modules/` folder.

This is what it should contain in a first iteration (we will add things later):

```cpp
// Global module fragment empty for now. We will add things later here
module;

// Begins the module purview
export module boost.xyz;

// Include any dependency that your library might have
import std;
import boost.core;

// We will use these macros when we get to compatibility headers
#define BOOST_XYZ_INTERFACE_UNIT
#define BOOST_IN_MODULE_PURVIEW

// Including headers with #include <> triggers warnings.
// If you're following this guide, they should be safe to ignore.
// This header disables them
#include <boost/config/disable_module_warnings.hpp>

// Now include your library. Add any other header that exports symbols
#include <boost/xyz.hpp>
```

We'll get more in-depth into why each statement is required later.
For now, have in mind that we're just including our entire library in the module purview.

### CMake code

Next, we need to add code to our `CMakeLists.txt` to that CMake
knows how to build our code. If you're following Boost best practice,
your code may look like:

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

Module units are translation units, so our when using modules,
our library will no longer be an INTERFACE library.
A small binary will get generated, containing the module initializer only.
(TODO: can we make this a footnote?) This is a function that initializes
global variables. It should be a no-op in most header-only libraries.
This is what the CMake code looks like after the change:

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

* We use a STATIC library (vs. not specifying a type and letting the user choose)
  because the binary is expected to contain almost no code.
  It should make initialization more efficient and simplify deployment.
* We use `__scope` because it's an error to use `PUBLIC` with an interface library.
* `modules/boost_xyz.cppm` will be installed alongside the produced binary.
  This happens automatically. This is required because BMIs must be regenerated
  by consumers.


### Marking exported entities

By default, entities defined in the module purview are not exported,
and won't be visible to importers. We need to mark public names with the `export` keyword.
To maintain compatibility, we advise to define a macro like this:

```cpp
// For example, in boost/xyz/detail/config.hpp
#ifdef BOOST_USE_MODULES
#  define BOOST_XYZ_MODULE_EXPORT export
#else
#  define BOOST_XYZ_MODULE_EXPORT
#endif
```

We should now stick `BOOST_XYZ_MODULE_EXPORT` in front of every entity exported by the library.

For templates, only the primary template should be exported.
Specializations should not. This means that if you're specializing
a template from the standard library, you don't need to export it.
It will be made available to importers by the compiler automatically.

### Disabling includes for dependencies

As you might know, anything included in the module purview
will get attached to our `boost.xyz` named module.
Only the names that our library exports should be attached there,
and not the names defined by our dependencies.
This is why compilers warn when using `#include <>` in the module
purview.

While you can manually add `#ifdef` blocks for every dependency,
this is usually error-prone. For the standard library, Boost.Config
offers "compatibility headers" that will become a no-op when
building with modules.

For instance, if a header contains this:

```cpp
// ...
#include <string>
#include <type_traits>
// ...
```

You can write:

```cpp
// ...
#include <boost/config/std/string.hpp>
#include <boost/config/std/type_traits.hpp>
// ...
```

This will expand to nothing in our purview, and is equivalent to
the former when `BOOST_USE_MODULES` is not defined.

Some standard library headers also export macros. Boost.Config
compatibility headers don't export any macros. If you need the macros,
you need to include the original header in the global module fragment:

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

Most already modularized Boost dependencies don't need any change.
You just need to add the relevant include:

```cpp
//
// header.hpp
//
#include <boost/core/bit.hpp> // doesn't need to be modified

// ...

//
// boost_xyz.cppm
//

// ...
export module boost.xyz;
import boost.core; // needs to be added because we use <boost/core/bit.hpp>

// ...
```

Like for the standard library, some Boost headers export mainly macros.
These need to be included in the global module fragment, too.
Unlike the standard library headers, these Boost headers will
emit a clear error if you use them in the purview, but don't include
them in the global module fragment. The `BOOST_IN_MODULE_PURVIEW`
macro is used to detect this.

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

Finally, if you have any other dependencies, you need to ifdef-out them yourself.
For example, say that your library includes `<Windows.h>` in a header.
You'd need to do the following:

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

You can also create a small wrapper header to avoid cluttering.

### Creating the compatibility headers

We should now have to go over all our public headers and apply appropriate preprocessor
magic to make them "compatibility headers". For the sake of simplicity, let's consider
headers that don't export macros first.

It is useful to think how do we want our headers to behave in different contexts
(always with `BOOST_USE_MODULES` defined):

1. In non-modular code: translate to `import boost.xyz` and nothing else.
   An example of this case is the `main.cpp` file of an executable.
   The global module fragment shares the same characteristics as non-modular code.
2. In the purview of our own module: leave the header as-is.
   We need all of our declarations intact so we can export them.
3. In the purview of other modules: translate to nothing.
   In modules, `import` needs to happen either in the global module fragment,
   or immediately after `export module boost.xyz`. This means that we need
   to disable the import in purviews, or we will generate errors to consumers.

With this scheme in mind, our public headers become:

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

The idea is that all Boost modules define `BOOST_IN_MODULE_PURVIEW` when their purview
begins, and we use this to disable the import. If you double-check, we're already
defining this macro in `boost_xyz.cppm`. `BOOST_XYZ_INTERFACE_UNIT` is only defined
in `boost_xyz.cppm`, and used to distinguish case 1 in the list above.

### Headers that export macros

If your header exports public macros, the compatibility headers needs to make these available.
In the simplest case, your macros don't depend on other macros, and this is trivial.
Consider a `BOOST_XYZ_VERSION` macro:

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

However, there is a big chance that your macros are expressed in terms
of other macros. If you need a third-party include that might also declare
C++ entities, your header is no longer suitable to be used in module purviews.

For example, consider this header:

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

This header is usable as-is in case 1 (non-modular code),
but can't be used in purviews (case 2 and 3) because any names defined by `<cfloat>`
would end up attached to your module.

Your best chance is to try to detect misuse and issue an error:

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

Headers like `<boost/config.hpp>`, `<boost/assert.hpp>` and `<boost/throw_exception.hpp>`
use this technique.

### Running the test suite

Running a big part of the library's test suite is critical to guarantee correctness.
Module support is still clunky under some compilers. It is also easy
to forget an export macro.

You should run all tests that target the library's public API.
This way, if you forgot an export, or commented a header in an unintended way, you will know.

While testing implementation details is possible, it is more trouble than
is worth, since functionality itself should be tested already in non-modular builds.

The only change that should be required to your tests is replacing
the standard library includes by the compatibility headers in Boost.Config.
You can use `BOOST_USE_MODULES` to ifdef-out tests targeting the private API.

Additionally, you need to enable `import std` in your tests by modifying your `test/CMakeLists.txt`:

```cmake
# ...
if(BOOST_USE_MODULES)
  set(CMAKE_CXX_MODULE_STD ON)
endif()

# add your tests here
```

This is required because `CMAKE_CXX_MODULE_STD` doesn't propagate to dependent targets.


## Design decisions

* Why ABI breaking vs other approaches?
  * Vs. export using: because it works. export using (TBC: include an example) looks attractive because
    it's non-intrusive. But once you try to build enough of your test suite with it, you realize it doesn't
    work. This is because of GMF discards: there are a number of corner cases (TBC: link to modules4)
    where entities are discarded and change the meaning of the program
    * The tuple protocol
    * Template specializations
  * Vs. non-ABI-breaking: because it's easier for the compiler to diagnose ODR violations.
    The cost is not being able to mix include/import.
    TBC: expand this argument.
* Why using a static library in CMake

  Some libraries don't get a module at all (e.g. Boost.Config because it exports only macros). More on this later.

Libraries that only export macros  don't get a module.


