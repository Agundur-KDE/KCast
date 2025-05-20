cmake_minimum_required(VERSION 3.10)
project(chromecast_avahi)

set(CMAKE_CXX_STANDARD 17)

find_package(PkgConfig REQUIRED)
pkg_check_modules(AVAHI REQUIRED avahi-client)

include_directories(${AVAHI_INCLUDE_DIRS})
link_directories(${AVAHI_LIBRARY_DIRS})

add_executable(chromecast_avahi main.cpp)
target_link_libraries(chromecast_avahi ${AVAHI_LIBRARIES})
