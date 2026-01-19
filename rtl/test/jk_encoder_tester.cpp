
#include <print>
#include <random>
#include "mod_test.hpp"
#include "Vjk_encoder.h"

typedef UsbModTest<Vjk_encoder> JKEncoderTest;

class JKDecoder {

    public:

    JKDecoder() :
        state_(IDLE),
        sample_clock_(0),
        sync_counter_(0),
        bitstuff_counter_(0),
        payload_counter_(0),
        last_bus_(BUS_INVALID),
        byte_in_(0),
        decoded_(),
        err_() {
    };

    enum busstate_t {
        BUS_SE0,
        BUS_J,
        BUS_K,
        BUS_INVALID
    };


    void step(uint8_t dp, uint8_t dn) {
        busstate_t bus = get_busstate(dp, dn);
        if (state_ == IDLE) {
            if (bus == BUS_K) {
                state_ = SYNC;
                sample_clock_ = 1;
                sync_counter_ = 0;
            }
        } else {
            if (sample_clock_ == 0) {
                int bit = get_bit(bus);
                last_bus_ = bus;
                sample_clock_++;

                /*
                std::println("Sample: {} {} {} {} ({} {} {})",
                             dp, dn, std::to_underlying(bus), bit,
                             std::to_underlying(state_),
                             sample_clock_,
                             bitstuff_counter_);
                             */

                if (state_ == SYNC) {
                    sync_counter_++;
                    if (sync_counter_ == 0 ||
                        sync_counter_ == 2 ||
                        sync_counter_ == 4 ||
                        sync_counter_ == 6 ||
                        sync_counter_ == 7) {
                        if (bus != BUS_K) {
                            err_ = std::format("SYNC: Expected BUS_K at sync byte {}. Found {}",
                                               sync_counter_, std::to_underlying(bus));
                            return;
                        }
                    } else {
                        if (bus != BUS_J) {
                            err_ = std::format("SYNC: Expected BUS_J at sync byte {}. Found {}",
                                               sync_counter_, std::to_underlying(bus));
                            return;
                        }
                    }

                    if (sync_counter_ == 7) {
                        state_ = PAYLOAD;
                    }

                } else if (state_ == PAYLOAD) {
                    if (bus == BUS_INVALID) {
                        err_ = std::format("PAYLOAD: Bus in invalid state. Found {}",
                                           std::to_underlying(bus));
                        return;
                    }

                    if (bus == BUS_SE0) {
                        if (bitstuff_counter_ == 6) {
                            err_ = std::format("PAYLOAD: Expected final bitstuff before EOP");
                            return;
                        }
                        state_ = EOP;
                    } else {
                        if (bitstuff_counter_ < 6) {
                            assert(bit == 0 || bit == 1);

                            byte_in_ = (byte_in_ >> 1) | (bit << 7);
                            payload_counter_++;
                            if ((payload_counter_ % 8) == 0) {
                                decoded_.push_back(byte_in_);
                                byte_in_ = 0;
                            }
                        }
                        if (bitstuff_counter_ == 6 && bit == 1) {
                            err_ = std::format("PAYLOAD: Expected bitstuff");
                            return;
                        }
                    }
                } else {
                    if (bus == BUS_J) {
                        state_ = COMPLETE;
                    }
                }

                if (bit == 1) {
                    bitstuff_counter_++;
                } else {
                    bitstuff_counter_ = 0;
                }

            } else {
                sample_clock_++;
                if (sample_clock_ == 4) {
                    sample_clock_ = 0;
                }
            }
        }
    }

    std::optional<std::string> get_err() {
        return err_;
    }

    bool is_complete() {
        return state_ == COMPLETE;
    }

    std::vector<uint8_t> get_decoded() {
        return decoded_;
    }

    private:

    busstate_t get_busstate(uint8_t dp, uint8_t dn) {
        if (dp == 0 && dn == 0) {
            return BUS_SE0;
        } else if (dp == 1 && dn == 0) {
            return BUS_J;
        } else if (dp == 0 && dn == 1) {
            return BUS_K;
        } else {
            return BUS_INVALID;
        }
    }

    int get_bit(busstate_t bus) {
        if (bus == BUS_INVALID ||
            bus == BUS_SE0 ||
            last_bus_ == BUS_INVALID ||
            last_bus_ == BUS_SE0) {
            return -1;
        } else if (bus != last_bus_) {
            return 0;
        } else {
            return 1;
        }
    }

    enum state_t {
        IDLE,
        SYNC,
        PAYLOAD,
        EOP,
        COMPLETE
    } state_;
    int sample_clock_;
    int sync_counter_;
    int bitstuff_counter_;
    int payload_counter_;
    busstate_t last_bus_;
    uint8_t byte_in_;
    std::vector<uint8_t> decoded_;
    std::optional<std::string> err_;
};


TEST_F(JKEncoderTest, Reset) {
    reset();

    ASSERT_EQ(mod->bit_ack, 0);
    ASSERT_EQ(mod->dp, 1);
    ASSERT_EQ(mod->dn, 0);
}


void loopback_test(JKEncoderTest& tester, std::vector<uint8_t> byte_vals, int max_cycles) {

    JKDecoder decoder;

    tester.mod->start_txn = 1;
    tester.clk();
    tester.mod->start_txn = 0;
    decoder.step(tester.mod->dp, tester.mod->dn);
    ASSERT_FALSE(decoder.get_err().has_value()) << decoder.get_err().value();
    ASSERT_FALSE(decoder.is_complete());

    int byte_idx = 0;
    int bit_idx = 0;

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
    clk();
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
    clk();
    loopback_test(*this, test_b, 35000);
}


