
`include "types.sv"
`include "jk_encoder.sv"
`include "crc.v"

module packet_encoder (
    input reset, clk48,
    input Pid pid,
    input [7:0]byte_in,
    input last_byte,
    output byte_ack,
    output dp, dn,
    output done
);

typedef enum logic[2:0] {PID, PAYLOAD, CRC_START, CRC, COMPLETE} EncoderState;

EncoderState encoder_state;

logic jk_bit_out;
logic jk_bit_ack;
logic jk_last_bit;

jk_encoder jkenc0 (
    .reset(reset),
    .clk48(clk48),
    .bit_in(jk_bit_out),
    .bit_ack(jk_bit_ack),
    .last_bit(jk_last_bit),
    .dp(dp),
    .dn(dn),
    .done(done)
);

logic [4:0]crc5;
logic [15:0]crc16;
logic [15:0]crc_buffer;

logic crc_en;
assign crc_en = jk_bit_ack && encoder_state == PAYLOAD;

USBCRC5 crc5calc(.data_in(jk_bit_out),
                 .crc_en(crc_en),
                 .crc_out(crc5),
                 .rst(reset),
                 .clk(clk48));

USBCRC16 crc16calc(.data_in(jk_bit_out),
                   .crc_en(crc_en),
                   .crc_out(crc16),
                   .rst(reset),
                   .clk(clk48));

logic [3:0]crc_counter;

always_ff @(posedge clk48) begin
    if (reset) begin
        crc_counter <= 0;
        crc_buffer <= 0;
    end else
        if (encoder_state == CRC_START)
            case (pid)
                PID_SETUP,
                PID_IN,
                PID_OUT: begin
                    crc_counter <= 4;
                    crc_buffer <= {11'd0, ~crc5};
                end
                PID_DATA0,
                PID_DATA1: begin
                    crc_counter <= 15;
                    crc_buffer <= ~crc16;
                end
                default: begin
                    crc_counter <= 0;
                    crc_buffer <= 0;
                end
            endcase
        else begin
            crc_buffer <= crc_buffer;
            if (jk_bit_ack)
                crc_counter <= crc_counter - 1;
            else
                crc_counter <= crc_counter;
        end
end

logic [2:0]byte_counter;

always_ff @(posedge clk48) begin
    if (reset)
        byte_counter <= 0;
    else
        if (jk_bit_ack)
            byte_counter <= byte_counter + 1;
        else
            byte_counter <= byte_counter;
end

assign byte_ack = encoder_state == PAYLOAD &&
                  byte_counter == 7 &&
                  jk_bit_ack;
assign jk_last_bit = (encoder_state == PID &&
                      byte_counter == 7 &&
                      pid_is_handshake) ||
                     (encoder_state == CRC &&
                      crc_counter == 0);

logic [7:0]pid_full;
assign pid_full = {~pid, pid};

logic pid_is_handshake;
assign pid_is_handshake = pid == PID_ACK ||
                          pid == PID_NAK ||
                          pid == PID_STALL;

always_ff @(posedge clk48) begin
    if (reset)
        jk_bit_out <= 0;
    else
        case (encoder_state)
        PID:
            jk_bit_out <= pid_full[byte_counter];
        PAYLOAD:
            jk_bit_out <= byte_in[byte_counter];
        CRC_START:
            jk_bit_out <= 0;
        CRC:
            jk_bit_out <= crc_buffer[crc_counter];
        COMPLETE:
            jk_bit_out <= 0;
        default:
            jk_bit_out <= 0;
        endcase
end

always_ff @(posedge clk48) begin
    if (reset)
        encoder_state <= PID;
    else begin
        encoder_state <= encoder_state;
        case (encoder_state)
        PID:
            if (byte_counter == 7 && jk_bit_ack)
                if (pid_is_handshake)
                    encoder_state <= COMPLETE;
                else
                    encoder_state <= PAYLOAD;
        PAYLOAD:
            if (jk_bit_ack &&
                byte_counter == 7 &&
                last_byte)
                encoder_state <= CRC_START;
        CRC_START:
            encoder_state <= CRC;
        CRC:
            if (jk_bit_ack &&
                crc_counter == 0)
                encoder_state <= COMPLETE;
        COMPLETE:
            encoder_state <= COMPLETE;
        default:
            encoder_state <= COMPLETE;
        endcase
    end
end

endmodule

