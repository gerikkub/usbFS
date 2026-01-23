
add_library(mod_test mod_test.cpp)
target_include_directories(mod_test PUBLIC SYSTEM
    ${VERILATOR_INCLUDE_DIRS}
)

find_package(PkgConfig REQUIRED)
pkg_check_modules(VERILATOR REQUIRED verilator)

find_package(GTest REQUIRED)

macro(add_verilator_test)
    set(oneValueArgs MOD)
    cmake_parse_arguments(arg
        "" "${oneValueArgs}" ""
        ${ARGV})

    add_executable(${arg_MOD}_test ${arg_MOD}_tester.cpp)
    target_link_libraries(${arg_MOD}_test PRIVATE v${arg_MOD}_verilator_lib mod_test GTest::gtest)
    add_test(NAME ${arg_MOD}_test
             COMMAND ${arg_MOD}_test
             WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
    )
    target_compile_options(${arg_MOD}_test PRIVATE
        -Wall
        -Wextra
        -Werror
    )

endmacro()

add_verilator_test(MOD jk_decoder)
add_verilator_test(MOD jk_encoder)
add_verilator_test(MOD packet_decoder)
add_verilator_test(MOD packet_encoder)
add_verilator_test(MOD transaction_sm)

