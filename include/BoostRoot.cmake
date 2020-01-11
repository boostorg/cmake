# Copyright 2019 Peter Dimov
# Distributed under the Boost Software License, Version 1.0.
# See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

include(BoostMessage)
include(GNUInstallDirs)

if(NOT BOOST_ENABLE_CMAKE)
  message(FATAL_ERROR
    "CMake support in Boost is experimental and part of an ongoing "
    "development effort. It's not ready for use yet. Please use b2 "
    "(Boost.Build) to build and install Boost.")
endif()

# --with-<library>
set(BOOST_INCLUDE_LIBRARIES "" CACHE STRING "List of libraries to build (default: all but excluded and incompatible)")

# --without-<library>
set(BOOST_EXCLUDE_LIBRARIES "" CACHE STRING "List of libraries to exclude from build")

set(BOOST_INCOMPATIBLE_LIBRARIES beast;callable_traits;compute;gil;hana;hof;safe_numerics;serialization;yap CACHE STRING "List of libraries with incompatible CMakeLists.txt files")

# --layout, --libdir, --cmakedir, --includedir in BoostInstall

# runtime-link=static|shared

set(BOOST_RUNTIME_LINK shared CACHE STRING "Runtime library selection for the MS ABI (shared or static)")
set_property(CACHE BOOST_RUNTIME_LINK PROPERTY STRINGS shared static)

if(NOT CMAKE_MSVC_RUNTIME_LIBRARY)

  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

  if(NOT BOOST_RUNTIME_LINK STREQUAL "static")
    string(APPEND CMAKE_MSVC_RUNTIME_LIBRARY "DLL")
  endif()

endif()

#

if(CMAKE_SOURCE_DIR STREQUAL Boost_SOURCE_DIR)

  include(CTest)

  if(WIN32 AND CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)

    set(CMAKE_INSTALL_PREFIX "C:/Boost" CACHE PATH "Installation path prefix, prepended to installation directories" FORCE)

  endif()

  # link=static|shared
  option(BUILD_SHARED_LIBS "Build shared libraries")

  # --stagedir
  set(BOOST_STAGEDIR "${CMAKE_CURRENT_BINARY_DIR}/stage" CACHE STRING "Build output directory")

  if(NOT CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${BOOST_STAGEDIR}/bin")
  endif()

  if(NOT CMAKE_LIBRARY_OUTPUT_DIRECTORY)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${BOOST_STAGEDIR}/lib")
  endif()

  if(NOT CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${BOOST_STAGEDIR}/lib")
  endif()

endif()

file(GLOB __boost_libraries RELATIVE "${BOOST_SUPERPROJECT_SOURCE_DIR}/libs" "${BOOST_SUPERPROJECT_SOURCE_DIR}/libs/*/CMakeLists.txt" "${BOOST_SUPERPROJECT_SOURCE_DIR}/libs/numeric/*/CMakeLists.txt")

# Check for mistakes in BOOST_INCLUDE_LIBRARIES
foreach(__boost_included_lib IN LISTS BOOST_INCLUDE_LIBRARIES)

  if(NOT "${__boost_included_lib}/CMakeLists.txt" IN_LIST __boost_libraries)

    message(WARNING "Library '${__boost_included_lib}' given in BOOST_INCLUDE_LIBRARIES has not been found.")

  endif()

endforeach()

foreach(__boost_lib_cml IN LISTS __boost_libraries)

  get_filename_component(__boost_lib "${__boost_lib_cml}" DIRECTORY)

  if(__boost_lib IN_LIST BOOST_INCOMPATIBLE_LIBRARIES)

    boost_message(DEBUG "Skipping incompatible Boost library ${__boost_lib}")

  elseif(__boost_lib IN_LIST BOOST_EXCLUDE_LIBRARIES)

    boost_message(DEBUG "Skipping excluded Boost library ${__boost_lib}")

  else()

    if(BOOST_INCLUDE_LIBRARIES AND NOT __boost_lib IN_LIST BOOST_INCLUDE_LIBRARIES)

      boost_message(DEBUG "Adding Boost library ${__boost_lib} (w/ EXCLUDE_FROM_ALL)")

      set(BUILD_TESTING OFF) # hide cache variable
      add_subdirectory("${BOOST_SUPERPROJECT_SOURCE_DIR}/libs/${__boost_lib}" "${CMAKE_CURRENT_BINARY_DIR}/boostorg/${__boost_lib}" EXCLUDE_FROM_ALL)
      unset(BUILD_TESTING)

    else()

      boost_message(VERBOSE "Adding Boost library ${__boost_lib}")
      add_subdirectory("${BOOST_SUPERPROJECT_SOURCE_DIR}/libs/${__boost_lib}" "${CMAKE_CURRENT_BINARY_DIR}/boostorg/${__boost_lib}")

    endif()

  endif()

endforeach()
