module maze_solve(
    clk,
    rst_n,
    cmd_md,
    cmd0,
    lft_opn,
    rght_opn,
    mv_cmplt,
    sol_cmplt,
    strt_hdng,
    dsrd_hdng,
    strt_mv,
    stp_lft,
    stp_rght
);

input clk, rst_n, cmd_md, cmd0, lft_opn, rght_opn, mv_cmplt, sol_cmplt;

output logic strt_hdng, strt_mv, stp_lft, stp_rght;
output logic [11:0] dsrd_hdng;

// State encoding
typedef enum logic[2:0] { IDLE, MOVE, SOL_CHECK, WAIT_FOR_TURN, DONE } state_t;

state_t state, next_state;

// State flops
always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

// Left or right affinity
assign stp_lft = cmd0;
assign stp_rght = ~cmd0;

logic [11:0] dsrd_hdng_tmp;

// State logic
always_comb begin 
    // Default outputs
    strt_mv = 0;
    strt_hdng = 0;
    dsrd_hdng_tmp = 0;
    next_state = state;

    case(state)
        MOVE: begin
            if (mv_cmplt) begin
                next_state = SOL_CHECK;
            end
        end
        SOL_CHECK: begin
            if (sol_cmplt)
                next_state = DONE;
            else if (cmd0) begin
                next_state = WAIT_FOR_TURN;
                strt_hdng = 1;
                if (lft_opn)
                    // Turn left
                    dsrd_hdng_tmp = dsrd_hdng + 12'h400;
                else if (rght_opn)
                    // Turn right
                    dsrd_hdng_tmp = dsrd_hdng - 12'h400;
                else
                    // Turn 180
                    dsrd_hdng_tmp = dsrd_hdng +12'h800;
            end
            else begin
                next_state = WAIT_FOR_TURN;
                strt_hdng = 1;
                if (rght_opn)
                    // Turn right
                    dsrd_hdng_tmp = dsrd_hdng - 12'h400;
                else if (lft_opn)
                    // Turn left
                    dsrd_hdng_tmp = dsrd_hdng + 12'h400;
                else
                    // Turn 180
                    dsrd_hdng_tmp = dsrd_hdng +12'h800;
            end
        end
        WAIT_FOR_TURN: begin
            if (mv_cmplt) begin
                next_state = MOVE;
                strt_mv = 1;
            end
        end
        DONE: begin
            // Stay in DONE state
            next_state = DONE;
        end
        // IDLE state
        default: begin
            if (~cmd_md) begin
                strt_mv = 1;
                next_state = MOVE;
            end
        end
    endcase
end

always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        dsrd_hdng <= 0;
    else if (strt_hdng)
        dsrd_hdng <= dsrd_hdng_tmp;
end
endmodule