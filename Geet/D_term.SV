module D_term (
    input  logic               clk,
    input  logic               rst_n,
    input  logic               hdng_vld,    // New heading valid (sample clock)
    input  logic signed [9:0]  err_sat,     // P-term error saturated to 10-bits
    output logic signed [12:0] D_term
);

    // D_COEFF = 14. Defined as 6-bit signed for proper multiplication.
    localparam signed [5:0] D_COEFF = 6'h0E; 

    logic signed [9:0]  q1;
    logic signed [9:0]  prev_err;
    logic signed [10:0] D_diff; 
    logic signed [7:0]  D_diff_sat;

    // *** Cascaded Delay Registers ***
    // We capture two previous samples to calculate the derivative
    // Logic only updates when 'hdng_vld' is asserted 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1       <= 10'sb0;
            prev_err <= 10'sb0;
        end else if (hdng_vld) begin
            q1       <= err_sat;    // Current error becomes next cycle's q1
            prev_err <= q1;         // q1 becomes next cycle's prev_err
        end
    end

    // *** Difference Calculation ***
    // D_diff = Current_Error - Previous_Error. 
    // Sign extension to 11-bits prevents overflow during subtraction.
    assign D_diff = $signed({err_sat[9], err_sat}) - $signed({prev_err[9], prev_err});


    // *** Saturation to 8-bits ***
    always_comb begin
        if (D_diff > 11'sd127)
            D_diff_sat = 8'sd127;
        else if (D_diff < -11'sd128)
            D_diff_sat = -8'sd128;
        else
            // Safe to truncate if within range
            D_diff_sat = D_diff[7:0]; 
    end

    // *** Final D Multiplication ***
    // Multiplies the change (slope) by the derivative coefficient.
    assign D_term = $signed(D_diff_sat) * $signed(D_COEFF);

endmodule