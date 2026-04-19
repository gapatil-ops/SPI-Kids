module cmd_proc (
    input  logic        clk,          // Standard system clock
    input  logic        rst_n,        // Active-low asynchronous reset
    
    // --- Interface with UART_wrapper ---
    input  logic [15:0] cmd,          // 16-bit incoming command
    input  logic        cmd_rdy,      // Asserted when a new command is available
    output logic        clr_cmd_rdy,  // Asserts to clear the cmd_rdy flag
    output logic        send_resp,    // Asserts to send the 0xA5 response byte
    
    // --- Interface with inert_intf ---
    input  logic        cal_done,     // Asserts when gyro calibration finishes
    output logic        strt_cal,     // 1-cycle pulse to start calibration
    output logic        in_cal,       // High while calibration is ongoing
    
    // --- Interface with Navigation (navigate muxing) ---
    input  logic        mv_cmplt,     // Asserts when robot reaches heading or finishes move
    output logic        strt_hdng,    // 1-cycle pulse to execute a heading change
    output logic        strt_mv,      // 1-cycle pulse to execute a forward move
    output logic        stp_lft,      // Registered flag: stop at left opening
    output logic        stp_rght,     // Registered flag: stop at right opening
    output logic [11:0] dsrd_hdng,    // Registered 12-bit desired heading
    
    // --- Interface with Maze Solver ---
    input  logic        sol_cmplt,    // Asserts when the hall sensor finds the magnet
    output logic        cmd_md        // 1 = Command mode, 0 = Autonomous solve mode
);

    // =========================================================================
    // Typedefs & Internal Signals
    // =========================================================================
    
    // Define your FSM states here. 
    // You will need IDLE, plus states to wait for cal_done, mv_cmplt, and sol_cmplt.
    typedef enum logic [2:0] {
        IDLE,
        CALIBRATE,
        HEADING,
        MOVEMENT,
        SOLVE
    } state_t;

    state_t state, nxt_state;

    // Extracting the opcode makes the FSM case statements much cleaner to read
    logic [2:0] opcode;
    assign opcode = cmd[15:13];

    // =========================================================================
    // Datapath & Registered Outputs
    // =========================================================================
    
    // The desired heading, stop left, and stop right flags must be remembered 
    // after the command is processed, so they require their own flip-flops.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dsrd_hdng <= 12'h000; // Default to North
            stp_lft   <= 1'b0;
            stp_rght  <= 1'b0;
        end else begin

            if (state == IDLE && cmd_rdy) begin
                
                // Check the opcode (top 3 bits) to see what kind of command it is
                if (cmd[15:13] == 3'b001) begin
                    // It's a Heading command: capture the desired heading
                    dsrd_hdng <= cmd[11:0];
                end 
                else if (cmd[15:13] == 3'b010) begin
                    // It's a Move command: capture the stop conditions
                    stp_lft  <= cmd[1];
                    stp_rght <= cmd[0];
                end
                
            end
        end
    end

    // =========================================================================
    // FSM State Register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    // =========================================================================
    // FSM Next State & Output Logic (Combinational)
    // =========================================================================
    always_comb begin
        // Default output assignments to prevent latches
        clr_cmd_rdy = 1'b0;
        send_resp   = 1'b0;
        strt_cal    = 1'b0;
        in_cal      = 1'b0;
        strt_hdng   = 1'b0;
        strt_mv     = 1'b0;
        cmd_md      = 1'b1;     // Default to 1 (Command Mode) 
        nxt_state   = state;    // Default to staying in the current state

        case(state)
            IDLE: begin
                
                if (cmd_rdy) begin
                    clr_cmd_rdy = 1'b1; // Clear the cmd_rdy flag to acknowledge the command

                    case (opcode)
                        3'b000: begin
                            // Calibration command
                            strt_cal = 1'b1; // Start calibration
                            nxt_state = CALIBRATE; // Transition to calibration state
                        end
                        3'b001: begin
                            // Heading command
                            strt_hdng = 1'b1; // Start heading change
                            nxt_state = HEADING; // Transition to heading state
                        end
                        3'b010: begin
                            // Move command
                            strt_mv = 1'b1; // Start movement
                            nxt_state = MOVEMENT; // Transition to movement state
                        end
                        3'b011: begin
                            // Solve command 
                            cmd_md = 1'b0; // Switch to Autonomous solve mode
                            nxt_state = SOLVE; // Transition to solve state
                        end
                        default: begin
                            // Invalid opcode, stay in IDLE and maybe handle error (not specified)
                            nxt_state = IDLE;
                        end
                    endcase
                end else begin
                    nxt_state = IDLE; // Stay in IDLE if no command is ready
                end
            end
            
            CALIBRATE: begin
                in_cal = 1'b1; // Indicate that calibration is ongoing
                if (cal_done) begin
                    send_resp = 1'b1; // Send response when calibration is done
                    nxt_state = IDLE; // Return to IDLE
                end else begin
                    nxt_state = CALIBRATE; // Stay in CALIBRATE until done
                end
            end

            HEADING: begin
                if (mv_cmplt) begin
                    send_resp = 1'b1; // Send response when heading change is complete
                    nxt_state = IDLE; // Return to IDLE
                end else begin
                    nxt_state = HEADING; // Stay in HEADING until move is complete
                end
            end

            MOVEMENT: begin
                if (mv_cmplt) begin
                    send_resp = 1'b1; // Send response when movement is complete
                    nxt_state = IDLE; // Return to IDLE
                end else begin
                    nxt_state = MOVEMENT; // Stay in MOVEMENT until move is complete
                end
            end

                SOLVE: begin
                    cmd_md = 1'b0; // Ensure we stay in Autonomous solve mode
                    if (sol_cmplt) begin
                        send_resp = 1'b1; // Send response when solve is complete
                        nxt_state = IDLE; // Return to IDLE
                    end else begin
                        nxt_state = SOLVE; // Stay in SOLVE until complete
                    end
                end

            default: nxt_state = IDLE;
        endcase
    end

endmodule