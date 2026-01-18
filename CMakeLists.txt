cmake_minimum_required(VERSION 3.31)
project(usbFS)

cmake_policy(SET CMP0163 NEW)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_COLOR_DIAGNOSTICS ON)
add_compile_options (-fdiagnostics-color=always)

set(CMAKE_CXX_STANDARD 26)
enable_testing()

add_subdirectory(rtl)

