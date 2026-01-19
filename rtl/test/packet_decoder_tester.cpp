
#include "mod_test.hpp"
#include "usb_utils.hpp"
#include "Vpacket_decoder.h"

typedef UsbModTest<Vpacket_decoder> PacketDecoderTest;

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
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_SOF);
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
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_SETUP);
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
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_DATA0);
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
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_ACK);
    ASSERT_EQ(mod->packet_pid_valid, 1);
}

void step_packet(PacketDecoderTest& tester, UsbUtils::JKEncoder encoder, std::vector<uint8_t>* payload) {

    while (!encoder.is_complete()) {

        UsbUtils::BusState next_state = encoder.step();

        ASSERT_NE(next_state, UsbUtils::BUS_INVALID);
        switch (next_state) {
            case UsbUtils::BUS_SE0:
                tester.mod->dn = 0;
                tester.mod->dp = 0;
                break;
            case UsbUtils::BUS_J:
                tester.mod->dn = 0;
                tester.mod->dp = 1;
                break;
            case UsbUtils::BUS_K:
                tester.mod->dn = 1;
                tester.mod->dp = 0;
                break;
            default:
                ASSERT_TRUE(false);
                break;
        }
        tester.clk();

        if (tester.mod->byte_out_valid &&
            payload != nullptr) {
            payload->push_back(tester.mod->byte_out);
        }
    }

    tester.clk();
}

TEST_F(PacketDecoderTest, InPacket) {
    reset();

    UsbUtils::JKEncoder encoder =
        create_token_packet(UsbUtils::PID_IN, 0x32, 0x4);

    step_packet(*this, encoder, nullptr);

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_IN);
    ASSERT_EQ(mod->packet_addr, 0x32);
    ASSERT_EQ(mod->packet_endp, 0x4);
}

TEST_F(PacketDecoderTest, OutPacket) {
    reset();

    UsbUtils::JKEncoder encoder =
        create_token_packet(UsbUtils::PID_OUT, 0x5C, 0x1);

    step_packet(*this, encoder, nullptr);

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_OUT);
    ASSERT_EQ(mod->packet_addr, 0x5C);
    ASSERT_EQ(mod->packet_endp, 0x1);
}

TEST_F(PacketDecoderTest, SetupPacket) {
    reset();

    UsbUtils::JKEncoder encoder =
        create_token_packet(UsbUtils::PID_SETUP, 0, 0);

    step_packet(*this, encoder, nullptr);

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_SETUP);
    ASSERT_EQ(mod->packet_addr, 0);
    ASSERT_EQ(mod->packet_endp, 0);
}

TEST_F(PacketDecoderTest, SofPacket) {
    reset();

    UsbUtils::JKEncoder encoder =
        UsbUtils::create_sof_packet(0x321);

    step_packet(*this, encoder, nullptr);

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_SOF);
    ASSERT_EQ(mod->packet_frame, 0x321);
}


TEST_F(PacketDecoderTest, AckPacket) {
    reset();

    UsbUtils::JKEncoder encoder =
        create_handshake_packet(UsbUtils::PID_ACK);

    step_packet(*this, encoder, nullptr);

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_ACK);
}

TEST_F(PacketDecoderTest, NakPacket) {
    reset();

    UsbUtils::JKEncoder encoder =
        create_handshake_packet(UsbUtils::PID_NAK);

    step_packet(*this, encoder, nullptr);

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_NAK);
}

TEST_F(PacketDecoderTest, Data0Packet) {
    reset();

    std::vector<uint8_t> exp_data = {0x55,0xAB, 0xF7, 0x02};
    UsbUtils::JKEncoder encoder =
        create_data_packet(UsbUtils::PID_DATA0,
                           exp_data);

    std::vector<uint8_t> act_data;
    step_packet(*this, encoder, &act_data);
    

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_DATA0);

    ASSERT_GT(act_data.size(), 2);
    // Pop CRC bytes off
    act_data.pop_back();
    act_data.pop_back();
    ASSERT_EQ(act_data, exp_data);
}

TEST_F(PacketDecoderTest, Data1Packet) {
    reset();

    std::vector<uint8_t> exp_data = {0xFF, 0xFF, 0xFF, 0xFF, 0x75, 0x77, 0x22, 0xFF};
    UsbUtils::JKEncoder encoder =
        create_data_packet(UsbUtils::PID_DATA1,
                           exp_data);

    std::vector<uint8_t> act_data;
    step_packet(*this, encoder, &act_data);
    

    ASSERT_EQ(mod->packet_eop, 1);
    ASSERT_EQ(mod->packet_good, 1);
    ASSERT_EQ(mod->packet_pid_valid, 1);
    ASSERT_EQ(mod->packet_pid_out, UsbUtils::PID_DATA1);

    ASSERT_GT(act_data.size(), 2);
    // Pop CRC bytes off
    act_data.pop_back();
    act_data.pop_back();
    ASSERT_EQ(act_data, exp_data);
}


