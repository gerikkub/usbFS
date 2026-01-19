
#include "mod_test.hpp"
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
                 "../rtl/test/bus_captures/sof_capture.csv",
                 "../rtl/test/bus_captures/sof_capture_jk.csv");
}

TEST_F(JKDecoderTest, Bitstuff) {
    reset();

    capture_test(*this,
                 "../rtl/test/bus_captures/bitstuff_capture.csv",
                 "../rtl/test/bus_captures/bitstuff_capture_jk.csv");
}

TEST_F(JKDecoderTest, SetupIn) {
    reset();

    capture_test(*this,
                 "../rtl/test/bus_captures/setupin_capture.csv",
                 "../rtl/test/bus_captures/setupin_capture_jk.csv");
}

