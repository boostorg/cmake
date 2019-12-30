# Copyright 2019 Peter Dimov
# Distributed under the Boost Software License, Version 1.0.
# See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

if(NOT CMAKE_VERSION VERSION_LESS 3.10)
  include_guard()
endif()

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Variables

if(WIN32)
  set(__boost_default_layout "versioned")
else()
  set(__boost_default_layout "system")
endif()

set(BOOST_INSTALL_LAYOUT ${__boost_default_layout} CACHE STRING "Installation layout (versioned, tagged, or system)")
set_property(CACHE BOOST_INSTALL_LAYOUT PROPERTY STRINGS versioned tagged system)

set(BOOST_INSTALL_LIBDIR "${CMAKE_INSTALL_LIBDIR}" CACHE STRING "Installation directory for library files")
set(BOOST_INSTALL_CMAKEDIR "${BOOST_INSTALL_LIBDIR}/cmake" CACHE STRING "Installation directory for CMake configuration files")
set(BOOST_INSTALL_INCLUDEDIR "${CMAKE_INSTALL_INCLUDEDIR}" CACHE STRING "Installation directory for header files")

if(BOOST_INSTALL_LAYOUT STREQUAL "versioned")
  set(BOOST_INSTALL_INCLUDEDIR "$CACHE{BOOST_INSTALL_INCLUDEDIR}/boost-${PROJECT_VERSION_MAJOR}_${PROJECT_VERSION_MINOR}")
endif()

#

function(__boost_install_set_output_name LIB TYPE)

  set(name ${LIB})

  # prefix
  if(WIN32 AND TYPE STREQUAL "STATIC_LIBRARY")
    set_target_properties(${LIB} PROPERTIES PREFIX "lib")
  endif()

  # toolset
  if(BOOST_INSTALL_LAYOUT STREQUAL versioned)

    string(TOLOWER ${CMAKE_CXX_COMPILER_ID} toolset)

    if(toolset STREQUAL "msvc")

      set(toolset "vc")

      if(CMAKE_CXX_COMPILER_VERSION MATCHES "^([0-9]+)[.]([0-9]+)")

        if(CMAKE_MATCH_1 GREATER 18)
          math(EXPR major ${CMAKE_MATCH_1}-5)
        else()
          math(EXPR major ${CMAKE_MATCH_1}-6)
        endif()

        math(EXPR minor ${CMAKE_MATCH_2}/10)

        string(APPEND toolset ${major}${minor})

      endif()

    else()

      if(toolset STREQUAL "gnu")

        set(toolset "gcc")

      elseif(toolset STREQUAL "clang")

        if(MSVC)
          set(toolset "clangw")
        endif()

      endif()

      if(CMAKE_CXX_COMPILER_VERSION MATCHES "^([0-9]+)[.]")
        string(APPEND toolset ${CMAKE_MATCH_1})
      endif()

    endif()

    string(APPEND name "-${toolset}")

  endif()

  if(BOOST_INSTALL_LAYOUT STREQUAL versioned OR BOOST_INSTALL_LAYOUT STREQUAL tagged)

    # threading
    string(APPEND name "-mt")

    # ABI tag

    if(NOT CMAKE_VERSION VERSION_LESS 3.15)

      string(APPEND tag "$<$<STREQUAL:$<TARGET_GENEX_EVAL:${LIB},$<TARGET_PROPERTY:${LIB},MSVC_RUNTIME_LIBRARY>>,MultiThreaded>:s>")
      string(APPEND tag "$<$<STREQUAL:$<TARGET_GENEX_EVAL:${LIB},$<TARGET_PROPERTY:${LIB},MSVC_RUNTIME_LIBRARY>>,MultiThreadedDebug>:s>")

      string(APPEND tag "$<$<STREQUAL:$<TARGET_GENEX_EVAL:${LIB},$<TARGET_PROPERTY:${LIB},MSVC_RUNTIME_LIBRARY>>,MultiThreadedDebug>:g>")
      string(APPEND tag "$<$<STREQUAL:$<TARGET_GENEX_EVAL:${LIB},$<TARGET_PROPERTY:${LIB},MSVC_RUNTIME_LIBRARY>>,MultiThreadedDebugDLL>:g>")

    endif()

    string(APPEND tag "$<$<CONFIG:Debug>:d>")

    string(APPEND name "$<$<BOOL:${tag}>:->${tag}")

    # Arch and model
    math(EXPR bits ${CMAKE_SIZEOF_VOID_P}*8)
    string(APPEND name "-x${bits}") # x86 only for now

  endif()

  if(BOOST_INSTALL_LAYOUT STREQUAL versioned)
    string(APPEND name "-${PROJECT_VERSION_MAJOR}_${PROJECT_VERSION_MINOR}")
  endif()

  set_target_properties(${LIB} PROPERTIES OUTPUT_NAME ${name})

endfunction()

function(__boost_install_update_include_directory lib prop)

  get_target_property(value ${lib} ${prop})

  if(value STREQUAL "${CMAKE_CURRENT_SOURCE_DIR}/include")

    set_target_properties(${lib} PROPERTIES ${prop} "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>;$<INSTALL_INTERFACE:${BOOST_INSTALL_INCLUDEDIR}>")

  endif()

endfunction()

# Installs a single target

