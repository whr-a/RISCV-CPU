`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/30 15:30:44
// Design Name: 
// Module Name: iFetch
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`ifndef IFETCH
`define IFETCH
`include "SetSize.v"
module iFetch(
    input wire clk,
    input wire rst,
    input wire rdy,
    
    input wire rs_full,
    input wire lsb_full,
    input wire rob_full,

    //id means Instruction Decoder
    output reg id_en,
    output reg [`INST_WID] inst,

    //assign to memctrl
    output reg memctrl_en,
    output reg [`ADDR_WID] memctrl_pc,
    input wire memctrl_done,
    input wire [`ICACHE_BLK_WID] memctrl_data,
    
    input wire rob_set_pc_en,
    input wire[`ADDR_WID] rob_set_pc

    input wire rob_pre_fresh,
    input wire[`ADDR_WID] rob_pc,
    input wire rob_pc_jump,
    output reg predict
);
reg status; //Ϊ0��ʾ���У�Ϊ1��ʾ�ȴ�memctrl�ṩ����
reg [`ADDR_WID] pc;
reg [`ADDR_WID] next_pc;
reg valid[`ICACHE_BLK_NUM-1:0];
reg [`ICACHE_TAG_WID] tag[`ICACHE_BLK_NUM-1:0];
reg [`ICACHE_BLK_WID] data[`ICACHE_BLK_NUM-1:0];

wire [`ICACHE_BYTESELECT_WID] pc_byteselect = pc[`ICACHE_BYTESELECT_RANGE];
wire [`ICACHE_INDEX_WID] pc_index = pc[`ICACHE_INDEX_RANGE];
wire [`ICACHE_TAG_WID] pc_tag = pc[`ICACHE_TAG_RANGE];
wire hit = valid[pc_index] && (tag[pc_index] == pc_tag);
wire [`ICACHE_INDEX_WID] memctrl_pc_index = memctrl_pc[`ICACHE_INDEX_RANGE];
wire [`ICACHE_TAG_WID] memctrl_pc_tag = memctrl_pc[`ICACHE_TAG_RANGE];

wire [`ICACHE_BLK_WID] cur_block_raw = data[pc_index];
wire [`INST_WID] cur_block[15:0];//һ������16��ָ��
wire [`INST_WID] get_inst = cur_block[pc_byteselect];

genvar i;generate
    for (i = 0; i < `ICACHE_BLK_SIZE / `INST_BYTE_SIZE; i = i + 1) begin//����һ�������ɵ�ָ��
        assign cur_block[i] = cur_block_raw[i*32+31:i*32];
    end
endgenerate
integer j;
always @(posedge clk) begin
    if (rst) begin
        pc <= 32'b0;
        memctrl_pc <= 32'b0;
        memctrl_en <= 0;
        for(j = 0; j < `ICACHE_BLK_NUM; j = j + 1)
            valid[j] <= 0;
        id_en <= 0;
        status <= 0;
    end
    else if(rdy)begin
        if(rob_set_pc_en)begin
            pc <= rob_set_pc;
            id_en <= 0;
        end
        else begin
            if(hit && !rs_full && !lsb_full && !rob_full)begin
                id_en <= 1;
                inst <= get_inst;
                pc <= next_pc;
            end
            else begin
                id_en <= 0;
            end
        end
    end
    if (status == 1'b0) begin
        if(!hit)begin
            memctrl_en <= 1'b1;
            memctrl_pc <= {pc[31:6],6'b0};
            status <= 1'b1;
        end
    end
    else begin
        if(memctrl_done)begin
            memctrl_en <= 0;
            valid[memctrl_pc_index] <= 1;
            tag[memctrl_pc_index] <= memctrl_pc_tag;
            data[memctrl_pc_index] <= memctrl_data;
            status <= 1'b0;
        end
    end
end
reg[2:0] predict_table[255:0];
wire[7:0] idx = rob_pc[9:2];
always @(posedge clk)begin
    if(rst)begin
        for(j = 0; j < 256; j = j + 1)begin
            predict_table[j] <= 0;
        end
    end
    else if(rdy)begin
        if(rob_pre_fresh)begin
            if(rob_pc_jump)begin
                if(predict_table[idx] < 2'b11)predict_table[idx] = predict_table[idx] + 1;
            end
            else begin
                if(predict_table[idx] > 2'b00)predict_table[idx] = predict_table[idx] - 1;
            end
        end
    end
end
wire[7:0] pc_idx = pc[9:2];
always @(*)begin
    if(get_inst[`OPCODE_RANGE] == `OPCODE_JAL)begin
        next_pc = pc + {{12{get_inst[31]}}, get_inst[19:12], get_inst[20], get_inst[30:21], 1'b0};
        predict = 1'b1;
    end
    else if(get_inst[`OPCODE_RANGE] == `OPCODE_JALR)begin
        if(predict_table[pc_idx] >= 2'b10)begin
            next_pc = pc + {{20{get_inst[31]}}, get_inst[7], get_inst[30:25], get_inst[11:8], 1'b0};
            predict = 1'b1;
        end
    end
    else begin
        next_pc = pc + 4;
        predict = 1'b0;
    end
end
endmodule
`endif