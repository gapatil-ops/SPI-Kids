module MtrDrv(
    input [11:0] lft_spd,
    input [11:0] vbatt,
    input [11:0] rght_spd,
    input clk,
    input rst_n,
    output lftPWM1,
    output lftPWM2,
    output rghtPWM1,
    output rghtPWM2
);

    logic [12:0] scale_factor;
    DutyScaleROM lookupTable(.clk(clk), .batt_level(vbatt[9:4]), .scale(scale_factor));

    logic signed [23:0] lft_prod_temp;
    logic signed [23:0] rght_prod_temp;

    logic signed [23:0] lft_prod;
    logic signed [23:0] rght_prod;

    assign lft_prod_temp = $signed(scale_factor) * $signed(lft_spd);
    assign rght_prod_temp = $signed(scale_factor) * $signed(rght_spd);

    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            lft_prod <= 24'h000000;
            rght_prod <= 24'h000000;
        end else begin
            lft_prod <= lft_prod_temp;
            rght_prod <= rght_prod_temp;
        end
    end

    logic [11:0] lft_scaled;
    logic [11:0] rght_scaled;

    assign lft_scaled = (lft_prod[23] && ~lft_prod[22]) ? 12'h800: /*Sat negative*/
                        (~lft_prod[23] && lft_prod[22]) ? 12'h7FF: /*Sat postive*/
                        lft_prod[22:11]; /*grab the correct 12 bit value*/
    
    assign rght_scaled = (rght_prod[23] && ~rght_prod[22]) ? 12'h800: /*Sat negative*/
                        (~rght_prod[23] && rght_prod[22]) ? 12'h7FF: /*Sat postive*/
                        rght_prod[22:11]; /*grab the correct 12 bit value*/

    logic [11:0] lft_scaled_unsigned;
    logic [11:0] rght_scaled_unsigned;

    /*Convert to unsigned by adding 2048*/
    assign lft_scaled_unsigned = 12'h800  + lft_scaled; 
    assign rght_scaled_unsigned = 12'h800 - rght_scaled;

    PWM12 leftPWM(.clk(clk), .rst_n(rst_n), .duty(lft_scaled_unsigned), .PWM1(lftPWM1), .PWM2(lftPWM2));
    PWM12 rghtPWM(.clk(clk), .rst_n(rst_n), .duty(rght_scaled_unsigned), .PWM1(rghtPWM1), .PWM2(rghtPWM2));

endmodule