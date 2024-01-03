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
`ifndef MEMCTRL
`define MEMCTRL
`include "SetSize.v"
module MemCtrl(
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,
    input  wire [ 7:0] mem_din,   // data input bus
    output reg  [ 7:0] mem_dout,  // data output bus
    output reg  [31:0] mem_a,     // address bus (only 17:0 is used)
    output reg         mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full
    
    input wire ifetch_en,
    input wire[`ADDR_WID] ifetch_pc,
    output reg ifetch_done,
    output wire [`ICACHE_BLK_WID] ifetch_data

    input wire lsb_en,
    input wire lsb_wr,
    input wire [`ADDR_WID] lsb_addr,
    input wire [2:0] lsb_len,
    input wire [`DATA_WID] lsb_w_data,
    output reg lsb_done,
    output reg [`DATA_WID] lsb_r_data
);
    reg [1:0] status;//00IDLE 01IFETCH 10STORE 11LOAD
    reg [`BYTE_WID] ifetch_data_[`ICACHE_BLK_SIZE-1:0];//Ԥ��һ�еĿռ�
    reg[`MEMCTRL_TOTAL_WID] cnt;
    wire[`MEMCTRL_TOTAL_WID] total;
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
            lsb_done <= 0;
            mem_a <= 0;
            mem_wr <= 0;
        end
        else begin
            mem_wr <= 0;
            case(status)
                2'b00:begin
                    if(ifetch_done || lsb_done)begin
                        ifetch_done <= 0;
                        lsb_done <= 0;
                    end
                    else if (!rollback)begin
                        if(lsb_en)begin
                            if(lsb_wr)begin
                                status <= 2'b10;
                                store_addr <= lsb_addr;
                            end
                            else begin
                                status <= 2'b11;
                                mem_a <= lsb_addr;
                                lsb_r_data <= 0;
                            end
                            stage <= 0;
                            total <= {4'b0,lsb_len};
                        end
                        else if(ifetch_en)begin
                            status <= 2'b01;
                            mem_a <= ifetch_pc;
                            cnt <= 0;
                            total <= `ICACHE_BLK_SIZE;
                        end
                    end
                end
                2'b01:begin
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
                2'b10:begin
                    if(store_addr[17:16] != 2'b11 || !io_buffer_full)begin
                        mem_wr <= 1;
                        case (cnt)
                            0: mem_dout <= lsb_w_data[7:0];
                            1: mem_dout <= lsb_w_data[15:8];
                            2: mem_dout <= lsb_w_data[23:16];
                            3: mem_dout <= lsb_w_data[31:24];
                        endcase
                        if(cnt == 0)mem_a <= store_addr;
                        else mem_a <= mem_a + 1;
                        if(cnt == total)begin
                            lsb_done <= 1;
                            mem_wr <= 0;
                            mem_a <= 0;
                            cnt <= 0;
                            status <= 2'b00;
                        end
                        else begin
                            cnt <= cnt + 1;
                        end
                    end
                end
                2'b11:begin
                    if(rollback)begin
                        lsb_done <= 0;
                        mem_wr <= 0;
                        mem_a <= 0;
                        stage <= 0;
                        status <= 2'b00;
                    end
                    else begin
                        case (cnt)
                            1: lsb_r_data[7:0] <= mem_din;
                            2: lsb_r_data[15:8] <= mem_din;
                            3: lsb_r_data[23:16] <= mem_din;
                            4: lsb_r_data[31:24] <= mem_din;
                        endcase
                        if(cnt + 1 == total)mem_a <= 0;
                        else mem_a <= mem_a + 1;
                        if(cnt == total)begin
                            lsb_done <= 1;
                            mem_wr <= 0;
                            mem_a <= 0;
                            cnt <= 0;
                            status <= 2'b00;
                        end
                        else begin
                            cnt <= cnt + 1;
                        end
                    end
                end
            endcase
        end
    end
endmodule
`endif