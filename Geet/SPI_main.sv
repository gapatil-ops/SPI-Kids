module SPI_main(
    input clk, rst_n,           // 50MHz system clock and active-low reset
    input wrt,                  // Trigger to initiate a 16-bit SPI transaction
    input [15:0] wt_data,       // Data/Command to be sent to the secondary device
    input MISO,                 // Master In Slave Out: data from the sensor
    output reg SS_n,            // Active-low Secondary Select
    output SCLK,                // Serial Clock: 1/32 of the system clock (approx. 1.56MHz)
    output MOSI,                // Master Out Slave In: data to the sensor
    output reg done,            // Indicates completion of the 16-bit transaction
    output [15:0] rd_data       // Data received from the secondary device
);

    // State definitions for the FSM
    // WAIT handles the front porch; ACTIVE handles the data transfer and back porch
    typedef enum reg [1:0] { IDLE, WAIT, ACTIVE } state_t;
    state_t state, nxt_state;

    // Internal registers
    reg [4:0] SCLK_div;         // 5-bit clock divider to generate SCLK from system clock
    reg [3:0] bit_cnt;          // 4-bit counter to track the 16 bits of the transaction
    reg [15:0] shft_reg;        // Shared shift register for full-duplex transmit/receive
    reg MISO_smpl;              // Buffer to hold the MISO bit sampled on SCLK rising edge

    // Internal control and status signals
    logic init, shft, ld_SCLK, set_done; 
    logic smpl, shft_imm, done15;        

    // Clock divider and SCLK generation logic
    always_ff @(posedge clk) begin
        if (ld_SCLK)
            // Initializing to 23 (5'b10111) creates a "front porch" delay 
            // of 8 cycles before the first SCLK falling edge
            SCLK_div <= 5'b10111; 
        else
            SCLK_div <= SCLK_div + 1;
    end
    
    // SCLK is the MSB of the divider (1/32 of system clock)
    assign SCLK = SCLK_div[4];    
    // Sample MISO just before SCLK rises
    assign smpl = (SCLK_div == 5'b01111);     
    // Shift MOSI just before SCLK falls
    assign shft_imm = (SCLK_div == 5'b11111); 

    // Full-duplex shift register logic
    always_ff @(posedge clk) begin
        if (smpl)
            MISO_smpl <= MISO;    // Capture incoming bit on rising edge
            
        if (init)
            shft_reg <= wt_data;  // Load outgoing data at start of transaction
        else if (shft)
            // Shift out MSB (MOSI) and shift in sampled MISO bit to LSB
            shft_reg <= {shft_reg[14:0], MISO_smpl}; 
    end
    
    assign MOSI = shft_reg[15];   // Transmit MSB
    assign rd_data = shft_reg;    // Output buffer contains received data after 16 shifts

    // Bit counter logic to track 16 bits
    always_ff @(posedge clk) begin
        if (init)
            bit_cnt <= 4'b0000;   // Reset counter at the start of a transaction
        else if (shft)
            bit_cnt <= bit_cnt + 1; 
    end
    
    // Becomes true when the 16th bit (bit 15) is being processed
    assign done15 = &bit_cnt;     

    // Sequential state transitions and glitch-free output control
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            SS_n  <= 1'b1;        // sensor not selected
            done  <= 1'b1;        //  no transaction in progress
        end else begin
            state <= nxt_state;
            
            // Using set/reset logic within the flip-flop to ensure 
            // SS_n and done signals are free of combinational glitches
            if (init) begin
                SS_n <= 1'b0;     // Start of transaction: select sensor
                done <= 1'b0;     
            end else if (set_done) begin
                SS_n <= 1'b1;     // End of transaction: deselect sensor
                done <= 1'b1;     
            end
        end
    end

    // Combinational FSM logic for state transitions and control signals
    always_comb begin
        // Default assignments to avoid latches
        nxt_state = state;
        init      = 1'b0;
        shft      = 1'b0;
        ld_SCLK   = 1'b0;
        set_done  = 1'b0;

        case (state)
            IDLE: begin
                ld_SCLK = 1'b1;   // Hold clock divider to prep for front porch
                if (wrt) begin
                    init = 1'b1;  // Load shift register and reset bit counter
                    nxt_state = WAIT;
                end
            end

            WAIT: begin
                // Creates front porch lead-time before first SCLK fall
                if (shft_imm)     
                    nxt_state = ACTIVE;
            end

            ACTIVE: begin
                // Toggling SCLK and transferring data
                if (shft_imm) begin
                    shft = 1'b1;  // Trigger shift register and increment bit count
                    if (done15) begin
                        // Transaction ends after 16th shift, providing back porch delay
                        set_done = 1'b1; 
                        nxt_state = IDLE;
                    end
                end
            end
            
            default: nxt_state = IDLE;
        endcase
    end

endmodule