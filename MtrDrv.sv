module MtrDrv(lft_spd, vbatt, rght_spd, lftPWM1, lftPWM2, rghtPWM1, rghtPWM2, clk, rst_n);

input clk, rst_n;
input [11:0] vbatt; // 12-bit battery voltage level input
input signed [11:0] lft_spd, rght_spd;
output lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;

logic signed  [11:0] lft_scaled, rght_scaled;
wire [12:0] scalefactor;
wire signed [23:0] lft_prod, rght_prod;
wire [11:0] lft_duty, rght_duty;

DutyScaleROM scaleROM(.clk(clk), .batt_level(vbatt[9:4]), .scale(scalefactor));


assign lft_prod = lft_spd * $signed({1'b0, scalefactor});
assign rght_prod = rght_spd * $signed({1'b0, scalefactor});


// Assuming lft_prod is a 24-bit signed wire
wire signed [23:0] shifted_prod;
assign shifted_prod = lft_prod >>> 11; // Divide by 2048

// 12-bit Saturation Logic
always_comb begin
    if (shifted_prod > 24'sd2047) begin
        lft_scaled = 12'sd2047;       // Cap at max positive (12'h7FF)
    end 
    else if (shifted_prod < -24'sd2048) begin
        lft_scaled = -12'sd2048;      // Cap at max negative (12'h800)
    end 
    else begin
        lft_scaled = shifted_prod[11:0]; // Value is safe, keep it
    end
end


// Repeat the same for rght_prod
wire signed [23:0] shifted_prod_r;
assign shifted_prod_r = rght_prod >>> 11; // Divide by 2048

always_comb begin
    if (shifted_prod_r > 24'sd2047) begin
        rght_scaled = 12'sd2047;       // Cap at max positive (12'h7FF)
    end 
    else if (shifted_prod_r < -24'sd2048) begin
        rght_scaled = -12'sd2048;      // Cap at max negative (12'h800)
    end 
    else begin
        rght_scaled = shifted_prod_r[11:0]; // Value is safe, keep it
    end
end




assign lft_duty = 12'h800 + lft_scaled; // Shift to unsigned range for PWM input
assign rght_duty = 12'h800 - rght_scaled; // Shift to unsigned range for PWM input

PWM12 lft_pwm_gen(.clk(clk), .rst_n(rst_n), .duty(lft_duty), .PWM1(lftPWM1), .PWM2(lftPWM2));
PWM12 rght_pwm_gen(.clk(clk), .rst_n(rst_n), .duty(rght_duty), .PWM1(rghtPWM1), .PWM2(rghtPWM2));





endmodule