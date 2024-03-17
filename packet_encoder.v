
`include "jk_encoder.v"
`include "crc.v"

module PacketEncoder (
    input reset, clk48,
    input [3:0]pid,
    input [7:0]byte_in,
    input last_byte,
    output byte_ack,
    output dp, dn,
    output done,
    output [11:0]debug
);


wire bit_out;
wire jk_bit_ack;
wire jk_last_bit;

JKEncoder jkenc0 (
    .reset(reset),
    .clk48(clk48),
    .bit_in(bit_out),
    .bit_ack(jk_bit_ack),
    .last_bit(jk_last_bit),
    .dp(dp),
    .dn(dn),
    .done(done),
    .debug(debug)
);

wire [4:0]crc5;
wire [15:0]crc16;

wire crc_en;

USBCRC5 crc5calc(.data_in(bit_out),
                 .crc_en(crc_en),
                 .crc_out(crc5),
                 .rst(reset),
                 .clk(clk48));

USBCRC16 crc16calc(.data_in(bit_out),
                   .crc_en(crc_en),
                   .crc_out(crc16),
                   .rst(reset),
                   .clk(clk48));


localparam PID = 3'd0;
localparam PAYLOAD = 3'd1;
localparam CRC_START = 3'd2;
localparam CRC = 3'd3;
localparam COMPLETE = 3'd4;

localparam PID_OUT = 4'b0001;
localparam PID_IN = 4'b1001;
localparam PID_SOF = 4'b0101;
localparam PID_SETUP = 4'b1101;

localparam PID_DATA0 = 4'b0011;
localparam PID_DATA1 = 4'b1011;
localparam PID_DATA2 = 4'b0111;
localparam PID_MDATA = 4'b1111;

localparam PID_ACK =   4'b0010;
localparam PID_NAK =   4'b1010;
localparam PID_STALL = 4'b1110;
localparam PID_NYET =  4'b0110;

localparam PID_ERR =   4'b1100;
localparam PID_SPLIT = 4'b1000;
localparam PID_PING =  4'b0100;

reg [2:0]encoder_state;

reg [2:0]pid_counter;

wire [7:0]fullpid = (~pid) << 4 | pid;

reg [15:0]crc_buffer;
reg [4:0]crc_counter;

reg [7:0]byte_buffer;
reg [2:0]byte_bit_counter;

reg last_bit_crc;

reg bit_out_reg;
assign bit_out = bit_out_reg;

reg jk_last_bit_reg;
assign jk_last_bit = jk_last_bit_reg;

assign crc_en = jk_bit_ack && encoder_state == PAYLOAD;

reg byte_ack_reg;
assign byte_ack = byte_ack_reg;

wire should_crc;
assign should_crc = pid == PID_DATA0 ||
                    pid == PID_DATA1;

always @(posedge clk48) begin

    if (reset) begin
        encoder_state <= PID;
        pid_counter <= 'd0;
        bit_out_reg <= 'd0;
        crc_buffer <='d0;
        crc_counter <='d0;
        last_bit_crc <= 'd0;
        byte_ack_reg <= 'd0;

        jk_last_bit_reg <= 'd0;

        byte_buffer <= 'd0;
        byte_bit_counter <= 'd0;
    end else begin
        encoder_state <= encoder_state;
        pid_counter <= pid_counter;
        bit_out_reg <= 'd0;
        crc_buffer <= crc_buffer;
        crc_counter <= crc_counter;
        last_bit_crc <= 'd0;
        byte_ack_reg <= 'd0;
        jk_last_bit_reg <= jk_last_bit_reg;

        byte_buffer <= byte_buffer;
        byte_bit_counter <= byte_bit_counter;

        case (encoder_state)
         PID: begin
            bit_out_reg <= fullpid[pid_counter];

            if (jk_bit_ack == 'd1) begin
                if (pid_counter < 'd7) begin
                    pid_counter <= pid_counter + 'd1;
                end

                if (pid_counter == 'd6) begin
                    if (!should_crc)
                        jk_last_bit_reg <= last_byte;
                end else if(pid_counter == 'd7) begin
                    if (last_byte) begin
                        if (should_crc)
                            encoder_state <= CRC_START;
                        else
                            encoder_state <= COMPLETE;

                    end else begin
                        encoder_state <= PAYLOAD;
                        byte_buffer <= byte_in;
                        byte_ack_reg <= 'd1;
                    end
                end
            end
         end

         PAYLOAD: begin

            bit_out_reg <= byte_buffer[0];

            if (jk_bit_ack) begin
                if (byte_bit_counter < 'd7) begin
                    byte_buffer <= {1'b0, byte_buffer[7:1]};
                    byte_bit_counter <= byte_bit_counter + 'd1;
                end else begin
                    if (last_byte) begin
                        encoder_state <= CRC_START;
                    end else begin
                        byte_buffer <= byte_in;
                        byte_ack_reg <= 'b1;
                        byte_bit_counter <= 'd0;

                    end
                end
            end

         end

         CRC_START: begin
            case (pid)
                PID_SETUP,
                PID_IN,
                PID_OUT,
                PID_SOF: begin
                    crc_buffer <= ~crc5;
                    crc_counter <= 'd4;
                end
                PID_DATA0,
                PID_DATA1: begin
                    crc_buffer <= ~crc16;
                    crc_counter <= 'd15;
                end
            endcase

            encoder_state <= CRC;
         end

         CRC: begin

            bit_out_reg <= crc_buffer[crc_counter];

            if (jk_bit_ack) begin
                if (crc_counter == 'd0) begin
                    encoder_state <= COMPLETE;
                end else begin
                    crc_counter <= crc_counter - 'd1;
                end
            end

            if (crc_counter == 'd0) begin
                jk_last_bit_reg <= 'd1;
            end
         end
        endcase
    end
end

endmodule