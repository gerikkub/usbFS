
`include "packet_decoder.v"
`include "packet_encoder.v"
`include "setup_buffer.v"
`include "ep0_handler.v"

module TransactionSM(
    input reset, clk48,
    input dp_in, dn_in,

    output dp_out, dn_out,
    output out_en,
    output sof_pulse,
    output [11:0]debug,
    output busReset,

    output [3:0]pid,
    output [10:0]token,
    output tokenValid,
    input ackToken,

    output [7:0]outByte,
    output outByteValid,
    output packetEop,
    output [1:0]packetAckCode,

    input [7:0]inByte,
    output inByteAck,
    input inByteLast,
    input use_data0
);

wire d_reset;
wire d_bus_reset;
wire d_bus_sop;
wire d_bit_out;
wire d_bit_valid;
wire [7:0]d_byte_out;
wire d_byte_valid;
wire [3:0]d_pid;
wire d_pid_valid;
wire d_packet_valid;
wire d_packet_eop;

PacketDecoder pkdec0(
    .reset(d_reset),
    .clk48(clk48),
    .dp(dp_in),
    .dn(dn_in),
    .bus_reset(d_bus_reset),
    .bus_sop(d_bus_sop),
    .bit_out(d_bit_out),
    .packet_bit_valid(d_bit_valid),
    .byte_out(d_byte_out),
    .byte_out_valid(d_byte_valid),
    .packet_kind(d_pid),
    .packet_kind_valid(d_pid_valid),
    .packet_valid(d_packet_valid),
    .packet_eop(d_packet_eop)
);

assign d_reset = reset | out_en;
assign packetEop = d_packet_eop;
assign busReset = d_bus_reset;

wire e_reset;
wire [3:0]e_pid;
wire [7:0]e_byte_in;
wire e_last_byte;
wire e_byte_ack;
wire e_done;
wire [11:0]e_debug;

PacketEncoder pcenc0(
    .reset(e_reset),
    .clk48(clk48),
    .pid(e_pid),
    .byte_in(e_byte_in),
    .last_byte(e_last_byte),
    .byte_ack(e_byte_ack),
    .dp(dp_out),
    .dn(dn_out),
    .done(e_done),
    .debug(e_debug)
);

assign e_reset = reset | ~out_en;

localparam PID_TOKEN = 2'b01;
localparam PID_DATA = 2'b11;
localparam PID_HANDSHAKE = 2'b10;
localparam PID_SPECIAL = 2'b00;

localparam PID_OUT = 4'b0001;
localparam PID_IN = 4'b1001;
localparam PID_SOF = 4'b0101;
localparam PID_SETUP = 4'b1101;

localparam PID_DATA0 = 4'b0011;
localparam PID_DATA1 = 4'b1011;

localparam PID_ACK =   4'b0010;
localparam PID_NAK =   4'b1010;
localparam PID_STALL = 4'b1110;

localparam PID_ERR =   4'b1100;


localparam IDLE = 4'd0;
localparam CTRL_SOF = 4'd1;
localparam CTRL_TOKEN = 4'd2;
localparam CTRL_SENDACK = 4'd4;
localparam CTRL_SENDSTALL = 4'd5;
localparam CTRL_IN_START_SENDDATA = 4'd6;
localparam CTRL_IN_SENDDATA = 4'd7;
localparam CTRL_OUT_RECVDATA = 4'd8;
localparam CTRL_WAIT_HANDSHAKE = 4'd9;
localparam CTRL_IN_WAITACK = 4'd10;

reg [3:0] ctrl_state;

reg [15:0]token_buffer;
wire [6:0]token_addr;
wire [3:0]token_endp;

assign inByteAck = e_byte_ack && ctrl_state == CTRL_IN_SENDDATA;

reg [3:0]e_pid_reg;

reg [3:0]last_pid;
reg last_pid_valid;

assign out_en = ctrl_state == CTRL_SENDACK ||
                ctrl_state == CTRL_SENDSTALL ||
                ctrl_state == CTRL_IN_SENDDATA;
assign e_pid = e_pid_reg;
assign e_byte_in = ctrl_state == CTRL_IN_SENDDATA ? inByte :
                                                    'd0;
assign e_last_byte = ctrl_state == CTRL_IN_SENDDATA ? inByteLast :
                     ctrl_state == CTRL_SENDACK ? 'b1 :
                     ctrl_state == CTRL_SENDSTALL ? 'b1 : 'b0;

assign token_addr = token_buffer[6:0];
assign token_endp = token_buffer[10:7];

// Max value of 127
reg [7:0]in_ack_wait_counter;

localparam IN_RESP_NONE = 2'd0;
localparam IN_RESP_ACK = 2'd1;
localparam IN_RESP_NO_ACK = 2'd2;

reg [1:0]in_resp_code;
assign packetAckCode = in_resp_code;

assign ep0_reqValid = ctrl_state == CTRL_IN_SENDDATA;

