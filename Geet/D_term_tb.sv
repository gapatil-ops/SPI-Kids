module Dterm_tb();

    // Testbench signals
    logic               clk;
    logic               rst_n;
    logic               hdng_vld;
    logic signed [9:0]  err_sat;
    logic signed [12:0] D_term_out;

    // Instantiate the D_term module
    D_term iDUT(
        .clk(clk),
        .rst_n(rst_n),
        .hdng_vld(hdng_vld),
        .err_sat(err_sat),
        .D_term(D_term_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Sequential Test Sequence
    initial begin
        // 1. Initialize signals and apply reset
        err_sat = 10'sd0;
        hdng_vld = 1'b0;
        rst_n = 1'b0;
        
        @(negedge clk);
        rst_n = 1'b1; // Deassert reset
        hdng_vld = 1'b1; // Enable the pipeline for testing
        
        // ---------------------------------------------------------
        // Test 1: Simple positive difference
        // Currently prev_err = 0.
        // err_sat = 10. Difference = 10 - 0 = 10.
        // D_term = 10 * 14 = 140
        // ---------------------------------------------------------
        err_sat = 10'sd10;
        #1; // Wait 1 unit of time for math to calculate
        if (D_term_out !== 13'sd140) 
            $display("ERR: Test 1 failed. Expected 140, got %d", D_term_out);
        else 
            $display("GOOD: Test 1 passed");
            
        // Wait two clock cycles to let the '10' shift all the way into prev_err
        @(negedge clk); 
        @(negedge clk); 

        // ---------------------------------------------------------
        // Test 2: Simple negative difference
        // Currently prev_err = 10.
        // err_sat = -5. Difference = -5 - 10 = -15.
        // D_term = -15 * 14 = -210
        // ---------------------------------------------------------
        err_sat = -10'sd5;
        #1;
        if (D_term_out !== -13'sd210) 
            $display("ERR: Test 2 failed. Expected -210, got %d", D_term_out);
        else 
            $display("GOOD: Test 2 passed");

        // Wait two clock cycles to let the '-5' shift all the way into prev_err
        @(negedge clk); 
        @(negedge clk); 

        // ---------------------------------------------------------
        // Test 3: Positive Saturation
        // Currently prev_err = -5.
        // err_sat = 300. Difference = 300 - (-5) = 305.
        // 305 saturates to 127. D_term = 127 * 14 = 1778.
        // ---------------------------------------------------------
        err_sat = 10'sd300;
        #1;
        if (D_term_out !== 13'sd1778) 
            $display("ERR: Test 3 failed. Expected 1778, got %d", D_term_out);
        else 
            $display("GOOD: Test 3 passed");
            
        // Wait two clock cycles to let the '300' shift all the way into prev_err
        @(negedge clk); 
        @(negedge clk); 

        // ---------------------------------------------------------
        // Test 4: Negative Saturation
        // Currently prev_err = 300.
        // err_sat = -200. Difference = -200 - 300 = -500.
        // -500 saturates to -128. D_term = -128 * 14 = -1792.
        // ---------------------------------------------------------
        err_sat = -10'sd200;
        #1;
        if (D_term_out !== -13'sd1792) 
            $display("ERR: Test 4 failed. Expected -1792, got %d", D_term_out);
        else 
            $display("GOOD: Test 4 passed");

        $display("D_term testing complete!");
        $display("Submitted by Geet Patil, gapatil, SP26");
        $stop;
    end

endmodule