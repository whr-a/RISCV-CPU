`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/31 05:09:05
// Design Name: 
// Module Name: MemCtrl
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

`include "SetSize.v"
module MemCtrl(
    input wire clk,
    input wire rst,
    input wire rdy,
    
    input  wire [ 7:0] mem_din,   // data input bus
    output reg  [ 7:0] mem_dout,  // data output bus
    output reg  [31:0] mem_a,     // address bus (only 17:0 is used)
    output reg         mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full
    
    input wire ifetch_en,
    input wire[`ADDR_WID] ifetch_pc,
    output reg ifetch_done,
    output wire [`ICACHE_BLK_WID] ifetch_data
    );
    reg [1:0] status;//00为等待 01为帮IF读取内存 预留一位给load and store
    reg [`BYTE_WID] ifetch_data_[`ICACHE_BLK_SIZE-1:0];//预留一行的空间
    reg[`MEMCTRL_TOTAL_WID] cnt;
    wire[`MEMCTRL_TOTAL_WID] total= 6'b100000;//总数为64
    genvar i;generate
        for(i=0;i<`ICACHE_BLK_SIZE;i=i+1)begin
            assign ifetch_data[i*8+7:i*8] = ifetch_data_[i];
        end
    endgenerate
    always @(posedge clk)begin
        if(rst)begin
            status <= 0;
            ifetch_done <= 0;
            mem_a <= 0;
            mem_wr <= 0;
            cnt <= 0;
        end
        else if (!rdy)begin
            ifetch_done <= 0;
            mem_a <= 0;
            mem_wr <= 0;
        end
        else begin
            if(status == 2'b01)begin
                mem_wr <= 0;//不需要写，只需要读
                ifetch_data_[cnt-1] <= mem_din;
                if(cnt + 1 == total)mem_a <= 0;
                else mem_a <= mem_a + 1;
                if(cnt == total)begin
                    ifetch_done <= 1;
                    cnt = 0;
                    status = 2'b00;
                end
                else begin
                    cnt <= cnt + 1;
                end
            end
            else if(status == 2'b00)begin
                if(ifetch_done)ifetch_done <= 0;
                else if(ifetch_en) begin
                    status <= 2'b01;
                    mem_a <= ifetch_pc;
                    cnt <= 0;
                end
            end
        end
    end
endmodule
