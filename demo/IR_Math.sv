module IR_math(
    input lft_opn,
    input clk,
    input rght_opn,
    input [11:0] lft_IR,
    input [11:0] rght_IR,
    input [8:0] IR_Dtrm,
    input en_fusion,
    input [11:0] dsrd_hdng,
    output logic [11:0] dsrd_hdng_adj
);

    parameter NOM_IR = 12'h900;

    logic [12:0] IR_diff;
    logic [11:0] IR_diff_no_right; 
    logic [11:0] IR_diff_no_left;

    logic [11:0] IR_selected;
    logic [12:0] div_and_extend;
    logic [12:0] mult_and_extend;
    logic [12:0] sum_of_extend;

    logic [11:0] heading_adjustment;

    // These signals represent the difference between the IR readings in 3 cases
    // when both the left and right readings are valid, when only the left is valid,
    // and when only the right is valid
    assign IR_diff = lft_IR - rght_IR; 
    assign IR_diff_no_right = lft_IR - NOM_IR;
    assign IR_diff_no_left = NOM_IR - rght_IR;

    // We then select which IR_reading to use based on whether the left or right is open, neither is open or both are open
    assign IR_selected = (lft_opn & rght_opn) ? 12'h000 :
                         (lft_opn) ? IR_diff_no_left :
                         (rght_opn) ? IR_diff_no_right :
                         IR_diff[12:1];

    
    // Extend some IR signals to be used later on
    // the div_and_extend essentially represents our P_term
    // the mult_and extend is our D_term
    assign div_and_extend = {{6{IR_selected[11]}},IR_selected[11:5]}; // Divide by 32 with sign extension to 13 bits
    assign mult_and_extend = {{2{IR_Dtrm[8]}}, IR_Dtrm, 2'b00}; // Multiply by 4 with sign extension to 13 bits

    assign sum_of_extend = div_and_extend + mult_and_extend;
    assign heading_adjustment = sum_of_extend[12:1]; // add the P_term and D_term and divide by 2 to get our adjustment

    // if we're doing fusion, we adjust our dsrd_hdng with the adjustment
    logic [11:0] dsrd_hdng_adj_temp;

    assign dsrd_hdng_adj_temp = en_fusion ? (dsrd_hdng + heading_adjustment) : dsrd_hdng;

    always_ff @( posedge clk ) begin
        dsrd_hdng_adj <= dsrd_hdng_adj_temp;
    end

endmodule