
#include "mod_test.hpp"
#include "usb_utils.hpp"
#include "Vpacket_encoder.h"

typedef UsbModTest<Vpacket_encoder> PacketEncoderTest;

TEST_F(PacketEncoderTest, Reset) {
    reset();

    ASSERT_EQ(mod->done, 0);
    ASSERT_EQ(mod->byte_ack, 0);
    ASSERT_EQ(mod->dp, 1);
    ASSERT_EQ(mod->dn, 0);

    clk();

    ASSERT_EQ(mod->dp, 0);
    ASSERT_EQ(mod->dn, 1);
}

std::optional<UsbUtils::UsbPacket> packet_test(PacketEncoderTest& tester,
                                               UsbUtils::UsbPacket packet) {

    UsbUtils::JKDecoder decoder;

    tester.mod->pid = packet.pid;

    uint32_t idx = 0;
    int max_cycles = 10000;

    if (packet.payload.size() > 0) {
        tester.mod->byte_in = packet.payload[0];
    } else {
        tester.mod->byte_in = 0xFF;
    }

    while (!tester.mod->done && max_cycles-- > 0) {

        if (tester.mod->byte_ack) {
            if (idx < packet.payload.size()) {
                tester.mod->byte_in = packet.payload[idx];
            } else {
                tester.mod->byte_in = 0xFF;
            }
        }

        tester.clk();

        decoder.step(tester.mod->dp, tester.mod->dn);

        if (packet.payload.size() == 0 ||
            idx == (packet.payload.size() - 1)) {
            tester.mod->last_byte = 1;
        }

        if (tester.mod->byte_ack) {
            idx++;
        }
    }

    return UsbUtils::UsbPacket::decode_packet(decoder.get_decoded());
}

TEST_F(PacketEncoderTest, PacketAck) {
    reset();

    ASSERT_EQ(mod->done, 0);
    ASSERT_EQ(mod->byte_ack, 0);
    ASSERT_EQ(mod->dp, 1);
    ASSERT_EQ(mod->dn, 0);

    auto ack_packet = UsbUtils::UsbPacket::create_handshake_packet(UsbUtils::PID_ACK);


    std::optional<UsbUtils::UsbPacket> decoded_packet =
        packet_test(*this, ack_packet);

    ASSERT_EQ(mod->done, 1);
    ASSERT_TRUE(decoded_packet.has_value());
    ASSERT_EQ(*decoded_packet, ack_packet);
}

TEST_F(PacketEncoderTest, PacketData) {
    reset();

    ASSERT_EQ(mod->done, 0);
    ASSERT_EQ(mod->byte_ack, 0);
    ASSERT_EQ(mod->dp, 1);
    ASSERT_EQ(mod->dn, 0);

    std::vector<uint8_t> data_bytes = {
        0x80,0x06,0x00,0x01,0x00,0x00,0x40,0x00
    };
    auto data_packet =
        UsbUtils::UsbPacket::create_data_packet(UsbUtils::PID_DATA1,
                                                data_bytes);

    std::optional<UsbUtils::UsbPacket> decoded_packet =
        packet_test(*this, data_packet);

    ASSERT_EQ(mod->done, 1);
    ASSERT_TRUE(decoded_packet.has_value());
    ASSERT_EQ(*decoded_packet, data_packet);
}

TEST_F(PacketEncoderTest, MultiplePackets) {
    reset();

    ASSERT_EQ(mod->done, 0);
    ASSERT_EQ(mod->byte_ack, 0);
    ASSERT_EQ(mod->dp, 1);
    ASSERT_EQ(mod->dn, 0);

    std::vector<uint8_t> data_bytes = {
        0xAA, 0xFF, 0x0F, 0xB5, 0x39, 0xFF, 0xEC, 0x01
    };
    auto data_packet =
        UsbUtils::UsbPacket::create_data_packet(UsbUtils::PID_DATA1,
                                                data_bytes);

    std::optional<UsbUtils::UsbPacket> decoded_packet =
        packet_test(*this, data_packet);

    ASSERT_EQ(mod->done, 1);
    ASSERT_TRUE(decoded_packet.has_value());
    ASSERT_EQ(*decoded_packet, data_packet);

    reset();

    ASSERT_EQ(mod->done, 0);
    ASSERT_EQ(mod->byte_ack, 0);
    ASSERT_EQ(mod->dp, 1);
    ASSERT_EQ(mod->dn, 0);

    auto handshake_packet =
        UsbUtils::UsbPacket::create_handshake_packet(UsbUtils::PID_ACK);

    decoded_packet = packet_test(*this, handshake_packet);

    ASSERT_EQ(mod->done, 1);
    ASSERT_TRUE(decoded_packet.has_value());
    ASSERT_EQ(*decoded_packet, handshake_packet);

}
