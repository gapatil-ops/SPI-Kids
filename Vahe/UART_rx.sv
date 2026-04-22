module UART_rx(
    input RX,
    input clk,
    input rst_n,
    input clr_rdy,
    output [7:0] rx_data,
    output logic rdy
);

    // let's clear out our metastability
    logic RX_stable;
    logic RX_intermediate;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin // we preset our RX flops to 1 because the RX line should idly be high
            RX_stable <= '1;
            RX_intermediate <= '1;
        end else begin
            RX_stable <= RX_intermediate;
            RX_intermediate <= RX;
        end
    end

    logic [8:0] dataframe;
    logic inc_shift;
    logic receiving;
    
    // shift-in register - that shifts in and to the right
    always_ff @(posedge clk, negedge rst_n) 
        if (!rst_n)
            dataframe <= '0;
        else if (inc_shift && receiving)
            dataframe <= {RX_stable, dataframe[8:1]}; // we shift in RX_stable to our dataframe
    
    // our rx_data is the lower 8 bits of our dataframe
    assign rx_data = dataframe[7:0];

    // 12-bit down-counter from 2604 or 1302
    logic [12:0] baud_cntr;
    logic init; // init is the signal that lets us know we should load our timer halfway and load our bit counter to 0

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            baud_cntr <= '0;
        else if (init)
            baud_cntr <= 1301;
        else if (inc_shift)
            baud_cntr <= 2603;
        else 
            baud_cntr <= baud_cntr - 1;
    
    assign inc_shift = ~|baud_cntr; // we increment our bit counter and shift our bit in once our baud counter reaches 0;

    // 4-bit counter up to and including 10
    logic [4:0] bit_cnt;
    logic cnt_hit_10;
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            bit_cnt <= '0;
        else if (init)
            bit_cnt <= '0;
        else if (cnt_hit_10)
            bit_cnt <= '0;
        else if (inc_shift)
            bit_cnt <= bit_cnt + 1;
    assign cnt_hit_10 = (bit_cnt == 10);

    // set-reset flop for rdy (chef's kiss design)
    logic set_rdy;
    
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            rdy <= 1'b0;
        else if (clr_rdy)
            rdy <= 1'b0;
        else if (set_rdy)
            rdy <= 1'b1;

    
    // STATE MACHINE
    typedef enum logic {CHILLIN, RECEIVE} state_t;
    state_t state;
    state_t nxt_state;

    // state machine registers
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            state <= CHILLIN;
        else 
            state <= nxt_state;
    
    // LOGIC FOR RX STATE MACHINE
    always_comb begin
        nxt_state = state;
        init = 1'b0;
        set_rdy = 1'b0;
        receiving = 1'b0;

        case (state) // When we're chillin, we wait for RX_stable to go low, which indicates the start bit. At that point
                    // we assert init and move to the RECEIVE state.
            CHILLIN: begin
                if (!RX_stable) begin // i.e. RX_stable goes low
                    init = 1'b1;
                    nxt_state = RECEIVE;
                end
            end

            RECEIVE: begin // In the RECEIVE state, we assert receiving so that we can shift in bits and count them.
                           // In the background, we have inc_shift incrementing the data in from the RX line and incrementing the counter.
                receiving = 1'b1;
                if (cnt_hit_10) begin
                    set_rdy = 1'b1;
                    nxt_state = CHILLIN;
                end
            end
        endcase
    end

endmodule