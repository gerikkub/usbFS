`timescale 1ns/100ps

`include "jk_encoder.v"

module tb;
  reg mod_clk;
  reg mod_reset;
  reg mod_bit_in;
  reg mod_last_bit;

  wire mod_bit_ack;
  wire mod_dp;
  wire mod_dn;
  wire mod_done;

  JKEncoder u0 (.reset(mod_reset),
               .clk36(mod_clk),
               .bit_in(mod_bit_in),
               .last_bit(mod_last_bit),
               .bit_ack(mod_bit_ack),
               .dp(mod_dp),
               .dn(mod_dn),
               .done(mod_done));

  bit [7:0]xmit_sequence[4] ;
  int i;
  int j;

  initial begin

    xmit_sequence <= '{8'hC3, 8'h00, 8'hA5, 8'hFF};

    mod_reset <= 'd1;
    mod_clk <= 'd0;
    #1;
    mod_clk <= 'd1;
    #1;
    mod_clk <= 'd0;
    mod_reset <= 'd0;
    #1;

    for (i = 0; i < 4; i++) begin

        j = 0;
        while (j < 8) begin

            mod_bit_in <= xmit_sequence[i][j];
            if (i == 3 && j ==7) begin
                mod_last_bit <= 'd1;
            end else begin
                mod_last_bit <= 'd0;
            end

            mod_clk <= 'd1;
            #1
            mod_clk <= 'd0;
            #1

            if (mod_bit_ack == 'd1) begin
                j <= j + 'd1;
            end

        end


    end

  end
endmodule
