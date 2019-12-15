# Copyright 2019 Peter Dimov
# Distributed under the Boost Software License, Version 1.0.
# See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

function(boost_message type)
  if(type STREQUAL "VERBOSE" OR type STREQUAL "DEBUG")
    if(Boost_${type})
      message(STATUS ${ARGN})
    elseif(CMAKE_VERSION VERSION_GREATER_EQUAL 3.15)
      message(${type} ${ARGN})
    endif()
  else()
    message(${type} ${ARGN})
  endif()
endfunction()
