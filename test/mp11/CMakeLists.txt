# Copyright 2018 Peter Dimov
# Distributed under the Boost Software License, Version 1.0.
# See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

cmake_minimum_required(VERSION 3.5...3.16)

project(boost_mp11_install_test LANGUAGES CXX)

find_package(boost_mp11 REQUIRED)

add_executable(main main.cpp)
target_link_libraries(main Boost::mp11)

enable_testing()
add_test(NAME main COMMAND main)

add_custom_target(check VERBATIM COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --no-tests=error -C $<CONFIG>)
