

module JKDecoder (
    input reset, clk48,
    input dp, dn,
    output bit_out,
    output bit_valid,
    output bus_reset,
    output bus_sop,
    output bus_eop
);

localparam IDLE = 3'd0;
localparam SOP = 3'd1;
localparam SYNC = 3'd2;
localparam PAYLOAD = 3'd3;
localparam EOP = 3'd4;

localparam BUS_J = 1'd0;
localparam BUS_K = 1'd1;
localparam BUS_IDLE = 2'd2;
localparam BUS_INVALID = 2'd3;

wire [1:0]bus_state;

assign bus_state = dp == 'b0 && dn == 'b0 ? BUS_IDLE :
                   dp == 'b1 && dn == 'b0 ? BUS_J :
                   dp == 'b0 && dn == 'b1 ? BUS_K :
                   BUS_INVALID;

reg [18:0]idle_counter;
reg [2:0]bus_sample_offset;
reg [2:0]decoder_state;

reg [1:0]last_sample;

reg payload_valid;

reg [3:0]stuffing_counter;

wire [1:0]sampled_bus_state;
wire sampled_nrzi;


assign sampled_bus_state = bus_sample_offset == 'b00 ? bus_state : BUS_INVALID;
assign sampled_nrzi = sampled_bus_state == last_sample ? 'b1 : 'b0;


assign bit_out = sampled_nrzi;
assign bit_valid = payload_valid;

assign bus_reset = idle_counter == 'd360000 ? 'b1 : 'b0;
assign bus_sop = decoder_state == SOP ? 'b1 : 'b0;
assign bus_eop = decoder_state == EOP ? 'b1 : 'b0;

always @(*) begin
    payload_valid <= 'd0;

    if (decoder_state == PAYLOAD &&
        (sampled_bus_state == BUS_J ||
            sampled_bus_state == BUS_K)) begin

        if (stuffing_counter < 'd6) begin
            payload_valid <= 'd1;
        end
    end

end

always @(posedge clk48) begin
    if (reset) begin
        bus_sample_offset <= 'd0;
        decoder_state <= IDLE;
        idle_counter <= 'd0;
        last_sample <= BUS_INVALID;

        stuffing_counter <= 'd0;
    end else begin
        idle_counter <= 'd0;
        decoder_state <= decoder_state;
        stuffing_counter <= stuffing_counter;

        if (sampled_bus_state != BUS_INVALID) begin
            last_sample <= sampled_bus_state;
        end else begin
            last_sample <= last_sample;
        end


        if (bus_sample_offset == 'd3) begin
            bus_sample_offset <= 'd0;
        end else begin
            bus_sample_offset <= bus_sample_offset + 'd1;
        end

        case (decoder_state)
        // Bus IDLE state. Handle transition to SOP and RESET
         IDLE: begin
            case (bus_state)
              BUS_IDLE: begin
                if (idle_counter < 'd360000) begin
                    idle_counter <= idle_counter + 'd1;
                end else begin
                    idle_counter <= idle_counter;
                end
              end
              BUS_K: begin
                decoder_state <= SOP;
              end
            endcase
         end

        // Delay SYNC for one cycle to sample mid-waveform
         SOP: begin
            decoder_state <= SYNC;
            bus_sample_offset <= 'd0;
            last_sample <= BUS_INVALID;
            stuffing_counter <= 'd0;
         end

        // Wait for two BUS_K samples in a row
         SYNC: begin
            if (sampled_bus_state == BUS_K &&
               last_sample == BUS_K) begin
                decoder_state <= PAYLOAD;
            end
         end

        // Primary Payload decoder
         PAYLOAD: begin

            case (sampled_bus_state)
                BUS_J,
                BUS_K: begin

                    if (sampled_nrzi == 'd1) begin
                        stuffing_counter <= stuffing_counter + 'd1;
                    end else begin
                        stuffing_counter <= 'd0;
                    end


                end
                BUS_IDLE: begin
                    decoder_state <= EOP;
                end
            endcase
         end

         EOP: begin
            if (sampled_bus_state == BUS_J &&
                last_sample == BUS_J) begin
                decoder_state <= IDLE;
            end
         end
        endcase
    end
end

endmodule