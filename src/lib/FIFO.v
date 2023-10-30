`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/25 00:44:21
// Design Name: 
// Module Name: fifo
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


module fifo(
    input wire clk,
    input wire rst,
    input wire write,
    input wire[7:0] writedata,
    input wire read,
    output wire[7:0] readdata,
    output wire empty,
    output wire full 
    );
    reg[2:0] f_readptr;
    wire[2:0] n_readptr;
    reg[2:0] f_writeptr;
    wire[2:0] n_writeptr;
    reg f_empty;
    wire n_empty;
    reg f_full;
    wire n_full;
    reg[7:0] data[7:0];
    wire [7:0] datawrite;
    
    always @(posedge clk)begin
        if(rst)begin
            f_readptr <= 1'b0;
            f_writeptr <= 1'b0;
            f_empty <= 1'b1;
            f_full <= 1'b0;
        end
        else begin
            f_readptr <= n_readptr;
            f_writeptr <= n_writeptr;
            f_empty <= n_empty;
            f_full <= n_full;
            data[f_writeptr] <= datawrite;
        end
    end
    wire canread,canwrite;
    assign canread = (read && !f_empty);
    assign canwrite = (write && !f_full);
    
    assign n_readptr = canread ? f_readptr + 1'b1 : f_readptr;
    assign n_writeptr = canwrite ? f_writeptr + 1'b1 : f_writeptr;
    
    assign datawrite = canwrite ? writedata : data[f_writeptr];
    assign n_empty = (f_empty && !canwrite) || (f_writeptr - f_readptr == 1'b1 && canread);
    assign n_full = (f_full && !canread) || (f_readptr - f_writeptr == 1'b1 && canwrite);
    
    assign readdata = data[f_readptr];
    assign empty = f_empty;
    assign full = f_full;
endmodule

