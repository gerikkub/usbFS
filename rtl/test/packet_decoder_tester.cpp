
#include "mod_test.hpp"
#include "Vpacket_decoder.h"


typedef UsbModTest<Vpacket_decoder> PacketDecoderTest;

TEST_F(PacketDecoderTest, Reset) {
    reset();

    ASSERT_EQ(mod->packet_bit_valid, 0);
    ASSERT_EQ(mod->byte_out_valid, 0);
    ASSERT_EQ(mod->packet_kind_valid, 0);
    ASSERT_EQ(mod->packet_eop, 0);
}

TEST_F(PacketDecoderTest, SOF) {
    reset();

    std::vector<USBCaptureInput> capture_entries = load_usb_capture("../rtl/test/bus_captures/sof_capture.csv");
    ASSERT_GT(capture_entries.size(), 0);
    this->mod->dn = 0;
    this->mod->dp = 0;

    auto cap_iter = capture_entries.begin();

    while (cap_iter != capture_entries.end()) {
        cap_iter = this->step_capture(cap_iter);
    }


    /*
    ASSERT_EQ(mod->packet_bit_valid, 0);
    ASSERT_EQ(mod->byte_out_valid, 0);
    ASSERT_EQ(mod->packet_kind_valid, 0);
    ASSERT_EQ(mod->packet_eop, 0);
    */
}


