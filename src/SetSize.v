`ifndef SetSize
`define SetSize
`define INST_BYTE_SIZE 4
`define INST_WID 31:0//ָ����
`define DATA_WID 31:0//���ݿ��
`define ADDR_WID 31:0//��ַ���

`define BYTE_WID 7:0
`define ICACHE_BLK_SIZE 64
`define ICACHE_BLK_WID 511:0
`define ICACHE_BLK_NUM 16//����16��64�е�cache����
`define ICACHE_TAG_WID 21:0
`define ICACHE_TAG_RANGE 31:10
`define ICACHE_INDEX_WID 3:0
`define ICACHE_INDEX_RANGE 9:6
`define ICACHE_BYTESELECT_WID 3:0
`define ICACHE_BYTESELECT_RANGE 5:2//��Ϊ��ȡָ������4byte��ȡ������Ϊaddress�����λû������

`define MEMCTRL_TOTAL_WID 6:0
`endif