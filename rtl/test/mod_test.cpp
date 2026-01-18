
#include <cassert>
#include <fstream>

#include <gtest/gtest.h>
#include <verilated.h>

#include "mod_test.hpp"

std::vector<USBCaptureInput> load_usb_capture(std::string capture_fname) {

    std::fstream captures_f(capture_fname, std::ios_base::in);
    std::string line;
    std::vector<USBCaptureInput> entries;

    // Skip header
    std::getline(captures_f, line);

    double min_time = 0;
    while (std::getline(captures_f, line)) {
        USBCaptureInput entry;
        sscanf(line.c_str(), "%lf,%d,%d\n",
               &entry.time,
               &entry.dn, &entry.dp);
        if (entries.size() == 0) {
            min_time = entry.time;
        }
        entry.time -= min_time;
        entry.time += 8 * (1./(48.*1000.*1000.));
        entries.push_back(entry);
    }

    return entries;
}

std::vector<std::vector<uint8_t>> load_usb_decoder_output(std::string decoder_fname) {

    std::fstream bytes_f(decoder_fname, std::ios_base::in);
    std::string line;
    std::vector<std::vector<uint8_t>> exp_list;

    while (std::getline(bytes_f, line)) {
        std::vector<uint8_t> exp_pkt;
        std::string val;
        std::stringstream line_stream(line);
        while (std::getline(line_stream, val, ',')) {
            exp_pkt.push_back(std::strtol(val.c_str(), NULL, 16));
        }
        exp_list.push_back(exp_pkt);
    }

    return exp_list;
}

int main(int argc, char** argv) {

    int res;

    Verilated::commandArgs(argc, argv);

    ::testing::InitGoogleTest(&argc, argv);

    return RUN_ALL_TESTS();
}


