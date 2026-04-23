module SPI_mnrch (clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, wt_data, done, rd_data);

input clk, rst_n;
input MISO;
output logic SS_n, MOSI;
output logic SCLK;
input wrt;                      // High for 1 clock period to initiate SPI transaction
input logic [15:0] wt_data;     // Data being sent to inertial sensor
output logic done;              // Asserted when SPI transaction is complete, till next wrt
output logic [15:0] rd_data;    // Data from SPI secondary, for inertial sensor will only use [7:0]

// SCLK generation
// 1/32 of clk frequency
logic [4:0] clk_div; // 5 bits to count up to 31
logic ld_SCLK; // Load SCLK at the end of each SPI transaction

always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        clk_div <= 0;
    else if (ld_SCLK)
        clk_div <= 5'b10111;
    else 
        clk_div <= clk_div + 1;
end

assign SCLK = clk_div[4]; // SCLK is the MSB of clk_div, toggles every 16 clk cycles

// SCLK control signals
logic smpl; // Indicate we are sampling MISO next, SCLK rising next clk
logic shft_imm; // Shift is imminent, SCLK falling next clk

assign smpl = ~clk_div[4] & &clk_div[3:0]; // Sample MISO at the 15th cycle (SCLK rising)
assign shft_imm = &clk_div; // Shift at the 31st cycle (SCLK falling)

// Shift register control signals
logic init, shift;

// MISO sampling
logic MISO_sample;

always_ff @( posedge clk, negedge rst_n ) begin 
    if (!rst_n)
        MISO_sample <= 0;
    else if (smpl)
        MISO_sample <= MISO;
end

// Shift register
logic [15:0] shift_reg;

always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        shift_reg <= 0;
    else if (init)
        shift_reg <= wt_data;
    else if (shift)
        shift_reg <= {shift_reg[14:0], MISO_sample}; // Shift left, sample in MISO
end

assign MOSI = shift_reg[15]; // MSB of shift register goes to MOSI

// Bit counter
logic [3:0] bit_cnt; // 4 bits to count up to 16

// Bit counter control signals
logic done_15;
assign done_15 = &bit_cnt; // done_15 is high when bit_cnt is 15 (all bits shifted)

always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        bit_cnt <= 0;
    else if (init)
        bit_cnt <= 0;
    else if (shift)
        bit_cnt <= bit_cnt + 1;
end

// Additional FSM control signals
logic set_done; // Set done at the end of transaction

// FSM state encoding
typedef enum logic [1:0] { IDLE, FRONT_PORCH, TRANSFER } state_t;

state_t state, next_state;

// FSM state transition
always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

// FSM next state logic and output logic
always_comb begin
    // Default outputs
    init = 0;
    ld_SCLK = 0;
    shift = 0;
    set_done = 0;
    next_state = state;

    case(state)
        FRONT_PORCH: begin
            if (shft_imm) 
                next_state = TRANSFER;
        end
        TRANSFER: begin
            if (shft_imm) begin
                shift = 1;
                if (done_15) begin
                    set_done = 1;
                    ld_SCLK = 1;
                    next_state = IDLE;
                end
            end
        end
        default: begin // IDLE
            ld_SCLK = 1; // hold SCLK high while idle
            if (wrt) begin
                init = 1;
                next_state = FRONT_PORCH;
            end
        end
    endcase
end

// Done output logic
always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        done <= 0;
    else if (init)
        done <= 0;
    else if (set_done) // Clear done on new transaction
        done <= 1;
end

// SS_n output logic
always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        SS_n <= 1; // Inactive high
    else if (init)
        SS_n <= 0; // Active low on initialization
    else if (set_done)
        SS_n <= 1; // Deactivate after transaction is done
end

// Read data output logic
assign rd_data = shift_reg; // Output whatever is currently in the shift register

endmodule