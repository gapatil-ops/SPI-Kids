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
logic signed [11:0] sum_actl_dsrd;
logic signed [9:0] err_sat;
logic signed [13:0] P_term;
logic signed [15:0] err_sat_sign_extend;
logic [15:0] accumulator;
logic signed [15:0] integrator;
logic overflow;
logic mux_1_sel_input;
logic [15:0] mux_1_output;
logic [15:0] mux_2_output;
logic [15:0] nxt_integrator;
logic signed [11:0] I_term;
logic signed [12:0] D_term;
logic signed [14:0] summation;
logic signed [14:0] sum_div_8;
logic signed [11:0] frwrd_spd_scaled;
logic signed [11:0] lft_input;
logic signed [11:0] rght_input;


assign sum_actl_dsrd = $signed(actl_hdng) - $signed(dsrd_hdng);


assign err_sat = (sum_actl_dsrd[11] && ~&sum_actl_dsrd[10:9])? 10'b1000000000 :
                 (~sum_actl_dsrd[11] && |(sum_actl_dsrd[10:9]))? 10'b0111111111 :
                 sum_actl_dsrd[9:0];

localparam signed [3:0] P_COEFF = 4'h3;

// Multiplying saturated error with P coefficient to get 14 bit P term
assign P_term = err_sat * P_COEFF;

//Sign extending err_sat to 16 bits
assign err_sat_sign_extend = (err_sat[9]==1'b1) ? {6'b111111, err_sat} : {6'b000000, err_sat};

//Accumulator logic- adding integrator and sign e
assign accumulator = $signed(integrator) + $signed(err_sat_sign_extend);

//Overflow logic
assign overflow = ((err_sat_sign_extend[15] & integrator[15] & !accumulator[15]) || (!err_sat_sign_extend[15] & !integrator[15] & accumulator[15])) ?
                    1'b1 : 1'b0;

assign mux_1_sel_input = !overflow & hdng_vld ;
assign mux_1_output = mux_1_sel_input ? accumulator : integrator ;
assign mux_2_output = moving ? mux_1_output : 16'h0000;
assign nxt_integrator = mux_2_output;

assign I_term = integrator[15:4];

//Synchronously updating integrator based on clock
always_ff @(posedge clk, negedge rst_n ) begin
    if(!rst_n) begin
        integrator <= 16'h0000;
    end
    else begin
        integrator <= nxt_integrator;
    end
end

logic [9:0] first_ff_out;
logic [9:0] second_ff_out;
logic signed [10:0] D_diff;
logic signed [7:0] D_diff_sat;
localparam [4:0] D_COEFF = 5'h0E;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        first_ff_out <= 0;
        second_ff_out <= 0;
    end else if (hdng_vld) begin
        first_ff_out <= err_sat;
        second_ff_out <= first_ff_out;
    end
end

// Use $signed to ensure 11-bit signed math
assign D_diff = $signed(err_sat) - $signed(second_ff_out);

// Positive saturation (7F): bit 10 is 0, but bits 9, 8, or 7 are high
// Negative saturation (80): bit 10 is 1, but bits 9, 8, and 7 are NOT all 1
assign D_diff_sat = (!D_diff[10] && |D_diff[9:7]) ? 8'b01111111 :
                    (D_diff[10] && !(&D_diff[9:7])) ? 8'b10000000 :
                    D_diff[7:0];

assign D_term = $signed(D_diff_sat) * $signed(D_COEFF);

assign at_hdng = (err_sat[9]) ? (~(err_sat) + 1'b1 < 10'd30) : (err_sat < 10'd30);

assign summation = $signed({{1{P_term[13]}}, P_term}) +
                   $signed({{3{I_term[11]}}, I_term}) +
                   $signed({{2{D_term[12]}}, D_term});

assign sum_div_8 = summation >>> 3;

assign frwrd_spd_scaled = {1'b0, frwrd_spd};


assign lft_input = $signed(frwrd_spd_scaled) + $signed(sum_div_8[11:0]);
assign rght_input = $signed(frwrd_spd_scaled) - $signed(sum_div_8[11:0]);

assign lft_spd = (moving) ? lft_input : 12'h000;
assign rght_spd = (moving) ? rght_input : 12'h000;

endmodule
