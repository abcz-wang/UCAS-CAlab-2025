`include "defines.vh"
module mycpu_top(
    input  wire       clk,
    input  wire       resetn,
    // inst sram interface
    output  wire      inst_sram_en,
    output wire[ 3:0] inst_sram_we,
    output wire[31:0] inst_sram_addr,
    output wire[31:0] inst_sram_wdata,
    input  wire[31:0] inst_sram_rdata,
    // data sram interface
    output wire       data_sram_en,
    output wire[ 3:0] data_sram_we,
    output wire[31:0] data_sram_addr,
    output wire[31:0] data_sram_wdata,
    input  wire[31:0] data_sram_rdata,
    // trace debug interface
    output wire[31:0] debug_wb_pc,
    output wire[ 3:0] debug_wb_rf_we,
    output wire[ 4:0] debug_wb_rf_wnum,
    output wire[31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         ID_allow;
wire         EX_allow;
wire         MEM_allow;
wire         WB_allow;
wire         IF_to_ID_valid;
wire         ID_to_EX_valid;
wire         EX_to_MEM_valid;
wire         MEM_to_WB_valid;
wire [`IF2ID_BUS_LEN - 1:0] IF_to_ID_bus;
wire [`ID2EX_BUS_LEN - 1:0] ID_to_EX_bus;
wire [`EX2MEM_BUS_LEN - 1:0] EX_to_MEM_bus;
wire [`MEM2WB_BUS_LEN - 1:0] MEM_to_WB_bus;
wire [`WB2ID_BUS_LEN- 1:0] WB_to_ID_bus;
wire [`ID2IF_BUS_LEN - 1:0] ID_to_IF_bus;
wire [`WB_BYPASS_LEN - 1:0] MEM_to_ID_forward;
wire [`MEM_BYPASS_LEN - 1:0] WB_to_ID_forward;
wire [`EX_BYPASS_LEN - 1:0] EX_to_ID_forward;
wire      EX_to_ID_load_up;
wire [`WB2CSR_BUS_LEN-1:0] WB2CSR_bus;
wire [79:0] WB_csr_access;
wire [31:0] csr_rvalue;
wire MEM_ertn_flush = MEM_to_WB_bus[1];
wire ertn_flush = WB2CSR_bus[80];
wire MEM_ex = |MEM_to_WB_bus[97:82];
wire wb_ex = WB2CSR_bus[79];
wire has_exc = MEM_ex  | wb_ex;
wire [31:0]ex_entry;
wire [31:0]era_pc;
wire has_int;
wire [7:0]hw_int_in = 8'b0;
wire [31:0]coreid_in = 32'b0;


csr my_csr(
	.clk(clk),
	.reset(reset),
	.WB_csr_access(WB_csr_access),
	.csr_rvalue(csr_rvalue),
	.hw_int_in(hw_int_in),
	.ex_entry(ex_entry),
	.era_pc(era_pc),
	.has_int(has_int),
	.WB2CSR_bus(WB2CSR_bus),
	.coreid_in(coreid_in)
);

// IF stage
if_stage if_stage(
    .clk            (clk),
    .reset          (reset),
    .ID_allow       (ID_allow),
    .ID_to_IF_bus   (ID_to_IF_bus),
    .IF_to_ID_valid (IF_to_ID_valid),
    .IF_to_ID_bus   (IF_to_ID_bus),
	.wb_ex(wb_ex),
	.ex_entry(ex_entry),
	.ertn_flush(ertn_flush),
	.era_pc(era_pc),
    // inst sram interface
    .inst_sram_en   (inst_sram_en),
    .inst_sram_we   (inst_sram_we),
    .inst_sram_addr (inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)
);
// ID stage
id_stage id_stage(
    .clk            (clk),
    .reset          (reset||wb_ex||ertn_flush),
    .EX_allow       (EX_allow),
    .ID_allow       (ID_allow),
    .IF_to_ID_valid (IF_to_ID_valid),
    .IF_to_ID_bus   (IF_to_ID_bus),
    .ID_to_EX_valid (ID_to_EX_valid),
    .EX_to_ID_forward(EX_to_ID_forward),
    .MEM_to_ID_forward(MEM_to_ID_forward),
    .WB_to_ID_forward(WB_to_ID_forward),
    .ID_to_EX_bus   (ID_to_EX_bus),
    .ID_to_IF_bus   (ID_to_IF_bus),
    .WB_to_ID_bus   (WB_to_ID_bus),
    .EX_to_ID_load_up(EX_to_ID_load_up)
);
// EX stage
ex_stage ex_stage(
    .clk            (clk),
    .reset          (reset||wb_ex||ertn_flush),
    .MEM_allow      (MEM_allow),
    .EX_allow       (EX_allow),
    .ID_to_EX_valid (ID_to_EX_valid),
    .ID_to_EX_bus   (ID_to_EX_bus),
    .EX_to_MEM_valid(EX_to_MEM_valid),
    .EX_to_MEM_bus  (EX_to_MEM_bus),
    .EX_to_ID_forward(EX_to_ID_forward),
    .EX_to_ID_load_up(EX_to_ID_load_up),
	.has_exc(has_exc),
	.has_ertn(MEM_ertn_flush||ertn_flush),
    // data sram interface
    .data_sram_en   (data_sram_en),
    .data_sram_we   (data_sram_we),
    .data_sram_addr (data_sram_addr),
    .data_sram_wdata(data_sram_wdata)
);
// MEM stage
mem_stage mem_stage(
    .clk             (clk),
    .reset           (reset||wb_ex||ertn_flush),
    .WB_allow        (WB_allow),
    .MEM_allow       (MEM_allow),
    .EX_to_MEM_valid (EX_to_MEM_valid),
    .EX_to_MEM_bus   (EX_to_MEM_bus),
    .MEM_to_WB_valid (MEM_to_WB_valid),
    .MEM_to_WB_bus   (MEM_to_WB_bus),
    .MEM_to_ID_forward (MEM_to_ID_forward),
    //from data-sram
    .data_sram_rdata(data_sram_rdata)
);
// WB stage
wb_stage wb_stage(
    .clk                (clk),
    .reset              (reset||wb_ex||ertn_flush),
    .WB_allow           (WB_allow),
    .MEM_to_WB_valid    (MEM_to_WB_valid),
    .MEM_to_WB_bus      (MEM_to_WB_bus),
    .WB_to_ID_bus       (WB_to_ID_bus),
    .WB_to_ID_forward   (WB_to_ID_forward),
	.WB2CSR_bus			(WB2CSR_bus),
	.WB_csr_access		(WB_csr_access),
	.csr_rvalue			(csr_rvalue),
    //trace debug interface
    .debug_wb_pc        (debug_wb_pc),
    .debug_wb_rf_we     (debug_wb_rf_we),
    .debug_wb_rf_wnum   (debug_wb_rf_wnum),
    .debug_wb_rf_wdata  (debug_wb_rf_wdata)

);


endmodule
