`include "setsize.v"
`include "ifetch.v"
`include "decoder.v"
`include "mem_ctrl.v"
`include "alu.v"
`include "rs.v"
`include "regfile.v"
`include "rob.v"
`include "lsb.v"

module cpu(
    input  wire                 clk_in,     // system clock signal
    input  wire                 rst_in,     // reset signal
    input  wire                 rdy_in,     // ready signal, pause cpu when low

    input  wire [ 7:0]          mem_din,    // data input bus
    output wire [ 7:0]          mem_dout,   // data output bus
    output wire [31:0]          mem_a,      // address bus (only 17:0 is used)//todo
    output wire                 mem_wr,     // write/read signal (1 for write)//todo
    
    input  wire                 io_buffer_full, // 1 if uart buffer is full
    
    output wire [31:0]      dbgreg_dout   // cpu register output (debugging demo)//todo
);

wire rollback;

wire rs_nxt_full;
wire lsb_nxt_full;
wire rob_nxt_full;

//ifetch <-> mem_ctrl
wire ifetch_to_memctrl_en;
wire [`ADDR_WID] ifetch_to_memctrl_pc;
wire [`IF_DATA_WID] memctrl_to_ifetch_data;
wire memctrl_to_ifetch_done;

//LSB <-> mem_ctrl
wire lsb_to_memctrl_en;
wire lsb_to_memctrl_wr;
wire [2:0] lsb_to_memctrl_len;
wire memctrl_to_lsb_done;
wire [`DATA_WID] lsb_to_memctrl_w_data;
wire [`DATA_WID] memctrl_to_lsb_r_data;
wire [`ADDR_WID] lsb_to_memctrl_addr;

//rob -> ifetch
wire rob_to_ifetch_br;
wire rob_to_ifetch_br_jump;
wire [`ADDR_WID] rob_to_ifetch_br_pc;

wire rob_to_ifetch_set_pc_en;
wire [`ADDR_WID] rob_to_ifetch_set_pc;

//ifetch -> decoder
wire ifetch_to_decoder_inst_rdy;
wire [`INST_WID] ifetch_to_decoder_inst;
wire [`ADDR_WID] ifetch_to_decoder_inst_pc;
wire ifetch_to_decoder_inst_pred_jump;

// decoder issue
wire issue;
wire [`ROB_POS_WID] issue_rob_pos;
wire [`ADDR_WID] issue_pc;
wire [`OPCODE_WID] issue_opcode;
wire [`FUNCT3_WID] issue_funct3;
wire issue_funct7;
wire [`REG_POS_WID] issue_rd;
wire [`DATA_WID] issue_rs1_val;
wire [`ROB_ID_WID] issue_rs1_rob_id;
wire [`DATA_WID] issue_rs2_val;
wire [`ROB_ID_WID] issue_rs2_rob_id;
wire [`DATA_WID] issue_imm;
wire issue_pred_jump;
wire issue_is_ready;
wire issue_is_store;

// decoder <- regfile
wire [`REG_POS_WID] decoder_query_reg_rs1;
wire [`DATA_WID] decoder_query_reg_rs1_val;
wire [`ROB_ID_WID] decoder_query_reg_rs1_rob_id;
wire [`REG_POS_WID] decoder_query_reg_rs2;
wire [`DATA_WID] decoder_query_reg_rs2_val;
wire [`ROB_ID_WID] decoder_query_reg_rs2_rob_id;

// decoder <- rob
wire [`ROB_POS_WID] decoder_query_rob_rs1_pos;
wire decoder_query_rob_rs1_ready;
wire [`DATA_WID] decoder_query_rob_rs1_val;
wire [`ROB_POS_WID] decoder_query_rob_rs2_pos;
wire decoder_query_rob_rs2_ready;
wire [`DATA_WID] decoder_query_rob_rs2_val;

// decoder -> rs
wire decoder_to_rs_en;

// decoder -> lsb
wire decoder_to_lsb_en;

