`ifndef DECODER
`define DECODER
`include "SetSize.v"

module Decoder (
    //input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,
    
    //form iFetch
    input wire inst_rdy,
    input wire [`INST_WID] inst,
    input wire [`ADDR_WID] inst_pc,
    input wire jump_predict,

    //发送指令 issue
    output reg issue,
    output reg [`ROB_POS_WID] rob_pos,
    output reg [`OPCODE_WID] opcode,
    output reg is_store,
    output reg [`FUNCT3_WID] funct3,
    output reg funct7,//只有30位有区别
    output reg [`DATA_WID] rs1_val,
    output reg [`ROB_ID_WID] rs1_rob_id,//输出依赖关系
    output reg [`DATA_WID] rs2_val,
    output reg [`ROB_ID_WID] rs2_rob_id,
    output reg [`DATA_WID] imm,
    output reg [`REG_POS_WID] rd,
    output reg [`ADDR_WID] pc,
    output reg jump_predict_out,
    output reg is_ready,

    //Regfile
    input wire [`DATA_WID] reg_rs1_val,
    input wire [`ROB_ID_WID] reg_rs1_rob_id,//regfile中记录的rs1依赖，可能有延迟
    output wire [`REG_POS_WID] reg_rs1,
    input wire [`DATA_WID] reg_rs2_val,
    input wire [`ROB_ID_WID] reg_rs2_rob_id,
    output wire [`REG_POS_WID] reg_rs2,

    //ROB
    input wire rob_rs1_ready,
    input wire[`DATA_WID] rob_rs1_val,
    output wire [`ROB_POS_WID] rob_rs1_pos,//本质上由regfile告知
    input wire rob_rs2_ready,
    input wire[`DATA_WID] rob_rs2_val,
    output wire [`ROB_POS_WID] rob_rs2_pos,

    output reg rs_en,
    output reg lsb_en,
    
    input wire [`ROB_POS_WID] nxt_rob_pos,

    //from RS
    input wire alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [`DATA_WID] alu_result_val
);
assign reg_rs1 = inst[`RS1_RANGE];
assign reg_rs2 = inst[`RS2_RANGE];
assign rob_rs1_pos = reg_rs1_rob_id[`ROB_POS_WID];//连接依赖位置为rob_rs1_pos
assign rob_rs2_pos = reg_rs2_rob_id[`ROB_POS_WID];

always @(*) begin
    opcode = inst[`OPCODE_RANGE];
    funct3 = inst[`FUNCT3_RANGE];
    funct7 = inst[30];
    rd = inst[`RD_RANGE];
    pc = inst_pc;
    imm = 0;
    jump_predict_out = jump_predict;

    rob_pos = next_rob_pos;

    issue = 0;
    lsb_en = 0;
    rs_en = 0;
    is_ready = 0;

    rs1_val = 0;
    rs2_val = 0;
    rs1_rob_id = 0;
    rs2_rob_id = 0;
    if(!rst && inst_rdy && !rollback && rdy)begin
        issue = 1;
        rs1_rob_id = 0;
        if(reg_rs1_rob_id[4] == 0)begin//0为ready 1为renamed
            rs1_val = reg_rs1_val;
        end
        else if(rob_rs1_ready)begin
            rs1_val = rob_rs1_val;
        end
        else if(alu_result && rob_rs1_pos == alu_result_rob_pos)begin//alu算出来正好是rs1的位置的值
            rs1_val = alu_result_val;
        end
        else if(lsb_result && rob_rs1_pos == lsb_result_rob_pos)begin
            rs1_val = lsb_result_val;
        end
        else begin
            rs1_val = 0;
            rs1_rob_id = reg_rs1_rob_id;
        end
        
        rs2_rob_id = 0;
        if(reg_rs2_rob_id[4] == 0)begin//0为ready 1为renamed
            rs2_val = reg_rs2_val;
        end
        else if(rob_rs2_ready)begin
            rs2_val = rob_rs2_val;
        end
        else if(alu_result && rob_rs2_pos == alu_result_rob_pos)begin//alu算出来正好是rs1的位置的值
            rs2_val = alu_result_val;
        end
        else if(lsb_result && rob_rs2_pos == lsb_result_rob_pos)begin
            rs2_val = lsb_result_val;
        end
        else begin
            rs2_val = 0;
            rs2_rob_id = reg_rs2_rob_id;
        end

        is_store = 0;
        case (inst[`OPCODE_RANGE])
            `OPCODE_S:begin
                lsb_en = 1;
                is_ready = 1;
                rd = 0;
                imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
                is_store = 1;
            end
            `OPCODE_L:begin
                lsb_en = 1;
                rs2_rob_id = 0;
                rs2_val = 0;
                imm = {{21{inst[31]}}, inst[30:20]};
            end
            `OPCODE_ARITHI,`OPCODE_JALR: begin
                rs_en = 1;
                rs2_rob_id = 0;
                rs2_val = 0;
                imm = {{21{inst[31]}}, inst[30:20]};
            end
            `OPCODE_ARITH:begin
                rs_en = 1;
            end
            `OPCODE_JAL:begin
                rs_en = 1;
                rs1_rob_id = 0;
                rs1_val = 0;
                rs2_rob_id = 0;
                rs2_val = 0;
                imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            end
            `OPCODE_BR:begin
                rs_en = 1;
                rd = 0;
                imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            end
            `OPCODE_LUI, `OPCODE_AUIPC: begin
                rs_en = 1;
                rs1_rob_id = 0;
                rs1_val = 0;
                rs2_rob_id = 0;
                rs2_val = 0;
                imm = {inst[31:12], 12'b0};
            end
        endcase
    end
end
endmodule
`endif