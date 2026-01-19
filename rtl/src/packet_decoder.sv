
`include "jk_decoder.sv"
`include "crc.v"

module packet_decoder (
    input reset, clk48,
    input dp, dn,
    output bus_reset,
    output bus_sop,
    output bit_out,
    output packet_bit_valid,
    output [7:0]byte_out,
    output byte_out_valid,
    output [3:0]packet_kind,
    output packet_kind_valid,
    output packet_valid,
    output packet_eop
);

wire bus_bit_out;
wire bus_bit_valid;
wire bus_bit_reset;
wire bus_bit_sop;
wire bus_bit_eop;

assign bus_sop = bus_bit_sop;
assign bus_reset = bus_bit_reset;

jk_decoder jk0(.reset(reset),
              .clk48(clk48),
              .dp(dp),
              .dn(dn),
              .bit_out(bus_bit_out),
              .bit_valid(bus_bit_valid),
              .bus_reset(bus_bit_reset),
              .bus_sop(bus_bit_sop),
              .bus_eop(bus_bit_eop));

assign bit_out = bus_bit_out;

wire [4:0]crc5;
wire [15:0]crc16;

reg crc_reset;

USBCRC5 crc5calc(.data_in(bus_bit_out),
                 .crc_en(packet_bit_valid),
                 .crc_out(crc5),
                 .rst(crc_reset),
                 .clk(clk48));

USBCRC16 crc16calc(.data_in(bus_bit_out),
                   .crc_en(packet_bit_valid),
                   .crc_out(crc16),
                   .rst(crc_reset),
                   .clk(clk48));

localparam WAIT = 3'd0;
localparam PID = 3'd1;
localparam PAYLOAD = 3'd2;
localparam EOP = 3'd3;
localparam FINAL = 3'd4;

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

reg [2:0]packet_state;
reg [7:0]packet_pid;
reg [2:0]packet_pid_counter;

reg crc_valid;

reg [7:0]byte_buffer;
reg byte_valid;
reg [3:0]byte_bit_counter;

assign byte_out = byte_buffer;
assign packet_kind = packet_pid[3:0];
assign packet_kind_valid = packet_pid[3:0] == ~packet_pid[7:4] &&
                           packet_state == PAYLOAD;
                            
assign packet_bit_valid = bus_bit_valid &&
                          packet_state == PAYLOAD &&
                          packet_pid[3:0] == ~packet_pid[7:4];
assign byte_out_valid = byte_valid;

assign packet_valid = packet_state == FINAL &&
                      packet_pid[3:0] == ~packet_pid[7:4] &&
                      crc_valid;

assign packet_eop = packet_state == FINAL;

always @(*) begin
    crc_valid = 'd1;

    case (packet_kind)
        PID_SETUP,
        PID_IN,
        PID_OUT,
        PID_SOF: begin
        crc_valid = crc5 == 'hC;
        end

        PID_DATA0,
        PID_DATA1: begin
        crc_valid = crc16 == 'h800D;
        end
        default:
        crc_valid = 0;
    endcase
end

always @(posedge clk48) begin
    if (reset) begin
        packet_state <= WAIT;
        packet_pid <= 'd0;
        packet_pid_counter <= 'd0;
        crc_reset <= 'b1;
        byte_buffer <= 'd0;
        byte_valid <= 'd0;
        byte_bit_counter <= 'd0;
    end else begin
        packet_state <= packet_state;
        packet_pid <= packet_pid;
        packet_pid_counter <= packet_pid_counter;
        crc_reset <= 'b0;

        byte_buffer <= byte_buffer;
        byte_valid <= 'd0;
        byte_bit_counter <= 'd0;

        case (packet_state)
         WAIT: begin
            if (bus_bit_sop) begin
                packet_state <= PID;
            end

         end

         PID: begin
            if (bus_bit_valid) begin
                packet_pid <= bus_bit_out << 7 | packet_pid >> 1;

                packet_pid_counter <= packet_pid_counter + 'd1;

                if (packet_pid_counter == 'd7) begin
                    crc_reset <= 'b1;
                    packet_state <= PAYLOAD;
                end
            end

            if (bus_bit_eop) begin
                packet_state <= FINAL;
            end
         end

         PAYLOAD: begin

            byte_bit_counter <= byte_bit_counter;

            if (bus_bit_valid) begin
                byte_buffer <= {bus_bit_out, byte_buffer[7:1]};

                if (byte_bit_counter == 'd7) begin
                    byte_valid <= 'b1;
                    byte_bit_counter <= 'd0;
                end else begin
                    byte_bit_counter <= byte_bit_counter + 'd1;
                end
            end

            if (bus_bit_eop) begin
                packet_state <= EOP;
            end
         end

         EOP: begin
            if (!bus_bit_eop) begin
                packet_state <= FINAL;
            end
         end

         FINAL: packet_state <= WAIT;
         default: packet_state <= WAIT;

        endcase
    end

end

endmodule
