module Dterm(
    input [9:0] err_sat,
    input clk,
    input rst_n,
    input hdng_vld,
    output [12:0] D_term
);
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

endmodule