
#include <deque>
#include <format>
#include <print>
#include <utility>
#include <vector>

#include <cassert>
#include <cstdint>

namespace UsbUtils {

enum BusState {
    BUS_SE0,
    BUS_J,
    BUS_K,
    BUS_INVALID
};

enum Pid {
    PID_OUT   = 0x1,
    PID_IN    = 0x9,
    PID_SOF   = 0x5,
    PID_SETUP = 0xd,

    PID_DATA0 = 0x3,
    PID_DATA1 = 0xb,
    PID_DATA2 = 0x7,
    PID_MDATA = 0xf,

    PID_ACK   = 0x2,
    PID_NAK   = 0xa,
    PID_STALL = 0xe,
    PID_NYET  = 0x6,

    PID_ERR   = 0xc,
    PID_SPLIT = 0x8,
    PID_PING  = 0x4,

    PID_INVALID = 0x0
};

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


    void step(uint8_t dp, uint8_t dn) {
        BusState bus = get_busstate(dp, dn);
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

    BusState get_busstate(uint8_t dp, uint8_t dn) {
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

    int get_bit(BusState bus) {
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
    BusState last_bus_;
    uint8_t byte_in_;
    std::vector<uint8_t> decoded_;
    std::optional<std::string> err_;
};

class JKEncoder {

    public:

    JKEncoder() :
        state_(IDLE),
        to_write_(),
        bit_counter_(0),
        write_counter_(0),
        sync_counter_(0),
        bitstuff_counter_(0),
        eop_counter_(0),
        last_bus_(),
        err_()
    {}

    JKEncoder(std::vector<uint8_t> to_write) :
        state_(IDLE),
        to_write_(to_write.begin(), to_write.end()),
        bit_counter_(0),
        write_counter_(0),
        sync_counter_(0),
        bitstuff_counter_(0),
        eop_counter_(0),
        last_bus_(),
        err_()
    {}

    BusState step() {

        BusState ret_bus = BUS_INVALID;

        if (state_ == IDLE) {
            write_counter_ = 1;
            state_ = SYNC;
            ret_bus = BUS_K;
        } else if (state_ != COMPLETE) {
            if (write_counter_ == 0) {


                if (state_ == SYNC) {
                    sync_counter_++;
                    if (sync_counter_ == 0 ||
                        sync_counter_ == 2 ||
                        sync_counter_ == 4 ||
                        sync_counter_ == 6 ||
                        sync_counter_ == 7) {
                        ret_bus =  BUS_K;
                    } else {
                        ret_bus =  BUS_J;
                    }
                    if (sync_counter_ == 7) {
                        state_ = PAYLOAD;
                    }
                } else if (state_ == PAYLOAD) {

                    if (bitstuff_counter_ == 6) {
                        ret_bus = get_bus_bit(0);
                    } else {
                        if (to_write_.size() == 0) {
                            eop_counter_ = 1;
                            state_ = EOP;
                            ret_bus = BUS_SE0;
                        } else {
                            ret_bus = get_bus_bit((to_write_[0] >> bit_counter_) & 1);
                            bit_counter_++;
                            assert(bit_counter_ <= 8);
                            if (bit_counter_ == 8) {
                                to_write_.pop_front();
                                bit_counter_ = 0;
                            }
                        }
                    }
                } else if (state_ == EOP) {
                    if (eop_counter_ < 2) {
                        ret_bus = BUS_SE0;
                    } else if (eop_counter_ == 2) {
                        state_ = COMPLETE;
                        ret_bus = BUS_J;
                    }
                    eop_counter_++;
                }

                if (ret_bus == last_bus_) {
                    bitstuff_counter_++;
                } else {
                    bitstuff_counter_ = 0;
                }
                assert(bitstuff_counter_ < 7);
            } else {
                ret_bus = last_bus_;
            }
            write_counter_++;
            if (write_counter_ == 4) {
                write_counter_ = 0;
            }
        }

        last_bus_ = ret_bus;
        return ret_bus;
    }

    std::optional<std::string> get_err() {
        return err_;
    }

    bool is_complete() {
        return state_ == COMPLETE;
    }

    private:
    BusState get_bus_bit(int i) {
        assert(last_bus_ == BUS_J || last_bus_ == BUS_K);
        if (i == 0) {
            return last_bus_ == BUS_J ? BUS_K : BUS_J;
        } else {
            return last_bus_;
        }
    }

    enum state_t {
        IDLE,
        SYNC,
        PAYLOAD,
        EOP,
        COMPLETE
    } state_;

    std::deque<uint8_t> to_write_;
    int bit_counter_;

    int write_counter_;
    int sync_counter_;
    int bitstuff_counter_;
    int eop_counter_;
    BusState last_bus_;
    std::optional<std::string> err_;
};

static uint8_t get_pid_byte(Pid pid) {
    uint8_t pid_byte = std::to_underlying(pid);
    return pid_byte | ((~(pid_byte << 4)) & 0xF0);
}

// Taken from https://electronics.stackexchange.com/questions/718294/how-is-crc5-calculated-in-detail-for-a-usb-token
static unsigned char crc5usb(unsigned short input)
{
        unsigned char res = 0x1f;
        unsigned char b;
        int i;

        for (i = 0;  i < 11;  ++i) {
                b = (input ^ res) & 1;
                input >>= 1;
                if (b) {
                        res = (res >> 1) ^ 0x14;        /* 10100 */
                } else {
                        res = (res >> 1);
                }
        }
        return res ^ 0x1f;
}

// Modified from https://www.reddit.com/r/embedded/comments/1acoobg/crc16_again_with_a_little_gift_for_you_all/
static uint16_t crc16usb(const uint8_t* data, size_t length) {

    uint16_t crc = 0xFFFF;

    for (size_t i = 0; i < length; i++) {
        uint8_t  d = data[i];
		uint32_t x = ((crc ^ d) & 0xff) << 8;
		uint32_t y = x;

		x ^= x << 1;
		x ^= x << 2;
		x ^= x << 4;
		
		x  = (x & 0x8000) | (y >> 1);

		crc = (crc >> 8) ^ (x >> 15) ^ (x >> 1) ^ x;
    }

    return crc ^ 0xFFFF;
}

static JKEncoder create_token_packet(Pid pid,
                                     uint8_t addr,
                                     uint8_t endp) {
    assert(pid == PID_IN ||
           pid == PID_OUT ||
           pid == PID_SETUP);

    uint8_t crc5 = crc5usb((endp << 7) | addr);

    std::vector<uint8_t> data = {
        get_pid_byte(pid),
        (uint8_t)((addr & 0x7F) | ((endp & 1) << 7)),
        (uint8_t)(((endp >> 1) & 0x7 | (crc5 << 3)))
    };

    return JKEncoder(data);
}

static JKEncoder create_sof_packet(uint16_t frame) {

    uint8_t crc5 = crc5usb(frame);

    std::vector<uint8_t> data = {
        get_pid_byte(PID_SOF),
        (uint8_t)(frame & 0xFF),
        (uint8_t)(((frame >> 8) & 0x7) | (crc5 << 3))
    };

    return JKEncoder(data);
}

static JKEncoder create_handshake_packet(Pid pid) {

    assert(pid == PID_ACK ||
           pid == PID_NAK ||
           pid == PID_STALL);

    std::vector<uint8_t> data = {
        get_pid_byte(pid)
    };
    return JKEncoder(data);
}

static JKEncoder create_data_packet(Pid pid,
                                    std::vector<uint8_t> data_in) {

    assert(pid == PID_DATA0 ||
           pid == PID_DATA1);

    std::vector<uint8_t> data = {
        get_pid_byte(pid)
    };
    for (auto b : data_in) {
        data.push_back(b);
    }
    uint16_t crc = crc16usb(data_in.data(), data_in.size());

    data.push_back(crc & 0xFF);
    data.push_back(crc >> 8);

    return JKEncoder(data);
}

}

