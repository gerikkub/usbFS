
`include "types.sv"
`include "packet_decoder.sv"
`include "ep0_handler.sv"

module transaction_sm (
    input logic reset, clk48,
    input logic dp, dn,
    output logic bus_reset
);

typedef enum logic [3:0] {
    TXN_IDLE,
    TXN_TOKEN,

    TXN_DATA_RECV_WAIT,
    TXN_DATA_RECV,

    TXN_DATA_SEND_WAIT,
    TXN_DATA_SEND,

    TXN_HANDSHAKE_SEND_WAIT,
    TXN_HANDSHAKE_SEND,

    TXN_HANDSHAKE_RECV_WAIT,
    TXN_HANDSHAKE_RECV
} TransactionState;

TransactionState txn_state;

logic disable_decoder;

logic decoder_dp;
logic decoder_dn;
assign decoder_dp = dp;
assign decoder_dn = dn;

logic decoder_reset;
logic decoder_bus_reset;
logic decoder_bus_sop;
logic [7:0]decoder_byte;
logic decoder_byte_valid;
Pid decoder_packet_pid;
logic decoder_packet_pid_valid;
logic [6:0]decoder_packet_addr;
logic [3:0]decoder_packet_endp;
logic [10:0]decoder_packet_frame;
logic decoder_packet_good;
logic decoder_packet_eop;

assign decoder_reset = disable_decoder ? 1 : reset;

packet_decoder pkt_dec0(.reset(decoder_reset),
                        .clk48(clk48),
                        .dp(decoder_dp),
                        .dn(decoder_dn),
                        .bus_reset(decoder_bus_reset),
                        .bus_sop(decoder_bus_sop),
                        .byte_out(decoder_byte),
                        .byte_out_valid(decoder_byte_valid),
                        .packet_pid_out(decoder_packet_pid),
                        .packet_pid_valid(decoder_packet_pid_valid),
                        .packet_addr(decoder_packet_addr),
                        .packet_endp(decoder_packet_endp),
                        .packet_frame(decoder_packet_frame),
                        .packet_good(decoder_packet_good),
                        .packet_eop(decoder_packet_eop));

logic token_complete;
logic data_complete;
logic handshake_complete;

assign token_complete     = txn_state == TXN_TOKEN &&
                            decoder_packet_good;
assign data_complete      = txn_state == TXN_DATA_RECV &&
                            decoder_packet_good;
assign handshake_complete = txn_state == TXN_HANDSHAKE_RECV &&
                            decoder_packet_good;

logic ep0_active;

Handshake ep0_handshake;
logic ep0_handshake_valid;

ep0_handler ep0(.reset(reset),
                .clk48(clk48),
                .bus_reset(decoder_bus_reset),
                .txn_active(ep0_active),
                .pid(decoder_packet_pid),
                .token_complete(token_complete),
                .data_complete(data_complete),
                .handshake_complete(handshake_complete),
                .data_in(decoder_byte),
                .data_in_valid(decoder_byte_valid),
                .handshake_out(ep0_handshake),
                .handshake_out_valid(ep0_handshake_valid));

always_ff @(posedge clk48) begin
    if (reset)
        ep0_active <= 0;
    else
        if (txn_state == TXN_IDLE)
            ep0_active <= 0;
        else if (txn_state == TXN_TOKEN &&
                 decoder_packet_good &&
                 (decoder_packet_pid == PID_SETUP ||
                  decoder_packet_pid == PID_OUT ||
                  decoder_packet_pid == PID_IN) &&
                 decoder_packet_endp == 0)
            ep0_active <= 1;
        else
            ep0_active <= ep0_active;
end

Handshake handshake = ep0_handshake;
logic handshake_valid = ep0_handshake_valid;

logic [4:0] txn_endp;
always_ff @(posedge clk48) begin
    if (reset)
        txn_endp <= 0;
    else
        if (txn_state == TXN_TOKEN &&
            decoder_packet_good)
            if (decoder_packet_pid == PID_SETUP)
                txn_endp <= {1'b0, decoder_packet_endp};
            else if (decoder_packet_pid == PID_OUT)
                txn_endp <= {1'b0, decoder_packet_endp};
            else if (decoder_packet_pid == PID_IN)
                txn_endp <= {1'b1, decoder_packet_endp};
            else
                // In the case of a SOF or invalid PID
                // the txn state machine will transition
                // back to IDLE
                txn_endp <= 0;
        else if (txn_state == TXN_IDLE)
            txn_endp <= 0;
        else
            txn_endp <= txn_endp;
end

logic should_handshake;
assign should_handshake = 1;

localparam TURN_AROUND_COUNT = 18*4;
logic [6:0]turn_around_counter;

always_ff @(posedge clk48) begin
    if (reset)
        turn_around_counter <= 0;
    else
        if (txn_state == TXN_DATA_RECV_WAIT ||
            txn_state == TXN_HANDSHAKE_RECV_WAIT)
            if (turn_around_counter == TURN_AROUND_COUNT)
                turn_around_counter <= turn_around_counter;
            else
                turn_around_counter <= turn_around_counter + 1;
        else
            turn_around_counter <= 0;
end

always_ff @(posedge clk48) begin
    if (reset)
        txn_state <= TXN_IDLE;
    else
        txn_state <= txn_state;
        case (txn_state)
            TXN_IDLE:
                if (decoder_bus_sop)
                    txn_state <= TXN_TOKEN;
            TXN_TOKEN:
                if (decoder_packet_eop)
                    if (decoder_packet_good)
                        if (decoder_packet_pid == PID_OUT ||
                            decoder_packet_pid == PID_SETUP)
                            // Device recv during the DATA stage
                            txn_state <= TXN_DATA_RECV_WAIT;
                        else if (decoder_packet_pid == PID_IN)
                            // Device send during the DATA stage
                            txn_state <= TXN_DATA_SEND_WAIT;
                        else
                            // Not a token packet
                            txn_state <= TXN_IDLE;
                    else
                        // Erroneous packet
                        txn_state <= TXN_IDLE;

            TXN_DATA_RECV_WAIT:
                if (decoder_bus_sop)
                    txn_state <= TXN_DATA_RECV;
                else if (turn_around_counter == TURN_AROUND_COUNT)
                    txn_state <= TXN_IDLE;

            TXN_DATA_RECV:
                if (decoder_packet_eop)
                    if (decoder_packet_good)
                        txn_state <= TXN_HANDSHAKE_SEND_WAIT;
                    else
                        // Note: No handshake on an error during the Data stage
                        txn_state <= TXN_IDLE;


            TXN_HANDSHAKE_SEND_WAIT:
                if (handshake_valid)
                    if (handshake == HANDSHAKE_NONE)
                        txn_state <= TXN_IDLE;
                    else
                        txn_state <= TXN_HANDSHAKE_SEND;

            TXN_HANDSHAKE_SEND:
                // TODO
                txn_state <= TXN_IDLE;

            TXN_DATA_SEND_WAIT:
                // TODO
                txn_state <= TXN_IDLE;
            TXN_DATA_SEND:
                // TODO
                txn_state <= TXN_IDLE;

            TXN_HANDSHAKE_RECV_WAIT:
                if (decoder_bus_sop)
                    txn_state <= TXN_HANDSHAKE_RECV;
                else if (turn_around_counter == TURN_AROUND_COUNT)
                    txn_state <= TXN_IDLE;
            TXN_HANDSHAKE_RECV:
                if (decoder_packet_eop)
                    txn_state <= TXN_IDLE;


            default:
                txn_state <= TXN_IDLE;
        endcase
end

endmodule