//rob next position
wire [`ROB_POS_WID] nxt_rob_pos;

// commit
wire [`ROB_POS_WID] rob_commit_pos;
// to regfile
wire rob_to_reg_write;
wire [`REG_POS_WID] rob_to_reg_rd;
wire [`DATA_WID] rob_to_reg_val;
// to lsb
wire rob_to_lsb_commit_store;

wire [`ROB_POS_WID] rob_head_pos;

//alu broadcast
wire cdb_alu_result;
wire [`ADDR_WID] cdb_alu_result_pc;
wire cdb_alu_result_jump;
wire [`ROB_POS_WID] cdb_alu_result_rob_pos;
wire [`DATA_WID] cdb_alu_result_val;

//lsb broadcast
wire cdb_lsb_result;
wire [`ROB_POS_WID] cdb_lsb_result_rob_pos;
wire [`DATA_WID] cdb_lsb_result_val;

//rs -> alu
wire rs_to_alu_en;
wire [`ADDR_WID] rs_to_alu_pc;
wire [`ROB_POS_WID] rs_to_alu_rob_pos;
wire [`OPCODE_WID] rs_to_alu_opcode;
wire [`FUNCT3_WID] rs_to_alu_funct3;
wire rs_to_alu_funct7;
wire [`DATA_WID] rs_to_alu_val1;
wire [`DATA_WID] rs_to_alu_val2;
wire [`DATA_WID] rs_to_alu_imm;

MemCtrl u_MemCtrl(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .mem_din(mem_din),
    .mem_dout(mem_dout),
    .mem_a(mem_a),
    .mem_wr(mem_wr),
    .io_buffer_full(io_buffer_full),
    .if_en(ifetch_to_memctrl_en),
    .if_pc(ifetch_to_memctrl_pc),
    .if_done(memctrl_to_ifetch_done),
    .if_data(memctrl_to_ifetch_data),
    .lsb_en(lsb_to_memctrl_en),
    .lsb_wr(lsb_to_memctrl_wr),
    .lsb_w_data(lsb_to_memctrl_w_data),
    .lsb_r_data(memctrl_to_lsb_r_data),
    .lsb_addr(lsb_to_memctrl_addr),
    .lsb_len(lsb_to_memctrl_len),
    .lsb_done(memctrl_to_lsb_done)
);

IFetch u_IFetch (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rs_nxt_full(rs_nxt_full),
    .lsb_nxt_full(lsb_nxt_full),
    .rob_nxt_full(rob_nxt_full),
    .rob_set_pc_en(rob_to_ifetch_set_pc_en),
    .rob_set_pc(rob_to_ifetch_set_pc),
    .rob_br(rob_to_ifetch_br),
    .rob_br_jump(rob_to_ifetch_br_jump),
    .rob_br_pc(rob_to_ifetch_br_pc),
    .inst_rdy(ifetch_to_decoder_inst_rdy),
    .inst(ifetch_to_decoder_inst),
    .inst_pc(ifetch_to_decoder_inst_pc),
    .inst_pred_jump(ifetch_to_decoder_inst_pred_jump),
    .mc_en(ifetch_to_memctrl_en),
    .mc_pc(ifetch_to_memctrl_pc),
    .mc_done(memctrl_to_ifetch_done),
    .mc_data(memctrl_to_ifetch_data)
);

Decoder u_Decoder (
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .inst_rdy(ifetch_to_decoder_inst_rdy),
    .inst(ifetch_to_decoder_inst),
    .inst_pc(ifetch_to_decoder_inst_pc),
    .inst_pred_jump(ifetch_to_decoder_inst_pred_jump),

    .issue(issue),
    .rob_pos(issue_rob_pos),
    .opcode(issue_opcode),
    .is_store(issue_is_store),
    .funct3(issue_funct3),
    .funct7(issue_funct7),
    .rs1_val(issue_rs1_val),
    .rs1_rob_id(issue_rs1_rob_id),
    .rs2_val(issue_rs2_val),
    .rs2_rob_id(issue_rs2_rob_id),
    .imm(issue_imm),
    .rd(issue_rd),
    .pc(issue_pc),
    .pred_jump(issue_pred_jump),
    .is_ready(issue_is_ready),

    .reg_rs1(decoder_query_reg_rs1),
    .reg_rs1_val(decoder_query_reg_rs1_val),
    .reg_rs1_rob_id(decoder_query_reg_rs1_rob_id),
    .reg_rs2(decoder_query_reg_rs2),
    .reg_rs2_val(decoder_query_reg_rs2_val),
    .reg_rs2_rob_id(decoder_query_reg_rs2_rob_id),

    .rob_rs1_pos(decoder_query_rob_rs1_pos),
    .rob_rs1_ready(decoder_query_rob_rs1_ready),
    .rob_rs1_val(decoder_query_rob_rs1_val),
    .rob_rs2_pos(decoder_query_rob_rs2_pos),
    .rob_rs2_ready(decoder_query_rob_rs2_ready),
    .rob_rs2_val(decoder_query_rob_rs2_val),

    .rs_en(decoder_to_rs_en),
    .lsb_en(decoder_to_lsb_en),
    .nxt_rob_pos(nxt_rob_pos),

    .alu_result(cdb_alu_result),
    .alu_result_rob_pos(cdb_alu_result_rob_pos),
    .alu_result_val(cdb_alu_result_val),

    .lsb_result(cdb_lsb_result),
    .lsb_result_rob_pos(cdb_lsb_result_rob_pos),
    .lsb_result_val(cdb_lsb_result_val)
);

RegFile u_RegFile (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),

    .issue(issue),
    .issue_rd(issue_rd),
    .issue_rob_pos(issue_rob_pos),

    .rs1(decoder_query_reg_rs1),
    .val1(decoder_query_reg_rs1_val),
    .rob_id1(decoder_query_reg_rs1_rob_id),
    .rs2(decoder_query_reg_rs2),
    .val2(decoder_query_reg_rs2_val),
    .rob_id2(decoder_query_reg_rs2_rob_id),

    .commit(rob_to_reg_write),
    .commit_rd(rob_to_reg_rd),
    .commit_val(rob_to_reg_val),
    .commit_rob_pos(rob_commit_pos)
);

RS u_RS (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .rs_nxt_full(rs_nxt_full),

    .alu_en(rs_to_alu_en),
    .alu_opcode(rs_to_alu_opcode),
    .alu_funct3(rs_to_alu_funct3),
    .alu_funct7(rs_to_alu_funct7),
    .alu_val1(rs_to_alu_val1),
    .alu_val2(rs_to_alu_val2),
    .alu_imm(rs_to_alu_imm),
    .alu_pc(rs_to_alu_pc),
    .alu_rob_pos(rs_to_alu_rob_pos),

    .issue(decoder_to_rs_en),
    .issue_rob_pos(issue_rob_pos),
    .issue_opcode(issue_opcode),
    .issue_funct3(issue_funct3),
    .issue_funct7(issue_funct7),
    .issue_rs1_val(issue_rs1_val),
    .issue_rs1_rob_id(issue_rs1_rob_id),
    .issue_rs2_val(issue_rs2_val),
    .issue_rs2_rob_id(issue_rs2_rob_id),
    .issue_imm(issue_imm),
    .issue_pc(issue_pc),

    .alu_result(cdb_alu_result),
    .alu_result_rob_pos(cdb_alu_result_rob_pos),
    .alu_result_val(cdb_alu_result_val),

    .lsb_result(cdb_lsb_result),
    .lsb_result_rob_pos(cdb_lsb_result_rob_pos),
    .lsb_result_val(cdb_lsb_result_val)
);

ALU u_ALU(
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),

    .alu_en(rs_to_alu_en),
    .pc(rs_to_alu_pc),
    .rob_pos(rs_to_alu_rob_pos),
    .opcode(rs_to_alu_opcode),
    .funct3(rs_to_alu_funct3),
    .funct7(rs_to_alu_funct7),
    .val1(rs_to_alu_val1),
    .val2(rs_to_alu_val2),
    .imm(rs_to_alu_imm),

    .result(cdb_alu_result),
    .result_rob_pos(cdb_alu_result_rob_pos),
    .result_val(cdb_alu_result_val),
    .result_jump(cdb_alu_result_jump),
    .result_pc(cdb_alu_result_pc)
);

LSB u_LSB (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rollback(rollback),
    .lsb_nxt_full(lsb_nxt_full),

    .issue(decoder_to_lsb_en),
    .issue_rob_pos(issue_rob_pos),
    .issue_is_store(issue_is_store),
    .issue_funct3(issue_funct3),
    .issue_rs1_val(issue_rs1_val),
    .issue_rs1_rob_id(issue_rs1_rob_id),
    .issue_rs2_val(issue_rs2_val),
    .issue_rs2_rob_id(issue_rs2_rob_id),
    .issue_imm(issue_imm),

    .mc_en(lsb_to_memctrl_en),
    .mc_wr(lsb_to_memctrl_wr),
    .mc_w_data(lsb_to_memctrl_w_data),
    .mc_r_data(memctrl_to_lsb_r_data),
    .mc_addr(lsb_to_memctrl_addr),
    .mc_len(lsb_to_memctrl_len),
    .mc_done(memctrl_to_lsb_done),

    .result(cdb_lsb_result),
    .result_rob_pos(cdb_lsb_result_rob_pos),
    .result_val(cdb_lsb_result_val),

    .alu_result(cdb_alu_result),
    .alu_result_rob_pos(cdb_alu_result_rob_pos),
    .alu_result_val(cdb_alu_result_val),

    .lsb_result(cdb_lsb_result),
    .lsb_result_rob_pos(cdb_lsb_result_rob_pos),
    .lsb_result_val(cdb_lsb_result_val),

    .commit_store(rob_to_lsb_commit_store),
    .commit_rob_pos(rob_commit_pos),
    .head_rob_pos(rob_head_pos)
);

ROB u_ROB (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rob_nxt_full(rob_nxt_full),
    .rollback(rollback),
    .nxt_rob_pos(nxt_rob_pos),

    .if_set_pc_en(rob_to_ifetch_set_pc_en),
    .if_set_pc(rob_to_ifetch_set_pc),

    .issue(issue),
    .issue_rd(issue_rd),
    .issue_opcode(issue_opcode),
    .issue_pc(issue_pc),
    .issue_pred_jump(issue_pred_jump),
    .issue_is_ready(issue_is_ready),

    .head_rob_pos(rob_head_pos),
    .commit_rob_pos(rob_commit_pos),
    .reg_write(rob_to_reg_write),
    .reg_rd(rob_to_reg_rd),
    .reg_val(rob_to_reg_val),
    .lsb_store(rob_to_lsb_commit_store),
    .commit_br(rob_to_ifetch_br),
    .commit_br_jump(rob_to_ifetch_br_jump),
    .commit_br_pc(rob_to_ifetch_br_pc),

    .rs1_pos(decoder_query_rob_rs1_pos),
    .rs1_ready(decoder_query_rob_rs1_ready),
    .rs1_val(decoder_query_rob_rs1_val),
    .rs2_pos(decoder_query_rob_rs2_pos),
    .rs2_ready(decoder_query_rob_rs2_ready),
    .rs2_val(decoder_query_rob_rs2_val),
    
    .alu_result(cdb_alu_result),
    .alu_result_rob_pos(cdb_alu_result_rob_pos),
    .alu_result_val(cdb_alu_result_val),
    .alu_result_jump(cdb_alu_result_jump),
    .alu_result_pc(cdb_alu_result_pc),

    .lsb_result(cdb_lsb_result),
    .lsb_result_rob_pos(cdb_lsb_result_rob_pos),
    .lsb_result_val(cdb_lsb_result_val)
);
endmodule