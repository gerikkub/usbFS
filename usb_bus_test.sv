`timescale 1ns/100ps

`include "packet_decoder.v"

module tb;
  int fd;
  int dn;
  int dp;
  int row;

  reg mod_dn;
  reg mod_dp;
  reg mod_clk;
  reg mod_reset;

  wire mod_bit_out;
  wire mod_bit_valid;
  wire mod_bus_reset;
  wire mod_bus_sop;

  JKDecoder u0 (.reset(mod_reset),
                .clk36(mod_clk),
                .dp(mod_dp),
                .dn(mod_dn),
                .bit_out(mod_bit_out),
                .bit_valid(mod_bit_valid),
                .bus_reset(mod_bus_reset),
                .bus_sop(mod_bus_sop));

  initial begin
    
    // fd = $fopen("../ip/usb_start_36.csv", "r");
    fd = $fopen("usb_start_36.csv", "r");

    mod_reset <= 'd1;
    mod_clk <= 'd0;
    #1;
    mod_clk <= 'd1;
    #1;
    mod_clk <= 'd0;
    mod_reset <= 'd0;
    #1;

    row <= 0;
    $display("Hello World!");
    while (! $feof(fd)) begin
        int j;
        j = $fscanf(fd, "%d,%d", dn, dp);

        row <= row + 1;
        mod_dn <= dn;
        mod_dp <= dp;
        mod_clk <= 'd1;
        #1;
        mod_clk <= 'd0;
        #1;
    end

    $display("Done");

  end
endmodule