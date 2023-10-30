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
    //id -> Instruction Decoder
    output reg id_en,
    output reg [`INST_WID] inst,
    //assign to memctrl
    output reg memctrl_en,
    output reg [`ADDR_WID] memctrl_pc,
    input wire memctrl_done,
    input wire [`ICACHE_BLK_WID] memctrl_data,
    
    input wire rob_set_pc_en,
    input wire[`ADDR_WID] rob_set_pc
    );
    reg status; //为0表示空闲，为1表示等待memctrl提供数据
    reg [`ADDR_WID] pc;
    
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
    wire [`INST_WID] cur_block[15:0];//一行容纳16条指令
    wire [`INST_WID] get_inst = cur_block[pc_byteselect];
    
    genvar i;generate
        for (i = 0; i < `ICACHE_BLK_SIZE / `INST_BYTE_SIZE; i = i + 1) begin//遍历一行能容纳的指令
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
                    pc <= pc + 4;//todo 后期需要添加分支预测
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
endmodule
`endif