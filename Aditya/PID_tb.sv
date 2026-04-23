`timescale 1ns/1ps
module PID_tb();

    //------------------------------------------------------
    // Clock & DUT signals
    //------------------------------------------------------
    logic        clk;
    logic        rst_n, moving, hdng_vld;
    logic [11:0] dsrd_hdng, actl_hdng;
    logic [10:0] frwrd_spd;

    logic        at_hdng;
    logic [11:0] lft_spd, rght_spd;

    //------------------------------------------------------
    // Stimulus / response memories (2000 vectors each)
    //------------------------------------------------------
    logic [37:0] stim_mem [0:1999];
    logic [24:0] resp_mem [0:1999];

    //------------------------------------------------------
    // DUT instantiation
    //------------------------------------------------------
    PID iDUT (
        .clk      (clk),
        .rst_n    (rst_n),
        .moving   (moving),
        .hdng_vld (hdng_vld),
        .dsrd_hdng(dsrd_hdng),
        .actl_hdng(actl_hdng),
        .frwrd_spd(frwrd_spd),
        .at_hdng  (at_hdng),
        .lft_spd  (lft_spd),
        .rght_spd (rght_spd)
    );

    //------------------------------------------------------
    // Clock generation — starts LOW, period = 10
    //------------------------------------------------------
    initial clk = 1'b0;
    always  #5  clk = ~clk;

    //------------------------------------------------------
    // Main stimulus & self-check block
    //------------------------------------------------------
    integer i;
    integer errors;

    logic        exp_at_hdng;
    logic [11:0] exp_lft_spd, exp_rght_spd;

    initial begin
        $readmemh("PID_stim.hex", stim_mem);
        $readmemh("PID_resp.hex", resp_mem);

        // Assert reset for 5 cycles
        rst_n = 0;
        moving = 0;
        hdng_vld = 0;
        dsrd_hdng = 0;
        actl_hdng = 0;
        frwrd_spd = 0;

        repeat (5) @(negedge clk);

        errors = 0;

        for (i = 0; i < 2000; i = i + 1) begin

            // Drive inputs while clock is low
            @(negedge clk);
            rst_n     = stim_mem[i][37];
            moving    = stim_mem[i][36];
            hdng_vld  = stim_mem[i][35];
            dsrd_hdng = stim_mem[i][34:23];
            actl_hdng = stim_mem[i][22:11];
            frwrd_spd = stim_mem[i][10:0];

            // Wait 1 time unit after the rising edge to sample outputs
            @(posedge clk);
            #1;

            // Decode expected outputs
            exp_at_hdng  = resp_mem[i][24];
            exp_lft_spd  = resp_mem[i][23:12];
            exp_rght_spd = resp_mem[i][11:0];

            // Compare
            if (at_hdng !== exp_at_hdng) begin
                $display("ERROR vector %0d: at_hdng  = %b,   expected %b",
                         i, at_hdng, exp_at_hdng);
                errors = errors + 1;
            end
            if (lft_spd !== exp_lft_spd) begin
                $display("ERROR vector %0d: lft_spd  = %h, expected %h",
                         i, lft_spd, exp_lft_spd);
                errors = errors + 1;
            end
            if (rght_spd !== exp_rght_spd) begin
                $display("ERROR vector %0d: rght_spd = %h, expected %h",
                         i, rght_spd, exp_rght_spd);
                errors = errors + 1;
            end
        end

        if (errors == 0) begin
            $display("YAHOO!! All 2000 vectors passed!.");
            $display("Jyotiraditya Patil");
        end
        else
            $display("FAIL: %0d error(s) found across 2000 vectors.", errors);

        $stop;
    end

endmodule
