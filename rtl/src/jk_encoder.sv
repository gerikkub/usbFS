


module jk_encoder (
    input reset, clk48,
    input start_txn,
    input bit_in,
    input last_bit,
    output bit_ack,
    output dp, dn,
    output done
);

typedef enum {IDLE, SYNC, PAYLOAD, EOP, COMPLETE} EncoderState;

EncoderState encoder_state;
EncoderState encoder_state_next;

typedef enum {WRITE_IDLE, WRITE_SE0, WRITE_J, WRITE_K} OutputState;

OutputState output_state;
OutputState output_state_next;

assign bit_ack = encoder_state == PAYLOAD &&
                 write_counter == 1 &&
                 should_bitstuff == 0 ? 1 : 0;

assign dp = output_state == WRITE_IDLE ? 1 :
            output_state == WRITE_SE0 ? 0 :
            output_state == WRITE_J ? 1 : 0;

assign dn = output_state == WRITE_IDLE ? 0 :
            output_state == WRITE_SE0 ? 0 :
            output_state == WRITE_J ? 0 : 1;

assign done = encoder_state == COMPLETE;

localparam WRITE_COUNT = 3;
int write_counter;

// Write counter cycles between 0 and 3 in the
// SYNC, PAYLOAD and EOP states
// A value of three signals that the output
// should be revaluated in these states
always_ff @(posedge clk48) begin
    if (reset)
        write_counter <= 'd0;
    else
        case (encoder_state)
            IDLE, COMPLETE:
                write_counter <= 0;
            SYNC, PAYLOAD, EOP:
                if (write_counter == WRITE_COUNT)
                    write_counter <= 0;
                else
                    write_counter <= write_counter + 1;
        endcase
end

// Hold the last written value
always_ff @(posedge clk48) begin
    if (reset)
        output_state <= WRITE_IDLE;
    else
        output_state <= output_state_next;
end


localparam SYNC_COUNT = 7;
int sync_counter;

always_ff @(posedge clk48) begin
    if (reset)
        sync_counter <= 0;
    else
        case (encoder_state)
            IDLE, PAYLOAD, EOP, COMPLETE:
                sync_counter <= 0;
            SYNC:
                if (write_counter == WRITE_COUNT)
                    sync_counter <= sync_counter + 1;
                else
                    sync_counter <= sync_counter;
        endcase
end

localparam EOP_COUNT = 3;
int eop_counter;

always_ff @(posedge clk48) begin
    if (reset)
        eop_counter <= 0;
    else
        case (encoder_state)
            IDLE, SYNC, PAYLOAD, COMPLETE:
                eop_counter <= 0;
            EOP:
                if (write_counter == WRITE_COUNT)
                    eop_counter <= eop_counter + 1;
                else
                    eop_counter <= eop_counter;
        endcase
end

localparam STUFFING_COUNT = 6;
int stuffing_counter;

// Count the number of 1 bits written
// during the SYNC and PAYLOAD stages
always_ff @(posedge clk48) begin
    if (reset)
        stuffing_counter <= 0;
    else
        case (encoder_state)
            IDLE, COMPLETE:
                stuffing_counter <= 0;
            SYNC, PAYLOAD:
                if (write_counter == 0)
                    if (output_state_next == one_val)
                        stuffing_counter <= stuffing_counter + 1;
                    else
                        stuffing_counter <= 0;
                else
                    stuffing_counter <= stuffing_counter;
        endcase
end

logic should_bitstuff;
assign should_bitstuff = stuffing_counter == 6;

OutputState one_val;
OutputState zero_val;
assign one_val = output_state;
assign zero_val = output_state == WRITE_J ? WRITE_K : WRITE_J;

always_comb begin
    if (reset)
        output_state_next = WRITE_IDLE;
    else
        case (encoder_state)
            IDLE:
                output_state_next = WRITE_IDLE;
            SYNC:
                if (write_counter == 0)
                    case (sync_counter)
                        0, 2, 4, 6, 7:
                            output_state_next = WRITE_K;
                        default:
                            output_state_next = WRITE_J;
                    endcase
                else
                    output_state_next = output_state;
            PAYLOAD:
                if (write_counter == 0)
                    if (should_bitstuff)
                        output_state_next = zero_val;
                    else
                        output_state_next = bit_in == 0 ? zero_val : one_val;
                else
                    output_state_next = output_state;
            EOP:
                if (write_counter == 0)
                    case (eop_counter)
                        0, 1:
                            output_state_next = WRITE_SE0;
                        default:
                            output_state_next = WRITE_J;
                    endcase
                else
                    output_state_next = output_state;
            COMPLETE:
                 output_state_next = WRITE_J;
        endcase
end

always_ff @(posedge clk48) begin
    if (reset)
        encoder_state <= IDLE;
    else
        encoder_state <= encoder_state_next;
end

logic last_payload;

always_ff @(posedge clk48) begin
    if (reset)
        last_payload <= 0;
    else
        if (encoder_state == PAYLOAD)
            if (write_counter == WRITE_COUNT &&
                last_bit == 1)
                last_payload <= 1;
            else
                last_payload <= last_payload;
        else
            last_payload <= 0;
end

always_comb begin
    case (encoder_state)
        IDLE:
            encoder_state_next =
                start_txn == 1 ? SYNC :
                                 IDLE;
        SYNC:
            encoder_state_next =
                sync_counter == SYNC_COUNT &&
                write_counter == WRITE_COUNT ? PAYLOAD :
                                               SYNC;
        PAYLOAD:
            encoder_state_next =
                write_counter == WRITE_COUNT &&
                should_bitstuff == 0 &&
                last_payload == 1 ? EOP :
                                    PAYLOAD;

        EOP:
            encoder_state_next =
                eop_counter == EOP_COUNT ? COMPLETE :
                                           EOP;
        COMPLETE:
            encoder_state_next = IDLE;
    endcase
end

/*
reg write_j;
reg write_se0;
reg stuff_bit;
reg bit_ack_reg;

assign bit_ack = bit_ack_reg;

assign dp = output_state == WRITE_SE0 ? 0 :
            output_state == WRITE_J ? 1 : 0;

assign dn = output_state == WRITE_SE0 ? 0 :
            output_state == WRITE_J ? 0 : 1;

assign done = encoder_state == COMPLETE;

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
*/

endmodule
