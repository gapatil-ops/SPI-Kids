module UART_tx(
    input clk,
    input rst_n,
    input trmt,
    input [7:0] tx_data,
    output TX,
    output logic tx_done
);

    logic [8:0] dataframe;
    logic load; // this is our synchronous signal that initializes our dataframe registers, and both our timers
    logic inc_shift;
    
    // shift register - that shifts lower bits out first
    always_ff @(posedge clk, negedge rst_n) 
        if (!rst_n)
            dataframe <= '1;
        else if (load)
            dataframe <= {tx_data,1'b0}; // 1'b0 is the start bit
        else if (inc_shift)
            dataframe <= {1'b1, dataframe[8:1]}; // 1'b1 is our stop bit and we shift it in

    assign TX = dataframe[0];

    // 12-bit counter to 2604
    logic [12:0] baud_cntr;
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            baud_cntr <= '0;
        else if (load)
            baud_cntr <= '0;
        else if (inc_shift) // this signifies once we reach 2063, we reset our counter
            baud_cntr <= '0;
        else 
            baud_cntr <= baud_cntr + 1;
    assign inc_shift = (baud_cntr == 2603); // we increment our bit counter and shift our bit out when our baud count reaches 2063

    // 4-bit counter up to and including 10
    logic [4:0] bit_cnt;
    logic cnt_hit_10;
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            bit_cnt <= '0;
        else if (load)
            bit_cnt <= '0;
        else if (cnt_hit_10)
            bit_cnt <= '0;
        else if (inc_shift)
            bit_cnt <= bit_cnt + 1;
    assign cnt_hit_10 = (bit_cnt == 10);

    // set-reset flop for tx_done (chef's kiss design)
    logic set_done;
    logic rst_done;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            tx_done <= 1'b0;
        else if (rst_done)
            tx_done <= 1'b0;
        else if (set_done)
            tx_done <= 1'b1;

    
    // STATE MACHINE
    typedef enum logic {CHILLIN, TRANSMIT} state_t;
    state_t state;
    state_t nxt_state;

    // Registers for state machine
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            state <= CHILLIN;
        else 
            state <= nxt_state;
    
    // LOGIC FOR TX STATE MACHINE
    always_comb begin
        nxt_state = state;
        load = 1'b0;
        rst_done = 1'b0;
        set_done = 1'b0;

        case (state) // When we're chillin, we wait until we're told to transmit, then we load in the value, reset the done signal.
                    // and go to the TRANSMIT state.
            CHILLIN: begin
                if (trmt) begin
                    load = 1'b1;
                    rst_done = 1'b1;
                    nxt_state = TRANSMIT;
                end
            end

            TRANSMIT: begin // In the transmit state, inc_shift does most of the work in the background, shifting bits out and incrementing the count
                            // But once our count hits 10, we know that we're done transmitting and we set set_done and go back to chillin.
                if (cnt_hit_10) begin
                    set_done = 1'b1;
                    nxt_state = CHILLIN;
                end
            end
        endcase
    end

endmodule