
module simple_dual_port(
    input clk,
    input ena,enb,
    input wea,
    input [9:0]addra,addrb
    input [7:0]dia,dob
);

reg [7:0] ram [1023:0];
reg [7:0] doa,dob;

always @(posedge clk) begin
    if (ena) begin
        if (wea)
            ram[addra] <= dia;
    end
end

always @(posedge clk) begin
    if (enb)
        dob <= ram[addrb];
end

endmodule