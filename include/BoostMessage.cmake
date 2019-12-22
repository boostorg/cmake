# Copyright 2019 Peter Dimov
# Distributed under the Boost Software License, Version 1.0.
# See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

if(NOT CMAKE_VERSION VERSION_LESS 3.10)
  include_guard()
endif()

function(boost_message type)

  # For CMake 3.15+ use `cmake --log-level=VERBOSE|DEBUG|TRACE`
  if(CMAKE_VERSION VERSION_LESS 3.15)
    if(type STREQUAL "VERBOSE")
      if(NOT Boost_VERBOSE AND NOT Boost_DEBUG)
        return()
      endif()
      set(type STATUS)
    elseif(type STREQUAL "DEBUG")
      if(NOT Boost_DEBUG)
        return()
      endif()
      set(type STATUS)
    endif()
  endif()

  message(${type} ${ARGN})

endfunction()
