


module JKEncoder (
    input reset, clk48,
    input bit_in,
    input last_bit,
    output bit_ack,
    output dp, dn,
    output done,
    output [11:0]debug
);

localparam SYNC = 3'd0;
localparam PAYLOAD = 3'd1;
localparam EOP = 3'd2;
localparam COMPLETE = 3'd3;

reg [1:0]encoder_state;

reg [2:0]sync_counter;
reg [3:0]bit_counter;
reg [1:0]eop_counter;
reg [2:0]stuffing_counter;

reg write_j;
reg write_se0;
reg stuff_bit;
reg bit_ack_reg;

assign bit_ack = bit_ack_reg;

assign dp = write_se0 ? 'b0 :
            write_j ? 'b1 : 'b0;

assign dn = write_se0 ? 'b0 :
            write_j ? 'b0 : 'b1;

assign done = encoder_state == COMPLETE;

assign debug[2:0] = stuffing_counter;
assign debug[3] = bit_in;
assign debug[4] = bit_ack;
assign debug[5] = last_bit;
assign debug[6] = stuff_bit;
assign debug[11:7] = 'd0;

always @(posedge clk48) begin

    if (reset) begin
        encoder_state <= SYNC;
        sync_counter <= 'd0;
        bit_counter <= 'd0;
        eop_counter <= 'd0;
        stuffing_counter <= 'd0;
        write_j <= 'd1;
        write_se0 <= 'd0;
        bit_ack_reg <= 'd0;
        stuff_bit <= 'd0;
    end else begin
        encoder_state <= encoder_state;
        stuffing_counter <= stuffing_counter;
        sync_counter <= sync_counter;
        eop_counter <= eop_counter;
        write_j <= write_j;
        write_se0 <= write_se0;
        bit_ack_reg <= 'd0;
        stuff_bit <= stuff_bit;

        if (bit_counter == 'd3) begin
            bit_counter <= 'd0;
        end else begin
            bit_counter <= bit_counter + 'd1;
        end

        case (encoder_state)
         SYNC: begin
            if (bit_counter == 'd0) begin
                write_se0 <= 'd0;
                case (sync_counter)
                 0, 2, 4, 6, 7: begin
                    write_j <= 'd0;
                 end
                 1, 3, 5: begin
                    write_j <= 'd1;
                 end
                endcase
                sync_counter <= sync_counter + 'd1;

                if (sync_counter == 'd7) begin
                    encoder_state <= PAYLOAD;
                end
            end

        end
         PAYLOAD: begin
            if (bit_counter == 'd0) begin
                write_se0 <= 'd0;

                if (stuff_bit) begin
                    write_j <= ~write_j;
                    stuffing_counter <= 'd0;
                    stuff_bit <= 'd0;
                end else begin

                    if (bit_in == 'd0) begin
                        write_j <= ~write_j;
                        stuffing_counter <= 'd0;
                    end else begin

                        write_j <= write_j;
                        stuffing_counter <= stuffing_counter + 'd1;

                        if (stuffing_counter == 'd6) begin
                            stuff_bit <= 'd1;
                        end
                    end

                    if (stuffing_counter < 'd6) begin
                        bit_ack_reg <= 'd1;

                        if (last_bit) begin
                            encoder_state <= EOP;
                        end
                    end
                end

            end
         end

         EOP: begin
            if (bit_counter == 'd0) begin
                if (eop_counter <= 'd1) begin
                    write_se0 <= 'd1;
                end else if (eop_counter == 'd2) begin
                    write_se0 <= 'd0;
                    write_j <= 'd1;
                end else begin
                    encoder_state <= COMPLETE;
                end
                eop_counter <= eop_counter + 'd1;
            end
         end
        endcase
    end
end

endmodule