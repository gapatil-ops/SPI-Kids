module Dterm_tb();

    logic clk;
    logic rst_n;
    logic hdng_vld;
    logic [9:0] err_sat;
    logic [12:0] D_term;

    Dterm dterm(.err_sat(err_sat), .clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .D_term(D_term));

    // In this testbench, we're testing the operation of the D-term (derivative) module
    // Note: the #1 delays are necessary to ensure that we give the combinational logic time to update before we check our outputs.

    initial begin
        clk = 0;
        rst_n = 0;
        hdng_vld = 0;
        err_sat = 0;

        @(posedge clk);
        @(negedge clk);
        rst_n = 1; // deassert reset

        // TEST 1: Testing basic operation
        // 1(a)
        hdng_vld = 0;
        err_sat = 0;
        repeat (2) @(negedge clk);
        err_sat = 16;
        
        #1;
        // our previous two values have been 0 and our current is 16, so our output is 16 * coeff
        if (D_term != 12'h0E0) begin
            $display("TEST 1 FAILED: D_term should be 0x0E0 but is %h", D_term);
            $stop(); 
        end

        // 1(b)
        repeat (2) @(negedge clk);
        err_sat = 48;
        #1; 
        // our previous two values have been 16, so our output is (48 - 16) * coeff
        if (D_term != 12'h2A0) begin
            $display("TEST 1B FAILED: D_term should be 0x2A0 but is %h", D_term);
            $stop();
        end

        // TEST 2: Testing positive saturation
        err_sat = 0;
        repeat (2) @(negedge clk);
        err_sat = 511; // this should saturate to 127, so our output should be 127 * coeff
        #1;
        if (D_term != 12'h6F2) begin
            $display("TEST 2 FAILED: D_term should be 0x06F2 but is %h", D_term);
            $stop();
        end

        // TEST 3: Testing negative saturation
        err_sat = 0;
        repeat (2) @(negedge clk);
        err_sat = -512; // this should saturate to -128, so our output should be -128 * coeff
        #1;
        if (D_term != 12'h900) begin
            $display("TEST 3 FAILED: D_term should be 0x900 but is %h", D_term);
            $stop();
        end

        $display("Cool beans!, All Tests Passed!");
        $stop();

    end

    always #5 clk = ~clk;
    

endmodule