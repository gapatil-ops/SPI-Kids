module SPI_main(
    input clk,
    input rst_n,
    input wrt,
    input [15:0] wt_data,
    input MISO,
    output logic SS_n,
    output SCLK,
    output MOSI,
    output logic done,
    output logic [15:0] rd_data
);

    // CLOCK DIVIDER LOGIC
    logic load_SCLK;
    logic running;

    logic smpl;
    logic shft_imm;

    logic [4:0] tmr; // we use this timer signal to divide the clock, by having the timer 
                     // have a period of x32 the clk, and thus 1/32 of the frequency
    
    // the running timer goes to 31 and then rolls over
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            tmr <= 5'b10111;
        else if (load_SCLK)
            tmr <= 5'b10111;
        else
            tmr <= tmr + 1;

    assign SCLK = tmr[4]; // the MSB Of tmr is low for half of its count cycle and high for half of it, thus it can act as our 50% clock
    
    assign smpl = (tmr == 5'b01111); // we're on a rising edge
    assign shft_imm = &tmr; // we're on a falling edge (all 1s)


    // SHIFT REGISTER
    // We're going to use rd_data as the shift register output where we first load
    // the new value and then shift out the old MSB bits as we shift in the new bits from the LSB side to reach the MSB side
    
    // FIRST want to be able to sample the MISO value
    logic MISO_smpl;
    logic shft;
    logic load;

    always_ff @(posedge clk)
        if (smpl)
            MISO_smpl <= MISO;        

    // WE have a shift register
        
    logic init; // that we want to be able to initialize with our value from our boss

    always_ff @(posedge clk) begin
        if (init)
            rd_data <= wt_data;
        else if (shft)
            rd_data <= {rd_data[14:0],  MISO_smpl};
    end

    // SR flip flop for SS_n
    logic finish;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            SS_n <= '1;
        else if (finish)
            SS_n <= '1;
        else if (init)
            SS_n <= '0;


    // SR flip flop for done

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            done <= '0;
        else if (init)
            done <= '0;
        else if (finish)
            done <= '1;
    
    assign MOSI = rd_data[15];

    // BIT CNTR
    logic [3:0] bit_cnt; 
    logic done_15;

    always_ff @(posedge clk)
        if (init)
            bit_cnt <= '0;
        else if (shft)
            bit_cnt <= bit_cnt + 1;
        
    assign done_15 = &bit_cnt;


    /////////////////////////////////
    /////////////////////////////////
    // I SPI WITH MY LITTLE EYE SM //
    /////////////////////////////////
    /////////////////////////////////

    typedef enum logic [1:0] {CHILLIN, FRONT_PORCH, TRANSCEIVE} state_t;

    state_t state;
    state_t nxt_state;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            state <= CHILLIN;
        else 
            state <= nxt_state;


    always_comb begin
    
        shft = 1'b0;
        load_SCLK = 1'b0;
        finish = 1'b0;
        init = 1'b0;
        nxt_state = state;

        case (state)

            CHILLIN: begin // While chilling, we assert load_SCLK because we want to maintain our SCLK line at high

                load_SCLK = 1'b1;
                if (wrt) begin // If we get a write instruction, we assert init, which:
                    init = 1'b1; // loads in the wt_data into our send/receive register, asserts chip select, 
                                 // initializes the clk divider, and initializes the bit count
                    nxt_state = FRONT_PORCH;
                end
            end

            FRONT_PORCH: begin // In the front porch state, we're waiting to see our first falling edge. Normally at the falling
                               // edge, we'd shift in a new value, but for this first one, we don't want to, so shft shouldn't be
                               // asserted even if shft_imm (at negedge) is.
                if (shft_imm)
                    nxt_state = TRANSCEIVE;
            end

            TRANSCEIVE: begin // When we're transceiving, we want to shift when our shft_imm value is asserted
                              // Meanwhile, in the background ....

                              // smpl is ensuring that we sample the incoming bit at the rising edge
                              // shft is automatically shifting in the new bits at the negative edge
                              // and shft is also incrementing bit counter, so we can keep track of how many bits we've shifted
                shft = shft_imm;

                // BACKPORCH PORTION
                if (shft && done_15) begin // If we've already finished shifting 15 times and we're about to do our last shift,
                                           // then that means that we've already sampled 16 times, and we want to shift in the
                                           // 16th final bit on an "about to be falling edge."

                                           // So, we want to prevent the clock from falling since we're done by asserting LD_SCLK
                                           // And finish up by deasserting chip select and saying we're done through the finish signal
                                           // Then, we go back to chillin
                    finish = 1'b1;
                    load_SCLK = 1'b1;
                    nxt_state = CHILLIN;
                end
            end
            
            default: begin
                nxt_state = CHILLIN;
            end

        endcase
    end


endmodule