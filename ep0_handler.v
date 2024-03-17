
`include "ep0_registers.v"

module EP0Handler(
    input reset, clk,
    input bus_reset,

    input [3:0]pid,
    input [10:0]token,
    input tokenValid,
    output ackToken,

    output [7:0]outByte,
    output outByteValid,
    input outByteAck,
    output outByteLast,

    input [7:0]inByte,
    input inByteValid,
    input packetEop,
    input packetAckCode,

    output useData0,

    output [9:0]descRomAddr,
    input [7:0]descRomData,

    output [11:0]debug
);

localparam IN_RESP_NONE = 2'd0;
localparam IN_RESP_ACK = 2'd1;
localparam IN_RESP_NO_ACK = 2'd2;

wire sb_reset;
reg sb_reset_reg;
reg sb_en_reg;

// Data Transfer Direction (0 = Host-to-device)
wire sb_bmRequestTypeDPTD;

// Type (0 = Standard, 1 = Class, 2 = Vendor, 3 = Reserved)
wire [1:0]sb_bmRequestTypeType;

//  Recipient (0 = Device, 1 = Interface, 2 = Endpoint, 3 = Other)
wire [4:0]sb_bmRequestTypeRecipient;

// Specific Request
wire [7:0]sb_bRequest;
wire [15:0]sb_wValue;
wire [15:0]sb_wIndex;

// Number of bytes in data stage
wire [15:0]sb_wLength;

SetupBuffer setupBuffer0(
    .reset(sb_reset),
    .clk(clk),
    .en(sb_en_reg),
    .byte_in(inByte),
    .byte_valid(inByteValid),
    .bmRequestTypeDPTD(sb_bmRequestTypeDPTD),
    .bmRequestTypeType(sb_bmRequestTypeType),
    .bmRequestTypeRecipient(sb_bmRequestTypeRecipient),
    .bRequest(sb_bRequest),
    .wValue(sb_wValue),
    .wIndex(sb_wIndex),
    .wLength(sb_wLength));

assign sb_reset = reset || bus_reset || sb_reset_reg;

wire ep0r_reset;
wire ep0r_request_valid;

wire [7:0]ep0r_outByte;
wire ep0r_outByteValid;
wire ep0r_outByteAck;
wire ep0r_outByteLast;

wire [7:0]ep0r_inByte;
wire ep0r_inByteValid;
wire [6:0]ep0r_address;

reg ep0r_clear_req_reg;
reg ep0r_commit_write_reg;
reg ep0r_reset_write_reg;

wire [9:0]ep0r_desc_device_offset;
wire [9:0]ep0r_desc_cfg_offset;

EP0Registers ep0Registers0(
    .reset(ep0r_reset),
    .clk(clk),

    .clearRequest(ep0r_clear_req_reg),
    .bmRequestTypeDPTD(sb_bmRequestTypeDPTD),
    .bmRequestTypeType(sb_bmRequestTypeType),
    .bmRequestTypeRecipient(sb_bmRequestTypeRecipient),
    .bRequest(sb_bRequest),
    .wValue(sb_wValue),
    .wIndex(sb_wIndex),
    .wLength(sb_wLength),
    .requestValid(ep0r_request_valid),

    .outByte(ep0r_outByte),
    .outByteValid(ep0r_outByteValid),
    .outByteAck(ep0r_outByteAck),
    .outByteLast(ep0r_outByteLast),
    .inByte(ep0r_inByte),
    .inByteValid(ep0r_inByteValid),
    .reg_address(ep0r_address),
    
    .commitWrite(ep0r_commit_write_reg),
    .resetWrite(ep0r_reset_write_reg),

    .descRomAddr(descRomAddr),
    .descRomData(descRomData),

    .desc_device_offset(ep0r_desc_device_offset),
    .desc_cfg_offset(ep0r_desc_cfg_offset)
);

assign ep0r_reset = reset || bus_reset;

assign outByte = ep0r_outByte;
assign outByteValid = ep0r_outByteValid;
assign outByteLast = ep0r_outByteLast;
assign ep0r_outByteAck = outByteAck;

assign ep0r_inByte = inByte;
assign ep0r_inByteValid = inByteValid;

assign ep0r_desc_device_offset = 'd0;
assign ep0r_desc_cfg_offset = 'd18;

localparam PID_OUT = 4'b0001;
localparam PID_IN = 4'b1001;
localparam PID_SOF = 4'b0101;
localparam PID_SETUP = 4'b1101;

localparam PID_DATA0 = 4'b0011;
localparam PID_DATA1 = 4'b1011;

localparam WAIT_TOKEN = 8'd0;
localparam READ_DD_REQUEST = 8'd1;
localparam WAIT_TXN_TOKEN = 8'd2;
localparam HANDLE_OUT_REQUEST = 8'd3;
localparam HANDLE_IN_REQUEST = 8'd4;
localparam WAIT_IN_RESPONSE = 8'd5;

reg [7:0]ctrl_state;

assign ackToken = ctrl_state == WAIT_TOKEN &&
                  tokenValid &&
                  token_addr == ep0r_address &&
                  token_endp == 'd0;


reg [10:0]setup_token;
reg [10:0]txn_token;

wire [6:0]token_addr;
wire [3:0]token_endp;

assign token_addr = token[6:0];
assign token_endp = token[10:7];

assign ep0r_request_valid = ctrl_state == HANDLE_IN_REQUEST ||
                            ctrl_state == HANDLE_OUT_REQUEST;

assign debug[0] = ep0r_outByteValid;
assign debug[1] = ep0r_outByteLast;
assign debug[4:2] = ctrl_state[2:0];

reg use_data0_reg;
assign useData0 = use_data0_reg;

always @(posedge clk) begin

    if (reset) begin
        ctrl_state <= WAIT_TOKEN;
        setup_token <= 'd0;
        txn_token <= 'd0;
        sb_en_reg <= 'd0;
        sb_reset_reg <= 'd0;
        ep0r_clear_req_reg <= 'd0;
        ep0r_reset_write_reg <= 'd0;
        ep0r_commit_write_reg <= 'd0;
        use_data0_reg <= 'd0;

    end else begin
        setup_token <= setup_token;
        txn_token <= txn_token;
        sb_en_reg <= 'd0;
        sb_reset_reg <= 'd0;
        ep0r_clear_req_reg <= 'd0;
        ep0r_reset_write_reg <= 'd0;
        ep0r_commit_write_reg <= 'd0;
        use_data0_reg <= use_data0_reg;

        case (ctrl_state)
         WAIT_TOKEN: begin
            if (tokenValid &&
                token_addr == ep0r_address &&
                token_endp == 'd0) begin

                if (pid == PID_SETUP) begin
                    setup_token <= token;
                    ctrl_state <= READ_DD_REQUEST;
                    ep0r_clear_req_reg <= 'd1;
                    sb_reset_reg <= 'd1;

                end else if (pid == PID_IN) begin
                    txn_token <= token;
                    ctrl_state <= HANDLE_IN_REQUEST;
                end else if (pid == PID_OUT) begin
                    txn_token <= token;
                    ctrl_state <= HANDLE_OUT_REQUEST;
                end
            end
         end
         READ_DD_REQUEST: begin
            if (pid == PID_DATA0) begin
                sb_en_reg <= 'd1;

                if (packetEop) begin
                    ctrl_state <= WAIT_TOKEN;

                    // Set DATA PID to DATA1
                    use_data0_reg <= 'd0;
                end
            end
         end
         HANDLE_IN_REQUEST: begin
            if (packetEop) begin
                ctrl_state <= WAIT_IN_RESPONSE;
            end
         end

         WAIT_IN_RESPONSE: begin
            case (packetAckCode)
             IN_RESP_ACK: begin
                ctrl_state <= WAIT_TOKEN;
                ep0r_commit_write_reg <= 'd1;
                use_data0_reg <= ~use_data0_reg;
             end
             IN_RESP_NO_ACK: begin
                ctrl_state <= WAIT_TOKEN;
                ep0r_reset_write_reg <= 'd1;
                use_data0_reg <= ~use_data0_reg;
             end
            endcase
         end

         HANDLE_OUT_REQUEST: begin
            if (packetEop) begin
                ctrl_state <= WAIT_TOKEN;
            end
         end

        endcase
    end
end




endmodule