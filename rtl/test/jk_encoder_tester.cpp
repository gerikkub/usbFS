
#include <random>
#include "mod_test.hpp"
#include "usb_utils.hpp"
#include "Vjk_encoder.h"

typedef UsbModTest<Vjk_encoder> JKEncoderTest;

TEST_F(JKEncoderTest, Reset) {
    reset();

    ASSERT_EQ(mod->bit_ack, 0);
    ASSERT_EQ(mod->dp, 1);
    ASSERT_EQ(mod->dn, 0);

    clk();

    ASSERT_EQ(mod->dp, 0);
    ASSERT_EQ(mod->dn, 1);
}


void loopback_test(JKEncoderTest& tester, std::vector<uint8_t> byte_vals, int max_cycles) {

    UsbUtils::JKDecoder decoder;

    tester.clk();
    decoder.step(tester.mod->dp, tester.mod->dn);
    ASSERT_FALSE(decoder.get_err().has_value()) << decoder.get_err().value();
    ASSERT_FALSE(decoder.is_complete());

    uint32_t byte_idx = 0;
    uint32_t bit_idx = 0;

    while (byte_idx < byte_vals.size()) {
        while (bit_idx < 8) {
            tester.mod->bit_in = (byte_vals[byte_idx] >> (bit_idx)) & 1;
            if ((byte_idx == byte_vals.size() - 1) &&
                bit_idx == 7) {
                tester.mod->last_bit = 1;
            } else {
                tester.mod->last_bit = 0;
            }

            tester.clk();
            decoder.step(tester.mod->dp, tester.mod->dn);
            ASSERT_FALSE(decoder.get_err().has_value()) << decoder.get_err().value();
            ASSERT_FALSE(decoder.is_complete());

            if (max_cycles-- == 0) {
                ASSERT_TRUE(false) << "Maximum cycle count hit";
                return;
            }
            if (tester.mod->bit_ack) {
                bit_idx++;
            }
        }
        byte_idx++;
        bit_idx = 0;
    }

    while (!tester.mod->done && max_cycles--) {
        tester.clk();
        decoder.step(tester.mod->dp, tester.mod->dn);
        ASSERT_FALSE(decoder.get_err().has_value()) << decoder.get_err().value();
    }

    ASSERT_TRUE(decoder.is_complete());

    auto decoded = decoder.get_decoded();

    ASSERT_EQ(decoded, byte_vals);
}

TEST_F(JKEncoderTest, SmallPacket) {
    reset();

    std::vector<uint8_t> test_sop = {0x80, 0xa5, 0xb9, 0x40};
    loopback_test(*this, test_sop, 1000);
}

TEST_F(JKEncoderTest, Bitstuff) {
    reset();

    std::vector<uint8_t> test_sop = {0xFF, 0xFF, 0x00, 0xFF};
    loopback_test(*this, test_sop, 1000);
}

TEST_F(JKEncoderTest, Bitstuff2) {
    reset();

    std::vector<uint8_t> test_sop = {0xFC};
    loopback_test(*this, test_sop, 1000);
}

TEST_F(JKEncoderTest, TwoXfers) {
    reset();

    std::vector<uint8_t> test_sop = {0x80, 0xa5, 0xb9, 0x40};
    loopback_test(*this, test_sop, 1000);
    reset();

    std::vector<uint8_t> test_sop2 = {0x80, 0xa5, 0xba, 0x40};
    loopback_test(*this, test_sop2, 1000);
}


TEST_F(JKEncoderTest, Random) {
    reset();

    std::random_device dev;
    std::mt19937 rng(dev());
    rng.seed(42);
    std::uniform_int_distribution<std::mt19937::result_type> dist256(0,255);

    std::vector<uint8_t> test_a;
    std::vector<uint8_t> test_b;
    for (int i = 0; i < 1025; i++) {
        test_a.push_back(dist256(rng));
        test_b.push_back(dist256(rng));
    }

    loopback_test(*this, test_a, 35000);
    reset();

    loopback_test(*this, test_b, 35000);
}


