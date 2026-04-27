onerror {resume}
quietly virtual signal -install /MazeRunner_tb_integrated_left/iDUT { (context /MazeRunner_tb_integrated_left/iDUT )&{lft_spd ,rght_spd }} MotorSpeeds
quietly virtual signal -install /MazeRunner_tb_integrated_left/iDUT { (context /MazeRunner_tb_integrated_left/iDUT )&{stp_lft , stp_rght }} STOP_CONDITIONS
quietly virtual signal -install /MazeRunner_tb_integrated_left/iDUT { (context /MazeRunner_tb_integrated_left/iDUT )&{stp_lft_cmd , stp_rght_cmd }} CMD_STOP_CONDITIONS
quietly virtual signal -install /MazeRunner_tb_integrated_left/iDUT { (context /MazeRunner_tb_integrated_left/iDUT )&{stp_lft_slv , stp_rght_slv }} SLV_STOP_CONDITIONS
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group Basic_Signals /MazeRunner_tb_integrated_left/iDUT/FAST_SIM
add wave -noupdate -expand -group Basic_Signals /MazeRunner_tb_integrated_left/clk
add wave -noupdate -expand -group Basic_Signals /MazeRunner_tb_integrated_left/RST_n
add wave -noupdate -expand -group Basic_Signals /MazeRunner_tb_integrated_left/iDUT/cmd_md
add wave -noupdate -expand -group Basic_Signals /MazeRunner_tb_integrated_left/iDUT/en_fusion
add wave -noupdate -expand -group Basic_Signals /MazeRunner_tb_integrated_left/iDUT/rst_n
add wave -noupdate -expand -group Basic_Signals /MazeRunner_tb_integrated_left/iDUT/batt_low
add wave -noupdate -expand -group Basic_Signals /MazeRunner_tb_integrated_left/iDUT/iIR/vbatt
add wave -noupdate -expand -group Basic_Signals /MazeRunner_tb_integrated_left/batt
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb_integrated_left/snd_cmd
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb_integrated_left/cmd
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb_integrated_left/cmd_sent
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb_integrated_left/resp_rdy
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb_integrated_left/resp
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb_integrated_left/clr_resp_rdy
add wave -noupdate -group Command_Sending_Sigs /MazeRunner_tb_integrated_left/iDUT/resp_sent
add wave -noupdate -group Remote_Comm_Signals /MazeRunner_tb_integrated_left/TX_RX
add wave -noupdate -group Remote_Comm_Signals /MazeRunner_tb_integrated_left/iDUT/send_resp
add wave -noupdate -group Remote_Comm_Signals /MazeRunner_tb_integrated_left/RX_TX
add wave -noupdate -group A2D_Comm_Sigs /MazeRunner_tb_integrated_left/A2D_MISO
add wave -noupdate -group A2D_Comm_Sigs /MazeRunner_tb_integrated_left/A2D_MOSI
add wave -noupdate -group A2D_Comm_Sigs /MazeRunner_tb_integrated_left/A2D_SCLK
add wave -noupdate -group A2D_Comm_Sigs /MazeRunner_tb_integrated_left/A2D_SS_n
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb_integrated_left/INRT_INT
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb_integrated_left/INRT_MISO
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb_integrated_left/INRT_MOSI
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb_integrated_left/INRT_SCLK
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb_integrated_left/INRT_SS_n
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb_integrated_left/IR_lft_en
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb_integrated_left/IR_cntr_en
add wave -noupdate -group Inert_Intf_Comm_Sigs /MazeRunner_tb_integrated_left/IR_rght_en
add wave -noupdate -group Movement_Signals /MazeRunner_tb_integrated_left/iDUT/moving
add wave -noupdate -group Movement_Signals -expand -group MotorSpeeds -format Analog-Step -height 84 -max 3896.0 -radix hexadecimal /MazeRunner_tb_integrated_left/iDUT/lft_spd
add wave -noupdate -group Movement_Signals -expand -group MotorSpeeds -format Analog-Step -height 84 -max 4094.0 -radix hexadecimal /MazeRunner_tb_integrated_left/iDUT/rght_spd
add wave -noupdate -group Movement_Signals -group PWM_Signals -expand -group lftPWM /MazeRunner_tb_integrated_left/lftPWM1
add wave -noupdate -group Movement_Signals -group PWM_Signals -expand -group lftPWM /MazeRunner_tb_integrated_left/lftPWM2
add wave -noupdate -group Movement_Signals -group PWM_Signals -expand -group rightPWM /MazeRunner_tb_integrated_left/rghtPWM1
add wave -noupdate -group Movement_Signals -group PWM_Signals -expand -group rightPWM /MazeRunner_tb_integrated_left/rghtPWM2
add wave -noupdate -group Movement_Signals -format Analog-Step -height 84 -max 688.0 -radix hexadecimal /MazeRunner_tb_integrated_left/iDUT/frwrd_spd
add wave -noupdate -group Movement_Signals /MazeRunner_tb_integrated_left/iDUT/IR_Dtrm
add wave -noupdate -expand -group Position_Signals -format Analog-Step -height 84 -max 14336.0 -min 6324.0 -radix hexadecimal /MazeRunner_tb_integrated_left/iPHYS/xx
add wave -noupdate -expand -group Position_Signals -format Analog-Step -height 84 -max 14336.0 -min 10474.0 -radix hexadecimal /MazeRunner_tb_integrated_left/iPHYS/yy
add wave -noupdate -expand -group Position_Signals /MazeRunner_tb_integrated_left/iDUT/dsrd_hdng
add wave -noupdate -expand -group Position_Signals -format Analog-Step -height 84 -max 4095.0 -radix hexadecimal /MazeRunner_tb_integrated_left/iDUT/iCNTRL/actl_hdng
add wave -noupdate -expand -group Piezo_Sigs /MazeRunner_tb_integrated_left/iDUT/piezo
add wave -noupdate -expand -group Indicator_Signals /MazeRunner_tb_integrated_left/iDUT/cal_done
add wave -noupdate -expand -group Indicator_Signals /MazeRunner_tb_integrated_left/hall_n
add wave -noupdate -expand -group Indicator_Signals /MazeRunner_tb_integrated_left/iDUT/sol_cmplt
add wave -noupdate -expand -group Indicator_Signals /MazeRunner_tb_integrated_left/LED
add wave -noupdate -expand -group Indicator_Signals /MazeRunner_tb_integrated_left/piezo
add wave -noupdate -group iCMD /MazeRunner_tb_integrated_left/iDUT/cmd
add wave -noupdate -group iCMD /MazeRunner_tb_integrated_left/iDUT/cmd_rdy
add wave -noupdate -group iCMD /MazeRunner_tb_integrated_left/iDUT/clr_cmd_rdy
add wave -noupdate -group Navigate_Signals /MazeRunner_tb_integrated_left/iDUT/iNAV/state
add wave -noupdate -group Navigate_Signals /MazeRunner_tb_integrated_left/iDUT/hdng_rdy
add wave -noupdate -group Navigate_Signals /MazeRunner_tb_integrated_left/iDUT/moving
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb_integrated_left/iDUT/strt_cal
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb_integrated_left/iDUT/strt_mv
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb_integrated_left/iDUT/mv_cmplt
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb_integrated_left/iDUT/STOP_CONDITIONS
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb_integrated_left/iDUT/stp_lft
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb_integrated_left/iDUT/stp_rght
add wave -noupdate -group Navigate_Signals -expand -group Nav_Control_Sigs /MazeRunner_tb_integrated_left/iDUT/en_fusion
add wave -noupdate -group Navigate_Signals -expand -group Nav_Condition_Sigs /MazeRunner_tb_integrated_left/iDUT/lft_opn
add wave -noupdate -group Navigate_Signals -expand -group Nav_Condition_Sigs /MazeRunner_tb_integrated_left/iDUT/rght_opn
add wave -noupdate -group Navigate_Signals -expand -group Nav_Condition_Sigs /MazeRunner_tb_integrated_left/iDUT/frwrd_opn
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/strt_cal
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/strt_hdng_cmd
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/dsrd_hdng_cmd
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/strt_mv_cmd
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/CMD_STOP_CONDITIONS
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/stp_lft_cmd
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/stp_rght_cmd
add wave -noupdate -group CmdProc_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/mv_cmplt
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/strt_cal
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/strt_hdng_slv
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/dsrd_hdng_slv
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/strt_mv_slv
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/SLV_STOP_CONDITIONS
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/stp_lft_slv
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/stp_rght_slv
add wave -noupdate -group MazeSolve_Nav_Sigs /MazeRunner_tb_integrated_left/iDUT/mv_cmplt
add wave -noupdate -group IR_distance_readings /MazeRunner_tb_integrated_left/iDUT/lft_IR
add wave -noupdate -group IR_distance_readings /MazeRunner_tb_integrated_left/iDUT/rght_IR
add wave -noupdate -group IR_distance_readings -clampanalog 1 -format Analog-Step -height 84 -max 3806.9999999999995 -radix hexadecimal /MazeRunner_tb_integrated_left/iDUT/lft_IR
add wave -noupdate -group IR_distance_readings -format Analog-Step -height 84 -max 2816.0 -radix hexadecimal -radixshowbase 0 /MazeRunner_tb_integrated_left/iDUT/rght_IR
add wave -noupdate -group IR_distance_readings /MazeRunner_tb_integrated_left/iDUT/NOM_IR
add wave -noupdate /MazeRunner_tb_integrated_left/iDUT/piezo_n
add wave -noupdate -group HeadingSignals /MazeRunner_tb_integrated_left/iDUT/actl_hdng
add wave -noupdate -group HeadingSignals /MazeRunner_tb_integrated_left/iDUT/dsrd_hdng
add wave -noupdate -group HeadingSignals /MazeRunner_tb_integrated_left/iDUT/dsrd_hdng_adj
add wave -noupdate -group HeadingSignals /MazeRunner_tb_integrated_left/iDUT/iCNTRL/error
add wave -noupdate -group HeadingSignals -format Analog-Step -height 84 -max 4095.0 -radix hexadecimal /MazeRunner_tb_integrated_left/iDUT/iCNTRL/actl_hdng
add wave -noupdate -group HeadingSignals /MazeRunner_tb_integrated_left/iDUT/at_hdng
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1375304 ns} 0}
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
WaveRestoreZoom {0 ns} {86354594 ns}
