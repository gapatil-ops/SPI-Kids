module RemoteComm(
    input clk,
    input rst_n,
    input snd_cmd,
    input [15:0] cmd,
    input RX,
    output TX,
    output logic cmd_sent,
    output [7:0] resp,
    output resp_rdy
);

    logic trmt;
    logic clr_rx_rdy;

    logic [7:0] tx_data;
    logic tx_done;

    // UART transceiver
    UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .trmt(trmt), 
    .clr_rx_rdy(clr_rx_rdy), .tx_data(tx_data), .rx_rdy(resp_rdy),
    .tx_done(tx_done), .rx_data(resp)
    );
    

    // DATAPATH for capturing command
    logic sel_high;
    logic [7:0] low_byte;

    always_ff @(posedge clk)
        if (snd_cmd) // We capture the low byte when we get a snd_cmd signal
            low_byte <= cmd[7:0];
        
    assign tx_data = (sel_high) ? cmd[15:8] : low_byte; 

    
    // SR flop for cmd_sent
    logic set_cmd_sent;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            cmd_sent <= 1'b0;
        else if (snd_cmd) // send command is the reset for the send command flops
            cmd_sent <= 1'b0;
        else if (set_cmd_sent) // we have a cmd_sent set signal controlled by FSM
            cmd_sent <= 1'b1;

    // State Machine for RemoteComm
    typedef enum logic[1:0] {CHILLIN, WAIT_FIRST, WAIT_SECOND} state_t;

    state_t state;
    state_t nxt_state;

    // Registers for state machine
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            state <= CHILLIN;
        else
            state <= nxt_state;
    
    // Logic for state machines
    always_comb begin
        
        // At a default, we stay at our current state, and we don't assert any inputs
        nxt_state = state;
        trmt = 1'b0;
        sel_high = 1'b0;
        set_cmd_sent = 1'b0;

        case (state)
            CHILLIN: begin // If we're chilling and are told to send a command
                           // Then we select the high byte as the input to TX
                           // and send it the transmit start command.
                if (snd_cmd) begin
                    sel_high = 1'b1;
                    trmt = 1'b1;
                    nxt_state = WAIT_FIRST;
                end
            end

            WAIT_FIRST: begin // In this state, we're waiting for the first byte
                              // to finish transmitting. Once TX is done, we select
                              // the low byte (that was capture by snd_command) and
                              // then transmit it
                if (tx_done) begin
                    trmt = 1'b1;
                    nxt_state = WAIT_SECOND;
                    // and sel_high = 1'b0, so we're selecting the low byte
                end
            end

            WAIT_SECOND: begin // In this state, we're waiting for the second byte
                               // to finish transmitting. Once this TX is done, we
                               // set the cmd_sent SR flip-flop and go back to chilling.
                if (tx_done) begin
                    set_cmd_sent = 1'b1;
                    nxt_state = CHILLIN;
                end
            end

            default: begin // if an alpha particle flips a bit, we want to make sure we're able to return to
                           // CHILLIN state 
                nxt_state = CHILLIN;
            end
        endcase
    end

endmodule