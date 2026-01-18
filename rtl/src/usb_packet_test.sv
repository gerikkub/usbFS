`timescale 1ns/100ps

`include "usbfsTop.v"

module packet_test_tb;
  int fd;
  int dn;
  int dp;
  int row;

  reg mod_dn;
  reg mod_dp;
  reg mod_clk;
  reg mod_reset;

  // wire mod_bus_reset;
  // wire mod_bus_sop;
  // wire mod_bit_out;
  // wire mod_bit_valid;
  // wire [3:0]mod_packet_kind;
  // wire mod_packet_kind_valid;
  // wire mod_packet_valid;
  // wire mod_packet_eop;

  // PacketDecoder u0 (.reset(mod_reset),
  //                   .clk36(mod_clk),
  //                   .dp(mod_dp),
  //                   .dn(mod_dn),
  //                   .bus_reset(mod_bus_reset),
  //                   .bus_sop(mod_bus_sop),
  //                   .bit_out(mod_bit_out),
  //                   .packet_bit_valid(mod_bit_valid),
  //                   .packet_kind(mod_packet_kind),
  //                   .packet_kind_valid(mod_packet_kind_valid),
  //                   .packet_valid(mod_packet_valid),
  //                   .packet_eop(mod_packet_eop));

  // wire mod_out_dp;
  // wire mod_out_dn;
  // wire mod_out_en;
  // wire mod_sof_pulse;

  // TransactionSM TSM (.reset(mod_reset),
  //                    .clk36(mod_clk),
  //                    .dp_in(mod_dp),
  //                    .dn_in(mod_dn),
  //                    .dp_out(mod_out_dp),
  //                    .dn_out(mod_out_dn),
  //                    .out_en(mod_out_en),
  //                    .sof_pulse(mod_sof_pulse));


  wire mod_out_dp;
  wire mod_out_dn;
  wire mod_out_en;
  wire mod_sof_pulse;
  wire [11:0]mod_debug;

  USBFSTop usbfsTop (.reset(mod_reset),
                     .clk48(mod_clk),
                     .usb_dp(mod_dp),
                     .usb_dn(mod_dn),
                     .usb_dp_out(mod_out_dp),
                     .usb_dn_out(mod_out_dn),
                     .out_en(mod_out_en),
                     .sof_pulse(mod_sof_pulse),
                     .debug(mod_debug));


  initial begin
    
    // fd = $fopen("usb_sof.csv", "r");
    // fd = $fopen("usb_setup.csv", "r");
    // fd = $fopen("usb_setup_in.csv", "r");
    // fd = $fopen("usb_setup_in_out.csv", "r");
    // fd = $fopen("usb_in_bad_addr.csv", "r");
    // fd = $fopen("usb_setup_in_2.csv", "r");
    // fd = $fopen("usb_set_address.csv", "r");
    // fd = $fopen("usb_setup_setaddr.csv", "r");
    // fd = $fopen("usb_bitstuff_in.csv", "r");
    // fd = $fopen("usb_get_dev_descriptor.csv", "r");
    // fd = $fopen("usb_addr_get_dev.csv", "r");
    fd = $fopen("usb_config_desc.csv", "r");

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