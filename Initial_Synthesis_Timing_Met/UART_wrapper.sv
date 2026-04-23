module UART_wrapper(
    input clk,
    input rst_n,
    input RX,
    input clr_cmd_rdy,
    input trmt,
    input [7:0] resp,
    output TX,
    output logic cmd_rdy,
    output logic [15:0] cmd,
    output tx_done
);
    
    logic rx_rdy;
    logic clr_rx_rdy;
    logic [7:0] rx_data;

    // DATAPATH that our statemachine controls
    logic cap_high; // signal that actives a mux that lets register capture high byte

    // Register captures the high byte from rx_data when cap_high asserted
    always_ff @(posedge clk) begin  // Don't need reset for this register because we won't use the cmd value until we load it
        if (cap_high)
            cmd[15:8] <= rx_data;
    end
    assign cmd[7:0] = rx_data;

    // internal signal so that our state machine can clear and set command ready
    logic intrl_clr_cmd_rdy; 
    logic set_cmd_rdy;

    UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .rx_rdy(rx_rdy), 
    .clr_rx_rdy(clr_rx_rdy), .tx_done(tx_done), .rx_data(rx_data), .tx_data(resp), 
    .trmt(trmt));

    // Set-Reset flip flop for cmd_rdy signal
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            cmd_rdy <= 1'b0;
        else if (clr_cmd_rdy || intrl_clr_cmd_rdy)
            cmd_rdy <= 1'b0;
        else if (set_cmd_rdy)
            cmd_rdy <= 1'b1;

    // STATES FOR STATE MACHINE
    typedef enum logic {CHILLIN, CAPTURE} state_t;

    state_t state;
    state_t nxt_state;

    // Register for holding state
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= CHILLIN;
        else
            state <= nxt_state;
    end

    // BYTE PACKAGER STATE MACHINE LOGIC
    always_comb begin

        nxt_state = state;
        cap_high = 1'b0;
        intrl_clr_cmd_rdy = 1'b0;
        clr_rx_rdy = 1'b0;
        set_cmd_rdy = 1'b0;

        // (unique just says synthesise this flat)
        
        unique case(state)
            CHILLIN: begin // While we're idly chilling, if we see an rx_rdy, we know a new command is
                           // coming in, so we assert the signal to first capture this transmission as
                           // the high byte, then clear any previous cmd_rdy, then make sure we clear the
                           // receivers ready signal so that we aren't accidentally triggered in the next state
                if (rx_rdy) begin
                    cap_high = 1'b1;
                    intrl_clr_cmd_rdy = 1'b1;
                    clr_rx_rdy = 1'b1;
                    nxt_state = CAPTURE;
                end
            end

            CAPTURE: begin // In capture state, we've already captured the high byte and we're just waiting
                           // for the low byte to come. Once it comes (rx_rdy), then we set the cmd rdy signal
                           // (note that this is a set-reset flop, so it isn't until the next cycle that cmd is shown as rdy)
                           // then we clear rx_rdy so that we aren't accidentally retriggered again
                           // Then we go back to chilling
                if (rx_rdy) begin
                    set_cmd_rdy = 1'b1;
                    clr_rx_rdy = 1'b1;
                    nxt_state = CHILLIN;
                end
            end
        endcase
    end

endmodule