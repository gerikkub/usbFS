
`include "transactionSM.v"
`include "ep0_handler.v"
`include "single_port_rom.v"

module USBFSTop(
    input reset, clk48,
    input usb_dp, usb_dn,
    input usb_dp_out, usb_dn_out,
    output out_en,

    output sof_pulse,
    output [11:0]debug
);

wire tsm_dp_out;
wire tsm_dn_out;
wire tsm_out_en;
wire tsm_sof_pulse;
wire [11:0]tsm_debug;

wire tsm_bus_reset;
wire [3:0]tsm_pid;
wire [10:0]tsm_token;
wire tsm_token_valid;
wire tsm_ack_token;

wire [7:0]tsm_out_byte;
wire tsm_out_byte_valid;
wire tsm_packet_eop;
wire tsm_packet_ack_code;

wire [7:0]tsm_in_byte;
wire tsm_in_byte_ack;
wire tsm_in_byte_last;

wire tsm_use_data0;

TransactionSM tsm0(
    .reset(reset),
    .clk48(clk48),
    .dp_in(usb_dp),
    .dn_in(usb_dn),
    .dp_out(tsm_dp_out),
    .dn_out(tsm_dn_out),
    .out_en(tsm_out_en),
    .sof_pulse(tsm_sof_pulse),
    .debug(tsm_debug),
    .busReset(tsm_bus_reset),
    .pid(tsm_pid),
    .token(tsm_token),
    .tokenValid(tsm_token_valid),
    .ackToken(tsm_ack_token),
    .outByte(tsm_out_byte),
    .outByteValid(tsm_out_byte_valid),
    .packetEop(tsm_packet_eop),
    .packetAckCode(tsm_packet_ack_code),
    .inByte(tsm_in_byte),
    .inByteAck(tsm_in_byte_ack),
    .inByteLast(tsm_in_byte_last),
    .use_data0(tsm_use_data0)
);

assign sof_pulse = tsm_sof_pulse;

assign usb_dp_out = tsm_dp_out;
assign usb_dn_out = tsm_dn_out;
assign out_en = tsm_out_en;

wire [11:0]ep0_debug;
wire [9:0]ep0_desc_rom_addr;
wire [7:0]ep0_desc_rom_data;

EP0Handler ep0Handler0(
    .reset(reset),
    .clk(clk48),
    .bus_reset(tsm_bus_reset),
    .pid(tsm_pid),
    .token(tsm_token),
    .tokenValid(tsm_token_valid),
    .ackToken(tsm_ack_token),
    .outByte(tsm_in_byte),
    .outByteValid(tsm_in_byte_valid),
    .outByteAck(tsm_in_byte_ack),
    .outByteLast(tsm_in_byte_last),
    .inByte(tsm_out_byte),
    .inByteValid(tsm_out_byte_valid),
    .packetEop(tsm_packet_eop),
    .packetAckCode(tsm_packet_ack_code),
    .useData0(tsm_use_data0),
    .descRomAddr(ep0_desc_rom_addr),
    .descRomData(ep0_desc_rom_data),
    .debug(ep0_debug)
);

single_port_rom descriptorROM(
    .clk(clk48),
    .addra(ep0_desc_rom_addr),
    .doa(ep0_desc_rom_data)
);

assign debug[4:0] = ep0_debug[4:0];
assign debug[11:5] = tsm_debug[11:5];



endmodule