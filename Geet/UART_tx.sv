module UART_tx (clk, rst_n, TX, trmt, tx_data, tx_done);

  input clk, rst_n, trmt;
  output logic TX, tx_done;
  input [7:0] tx_data;

    logic [3:0] bit_cnt;
    logic [11:0] baud_cnt;
    logic [8:0] tx_shft_reg;
    localparam BAUD_DIV = 12'd2604;  // 50MHz / 19200 Baud = ~2604 clocks
    logic init, shift, transmitting, set_done;

    typedef enum logic {IDLE, TRANSMITTING} state_t;
    state_t state, next_state;

    assign shift = (baud_cnt == BAUD_DIV);

// Bit counter : Tracks how many of the 10 bits have been sent
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        bit_cnt <= 4'h0;
    else if (init)  // 1 start + 8 data + 1 stop
        bit_cnt <= 4'h0;
    else if (shift)
        bit_cnt <= bit_cnt + 1;
    end

// Baud counter : Generates the timing for the specific Baud Rate
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        baud_cnt <= 12'h000;
    else if (init || shift)  // 1 start + 8 data + 1 stop
        baud_cnt <= 12'h000;
    else if (transmitting)  // shift at baud rate
        baud_cnt <= baud_cnt + 1; 
    end

// Shift register
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        tx_shft_reg <= 9'h1FF; // idle state is high
    else if (init) 
        tx_shft_reg <= {tx_data, 1'b0}; // start bit + data + stop bit
    else if (shift)
        tx_shft_reg <= {1'b1, tx_shft_reg[8:1]}; // shift right, fill with 1s for idle
    end
    assign TX = tx_shft_reg[0];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        tx_done <= 1'b0;
    else if (init)        // Clear done signal on new transmission 
        tx_done <= 1'b0;
    else if (set_done)    // Set done signal when finished 
        tx_done <= 1'b1;
    end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

 always_comb begin
        // Default the next state to the current state to prevent unintended latches 
        // and reduce code verbosity for conditions where the state doesn't change
        init = 1'b0;
        transmitting = 1'b0;
        set_done = 1'b0;
        next_state = state; 
        
        // Default outputs to their most common value to prevent latches

        case (state)
            IDLE: begin
                // State transitions
                if (trmt) begin
                    init = 1'b1;
                    next_state = TRANSMITTING;
                end
            end
            
            TRANSMITTING: begin
                // State outputs
                transmitting = 1'b1;
                
                // State transitions
                if (bit_cnt == 4'd10) begin
                    set_done = 1'b1;
                    next_state = IDLE;
                end
            end
            
            // Default case for synthesis safety and compliance
            default: next_state = IDLE; // Reset to a known state on invalid state encoding
        endcase
end

endmodule