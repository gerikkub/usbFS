
find_package(PkgConfig REQUIRED)
pkg_check_modules(VERILATOR REQUIRED verilator)

include(CMakePrintHelpers)

macro(add_verilator_library)

    set(oneValueArgs TOP TOP_DIR)
    set(multiValueArgs DEPENDS EXTRA_ARGS)
    cmake_parse_arguments(arg
        "" "${oneValueArgs}" "${multiValueArgs}"
        ${ARGV})

    cmake_print_variables(arg_TOP)
    cmake_print_variables(arg_TOP_DIR)
    cmake_print_variables(arg_DEPENDS)
    cmake_print_variables(arg_EXTRA_ARGS)

    set(TOP_OBJ_DIR ${CMAKE_CURRENT_BINARY_DIR}/V${arg_TOP})
    set(VERILATOR_FLAGS --trace --assert -CFLAGS "-g -std=c++14 -pthread -fdiagnostics-color=always" -LDFLAGS -lpthread -Isrc ${arg_EXTRA_ARGS})

    message("Out header: ${TOP_OBJ_DIR}/V${arg_TOP}.h")


    add_custom_command(
        OUTPUT ${TOP_OBJ_DIR}/V${arg_TOP}.cpp
        OUTPUT ${TOP_OBJ_DIR}/V${arg_TOP}.h
        COMMAND verilator ${arg_TOP_DIR}/${arg_TOP} --cc ${VERILATOR_FLAGS} -Mdir ${TOP_OBJ_DIR}
        VERBATIM
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS ${arg_DEPENDS}
    )

    #add_custom_target(v${arg_TOP}_verilator_codegen
    #BYPRODUCTS ${TOP_OBJ_DIR}/V${arg_TOP}.cpp
    #${TOP_OBJ_DIR}/V${arg_TOP}.h
    #)

    add_custom_command(
        OUTPUT ${TOP_OBJ_DIR}/libV${arg_TOP}.a
               ${TOP_OBJ_DIR}/libverilated.a
        COMMAND make -f V${arg_TOP}.mk
        DEPENDS ${TOP_OBJ_DIR}/V${arg_TOP}.cpp
        DEPENDS ${TOP_OBJ_DIR}/V${arg_TOP}.h
        WORKING_DIRECTORY ${TOP_OBJ_DIR}
    )

    add_custom_target(v${arg_TOP}_verilator_lib_gen DEPENDS
        ${TOP_OBJ_DIR}/libV${arg_TOP}.a
        ${TOP_OBJ_DIR}/libverilated.a
    )

    add_library(v${arg_TOP}_verilator_lib INTERFACE)
    target_sources(v${arg_TOP}_verilator_lib PUBLIC
        FILE_SET HEADERS
        BASE_DIRS ${TOP_OBJ_DIR} ${CMAKE_CURRENT_SOURCE_DIR}
        FILES ${TOP_OBJ_DIR}/V${arg_TOP}.h ${arg_DEPENDS}
    )
    set_source_files_properties(
        ${TOP_OBJ_DIR}/V${arg_TOP}.h
        PROPERTIES GENERATE TRUE
    )

    target_link_libraries(v${arg_TOP}_verilator_lib INTERFACE
        ${TOP_OBJ_DIR}/libV${arg_TOP}.a
        ${TOP_OBJ_DIR}/libverilated.a
        ${VERILATOR_LIBRARIES}
    )
    target_include_directories(v${arg_TOP}_verilator_lib INTERFACE
        ${TOP_OBJ_DIR}
        ${VERILATOR_INCLUDE_DIRS}
    )
    target_compile_options(v${arg_TOP}_verilator_lib INTERFACE
        ${VERILATOR_CFLAGS}
    )
    add_dependencies(v${arg_TOP}_verilator_lib
        v${arg_TOP}_verilator_lib_gen
        #v${arg_TOP}_verilator_codegen
        #${arg_DEPENDS}
    )

endmacro()

file(GLOB_RECURSE CORE_V_SRC src/*.v)
file(GLOB_RECURSE CORE_SV_SRC src/*.sv)

set(CORE_SRC "${CORE_V_SRC};${CORE_SV_SRC}")

cmake_print_variables(CORE_V_SRC)
cmake_print_variables(CORE_SV_SRC)
cmake_print_variables(CORE_SRC)

#add_verilator_library(
#TOP usbfsTop
#TOP_DIR src
#DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/usbfsTop.sv"
#)

add_verilator_library(
    TOP jk_decoder
    TOP_DIR src
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/jk_decoder.sv"
)

add_verilator_library(
    TOP jk_encoder
    TOP_DIR src
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/jk_encoder.sv"
)


add_verilator_library(
    TOP packet_decoder
    TOP_DIR src
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/packet_decoder.sv"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/jk_decoder.sv"
)

add_subdirectory(test)

