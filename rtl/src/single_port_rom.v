
module single_port_rom(
    input clk,
    input [9:0]addra,
    input [7:0]doa
);

reg [7:0] rom [1023:0];

integer i;
initial begin
    for (i=0; i<1024; i++) begin
        rom[i] = 0;
    end
    rom[24:0] = {
           // DEVICE DESCRIPTOR
           8'd18,      // bLength
           8'd1,       // bDescriptorType
           8'h10, 8'h1, // bcdUSB
           8'h02,       // bDeviceClass
           8'd0,       // bDeviceSubClass
           8'd0,       // bDeviceProtocol
           8'd8,      // bMaxPacketSize0
           8'h83, 8'h04, // idVendor
           8'h2a, 8'h57, // idProduct
           // 8'hAB, 8'hCD, // idVendor
           // 8'h11, 8'h22, // idProduct
           8'h0, 8'h1, // bcdDevice
           8'd0,       // iManufacturer
           8'd0,       // iProduct
           8'd0,       // iSerialNumber
           8'd1,       // bNumConfigurations
           // CONFIGURATION DESCRIPTOR
           8'd7,
           8'd2,
           8'h40, 8'd0,
           8'd1,
           8'd0,
           8'd0
           };
end

reg [7:0] doa_reg;
assign doa = doa_reg;

always @(posedge clk) begin
    doa_reg <= rom[addra];
end

endmodule