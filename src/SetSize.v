`ifndef SetSize
`define SetSize
`define INST_BYTE_SIZE 4
`define INST_WID 31:0//指令宽度
`define DATA_WID 31:0//数据宽度
`define ADDR_WID 31:0//地址宽度

`define BYTE_WID 7:0
`define ICACHE_BLK_SIZE 64
`define ICACHE_BLK_WID 511:0
`define ICACHE_BLK_NUM 16//开启16行64列的cache缓存
`define ICACHE_TAG_WID 21:0
`define ICACHE_TAG_RANGE 31:10
`define ICACHE_INDEX_WID 3:0
`define ICACHE_INDEX_RANGE 9:6
`define ICACHE_BYTESELECT_WID 3:0
`define ICACHE_BYTESELECT_RANGE 5:2//因为读取指令总是4byte读取，故作为address最后两位没有意义

`define MEMCTRL_TOTAL_WID 6:0
`endif