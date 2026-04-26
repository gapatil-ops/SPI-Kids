onerror {resume}
quietly virtual signal -install /MazeRunner_tb/iDUT { (context /MazeRunner_tb/iDUT )&{lft_spd ,rght_spd }} MotorSpeeds
quietly virtual signal -install /MazeRunner_tb/iDUT { (context /MazeRunner_tb/iDUT )&{stp_lft , stp_rght }} STOP_CONDITIONS
quietly virtual signal -install /MazeRunner_tb/iDUT { (context /MazeRunner_tb/iDUT )&{stp_lft_cmd , stp_rght_cmd }} CMD_STOP_CONDITIONS
quietly virtual signal -install /MazeRunner_tb/iDUT { (context /MazeRunner_tb/iDUT )&{stp_lft_slv , stp_rght_slv }} SLV_STOP_CONDITIONS
quietly WaveActivateNextPane {} 0
add wave -noupdate -group Basic_Signals /MazeRunner_tb/iDUT/FAST_SIM
add wave -noupdate -group Basic_Signals /MazeRunner_tb/clk
add wave -noupdate -group Basic_Signals /MazeRunner_tb/RST_n
add wave -noupdate -group Basic_Signals /MazeRunner_tb/iDUT/cmd_md
add wave -noupdate -group Basic_Signals /MazeRunner_tb/iDUT/en_fusion
add wave -noupdate -group Basic_Signals /MazeRunner_tb/iDUT/rst_n
add wave -noupdate -group Basic_Signals /MazeRunner_tb/iDUT/batt_low
add wave -noupdate -group Basic_Signals /MazeRunner_tb/batt
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb/snd_cmd
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb/cmd
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb/cmd_sent
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb/resp_rdy
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb/resp
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb/clr_resp_rdy
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb/iDUT/resp_sent
add wave -noupdate -group Remote_Comm_Signals /MazeRunner_tb/TX_RX
add wave -noupdate -group Remote_Comm_Signals /MazeRunner_tb/iDUT/send_resp
add wave -noupdate -group Remote_Comm_Signals /MazeRunner_tb/RX_TX
add wave -noupdate -group A2D_Comm_Sigs /MazeRunner_tb/A2D_MISO
add wave -noupdate -group A2D_Comm_Sigs /MazeRunner_tb/A2D_MOSI
add wave -noupdate -group A2D_Comm_Sigs /MazeRunner_tb/A2D_SCLK
add wave -noupdate -group A2D_Comm_Sigs /MazeRunner_tb/A2D_SS_n
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb/INRT_INT
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb/INRT_MISO
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb/INRT_MOSI
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb/INRT_SCLK
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb/INRT_SS_n
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb/IR_lft_en
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb/IR_cntr_en
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb/IR_rght_en
add wave -noupdate -group Movement_Signals /MazeRunner_tb/iDUT/moving
add wave -noupdate -group Movement_Signals -expand -group MotorSpeeds -format Analog-Step -height 84 -max 3896.0 -radix hexadecimal /MazeRunner_tb/iDUT/lft_spd
add wave -noupdate -group Movement_Signals -expand -group MotorSpeeds -format Analog-Step -height 84 -max 420.0 -radix hexadecimal /MazeRunner_tb/iDUT/rght_spd
add wave -noupdate -group Movement_Signals -group PWM_Signals -expand -group lftPWM /MazeRunner_tb/lftPWM1
add wave -noupdate -group Movement_Signals -group PWM_Signals -expand -group lftPWM /MazeRunner_tb/lftPWM2
add wave -noupdate -group Movement_Signals -group PWM_Signals -expand -group rightPWM /MazeRunner_tb/rghtPWM1
add wave -noupdate -group Movement_Signals -group PWM_Signals -expand -group rightPWM /MazeRunner_tb/rghtPWM2
add wave -noupdate -group Movement_Signals -format Analog-Step -height 84 -max 80.0 /MazeRunner_tb/iDUT/frwrd_spd
add wave -noupdate -group Movement_Signals /MazeRunner_tb/iDUT/IR_Dtrm
add wave -noupdate -group Indicator_Signals /MazeRunner_tb/iDUT/cal_done
add wave -noupdate -group Indicator_Signals /MazeRunner_tb/hall_n
add wave -noupdate -group Indicator_Signals /MazeRunner_tb/iDUT/sol_cmplt
add wave -noupdate -group Indicator_Signals /MazeRunner_tb/LED
add wave -noupdate -group Indicator_Signals /MazeRunner_tb/piezo
add wave -noupdate -group iCMD /MazeRunner_tb/iDUT/cmd
add wave -noupdate -group iCMD /MazeRunner_tb/iDUT/cmd_rdy
add wave -noupdate -group iCMD /MazeRunner_tb/iDUT/clr_cmd_rdy
add wave -noupdate -group Navigate_Signals /MazeRunner_tb/iDUT/iNAV/state
add wave -noupdate -group Navigate_Signals /MazeRunner_tb/iDUT/hdng_rdy
add wave -noupdate -group Navigate_Signals /MazeRunner_tb/iDUT/moving
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb/iDUT/strt_cal
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb/iDUT/strt_mv
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb/iDUT/mv_cmplt
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb/iDUT/STOP_CONDITIONS
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb/iDUT/stp_lft
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb/iDUT/stp_rght
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb/iDUT/en_fusion
add wave -noupdate -group Navigate_Signals -expand -group Nav_Condition_Sigs /MazeRunner_tb/iDUT/lft_opn
add wave -noupdate -group Navigate_Signals -expand -group Nav_Condition_Sigs /MazeRunner_tb/iDUT/rght_opn
add wave -noupdate -group Navigate_Signals -expand -group Nav_Condition_Sigs /MazeRunner_tb/iDUT/frwrd_opn
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb/iDUT/strt_cal
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb/iDUT/strt_hdng_cmd
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb/iDUT/dsrd_hdng_cmd
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb/iDUT/strt_mv_cmd
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb/iDUT/CMD_STOP_CONDITIONS
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb/iDUT/stp_lft_cmd
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb/iDUT/stp_rght_cmd
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb/iDUT/mv_cmplt
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb/iDUT/strt_cal
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb/iDUT/strt_hdng_slv
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb/iDUT/dsrd_hdng_slv
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb/iDUT/strt_mv_slv
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb/iDUT/SLV_STOP_CONDITIONS
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb/iDUT/stp_lft_slv
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb/iDUT/stp_rght_slv
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb/iDUT/mv_cmplt
add wave -noupdate -group IR_distance_readings /MazeRunner_tb/iDUT/lft_IR
add wave -noupdate -group IR_distance_readings /MazeRunner_tb/iDUT/rght_IR
add wave -noupdate -group IR_distance_readings -clampanalog 1 -format Analog-Step -height 84 -max 3806.9999999999995 -radix hexadecimal /MazeRunner_tb/iDUT/lft_IR
add wave -noupdate -group IR_distance_readings -format Analog-Step -height 84 -max 2816.0 -radix hexadecimal -radixshowbase 0 /MazeRunner_tb/iDUT/rght_IR
add wave -noupdate -group IR_distance_readings /MazeRunner_tb/iDUT/NOM_IR
add wave -noupdate -group Piezo_Sigs /MazeRunner_tb/iDUT/piezo
add wave -noupdate -group Piezo_Sigs /MazeRunner_tb/iDUT/piezo_n
add wave -noupdate -group HeadingSignals /MazeRunner_tb/iDUT/actl_hdng
add wave -noupdate -group HeadingSignals /MazeRunner_tb/iDUT/dsrd_hdng
add wave -noupdate -group HeadingSignals /MazeRunner_tb/iDUT/dsrd_hdng_adj
add wave -noupdate -group HeadingSignals /MazeRunner_tb/iDUT/iCNTRL/error
add wave -noupdate -group HeadingSignals -format Analog-Step -height 84 -max 994.0 -min -1.0 /MazeRunner_tb/iDUT/iCNTRL/actl_hdng
add wave -noupdate -group HeadingSignals /MazeRunner_tb/iDUT/at_hdng
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 263
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 2
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {8709614 ns}
