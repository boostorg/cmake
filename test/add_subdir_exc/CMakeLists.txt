# Copyright 2018-2021 Peter Dimov
# Distributed under the Boost Software License, Version 1.0.
# https://www.boost.org/LICENSE_1_0.txt

cmake_minimum_required(VERSION 3.5...3.20)

project(boost_add_sibdir_test LANGUAGES CXX)

set(BOOST_INCLUDE_LIBRARIES timer)

set(BUILD_TESTING OFF)
set(CMAKE_SKIP_INSTALL_RULES ON)

add_subdirectory(../../../.. deps/boost EXCLUDE_FROM_ALL)

unset(BUILD_TESTING)
unset(CMAKE_SKIP_INSTALL_RULES)

add_executable(main main.cpp)
target_link_libraries(main Boost::timer)

include(CTest)
add_test(NAME main COMMAND main)
