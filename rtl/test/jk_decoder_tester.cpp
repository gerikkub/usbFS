
#include "mod_test.hpp"
#include "usb_utils.hpp"
#include "Vjk_decoder.h"


typedef UsbModTest<Vjk_decoder> JKDecoderTest;

TEST_F(JKDecoderTest, Reset) {
    reset();

    ASSERT_EQ(mod->bit_valid, 0);
    ASSERT_EQ(mod->bus_reset, 0);
    ASSERT_EQ(mod->bus_sop, 0);
    ASSERT_EQ(mod->bus_eop, 0);
}

TEST_F(JKDecoderTest, BusIdle) {
    reset();

    mod->dn = 0;
    mod->dp = 0;

    for (int i = 0; i < (360000-1); i++) {
        clk();
        ASSERT_EQ(mod->bit_valid, 0);
        ASSERT_EQ(mod->bus_reset, 0);
        ASSERT_EQ(mod->bus_sop, 0);
        ASSERT_EQ(mod->bus_eop, 0);
    }

    clk();
    ASSERT_EQ(mod->bit_valid, 0);
    ASSERT_EQ(mod->bus_reset, 1);
    ASSERT_EQ(mod->bus_sop, 0);
    ASSERT_EQ(mod->bus_eop, 0);
}

void capture_test(JKDecoderTest& tester, std::string capture_fname, std::string decoder_fname) {

    std::vector<USBCaptureInput> capture_entries = load_usb_capture(capture_fname);
    auto exp_pkts = load_usb_decoder_output(decoder_fname);
    tester.mod->dn = 0;
    tester.mod->dp = 0;

    uint8_t in_b = 0;
    uint32_t in_idx = 0;
    uint32_t exp_idx = 0;
    auto pkt_itr = exp_pkts.begin();

    auto cap_iter = capture_entries.begin();

    while (cap_iter != capture_entries.end()) {
        cap_iter = tester.step_capture(cap_iter);
        if (tester.mod->bit_valid) {
            in_b |= (tester.mod->bit_out & 1) << in_idx;
            in_idx++;

            if (in_idx == 8) {
                ASSERT_NE(pkt_itr, exp_pkts.end());
                ASSERT_LT(exp_idx, pkt_itr->size());
                ASSERT_EQ(in_b, (*pkt_itr)[exp_idx]);
                exp_idx++;
                in_idx = 0;
                in_b = 0;
            }
        }

        if (tester.mod->bus_eop) {
            ASSERT_NE(pkt_itr, exp_pkts.end());
            ASSERT_EQ(exp_idx, pkt_itr->size());
            ASSERT_EQ(in_idx, 0);

            pkt_itr++;
            exp_idx = 0;
        }
    }

    ASSERT_EQ(pkt_itr, exp_pkts.end());
}

TEST_F(JKDecoderTest, SOF) {
    reset();

    capture_test(*this,
                 "bus_captures/sof_capture.csv",
                 "bus_captures/sof_capture_jk.csv");
}

TEST_F(JKDecoderTest, Bitstuff) {
    reset();

    capture_test(*this,
                 "bus_captures/bitstuff_capture.csv",
                 "bus_captures/bitstuff_capture_jk.csv");
}

TEST_F(JKDecoderTest, SetupIn) {
    reset();

    capture_test(*this,
                 "bus_captures/setupin_capture.csv",
                 "bus_captures/setupin_capture_jk.csv");
}

TEST_F(JKDecoderTest, AckPoorTiming) {
    reset();

    capture_test(*this,
                 "bus_captures/ack_poor_capture.csv",
                 "bus_captures/ack_poor_capture_jk.csv");
}

TEST_F(JKDecoderTest, CppEncoder) {
    reset();


    std::vector<uint8_t> exp_pkt = {0xFF, 0x00, 0xAA, 0xCF};
    UsbUtils::JKEncoder encoder(exp_pkt);


    mod->dn = 0;
    mod->dp = 0;

    uint8_t in_b = 0;
    uint32_t in_idx = 0;
    uint32_t exp_idx = 0;

    while (!encoder.is_complete()) {

        UsbUtils::BusState next_state = encoder.step();

        ASSERT_NE(next_state, UsbUtils::BUS_INVALID);
        switch (next_state) {
            case UsbUtils::BUS_SE0:
                mod->dn = 0;
                mod->dp = 0;
                break;
            case UsbUtils::BUS_J:
                mod->dn = 0;
                mod->dp = 1;
                break;
            case UsbUtils::BUS_K:
                mod->dn = 1;
                mod->dp = 0;
                break;
            default:
                ASSERT_TRUE(false);
                break;
        }

        clk();

        if (mod->bit_valid) {
            in_b |= (mod->bit_out & 1) << in_idx;
            in_idx++;

            if (in_idx == 8) {
                ASSERT_LT(exp_idx, exp_pkt.size());
                ASSERT_EQ(in_b, exp_pkt[exp_idx]);
                exp_idx++;
                in_idx = 0;
                in_b = 0;
            }
        }
    }

    ASSERT_EQ(in_b, 0);
    ASSERT_EQ(exp_idx, exp_pkt.size());
    ASSERT_EQ(mod->bus_eop, 1);
}
