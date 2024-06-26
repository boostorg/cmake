# Copyright 2018-2024 Peter Dimov
# Distributed under the Boost Software License, Version 1.0.
# https://www.boost.org/LICENSE_1_0.txt

cmake_minimum_required(VERSION 3.5...3.20)

project(boost_add_sibdir_compat_test LANGUAGES CXX)

include(CTest)

set(BOOST_INCLUDE_LIBRARIES smart_ptr timer)
set(BOOST_ENABLE_COMPATIBILITY_TARGETS ON)

add_subdirectory(../../../.. deps/boost)

add_executable(main main.cpp)
target_link_libraries(main Boost::boost Boost::timer Boost::disable_autolinking)

add_test(NAME main COMMAND main)

install(TARGETS main)