assign sof_pulse = ctrl_state == CTRL_SOF;

assign debug[4:0] = e_debug[4:0];
assign debug[6:5] = in_resp_code;
assign debug[7] = out_en;
assign debug[8] = d_packet_eop;
assign debug[9] = use_data0;
assign debug[10] = 'd0;
assign debug[11] = tokenValid;

assign pid = last_pid_valid ? last_pid : 'd0;
assign token = token_buffer[10:0];
assign tokenValid = ctrl_state == CTRL_TOKEN &&
                    d_packet_eop &&
                    d_packet_valid;

assign outByte = d_byte_out;
assign outByteValid = d_byte_valid &&
                      ctrl_state == CTRL_OUT_RECVDATA;

always @(posedge clk48) begin

    if (reset) begin
        ctrl_state <= IDLE;
        e_pid_reg <= 'd0;
        token_buffer <= 'd0;

        last_pid_valid <= 'd0;
        last_pid <= 'd0;

        in_ack_wait_counter <= 'd0;
        in_resp_code <= IN_RESP_NONE;
    end else begin
        ctrl_state <= ctrl_state;
        e_pid_reg <= e_pid_reg;
        token_buffer <= token_buffer;

        last_pid_valid <= last_pid_valid;
        last_pid <= last_pid;

        in_ack_wait_counter <= in_ack_wait_counter;
        in_resp_code <= in_resp_code;

        if (d_pid_valid) begin
            last_pid <= d_pid;
            last_pid_valid <= 'd1;
        end

        case (ctrl_state)
         IDLE: begin
            if (d_pid_valid) begin
                in_resp_code <= IN_RESP_NONE;
                if (d_pid[1:0] == PID_TOKEN && d_pid != PID_SOF) begin
                    ctrl_state <= CTRL_TOKEN;
                end else if (d_pid == PID_SOF) begin
                    ctrl_state <= CTRL_SOF;
                // TODO: Check that the last request was a SETUP
                end else if (d_pid == PID_ACK) begin
                    ctrl_state <= CTRL_WAIT_HANDSHAKE;
                end
            end
         end

         CTRL_WAIT_HANDSHAKE: begin
            if (d_packet_eop) begin
                ctrl_state <= IDLE;
            end
         end

         CTRL_TOKEN: begin
            if (d_packet_eop) begin


                if (!d_packet_valid ||
                    !ackToken) begin
                    ctrl_state <= IDLE;
                end else begin
                    case (d_pid)
                        PID_SETUP: begin 
                            ctrl_state <= CTRL_OUT_RECVDATA;
                        end
                        PID_IN: ctrl_state <= CTRL_IN_START_SENDDATA;
                        PID_OUT: ctrl_state <= CTRL_OUT_RECVDATA;
                        PID_ACK: begin

                            ctrl_state <= IDLE;
                        end
                        default: ctrl_state <= IDLE;
                    endcase
                end
            end

            if (d_bit_valid) begin
                token_buffer <= {d_bit_out, token_buffer[15:1]};
            end
         end

         CTRL_SENDACK: begin
            if (e_done) begin
                ctrl_state <= IDLE;
            end else begin
                e_pid_reg <= PID_ACK;
            end
         end

         CTRL_SENDSTALL: begin
            if (e_done) begin
                ctrl_state <= IDLE;
            end else begin
                e_pid_reg <= PID_STALL;
            end
         end

         CTRL_IN_START_SENDDATA: begin
            if (use_data0)
                e_pid_reg <= PID_DATA0;
            else
                e_pid_reg <= PID_DATA1;

            ctrl_state <= CTRL_IN_SENDDATA;
         end

         CTRL_IN_SENDDATA: begin

            if (e_done) begin
                ctrl_state <= CTRL_IN_WAITACK;
                in_ack_wait_counter <= 'd0;
            end
         end

         CTRL_IN_WAITACK: begin
            if (in_ack_wait_counter == 'd127) begin
                in_resp_code <= IN_RESP_NO_ACK;
                ctrl_state <= IDLE;
            end else if (d_packet_eop) begin
                ctrl_state <= IDLE;
                if (d_pid == PID_ACK)
                    in_resp_code <= IN_RESP_ACK;
                else
                    // This shouldn't occur. Host can only respond with ACK
                    in_resp_code <= IN_RESP_NO_ACK;
                    
            end
         end

         CTRL_OUT_RECVDATA: begin
            if (d_packet_eop) begin
                if (d_packet_valid) begin

                    ctrl_state <= CTRL_SENDACK;
                    // if (data_pid_correct) begin
                    //     ctrl_state <= CTRL_SENDACK;
                    // end else begin
                    //     // TODO: Should ignore packet
                    //     ctrl_state <= IDLE;
                    // end


                end else begin
                    ctrl_state <= CTRL_SENDSTALL;
                end
            end
         end

         CTRL_SOF: begin
            if (d_packet_eop) begin
                ctrl_state <= IDLE;
            end
         end
        endcase
    end
end

endmodule