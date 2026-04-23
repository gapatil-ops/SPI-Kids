module PWM12(
    input clk,
    input rst_n,
    input [11:0] duty,
    output logic PWM1,
    output logic PWM2
);

    // We use this parameter to ensure that there is a non-overlapping region between the two PWMs. This is important to prevent shoot-through current in applications like H-bridges where both signals might control
    localparam NONOVERLAP = 12'h02C;

    logic [11:0] cnt;
    logic PWM1_S, PWM1_R, PWM2_S, PWM2_R;

    // Free running 12 bit counter that we use to decide when to turn on and off our PWM signals
    always_ff @(posedge clk, negedge rst_n) 
        if (!rst_n)
            cnt <= 12'h000;
        else
            cnt <= cnt + 1;

    // PWM1 and PWM2 Set-Reset (SR) flip flops (reset has higher priority over set)
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n) begin
            PWM1 <= 1'b0;
            PWM2 <= 1'b0;
        end
        else begin
            if (PWM1_R)
                PWM1 <= 1'b0;
            else if (PWM1_S)
                PWM1 <= 1'b1;
            
            if (PWM2_R)
                PWM2 <= 1'b0;
            else if (PWM2_S)
                PWM2 <= 1'b1;
        end

    // We set PWM1 once we're past the beginnning overlap period and reset it once we're past our duty 
    assign PWM1_S = (cnt >= NONOVERLAP);
    assign PWM1_R = (cnt >= duty);

    // We set PW2 once we've finished PWM1's duty + NONOVERLAP
    // We reset PWM2 when our cnt reaches full duty cycle (i.e. the end of its period - all '1s)

    assign PWM2_S = (cnt >= duty + NONOVERLAP);
    assign PWM2_R = &cnt; // we reached 4095, so we should reset as the cnt rolls over


endmodule