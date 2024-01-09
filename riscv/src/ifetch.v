`ifndef IFETCH
`define IFETCH
`include "setsize.v"
module IFetch (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rs_nxt_full,
    input wire lsb_nxt_full,
    input wire rob_nxt_full,

    //to decoder
    output reg inst_rdy,
    output reg [`INST_WID] inst,
    output reg [`ADDR_WID] inst_pc,
    output reg inst_pred_jump,

    //to mem_ctrl
    output reg mc_en,
    output reg [`ADDR_WID] mc_pc,
    input  wire mc_done,
    input  wire [`IF_DATA_WID] mc_data,

    //rob set pc
    input wire rob_set_pc_en,
    input wire [`ADDR_WID] rob_set_pc,

    //rob update bht
    input wire rob_br,
    input wire rob_br_jump,
    input wire [`ADDR_WID] rob_br_pc
);
    integer i;
    reg [`ADDR_WID] pc;
    reg status;//true means waiting for mc

    // ICache
    reg valid[`ICACHE_BLK_NUM-1:0];
    reg [`ICACHE_TAG_WID] tag[`ICACHE_BLK_NUM-1:0];
    reg [`ICACHE_BLK_WID] data[`ICACHE_BLK_NUM-1:0];//512*4 byte

    // Branch Predictor
    reg [`ADDR_WID] pred_pc;
    reg pred_jump;

    wire [`ICACHE_IDX_WID] pc_index = pc[`ICACHE_IDX_RANGE];
    wire [`ICACHE_TAG_WID] pc_tag = pc[`ICACHE_TAG_RANGE];
    wire hit = valid[pc_index] && (tag[pc_index] == pc_tag);

    wire [`ICACHE_IDX_WID] mc_pc_index = mc_pc[`ICACHE_IDX_RANGE];
    wire [`ICACHE_TAG_WID] mc_pc_tag = mc_pc[`ICACHE_TAG_RANGE];

    wire [`ICACHE_BLK_WID] get_inst = data[pc_index];

    reg [1:0] bht[`BHT_SIZE-1:0];
    wire [`BHT_IDX_WID] bht_id = rob_br_pc[`BHT_IDX_RANGE];
    wire [`BHT_IDX_WID] pc_bht_id = pc[`BHT_IDX_RANGE];

    // Branch Predictor
    always @(*) begin
        pred_pc = pc + 4;
        pred_jump = 0;
        case (get_inst[`OPCODE_RANGE])
        `OPCODE_JAL: begin
            pred_pc = pc + {{12{get_inst[31]}}, get_inst[19:12], get_inst[20], get_inst[30:21], 1'b0};
            pred_jump = 1;
        end
        `OPCODE_BR: begin
            if (bht[pc_bht_id] >= 2'b10) begin
                pred_pc = pc + {{20{get_inst[31]}}, get_inst[7], get_inst[30:25], get_inst[11:8], 1'b0};
                pred_jump = 1;
            end
        end
        //if JALR then pc = pc + 4.
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'b0;
            mc_pc <= 32'b0;
            mc_en <= 0;
            inst_rdy <= 0;
            status <= 1'b0;
            for (i = 0; i < `ICACHE_BLK_NUM; i = i + 1) valid[i] <= 0;
            for (i = 0; i < `BHT_SIZE; i = i + 1) bht[i] <= 0;
        end
        else if (rdy) begin
            if (rob_set_pc_en) begin
                //change the pc, do nothing until next cycle.
                pc <= rob_set_pc;
                inst_rdy <= 0;
            end
            else begin
                if (hit && !rs_nxt_full && !lsb_nxt_full && !rob_nxt_full) begin
                    inst_rdy <= 1;
                    inst <= get_inst;
                    inst_pc <= pc;
                    pc <= pred_pc;
                    inst_pred_jump <= pred_jump;
                end
                else inst_rdy <= 0;
            end
            if (status) begin
                if (mc_done) begin
                    valid[mc_pc_index] <= 1;
                    tag[mc_pc_index] <= mc_pc_tag;
                    data[mc_pc_index] <= mc_data;
                    mc_en <= 0;
                    status <= 1'b0;
                end
            end
            else begin
                if (!hit) begin
                    mc_en <= 1;
                    mc_pc <= {pc[`ICACHE_TAG_RANGE], pc[`ICACHE_IDX_RANGE], 2'b0};
                    status <= 1'b1;
                end
            end
            //fresh bht
            if (rob_br) begin
                if (rob_br_jump)
                    if (bht[bht_id] < 2'b11) bht[bht_id] <= bht[bht_id] + 1;
                else
                    if (bht[bht_id] > 2'b0) bht[bht_id] <= bht[bht_id] - 1;
            end
        end
    end
endmodule
`endif