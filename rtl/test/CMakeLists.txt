

find_package(PkgConfig REQUIRED)
pkg_check_modules(VERILATOR REQUIRED verilator)

find_package(GTest REQUIRED)

add_library(mod_test mod_test.cpp)
target_include_directories(mod_test PUBLIC SYSTEM
    ${VERILATOR_INCLUDE_DIRS}
)

add_executable(jk_decoder_test jk_decoder_tester.cpp)
target_link_libraries(jk_decoder_test PRIVATE vjk_decoder_verilator_lib mod_test GTest::gtest)
add_test(NAME jk_decoder_test
         COMMAND jk_decoder_test
         WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
)

add_executable(jk_encoder_test jk_encoder_tester.cpp)
target_link_libraries(jk_encoder_test PRIVATE vjk_encoder_verilator_lib mod_test GTest::gtest)
add_test(NAME jk_encoder_test
         COMMAND jk_encoder_test
         WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
)

add_executable(packet_decoder_test packet_decoder_tester.cpp)
target_link_libraries(packet_decoder_test PRIVATE vpacket_decoder_verilator_lib mod_test GTest::gtest)
add_test(NAME packet_decoder_test
         COMMAND packet_decoder_test
         WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
)

