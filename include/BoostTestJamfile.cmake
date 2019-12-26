# Copyright 2018, 2019 Peter Dimov
# Distributed under the Boost Software License, Version 1.0.
# See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

if(NOT CMAKE_VERSION VERSION_LESS 3.10)
  include_guard()
endif()

include(BoostTest)
include(BoostMessage)

function(boost_test_jamfile)

    cmake_parse_arguments(_ "" "FILE;PREFIX" "LIBRARIES;LINK_LIBRARIES" ${ARGN})

    if(__UNPARSED_ARGUMENTS)
        message(AUTHOR_WARNING "boost_test_jamfile: extra arguments ignored: ${__UNPARSED_ARGUMENTS}")
    endif()

    if(__LIBRARIES)
        boost_message(DEBUG "boost_test_jamfile: LIBRARIES is deprecated, use LINK_LIBRARIES")
    endif()

    file(STRINGS ${__FILE} data)

    set(types compile compile-fail link link-fail run run-fail)

    foreach(line IN LISTS data)
        if(line)

            string(REGEX MATCHALL "[^ ]+" ll ${line})

            if(ll)
                list(GET ll 0 e0)

                if(e0 IN_LIST types)

                    list(LENGTH ll lln)

                    if(NOT lln EQUAL 2)

                        boost_message(DEBUG "boost_test_jamfile: Jamfile line ignored: ${line}")

                    else()

                        list(GET ll 1 e1)
                        boost_test(PREFIX ${__PREFIX} TYPE ${e0} SOURCES ${e1} LINK_LIBRARIES ${__LIBRARIES} ${__LINK_LIBRARIES})

                    endif()
                endif()
            endif()
        endif()
    endforeach(line)

endfunction(boost_test_jamfile)
