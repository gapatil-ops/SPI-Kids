module PID (
    input  logic               clk,
    input  logic               rst_n,
    input  logic               moving,
    input  logic signed [11:0] dsrd_hdng,
    input  logic signed [11:0] actl_hdng,
    input  logic               hdng_vld,
    input  logic        [10:0] frwrd_spd,
    output logic               at_hdng,
    output logic signed [11:0] lft_spd,
    output logic signed [11:0] rght_spd
);

    // Parameters & Internal Signals
    localparam P_COEFF = 4'h3; 
    localparam signed [5:0] D_COEFF = 6'h0E; 

    // Global Error Signals
    logic signed [11:0] error;
    logic signed [9:0]  err_sat;
    logic        [9:0]  abs_err;

    // Term Outputs
    logic signed [13:0] P_term;
    logic signed [11:0] I_term;
    logic signed [12:0] D_term;

    // Assembly Signals
    logic signed [14:0] PID_sum;
    logic signed [11:0] pid_div8;
    logic signed [11:0] frwrd_spd_ext;

    // *** Global Error & Saturation Logic ***

    // Calculate error 
    assign error = actl_hdng - dsrd_hdng;

    // 10-bit Saturation (From your P_term) 
    assign err_sat =
        (error >  12'sd511) ? 10'sd511 :
        (error < -12'sd512) ? -10'sd512 :
        error[9:0];

    // Calculate at_hdng [cite: 58-60]
    assign abs_err = (err_sat[9]) ? -err_sat : err_sat;
    assign at_hdng = (abs_err < 10'd30);


    //********* P_term Logic*************
    // Concatenate a 0 to P_COEFF to treat it as a positive signed number 
    assign P_term = $signed(err_sat) * $signed({1'b0, P_COEFF});


    //******** I_term Logic  ***************** 

    logic [15:0] integrator;
    wire  [15:0] err_sat_ext = { {6{err_sat[9]}}, err_sat };
    wire  [15:0] sum;
    wire         ov;
    wire         and0;
    wire  [15:0] mux1;
    wire  [15:0] nxt_integrator;

    assign sum = err_sat_ext + integrator;
    assign ov = (err_sat_ext[15] == integrator[15]) && (sum[15] != integrator[15]);
    assign and0 = !ov && hdng_vld;
    assign mux1 = and0 ? sum : integrator; 
    assign nxt_integrator = moving ? mux1 : 16'h0000;

    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            integrator <= 16'h0000;
        end else begin 
            integrator <= nxt_integrator;
        end
    end

    assign I_term = integrator[15:4];


    // *** D_term Logic  ****
    logic signed [9:0]  q1;
    logic signed [9:0]  prev_err;
    
    // Added 11-bit wires to prevent intermediate subtraction overflow
    logic signed [10:0] err_sat_ext11;  
    logic signed [10:0] prev_err_ext11; 
    
    logic signed [10:0] D_diff; 
    logic signed [7:0]  D_diff_sat;

    // Cascaded Registers 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1       <= 10'sb0;
            prev_err <= 10'sb0;
        end else if (hdng_vld) begin
            q1       <= err_sat;
            prev_err <= q1;
        end
    end

    // Difference and Saturation 
    assign err_sat_ext11 = err_sat;
    assign prev_err_ext11 = prev_err;
    assign D_diff = $signed({err_sat[9], err_sat}) - $signed({prev_err[9], prev_err});

    always_comb begin
        if (D_diff > 11'sd127)
            D_diff_sat = 8'sd127;
        else if (D_diff < -11'sd128)
            D_diff_sat = -8'sd128;
        else
            D_diff_sat = D_diff[7:0];
    end

    // Signed Multiplication 
    assign D_term = $signed(D_diff_sat) * $signed(D_COEFF);


    // **** PID Assembly & Motor Drive Logic ****
    // Sign extend (SE) all terms to 15-bits and sum them 
    assign PID_sum = {P_term[13], P_term} + 
                     {{3{I_term[11]}}, I_term} + 
                     {{2{D_term[12]}}, D_term};

    // Divide by 8 (shift right by 3) 
    assign pid_div8 = PID_sum[14:3];

    // Extend unsigned 11-bit forward speed to signed 12-bit 
    assign frwrd_spd_ext = {1'b0, frwrd_spd};

    // Motor multiplexers 
    assign lft_spd  = moving ? (pid_div8 + frwrd_spd_ext) : 12'h000;
    assign rght_spd = moving ? (frwrd_spd_ext - pid_div8) : 12'h000;

endmodule