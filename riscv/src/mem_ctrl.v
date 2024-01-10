`ifndef MEM_CTRL
`define MEM_CTRL
`include "setsize.v"
module MemCtrl (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,
    input  wire [ 7:0] mem_din,   // data input bus
    output reg  [ 7:0] mem_dout,  // data output bus
    output reg  [31:0] mem_a,     // address bus (only 17:0 is used)
    output reg         mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    input  wire if_en,
    input  wire [`ADDR_WID] if_pc,
    output reg if_done,
    output wire [`IF_DATA_WID] if_data,//connected to if_data_

    input  wire lsb_en,
    input  wire lsb_wr,
    input  wire [`ADDR_WID] lsb_addr,
    input  wire [2:0] lsb_len,
    input  wire [`DATA_WID] lsb_w_data,
    output reg lsb_done,
    output reg [`DATA_WID] lsb_r_data
);
    reg [1:0] status;//01 for if, 10 for load, 11 for store
    reg [`MEM_CTRL_LEN_WID] cur;
    reg [`MEM_CTRL_LEN_WID] total;
    reg [`ADDR_WID] store_addr;
    reg [7:0] if_data_[3:0];//read from memory

    assign if_data[7:0] = if_data_[0];
    assign if_data[15:8] = if_data_[1];
    assign if_data[23:16] = if_data_[2];
    assign if_data[31:24] = if_data_[3];

    always @(posedge clk) begin
        if (rst) begin
            status <= 2'b0;
            if_done <= 0;
            lsb_done <= 0;
            mem_wr <= 0;
            mem_a <= 0;
        end else if (!rdy) begin
            if_done <= 0;
            lsb_done <= 0;
            mem_wr <= 0;
            mem_a <= 0;
        end else begin
            mem_wr <= 0;
            case (status)
                2'b0: begin
                    if (if_done || lsb_done) begin
                        //spare a cycle to tell ifetch and lsb done
                        if_done <= 0;
                        lsb_done <= 0;
                    end else if (!rollback) begin
                        if (lsb_en) begin
                            if (lsb_wr) begin
                                status <= 2'b11;
                                store_addr <= lsb_addr;
                            end
                            else begin
                                status <= 2'b10;
                                mem_a <= lsb_addr;
                                lsb_r_data <= 0;
                            end
                            cur <= 0;
                            total <= {4'b0, lsb_len};
                        end
                        else if (if_en) begin
                            cur <= 0;
                            total <= 4;
                            status <= 2'b01;
                            mem_a <= if_pc;
                        end
                    end
                end
                2'b01: begin//ifetch
                    if_data_[cur-1] <= mem_din;
                    if (cur + 1 == total) mem_a <= 0;
                    else mem_a <= mem_a + 1;
                    if (cur == total) begin
                        cur <= 0;
                        status <= 2'b0;
                        if_done <= 1;
                        mem_wr <= 0;
                        mem_a <= 0;
                    end
                    else cur <= cur + 1;
                end
                2'b10: begin//load
                    if (rollback) begin
                        lsb_done <= 0;
                        mem_wr <= 0;
                        mem_a <= 0;
                        cur <= 0;
                        status <= 2'b0;
                    end else begin
                        case (cur)
                        1: lsb_r_data[7:0] <= mem_din;
                        2: lsb_r_data[15:8] <= mem_din;
                        3: lsb_r_data[23:16] <= mem_din;
                        4: lsb_r_data[31:24] <= mem_din;
                        endcase
                        if (cur + 1 == total) mem_a <= 0;
                        else mem_a <= mem_a + 1;
                        if (cur == total) begin
                            lsb_done <= 1;
                            mem_wr <= 0;
                            mem_a <= 0;
                            cur <= 0;
                            status <= 2'b0;
                        end
                        else cur <= cur + 1;
                    end
                end
                2'b11: begin//store
                    if (store_addr[17:16] != 2'b11 || !io_buffer_full) begin
                        mem_wr <= 1;
                        case (cur)
                        0: mem_dout <= lsb_w_data[7:0];
                        1: mem_dout <= lsb_w_data[15:8];
                        2: mem_dout <= lsb_w_data[23:16];
                        3: mem_dout <= lsb_w_data[31:24];
                        endcase
                        if (cur == 0) mem_a <= store_addr;
                        else mem_a <= mem_a + 1;
                        if (cur == total) begin
                            cur <= 0;
                            status <= 2'b0;
                            lsb_done <= 1;
                            mem_wr <= 0;
                            mem_a <= 0;
                        end else cur <= cur + 1;
                    end
                end
            endcase
        end
    end
endmodule
`endif