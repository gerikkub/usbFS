
module EP0Registers(
    input reset, clk,

    input clearRequest,
    input bmRequestTypeDPTD,
    input [1:0]bmRequestTypeType,
    input [4:0]bmRequestTypeRecipient,
    input [7:0]bRequest,
    input [15:0]wValue,
    input [15:0]wIndex,
    input [15:0]wLength,
    input requestValid,

    output [7:0]outByte,
    output outByteValid,
    input outByteAck,
    output outByteLast,

    input [7:0]inByte,
    input inByteValid,

    output [6:0]reg_address,

    input commitWrite,
    input resetWrite,

    output [9:0]descRomAddr,
    input [7:0]descRomData,

    input [9:0]desc_device_offset,
    input [9:0]desc_cfg_offset
);

reg [6:0]reg_adddress_reg;
assign reg_address = reg_adddress_reg;

reg [5:0]reg_max_txn_len_reg;

reg [5:0]txn_byte_count;
reg [4:0]index;
reg [4:0]last_index;

reg [7:0]outByteBuffer;
reg outByteValidReg;
reg outByteLastReg;
reg reqByteReg;

reg [9:0]desc_base_addr;
reg [7:0]desc_len;

reg [9:0]romReqAddr;

assign outByte = outByteBuffer;
assign outByteLast = outByteLastReg;
assign outByteValid = outByteValidReg;

assign descRomAddr = romReqAddr;


localparam DESC_DEVICE = 'd1;
localparam DESC_CONFIGURATION = 'd2;
localparam DESC_STRING = 'd3;
localparam DESC_INTERFACE = 'd4;
localparam DESC_ENDPOINT = 'd5;
localparam DESC_DEVICE_QUALIFIER = 'd6;

always @(*) begin

    desc_base_addr <= 'd0;
    desc_len <= 'd0;

    if (requestValid) begin
        if (bmRequestTypeDPTD == 'd1 &&
            bmRequestTypeType == 'd0 &&
            bmRequestTypeRecipient == 'd0 &&
            bRequest == 'h06) begin
            case (wValue[15:8])
             DESC_DEVICE: begin
                desc_base_addr <= desc_device_offset;
                desc_len <= 'd18;
             end
             DESC_CONFIGURATION: begin
                desc_base_addr <= desc_cfg_offset;
                desc_len <= 'd7;
             end
             default: begin
                desc_base_addr <= 'h1FF;
                desc_len <= 'd0;
             end
            endcase
        end
    end
end

always @(posedge clk) begin

    if (reset) begin
        reg_adddress_reg <= 'd0;
        reg_max_txn_len_reg <= 'd8;

        index <= 'd0;
        last_index <= 'd0;
        txn_byte_count <= 'd0;
        outByteBuffer <= 'd0;
        outByteValidReg <= 'd0;
        outByteLastReg <= 'd0;
        reqByteReg <= 'd0;
        romReqAddr <= 'd0;

    end else begin
        reg_adddress_reg <= reg_adddress_reg;

        index <= index;
        last_index <= last_index;
        txn_byte_count <= txn_byte_count;
        outByteBuffer <= outByteBuffer;
        outByteValidReg <= outByteValidReg;
        outByteLastReg <= 'd0;
        reqByteReg <= 'd0;
        romReqAddr <= romReqAddr;

        if (resetWrite) begin
            index <= last_index;
        end

        if (commitWrite) begin
            last_index <= index;
        end

        if (reqByteReg == 'd1) begin
            outByteBuffer <= descRomData;
            outByteValidReg <= 'd1;
        end

        if (requestValid) begin
            // GET_DESCRIPTOR
            if (bmRequestTypeDPTD == 'd1 &&
                bmRequestTypeType == 'd0 &&
                bmRequestTypeRecipient == 'd0 &&
                bRequest == 'h06) begin

                if (index < desc_len) begin
                    reqByteReg <= 'd1;
                    romReqAddr <= desc_base_addr + index;
                end else begin
                    outByteLastReg <= 'd1;
                    outByteBuffer <= 'd0;
                end
            // SET_ADDRESS
            end else if (bmRequestTypeDPTD == 'd0 &&
                         bmRequestTypeType == 'd0 &&
                         bmRequestTypeRecipient == 'd0 &&
                         bRequest == 'h05) begin
                reg_adddress_reg <= wValue;
            end else begin
                outByteLastReg <= 'd1;
                outByteBuffer <= 'd0;
            end

            if (txn_byte_count >= wLength ||
                txn_byte_count >= reg_max_txn_len_reg) begin
                outByteLastReg <= 'd1;
                outByteBuffer <= 'd0;
            end

            if (outByteAck) begin
                outByteValidReg <= 'd0;
                index <= index + 'd1;
                txn_byte_count <= txn_byte_count + 'd1;
            end
        end else begin
            txn_byte_count <= 'd0;
        end

        if (clearRequest) begin
            index <= 'd0;
            last_index <= 'd0;
        end
    end
end

endmodule