module PID(clk, 
        rst_n, 
        moving, 
        dsrd_hdng, 
        actl_hdng, 
        hdng_vld, 
        frwrd_spd, 
        at_hdng, 
        lft_spd, 
        rght_spd);

input clk, rst_n, moving, hdng_vld;
input signed [11:0] dsrd_hdng, actl_hdng;
input [10:0] frwrd_spd;

output at_hdng;
output logic signed [11:0] lft_spd, rght_spd;

// Intermediate signal
logic signed [11:0] error;

assign error = actl_hdng - dsrd_hdng;

// P term 
// Signed localparam for multiply
parameter signed [3:0] P_COEFF = 4'h3;

logic signed [13:0]P_term;         // Signed P component
logic signed [13:0]P_term_temp;    // Flopping
logic signed [14:0]P_term_se;      // Sign extended P component

// Intermediate signal
logic signed [9:0] err_sat_temp;       // Saturated error term

logic signed [9:0] err_sat;            // Saturated error term after flop

// Saturation component
assign err_sat_temp = (error[11] & ~&error[10:9]) ? 10'h200 :
                 (~error[11] & |error[10:9]) ? 10'h1ff :
                 error[9:0];

// Flop saturated error
always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        err_sat <= 10'h000;
    else
        err_sat <= err_sat_temp;
end

// Signed multiply
assign P_term_temp = err_sat*P_COEFF;

// Flop P term
always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        P_term <= 14'h0000;
    else
        P_term <= P_term_temp;
end

// Sign extend
assign P_term_se = {P_term[13],P_term};

// I term
logic signed [11:0] I_term;
logic signed [14:0] I_term_se;

// Intermediate signals
logic signed [15:0] err_sat_sign_extend;
logic signed [15:0] integrator;
logic signed [15:0] err_sat_integrator_sum;
logic overflow;
logic signed [15:0] overflow_checked;
logic signed [15:0] nxt_integrator;

// Sign extend the error signal to 16 bits
assign err_sat_sign_extend = {{6{err_sat[9]}}, err_sat};

// Sum the current integrator and incoming error value to potentially use
assign err_sat_integrator_sum = err_sat_sign_extend + integrator;

// Overflow logic
assign overflow = (err_sat_sign_extend[15] & integrator[15] & ~err_sat_integrator_sum[15]) | (~err_sat_sign_extend[15] & ~integrator[15] & err_sat_integrator_sum[15]);

// Choosing whether to accumulate based on overflow and validity of incoming heading
assign overflow_checked = (~overflow & hdng_vld) ? err_sat_integrator_sum : integrator;

// Checking if PID is active based on if bot is moving
assign nxt_integrator = moving ? overflow_checked : 16'h0000;

// Accumulator register
always_ff @( posedge clk, negedge rst_n ) begin 
    if (!rst_n)
        integrator <= 16'h0000;
    else
        integrator <= nxt_integrator;    
end

assign I_term = integrator[15:4];
assign I_term_se = {{3{I_term[11]}}, I_term};

// D_term
logic signed [12:0] D_term;
logic signed [12:0] D_term_temp;
logic signed [14:0] D_term_se;

// Signed multiply coefficient
parameter signed [4:0] D_COEFF = 5'h0E;

// Intermediate signals
logic signed [9:0] flop1, prev_error;
logic signed [10:0] D_diff;
logic signed [7:0] D_diff_sat;

// D term is based on change in error, so we need to store previous error value in a flop and find the difference
always_ff @( posedge clk, negedge rst_n ) begin 
    if (!rst_n) begin
        flop1 <= 10'b0;
        prev_error <= 10'b0;
    end
    else if (hdng_vld) begin
        flop1 <= err_sat;
        prev_error <= flop1;
    end
end

// Find difference
assign D_diff = err_sat - prev_error;

// Saturate difference
assign D_diff_sat = D_diff[10] ? (&D_diff[9:7] ? D_diff[7:0] : 8'h80) : (|D_diff[9:7] ? 8'h7F : D_diff[7:0]); 

// Signed multiply
assign D_term_temp = D_diff_sat * D_COEFF;

// Flop D term
always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        D_term <= 13'h0000;
    else
        D_term <= D_term_temp;
end

assign D_term_se = {{2{D_term[12]}}, D_term};

// Sum PID terms
logic signed [14:0] PID_sum_temp;

assign PID_sum_temp = P_term_se + I_term_se + D_term_se;

// Pipeline PID sum
logic signed [14:0] PID_sum;

always_ff @( posedge clk, negedge rst_n ) begin
	if (!rst_n)
		PID_sum <= 0;
	else
		PID_sum <= PID_sum_temp;
end

// Divide by 8
logic signed [11:0] PID_trim;

assign PID_trim = PID_sum[14:3];

// Extend frwrd_spd
logic [11:0]frwrd_spd_e;

assign frwrd_spd_e = {1'b0, frwrd_spd};

logic signed [11:0] lft_spd_temp;
logic signed [11:0] rght_spd_temp;

// Left speed mux
assign lft_spd_temp = moving ? (PID_trim + frwrd_spd_e) : 12'h000;

// Right speed mux
assign rght_spd_temp = moving ? (frwrd_spd_e - PID_trim) : 12'h000;

always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n) begin
        lft_spd <= 12'h000;
        rght_spd <= 12'h000;
    end else begin
        lft_spd <= lft_spd_temp;
        rght_spd <= rght_spd_temp;
    end
end

logic signed [9:0] err_abs;
assign err_abs  = err_sat[9] ? -err_sat : err_sat;
assign at_hdng  = (err_abs < 10'd30);

endmodule