function(boost_install_target LIB)

  if(NOT PROJECT_VERSION)

    message(AUTHOR_WARNING "boost_install_target(${LIB}): PROJECT_VERSION is not set, but is required for installation.")
    set(PROJECT_VERSION 0.0.0)

  endif()

  if(NOT BOOST_INSTALL_LIBDIR)
    set(BOOST_INSTALL_LIBDIR ${CMAKE_INSTALL_LIBDIR})
  endif()

  if(NOT BOOST_INSTALL_CMAKEDIR)
    set(BOOST_INSTALL_CMAKEDIR "${BOOST_INSTALL_LIBDIR}/cmake")
  endif()

  get_target_property(TYPE ${LIB} TYPE)

  __boost_install_update_include_directory(${LIB} INTERFACE_INCLUDE_DIRECTORIES)

  if(TYPE STREQUAL "STATIC_LIBRARY" OR TYPE STREQUAL "SHARED_LIBRARY")

    __boost_install_update_include_directory(${LIB} INCLUDE_DIRECTORIES)

    get_target_property(OUTPUT_NAME ${LIB} OUTPUT_NAME)

    if(NOT OUTPUT_NAME)
      __boost_install_set_output_name(${LIB} ${TYPE})
    endif()

  endif()

  if(TYPE STREQUAL "SHARED_LIBRARY" OR TYPE STREQUAL "EXECUTABLE")

    get_target_property(VERSION ${LIB} VERSION)

    if(NOT VERSION)
      set_target_properties(${LIB} PROPERTIES VERSION ${PROJECT_VERSION})
    endif()

  endif()

  if(LIB MATCHES "^boost_(.*)$")
    set_target_properties(${LIB} PROPERTIES EXPORT_NAME ${CMAKE_MATCH_1})
  endif()

  set(CONFIG_INSTALL_DIR "${BOOST_INSTALL_CMAKEDIR}/${LIB}-${PROJECT_VERSION}")

  install(TARGETS ${LIB} EXPORT ${LIB}-targets DESTINATION ${BOOST_INSTALL_LIBDIR})

  if(WIN32 AND TYPE STREQUAL "SHARED_LIBRARY")

    install(FILES $<TARGET_PDB_FILE:${LIB}> DESTINATION ${BOOST_INSTALL_LIBDIR} OPTIONAL)

  endif()

  install(EXPORT ${LIB}-targets DESTINATION "${CONFIG_INSTALL_DIR}" NAMESPACE Boost:: FILE ${LIB}-targets.cmake)

  set(CONFIG_FILE_NAME "${CMAKE_CURRENT_BINARY_DIR}/${LIB}-config.cmake")
  set(CONFIG_FILE_CONTENTS "# Generated by BoostInstall.cmake for ${LIB}-${PROJECT_VERSION}\n\n")

  get_target_property(INTERFACE_LINK_LIBRARIES ${LIB} INTERFACE_LINK_LIBRARIES)

  if(INTERFACE_LINK_LIBRARIES)

    string(APPEND CONFIG_FILE_CONTENTS "include(CMakeFindDependencyMacro)\n\n")

    foreach(dep IN LISTS INTERFACE_LINK_LIBRARIES)

      if(${dep} MATCHES "^Boost::(.*)$")

        string(APPEND CONFIG_FILE_CONTENTS "find_dependency(boost_${CMAKE_MATCH_1} ${PROJECT_VERSION} EXACT)\n")

      endif()

    endforeach()

    string(APPEND CONFIG_FILE_CONTENTS "\n")

  endif()

  string(APPEND CONFIG_FILE_CONTENTS "include(\"\${CMAKE_CURRENT_LIST_DIR}/${LIB}-targets.cmake\")\n")

  file(WRITE "${CONFIG_FILE_NAME}" "${CONFIG_FILE_CONTENTS}")
  install(FILES "${CONFIG_FILE_NAME}" DESTINATION "${CONFIG_INSTALL_DIR}")

  set(CONFIG_VERSION_FILE_NAME "${CMAKE_CURRENT_BINARY_DIR}/${LIB}-config-version.cmake")

  if(TYPE STREQUAL "INTERFACE_LIBRARY")

    # Header-only libraries are arcitecture-independent

    if(NOT CMAKE_VERSION VERSION_LESS 3.14)

      write_basic_package_version_file("${CONFIG_VERSION_FILE_NAME}" COMPATIBILITY AnyNewerVersion ARCH_INDEPENDENT)

    else()

      set(OLD_CMAKE_SIZEOF_VOID_P ${CMAKE_SIZEOF_VOID_P})
      set(CMAKE_SIZEOF_VOID_P "")

      write_basic_package_version_file("${CONFIG_VERSION_FILE_NAME}" COMPATIBILITY AnyNewerVersion)

      set(CMAKE_SIZEOF_VOID_P ${OLD_CMAKE_SIZEOF_VOID_P})

    endif()

  else()

    write_basic_package_version_file("${CONFIG_VERSION_FILE_NAME}" COMPATIBILITY AnyNewerVersion)

  endif()

  install(FILES "${CONFIG_VERSION_FILE_NAME}" DESTINATION "${CONFIG_INSTALL_DIR}")

endfunction()

# boost_install([TARGETS targets...] [HEADER_DIRECTORY directory])

function(boost_install)

  cmake_parse_arguments(_ "" HEADER_DIRECTORY TARGETS ${ARGN})

  if(NOT __TARGETS AND NOT __HEADER_DIRECTORY) # boost_install(target), backcompat

    boost_install_target(${__UNPARSED_ARGUMENTS})
    return()

  endif()

  if(__UNPARSED_ARGUMENTS)

    message(AUTHOR_WARNING "boost_install: extra arguments ignored: ${__UNPARSED_ARGUMENTS}")

  endif()

  if(__HEADER_DIRECTORY)

    install(DIRECTORY ${__HEADER_DIRECTORY} DESTINATION "${BOOST_INSTALL_INCLUDEDIR}")

  endif()

  foreach(target IN LISTS __TARGETS)

    boost_install_target(${target})

  endforeach()

endfunction()
