
`include "jk_decoder.sv"
`include "crc.v"

module packet_decoder (
    input reset, clk48,
    input dp, dn,
    output bus_reset,
    output bus_sop,
    output [7:0]byte_out,
    output byte_out_valid,
    output [3:0]packet_pid_out,
    output packet_pid_valid,
    output [6:0]packet_addr,
    output [3:0]packet_endp,
    output [10:0]packet_frame,
    output packet_good,
    output packet_eop
);

logic bus_bit_out;
logic bus_bit_valid;
logic bus_bit_reset;
logic bus_bit_sop;
logic bus_bit_eop;

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

logic [4:0]crc5;
logic [15:0]crc16;

logic crc_reset;
assign crc_reset = packet_state == WAIT ||
                   packet_state == PID;

USBCRC5 crc5calc(.data_in(bus_bit_out),
                 .crc_en(bus_bit_valid),
                 .crc_out(crc5),
                 .rst(crc_reset),
                 .clk(clk48));

USBCRC16 crc16calc(.data_in(bus_bit_out),
                   .crc_en(bus_bit_valid),
                   .crc_out(crc16),
                   .rst(crc_reset),
                   .clk(clk48));

typedef enum {WAIT, PID, PAYLOAD, EOP, COMPLETE} PacketState;

PacketState packet_state;

typedef enum logic [3:0] {
    PID_OUT   = 'h1,
    PID_IN    = 'h9,
    PID_SOF   = 'h5,
    PID_SETUP = 'hd,

    PID_DATA0 = 'h3,
    PID_DATA1 = 'hb,
    PID_DATA2 = 'h7,
    PID_MDATA = 'hf,

    PID_ACK   = 'h2,
    PID_NCK   = 'ha,
    PID_STALL = 'he,
    PID_NYET  = 'h6,

    PID_ERR   = 'hc,
    PID_SPLIT = 'h8,
    PID_PING  = 'h4,

    PID_INVALID = 'h0
} Pid;


logic [7:0]pid_buffer;
int pid_counter;

Pid packet_pid;
assign packet_pid = Pid'(pid_buffer[3:0]);

logic pid_valid;
assign pid_valid = pid_buffer[3:0] == ~pid_buffer[7:4] &&
                   packet_pid != PID_INVALID;

// Increment the pid counter for each byte while digesting the PID
always_ff @(posedge clk48) begin
    if (reset)
        pid_counter <= 0;
    else
        if (packet_state != PID)
            pid_counter <= 0;
        else
            if (bus_bit_valid)
                pid_counter <= pid_counter + 1;
            else
                pid_counter <= pid_counter;
end

assign packet_pid_out = packet_pid;
assign packet_pid_valid = pid_valid &&
                          (packet_state == PAYLOAD ||
                           packet_state == EOP ||
                           packet_state == COMPLETE);

// Pull PID bits intop pid_buffer
always_ff @(posedge clk48) begin
    if (reset)
        pid_buffer <= 0;
    else
        if (packet_state == WAIT)
            pid_buffer <= 0;
        else if (packet_state == PID &&
            bus_bit_valid)
            pid_buffer <= {bus_bit_out, pid_buffer[7:1]};
        else
            pid_buffer <= pid_buffer;
end

logic [10:0]token_buffer;
int token_counter;

assign packet_addr = token_buffer[10:4];
assign packet_endp = token_buffer[3:0];
assign packet_frame = token_buffer;


// Increment the token counter for the first 12 bytes of payload
always_ff @(posedge clk48) begin
    if (reset)
        token_counter <= 0;
    else
        if (packet_state != PAYLOAD)
            token_counter <= 0;
        else
            if (bus_bit_valid && token_counter != 11)
                token_counter <= token_counter + 1;
            else
                token_counter <= token_counter;
end

// Pull the first 12 bits into token buffer
always_ff @(posedge clk48) begin
    if (reset)
        token_buffer <= 0;
    else
        if (packet_state == WAIT)
            token_buffer <= 0;
        else if (packet_state == PAYLOAD &&
                 bus_bit_valid &&
                 token_counter != 11)
            token_buffer <= {bus_bit_out, token_buffer[10:1]};
        else
            token_buffer <= token_buffer;
end

logic [7:0]byte_buffer;
int byte_counter;
logic byte_valid;

assign byte_out = byte_buffer;
assign byte_out_valid = byte_valid;

// Count bits into full bytes and strobe the byte_valid
// output on rollover from 7 to 0
always_ff @(posedge clk48) begin
    byte_valid <= 0;

    if (reset)
        byte_counter <= 0;
    else
        if (packet_state != PAYLOAD)
            byte_counter <= 0;
        else
            if (bus_bit_valid)
                if (byte_counter == 7) begin
                    byte_counter <= 0;
                    byte_valid <= 1;
                end else
                    byte_counter <= byte_counter + 1;
            else
                byte_counter <= byte_counter;
end

always_ff @(posedge clk48) begin
    if (reset)
        byte_buffer <= 0;
    else
        if (packet_state == WAIT)
            byte_buffer <= 0;
        else if (packet_state == PAYLOAD &&
                 bus_bit_valid)
            byte_buffer <= {bus_bit_out, byte_buffer[7:1]};
        else
            byte_buffer <= byte_buffer;
end


localparam CRC5_RESIDUAL = 'hC;
localparam CRC16_RESIDUAL = 'h800D;

logic crc_valid;

always @(*) begin
    crc_valid = 'd1;

    case (packet_pid)
        PID_SETUP,
        PID_IN,
        PID_OUT,
        PID_SOF: begin
        crc_valid = crc5 == CRC5_RESIDUAL;
        end

        PID_DATA0,
        PID_DATA1: begin
        crc_valid = crc16 == CRC16_RESIDUAL;
        end
        default:
        crc_valid = 0;
    endcase
end

assign packet_eop = packet_state == COMPLETE;
assign packet_good = packet_eop &&
                     pid_valid &&
                     crc_valid;

always_ff @(posedge clk48) begin
    if (reset)
        packet_state <= WAIT;
    else
        packet_state <= packet_state;
        case (packet_state)
            WAIT:
                if (bus_bit_sop)
                    packet_state <= PID;
            PID:
                if (pid_counter == 8)
                    packet_state <= PAYLOAD;
            PAYLOAD:
                if (bus_bit_eop)
                    packet_state <= COMPLETE;
            COMPLETE:
                packet_state <= WAIT;
        endcase
end

endmodule
