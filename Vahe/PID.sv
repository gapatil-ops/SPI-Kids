module PID(
    input clk,
    input rst_n,
    input moving,
    input [11:0] dsrd_hdng,
    input [11:0] actl_hdng,
    input hdng_vld,
    input [10:0] frwrd_spd,
    output at_hdng,
    output [11:0] lft_spd,
    output [11:0] rght_spd
);
    logic signed [13:0] P_term;
    logic [11:0] I_term;
    logic [12:0] D_term;

    logic signed [9:0] err_sat;
    logic [11:0] control;

    localparam thresh = 10'd30;

    ////////////////////
    ////////////////////
    ////  P_TERM  //////
    ////////////////////
    ////////////////////
    logic signed [11:0] error;
    assign error = $signed(actl_hdng) - $signed(dsrd_hdng);
    localparam signed P_COEFF = 4'h3; // Default P coefficient is 3

    // We first saturate our 12-bit error value (positive or negative) to fit in a 10-bit range
    assign err_sat = (!error[11] && |error[10:9]) ? 10'h1FF :
                       (error[11] && ~&error[10:9]) ? 10'h200 :
                        error[9:0];

    // Then calculate the P_term by multipling the saturated error and the P_COEFF
    assign P_term = $signed(err_sat) * $signed(P_COEFF);

    ////////////////////
    ////////////////////
    ////  I_TERM  //////
    ////////////////////
    ////////////////////

    logic [15:0] err_sat_extended;
    logic [15:0] integrator;
    logic [15:0] sum;
    logic [15:0] nxt_integrator;

    logic overflowed;

    // sign extend the error term and add it to the running total
    assign err_sat_extended = {{6{err_sat[9]}},err_sat};
    assign sum = err_sat_extended + integrator;

    // overflow condition evalued
    assign overflowed = (!integrator[15] && !err_sat_extended[15] && sum[15]) || (integrator[15] && err_sat_extended[15] && !sum[15]);

    // we want our integrator to update if we're moving but we have to check if adding the num value causes us to overflow and that
    // the new error value is valid before accumulating
    assign nxt_integrator = (moving) ? ( (!overflowed && hdng_vld) ? sum : integrator ) :  
                                       16'h0000;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            integrator <= 16'h0000;
        end else begin
            integrator <= nxt_integrator;
        end
    end

    assign I_term = integrator[15:4]; // divide integrator value by 16

    ////////////////////
    ////////////////////
    ////  D_TERM  //////
    ////////////////////
    ////////////////////

    // D term is the derivative term, and since we only have to be proportional to the derivative, our D_term is 
    // just the difference between the current error and the error from 2 cycles ago, multiplied by a coefficient.

    localparam D_COEFF = 5'h0E;

    logic [9:0] prev_err_1; // error from 1 cycle ago
    logic [9:0] prev_err_2; // error from 2 cycles ago

    logic [10:0] D_diff; // the derivative we get from taking the cycle differences
    logic [7:0] D_diff_sat; // saturated derivative


    // Back to back register for the previous two error values, updated only when the heading is valid.
    always_ff @ (posedge clk, negedge rst_n)
        if (!rst_n) begin
            prev_err_1 <= '0;
            prev_err_2 <= '0;
        end else if (hdng_vld) begin
            prev_err_1 <= err_sat;
            prev_err_2 <= prev_err_1;
        end 
        // note: error registers implicitly retain their values if the heading isn't valid
    
    // We then calculate our current - previous errors and saturate it to fit into 8 bits.
    assign D_diff = $signed(err_sat) - $signed(prev_err_2);
    assign D_diff_sat = (!D_diff[10] && |D_diff[9:7]) ? 8'h7F:
                        (D_diff[10] && ~&D_diff[9:7]) ? 8'h80:
                        D_diff[7:0];
    
    // Our D_term is just that saturated difference multiplied by a coefficient
    assign D_term = $signed(D_diff_sat) * $signed(D_COEFF);

    ////////////////////
    ////////////////////
    ////  COMBINE  /////
    ////////////////////
    ////////////////////
    

    // sign-extend all of our PID outputs to 15 bits then add all the terms together, then divide by 8! 
    // That's our control value
    logic [15:0] control_intm;
    assign control_intm = {P_term[13],P_term} + {{3{I_term[11]}},I_term} + {{2{D_term[12]}},D_term};
    assign control = control_intm[14:3];

    // For our control, we take our base forward speed and add our control to our left speed and subtract it from
    // our right speed
    assign lft_spd = (moving) ? {1'b0,frwrd_spd} + control : 12'h000;
    assign rght_spd = (moving) ? {1'b0,frwrd_spd} - control : 12'h000;

    // We're at the right heading if the absolute value of our error is below the threshold
    assign at_hdng = ( (err_sat[9]) ? -err_sat : err_sat ) < thresh;

endmodule