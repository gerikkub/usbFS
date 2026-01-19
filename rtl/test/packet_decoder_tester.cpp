
#include "mod_test.hpp"
#include "Vpacket_decoder.h"

typedef UsbModTest<Vpacket_decoder> PacketDecoderTest;

enum {
    PID_OUT   = 0x1,
    PID_IN    = 0x9,
    PID_SOF   = 0x5,
    PID_SETUP = 0xd,

    PID_DATA0 = 0x3,
    PID_DATA1 = 0xb,
    PID_DATA2 = 0x7,
    PID_MDATA = 0xf,

    PID_ACK   = 0x2,
    PID_NCK   = 0xa,
    PID_STALL = 0xe,
    PID_NYET  = 0x6,

    PID_ERR   = 0xc,
    PID_SPLIT = 0x8,
    PID_PING  = 0x4,

    PID_INVALID = 0x0
};

TEST_F(PacketDecoderTest, Reset) {
    reset();

    ASSERT_EQ(mod->byte_out_valid, 0);
    ASSERT_EQ(mod->packet_pid_valid, 0);
    ASSERT_EQ(mod->packet_eop, 0);
    ASSERT_EQ(mod->packet_good, 0);
}

TEST_F(PacketDecoderTest, SOF) {
    reset();

    std::vector<USBCaptureInput> capture_entries = load_usb_capture("bus_captures/sof_capture.csv");
    ASSERT_GT(capture_entries.size(), 0);
    this->mod->dn = 0;
    this->mod->dp = 0;

    auto cap_iter = capture_entries.begin();

    while (cap_iter != capture_entries.end()) {
        cap_iter = this->step_capture(cap_iter);

        if (mod->packet_eop) {
            break;
        }
    }

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_out, PID_SOF);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(mod->packet_frame, 0x0b9);
}


TEST_F(PacketDecoderTest, SetupTransaction) {
    reset();

    std::vector<USBCaptureInput> capture_entries = load_usb_capture("bus_captures/setup_txn_capture.csv");
    ASSERT_GT(capture_entries.size(), 0);
    this->mod->dn = 0;
    this->mod->dp = 0;

    auto cap_iter = capture_entries.begin();

    // Setup packet
    while (cap_iter != capture_entries.end()) {
        cap_iter = this->step_capture(cap_iter);

        if (mod->packet_eop) {
            break;
        }
    }

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_out, PID_SETUP);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(mod->packet_addr, 0);
    ASSERT_EQ(mod->packet_endp, 0);

    // DATA packet
    clk();
    ASSERT_EQ(mod->packet_eop, 0);
    std::vector<uint8_t> byte_buffer;
    while (cap_iter != capture_entries.end()) {
        cap_iter = this->step_capture(cap_iter);

        if (mod->byte_out_valid) {
            byte_buffer.push_back(mod->byte_out);
        }

        if (mod->packet_eop) {
            break;
        }
    }
    std::vector<uint8_t> exp_byte_buffer = {0x80,0x06,0x00,0x01,0x00,0x00,0x40,0x00,0xdd,0x94};

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_out, PID_DATA0);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(byte_buffer, exp_byte_buffer);

    // ACK packet
    clk();
    ASSERT_EQ(mod->packet_eop, 0);
    while (cap_iter != capture_entries.end()) {
        cap_iter = this->step_capture(cap_iter);

        if (mod->packet_eop) {
            break;
        }
    }
    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_pid_out, PID_ACK);
    ASSERT_EQ(mod->packet_pid_valid, 1);
}


