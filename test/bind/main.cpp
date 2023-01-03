// Copyright 2019, 2022 Peter Dimov
// Distributed under the Boost Software License, Version 1.0.
// https://www.boost.org/LICENSE_1_0.txt

#include <boost/bind.hpp>

int f( int x, int y )
{
    return x + y;
}

int main()
{
    return boost::bind( f, 1, 2 )() == 3? 0: 1;
}
