

module setup_buffer(
    input reset, clk,
    input en,
    input [7:0]byte_in,
    input byte_valid,
    output bmRequestTypeDPTD,
    output [1:0]bmRequestTypeType,
    output [4:0]bmRequestTypeRecipient,
    output [7:0]bRequest,
    output [15:0]wValue,
    output [15:0]wIndex,
    output [15:0]wLength
);

reg [7:0]buffer[8];

reg [2:0]index;
reg full;

assign bmRequestTypeDPTD = buffer[0][7];
assign bmRequestTypeType = buffer[0][6:5];
assign bmRequestTypeRecipient = buffer[0][4:0];

assign bRequest = buffer[1];

assign wValue = {buffer[3] << 8, buffer[2]};
assign wIndex = {buffer[5] << 8, buffer[4]};
assign wLength = {buffer[7] << 8, buffer[6]};

always @(posedge clk) begin

    if (reset) begin
        buffer <= '{8{'d0}};
        index <= 'd0;
        full <= 'd0;
    end else begin

        buffer <= buffer;
        index <= index;
        full <= full;

        if (en && byte_valid && !full) begin
            buffer[index] <= byte_in;
            index <= index + 'd1;
            if (index == 'd7) begin
                full <= 'd1;
            end
        end
    end
end

endmodule

