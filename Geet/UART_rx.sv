module UART_rx(clk, rst_n, RX, clr_rdy, rx_data, rdy);

    input clk, rst_n, clr_rdy;
    input RX;
    output logic  [7:0] rx_data;
    output logic  rdy;

    logic receiving, start, set_rdy, shift;
    logic [3:0] bit_cnt;
    logic [11:0] baud_cnt;
    logic [8:0] rx_shft_reg;
    
    localparam BAUD_DIV = 12'd2604; // 50MHz / 19200 Baud = ~2604 clocks
    localparam BAUD_MID = 12'd1302; // Sample RX data in the middle of Baud period 

    // Gating the shift signal ensures it only pulses when we are actively receiving
    assign shift = (baud_cnt == 12'h000) && receiving; 

    typedef enum logic {IDLE, RECEIVE} state_t;
    state_t state, next_state;

    logic rx_ff1, rx_synced, rx_synced_q;
    
    // Double-flop synchronizer for the RX line to handle metastability
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_ff1      <= 1'b1; // Idle high
            rx_synced   <= 1'b1; // Idle high
            rx_synced_q <= 1'b1; // Used for edge detection
         end else begin
            rx_ff1      <= RX;
            rx_synced   <= rx_ff1;
            rx_synced_q <= rx_synced;
        end
    end

    // Bit counter: Counts 10 bits (Start, 8 Data, 1 Stop)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= 4'h0;
        else if (start)      // 1 start + 8 data + 1 stop 
            bit_cnt <= 4'h0;
        else if (shift)
            bit_cnt <= bit_cnt + 1;
    end

    // Baud counter: Implements the "Mid-Sample" timing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            baud_cnt <= 12'hFFF; // Initialize non-zero so shift doesn't falsely trigger
        else if (start) 
            baud_cnt <= BAUD_MID; // Load half a baud period to align the first 'shift' with bit-center
        else if (shift)
            baud_cnt <= BAUD_DIV;
        else if (receiving)    // shift at baud rate
            baud_cnt <= baud_cnt - 1;
    end

    // Shift register: Captures serial data into parallel form
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            rx_shft_reg <= 9'h1FF; // idle state is high
        else if (shift)
            rx_shft_reg <= {rx_synced, rx_shft_reg[8:1]}; // shift right, RX comes in at MSB
    end
    
    assign rx_data = rx_shft_reg[7:0];

    // Ready Flag logic: Standard SR-style flip-flop with Reset priority
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rdy <= 1'b0;
        else if (start || clr_rdy)   // Knocks down rdy when asserted 
            rdy <= 1'b0;
        else if (set_rdy)            // Asserted when byte received 
            rdy <= 1'b1;
    end

    // FSM State Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM Combinational Logic
    always_comb begin
        next_state = state;
        start     = 1'b0;
        receiving = 1'b0;
        set_rdy   = 1'b0;

        case (state)
            IDLE: begin
                // Monitor for falling edge of Start bit 
                if (~rx_synced & rx_synced_q) begin 
                    start = 1'b1;
                    next_state = RECEIVE;
                end
            end

            RECEIVE: begin
                receiving = 1'b1;
                if (bit_cnt == 4'd10) begin
                    set_rdy = 1'b1;
                    next_state = IDLE;
                end
            end
        
            default: next_state = IDLE;
        endcase
    end

endmodule