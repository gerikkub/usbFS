
#include "mod_test.hpp"
#include "usb_utils.hpp"
#include "Vtransaction_sm.h"

typedef UsbModTest<Vtransaction_sm> TransactionSMTest;

TEST_F(TransactionSMTest, Reset) {
    reset();

}

void step_packet(TransactionSMTest& tester, UsbUtils::JKEncoder encoder) {

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
    }

    tester.clk();
}


TEST_F(TransactionSMTest, SetupTxn) {
    reset();

    UsbUtils::JKEncoder setup_encoder =
        UsbUtils::JKEncoder::create_token_packet(UsbUtils::PID_SETUP, 0, 0);

    step_packet(*this, setup_encoder);

    clk();

    std::vector<uint8_t> data = {0x80,0x06,0x00,0x01,0x00,0x00,0x40,0x00};
    UsbUtils::JKEncoder data_encoder =
        UsbUtils::JKEncoder::create_data_packet(UsbUtils::PID_DATA0, data);

    step_packet(*this, data_encoder);

    clk();
}

