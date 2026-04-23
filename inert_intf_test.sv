module inert_intf_test(clk, RST_N, LED, SS_n, SCLK, MOSI, MISO, INT);

input clk, RST_N, MISO, INT;
output logic [7:0] LED;
output logic SS_n, SCLK, MOSI;

// Instantiate Reset Synchronizer
logic rst_n;
reset_synch iRST_SYNC(
    .clk(clk),
    .RST_N(RST_N),
    .rst_n(rst_n)
);

// 17 bit timer
logic [16:0] timer;

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        timer <= 17'h00000;
    else
        timer <= timer + 1;
end

// Instantiate the inertial interface
logic strt_cal;
logic cal_done;
logic [11:0] heading;
logic rdy;

inert_intf iINTF(
    .clk(clk),
    .rst_n(rst_n),
    .strt_cal(strt_cal),
    .cal_done(cal_done),
    .heading(heading),
    .moving(1'b1),
    .en_fusion(1'b0),
    .IR_Dtrm(9'h0),
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .MISO(MISO),
    .INT(INT),
    .rdy(rdy)
);

typedef enum logic [1:0] { IDLE, CAL, DISP } state_t;
state_t state, next_state;

// State flops
always_ff @( posedge clk, negedge rst_n ) begin 
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

logic sel;

// State Machine Outputs and Transitions
always_comb begin
    // Default outputs
    sel = 0;
    strt_cal = 0;
    case(state)
        CAL: begin
            sel = 1;
            if (cal_done)
                next_state = DISP;
        end
        DISP: 
            sel = 0;
        // Default case: IDLE
        IDLE: begin
            sel = 0;
            if (&timer) begin
                strt_cal = 1;
                next_state = CAL;
            end
        end
    endcase
end

// LED assign
assign LED = sel ? (8'hA5) : heading[11:4];

endmodule