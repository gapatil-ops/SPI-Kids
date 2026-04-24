module piezo_drv (
    input logic clk,
    input logic rst_n, // Active low reset
    input logic fanfare,
    input logic batt_low,
    output logic piezo,
    output logic piezo_n 
);

parameter FAST_SIM = 0; // Set to 1 for fast simulation, 0 for real timing

logic [4:0] decrement_amount;

generate if (FAST_SIM) 
    assign decrement_amount = 5'h10; // 16 for fast simulation
else
    assign decrement_amount = 5'h01; // 1 for real timing
endgenerate

logic [23:0] counter; // 24-bit counter

logic L_init, M_init, M_L_init, H_init;

// Duration counter
always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        counter <= 0;
    else if (L_init)
        counter <= 24'h3FFFFF; // Initialize to low value
    else if (M_init)
        counter <= 24'h7FFFFF; // Initialize to med value
    else if (M_L_init)
        counter <= 24'hAFFFFF; // Initialize to med + low value
    else if (H_init)
        counter <= 24'hFFFFFF; // Initialize to high value
    else 
        counter <= counter - decrement_amount; // Increment by the defined amount
end

logic time_done;

assign time_done = (counter < decrement_amount);

logic [14:0] freq_counter; // 15-bit frequency counter

logic G6_freq_init, C7_freq_init, E7_freq_init, G7_freq_init;

always_ff @( posedge clk, negedge rst_n ) begin 
    if (!rst_n)
        freq_counter <= 0;
    else if (G6_freq_init)
        freq_counter <= 15'h3E47; 
    else if (C7_freq_init)
        freq_counter <= 15'h2EA8; 
    else if (E7_freq_init)
        freq_counter <= 15'h2508;
    else if (G7_freq_init)
        freq_counter <= 15'h1F23;
    else 
        freq_counter <= freq_counter - 1; // Decrement frequency counter
end

logic freq_tick;

assign freq_tick = (freq_counter == 0);

typedef enum logic[2:0] { IDLE, G6_M, C7_M, E7_M, G7_M_L, E7_L, G7_H } state_t;

state_t state, next_state;

// Additional control signals
logic en;

always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

// State transition logic
always_comb begin
    // Default outputs
    en = 0;
    L_init = 0;
    M_init = 0;
    M_L_init = 0;
    H_init = 0;
    G6_freq_init = 0;
    C7_freq_init = 0;
    E7_freq_init = 0;
    G7_freq_init = 0;
    next_state = state;
    
    case(state)
        G6_M: begin
            if (time_done) begin
                M_init = 1;
                C7_freq_init = 1;
                next_state = C7_M;
            end
            else if (freq_tick)
                G6_freq_init = 1; // Reload G6 frequency
        end
        C7_M: begin
            if (time_done) begin
                M_init = 1;
                E7_freq_init = 1;
                next_state = E7_M;
            end
            else if (freq_tick)
                C7_freq_init = 1; // Reload C7 frequency
        end
        E7_M: begin
            if (time_done) begin
                if (batt_low) 
                    next_state = IDLE;
                else if (fanfare) begin
                    M_L_init = 1;
                    G7_freq_init = 1;
                    next_state = G7_M_L;
                end
                else 
                    next_state = IDLE;
            end
            else if (freq_tick)
                E7_freq_init = 1; // Reload E7 frequency
        end
        G7_M_L: begin
            if (time_done) begin
                L_init = 1;
                E7_freq_init = 1;
                next_state = E7_L;
            end
            else if (freq_tick)
                G7_freq_init = 1; // Reload G7 frequency
        end
        E7_L: begin
            if (time_done) begin
                H_init = 1;
                G7_freq_init = 1;
                next_state = G7_H;
            end
            else if (freq_tick)
                E7_freq_init = 1; // Reload E7 frequency
        end
        G7_H: begin
            if (time_done) 
                next_state = IDLE; // After high duration, go back to IDLE
            else if (freq_tick)
                G7_freq_init = 1; // Reload G7 frequency
        end
        default: begin // IDLE
            en = 1; // Enable the driver
            if (fanfare | batt_low) begin
                M_init = 1; // Start with medium duration
                G6_freq_init = 1; // Start with G6 frequency
                next_state = G6_M;
            end
        end
    endcase
end

// Piezo output logic
always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n) begin
        piezo <= 0;
        piezo_n <= 1;
    end
    else if (freq_tick & ~en) begin
        piezo <= ~piezo; // Toggle piezo output on frequency tick
        piezo_n <= ~piezo_n; // Toggle complementary output
    end
end

endmodule