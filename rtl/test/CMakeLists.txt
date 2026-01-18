

find_package(PkgConfig REQUIRED)
pkg_check_modules(VERILATOR REQUIRED verilator)

find_package(GTest REQUIRED)

add_library(mod_test mod_test.cpp)
target_include_directories(mod_test PUBLIC SYSTEM
    ${VERILATOR_INCLUDE_DIRS}
)
#target_link_libraries(mod_test PUBLIC GTest::gtest)

add_executable(jk_decoder_test jk_decoder_tester.cpp)
target_link_libraries(jk_decoder_test PRIVATE vjk_decoder_verilator_lib mod_test GTest::gtest)
add_test(NAME jk_decoder_test COMMAND jk_decoder_test)

