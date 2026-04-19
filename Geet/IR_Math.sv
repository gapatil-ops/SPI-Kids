module IR_math(
  lft_opn,
  rght_opn,
  lft_IR,
  rght_IR,
  IR_Dtrm,
  en_fusion,
  dsrd_hdng,
  dsrd_hdng_adj);

parameter NOM_IR = 12'h900; // 12-bit parameter defaulted to 12'h900 
input lft_opn;              // Indicate left IR sensor has no reading (path is open) 
input rght_opn;             // Indicate right IR sensor has no reading (path is open) 
input [11:0] lft_IR;        // Left IR reading 
input [11:0] rght_IR;       // Right IR reading 
input [8:0] IR_Dtrm;        // Derivative of IR readings, comes from sensor_intf 
input en_fusion;            // IR fused with gyro only when moving at decent speed 
input [11:0] dsrd_hdng;     // Desired heading of MazeRunner (comes from cmd_proc) 
output [11:0] dsrd_hdng_adj;// adjusted desired heading


wire [12:0] IR_diff;
wire [11:0] lft_NOM_IR;
wire [11:0] rght_NOM_IR;
wire [11:0] mux1_out;
wire [11:0] mux3_and;
wire [11:0] mux2_out;
wire [11:0] mux3_out;
wire [12:0] mux3_out_ext;
wire [12:0] IR_Dtrm_scaled;
wire [12:0] sum_mux3_Dtrm;
wire [12:0] sum_mux3_Dtrm_div;
wire [11:0] IR_final;


// Logic for determining if both sensors are open (AND gate in diagram) 
assign mux3_and = lft_opn & rght_opn;

// Calculate difference between left and right IR sensors 
assign IR_diff = {1'b0, lft_IR} - {1'b0, rght_IR};

// Calculate difference from nominal IR value for single-sensor cases 
assign lft_NOM_IR = lft_IR - NOM_IR;
assign rght_NOM_IR = NOM_IR - rght_IR;

// Muxing logic to select correction source based on lft/rght open flags 
assign mux1_out= rght_opn ? lft_NOM_IR : IR_diff[12:1];
assign mux2_out = lft_opn ? rght_NOM_IR : mux1_out;
assign mux3_out = mux3_and ? 12'h000 : mux2_out;

// "Div 32 & ext 13" block (Arithmetic shift right by 5)
assign mux3_out_ext = { {6{mux3_out[11]}}, mux3_out[11:5] };

// "x4 & ext 13" block (Shift left by 2) 
assign IR_Dtrm_scaled = { {2{IR_Dtrm[8]}}, IR_Dtrm, 2'b00 };

// Summing junction for Proportional and Derivative terms 
assign sum_mux3_Dtrm = IR_Dtrm_scaled + mux3_out_ext;

// "Div 2" block (Arithmetic shift right by 1)
assign sum_mux3_Dtrm_div = $signed(sum_mux3_Dtrm) >>> 1;

// Summing junction for Heading and Correction term
assign IR_final = sum_mux3_Dtrm_div[11:0] + dsrd_hdng;

// Final Mux to select adjusted heading if en_fusion is high 
assign dsrd_hdng_adj = en_fusion ? IR_final : dsrd_hdng;


endmodule