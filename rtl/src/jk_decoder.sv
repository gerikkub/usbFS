
module jk_decoder (
    input logic reset, clk48,
    input logic dp, dn,
    output logic bit_out,
    output logic bit_valid,
    output logic bus_reset,
    output logic bus_sop,
    output logic bus_eop
);

typedef enum {IDLE, SOP, SYNC, PAYLOAD, EOP} DecoderState;

DecoderState decoder_state_next;
DecoderState decoder_state;

localparam SAMPLE_CLK_PERIOD_FS = 4;

int sample_counter, sample_counter_next;
assign sample_counter_next = (decoder_state == IDLE ||
                              decoder_state == EOP) ? 0 :
                             decoder_state == SOP ? 2 :
                             sample_counter < (SAMPLE_CLK_PERIOD_FS - 1) ? sample_counter + 1 :
                                                                        0;
typedef enum {SAMPLE_IDLE, SAMPLE_TAKE, SAMPLE_PROCESS, SAMPLE_PRESENT} SampleState;

SampleState sample_state;
assign sample_state = sample_counter == 0 ? SAMPLE_TAKE :
                      sample_counter == 1 ? SAMPLE_PROCESS :
                      sample_counter == 2 ? SAMPLE_PRESENT :
                                            SAMPLE_IDLE;

always_ff @(posedge clk48) begin
    if (reset)
        sample_counter <= 0;
    else
        sample_counter <= sample_counter_next;
end

// TODO: Sample three times during the waveform and vote on the bit
logic should_sample;
always_comb begin
    if (reset)
        should_sample = 0;
    else
        case (decoder_state)
            IDLE: should_sample = 1;
            SOP: should_sample = 1;
            SYNC: should_sample = sample_state == SAMPLE_TAKE;
            PAYLOAD: should_sample = sample_state == SAMPLE_TAKE;
            EOP: should_sample = 0;
        endcase
end

typedef enum {BUS_J, BUS_K, BUS_IDLE, BUS_INVALID} BusState;

BusState bus_state_in;
assign bus_state_in = dp == 'b0 && dn == 'b0 ? BUS_IDLE :
                      dp == 'b1 && dn == 'b0 ? BUS_J :
                      dp == 'b0 && dn == 'b1 ? BUS_K :
                      BUS_INVALID;

BusState sampled_bus_state;
BusState last_sampled_bus_state;

// Sample the bus_state_in when requested by the decoder state
always_ff @(posedge clk48) begin
    if (reset) begin
        sampled_bus_state <= BUS_IDLE;
        last_sampled_bus_state <= BUS_IDLE;
    end else begin
        if (should_sample) begin
            sampled_bus_state <= bus_state_in;
            if (decoder_state == SYNC || decoder_state == PAYLOAD)
                last_sampled_bus_state <= sampled_bus_state;
            else
                last_sampled_bus_state <= BUS_IDLE;
        end else begin
            sampled_bus_state <= sampled_bus_state;
            last_sampled_bus_state <= last_sampled_bus_state;
        end
    end
end

always_comb begin
    case (decoder_state)
        IDLE: begin
            if (sampled_bus_state == BUS_K)
                decoder_state_next = SOP;
            else
                decoder_state_next = IDLE;
        end

        SOP: begin
            decoder_state_next = SYNC;
        end

        SYNC: begin
            if (sampled_bus_state == BUS_K &&
                last_sampled_bus_state == BUS_K &&
                sample_state == SAMPLE_PRESENT)
                decoder_state_next = PAYLOAD;
            else
                decoder_state_next = SYNC;
        end

        PAYLOAD: begin
            if (sampled_bus_state != BUS_IDLE)
                decoder_state_next = PAYLOAD;
            else
                decoder_state_next = EOP;
        end

        EOP: begin
                decoder_state_next = IDLE;
        end
    endcase
end

always_ff @(posedge clk48) begin
    if (reset)
        decoder_state <= IDLE;
    else
        decoder_state <= decoder_state_next;
end

logic sampled_nrzi;
assign sampled_nrzi = (sampled_bus_state == last_sampled_bus_state) &&
                      (sampled_bus_state == BUS_J || sampled_bus_state == BUS_K) ? 1 : 0;

localparam BIT_STUFFING_COUNT = 6;
logic [2:0] bit_stuffing_counter_next;
assign bit_stuffing_counter_next = bit_stuffing_counter == BIT_STUFFING_COUNT ? bit_stuffing_counter + 1 :
                                   sampled_nrzi == 1 ? bit_stuffing_counter + 1 :
                                                       0;
logic [2:0] bit_stuffing_counter;
logic bit_stuffing;
assign bit_stuffing = bit_stuffing_counter == (BIT_STUFFING_COUNT + 1);

always_ff @(posedge clk48) begin
    if (reset)
        bit_stuffing_counter <= 0;
    else if (decoder_state == PAYLOAD)
        if (sample_state == SAMPLE_PROCESS)
            bit_stuffing_counter <= bit_stuffing_counter_next;
        else
            bit_stuffing_counter <= bit_stuffing_counter;

    else
        bit_stuffing_counter <= 0;
end


localparam BUS_IDLE_CLKS = 360000;

// Hold the number of cycle in the IDLE decoder state
int idle_counter;
int  idle_counter_next;
assign idle_counter_next = reset == 1 ? 0 :
                           bus_state_in != BUS_IDLE ? 0 :
                           idle_counter < BUS_IDLE_CLKS ? idle_counter + 1 :
                                                       idle_counter;

always_ff @(posedge clk48) begin
    if (reset == 1)
        idle_counter <= 0;
    else
        idle_counter <= idle_counter_next;
end


assign bus_reset = idle_counter == BUS_IDLE_CLKS;
assign bus_sop = decoder_state == SOP ? 'd1 : 'd0;
assign bus_eop = decoder_state == EOP ? 'd1 : 'd0;

assign bit_out = sampled_nrzi;
assign bit_valid = decoder_state == PAYLOAD &&
                   bit_stuffing == 0 &&
                   sample_state == SAMPLE_PRESENT;



endmodule

