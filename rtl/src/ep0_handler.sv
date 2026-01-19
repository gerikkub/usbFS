
`include "types.sv"

module ep0_handler(
    input logic reset, clk48,
    input logic bus_reset,

    input logic txn_active,
    input Pid pid,

    input logic token_complete,
    input logic data_complete,
    input logic handshake_complete,

    input logic [7:0]data_in,
    input logic data_in_valid,

    output Handshake handshake_out,
    output logic handshake_out_valid
);

typedef enum {
    CTRL_IDLE,

    CTRL_SETUP_DATA,
    CTRL_SETUP_HANDSHAKE,

    CTRL_WRITE_DATA,
    CTRL_WRITE_STATUS,

    CTRL_READ_DATA,
    CTRL_READ_STATUS,

    CTRL_NODATA_STATUS
} CtrlState;

CtrlState ctrl_state;

logic sb_reset;
logic sb_write_en;

logic sb_bmRequestTypeDPTD;
logic [1:0]sb_bmRequestTypeType;
logic [4:0]sb_bmRequestTypeRecipient;
logic [7:0]sb_bRequest;
logic [15:0]sb_wValue;
logic [15:0]sb_wIndex;
logic [15:0]sb_wLength;

assign sb_reset = ctrl_state == CTRL_IDLE || reset;
assign sb_write_en = ctrl_state == CTRL_SETUP_DATA;

setup_buffer sb0(.reset(sb_reset),
                 .clk(clk48),
                 .en(sb_write_en),
                 .byte_in(data_in),
                 .byte_valid(data_in_valid),
                 .bmRequestTypeDPTD(sb_bmRequestTypeDPTD),
                 .bmRequestTypeType(sb_bmRequestTypeType),
                 .bmRequestTypeRecipient(sb_bmRequestTypeRecipient),
                 .bRequest(sb_bRequest),
                 .wValue(sb_wValue),
                 .wIndex(sb_wIndex),
                 .wLength(sb_wLength));

// Always ACK any transaction in a control transfer
// The transaction SM handles Data Error conditions
assign handshake_out = HANDSHAKE_ACK;
assign handshake_out_valid = ctrl_state == CTRL_SETUP_HANDSHAKE;

always_ff @(posedge clk48) begin
    if (reset)
        ctrl_state <= CTRL_IDLE;
    else
        ctrl_state <= ctrl_state;
        case (ctrl_state)
            CTRL_IDLE:
                if (txn_active && pid == PID_SETUP)
                    ctrl_state <= CTRL_SETUP_DATA;
            CTRL_SETUP_DATA:
                if (txn_active && data_complete)
                    ctrl_state <= CTRL_SETUP_HANDSHAKE;
                else if (!txn_active)
                    ctrl_state <= CTRL_IDLE;
            CTRL_SETUP_HANDSHAKE:
                if (!txn_active)
                    // TODO: Got to write or read states
                    ctrl_state <= CTRL_IDLE;
            default:
                ctrl_state <= CTRL_IDLE;
            /*
            CTRL_WRITE_DATA:
            CTRL_WRITE_STATUS:
            CTRL_READ_DATA:
            CTRL_READ_STATUS:
            CTRL_NODATA_STATUS:
            */
        endcase
end

endmodule

