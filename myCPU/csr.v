`include "csr.vh"
`include "defines.vh"
module csr(
input wire clk,
input wire reset,

//Command Access Interface
// input wire csr_re,
// input wire csr_we,
// input wire[13:0] csr_num,
// input wire[31:0] csr_wvalue,
// input wire[31:0] csr_wmask,
input wire[79:0] WB_csr_access,
output wire[31:0] csr_rvalue,
//Hardware circuit interface
input wire [7:0]hw_int_in,
output wire[31:0] ex_entry,
output wire [31:0]era_pc,
output  wire has_int,
// input wire ertn_flush,
// input wire wb_ex,
// input wire[5:0]wb_ecode,
// input wire [8:0] wb_esubcode,
// input wire [31:0]wb_pc,
// input wire [31:0]wb_vaddr,
input wire [`WB2CSR_BUS_LEN-1:0] WB2CSR_bus,
input wire [31:0] coreid_in

);
wire csr_re;
wire csr_we;
wire[13:0] csr_num;
wire[31:0] csr_wvalue;
wire[31:0] csr_wmask;
assign {csr_num, csr_re, csr_we, csr_wvalue, csr_wmask} = WB_csr_access;
wire ertn_flush;
wire wb_ex;
wire[5:0]wb_ecode;
wire [8:0] wb_esubcode;
wire [31:0]wb_pc;
wire [31:0]wb_vaddr;
assign {
	ertn_flush,
	wb_ex,
	wb_ecode,
	wb_esubcode,
	wb_pc,
	wb_vaddr
} = WB2CSR_bus;

//CRMD
reg[1:0]csr_crmd_plv;
reg csr_crmd_ie;
//暂时设为wire,第九章修改
wire csr_crmd_da;
wire csr_crmd_pg;
wire [1:0] csr_crmd_datf;
wire [1:0] csr_crmd_datm;
//PRMD
reg [1:0] csr_prmd_pplv;
reg csr_prmd_pie;
//ESTAT
reg [12:0] csr_estat_is;
reg [5:0] csr_estat_ecode;
reg [8:0] csr_estat_esubcode;
//ERA
reg [31:0] csr_era_pc;
//EENTRY
reg [25:0] csr_eentry_va;
//SAVE0~3
reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;

//ECFG
reg [12:0] csr_ecfg_lie;
//BADV
reg [31:0] csr_badv_vaddr;
//TID
reg [31:0] csr_tid_tid;
//TCFG
reg csr_tcfg_en;
reg csr_tcfg_periodic;
reg [29:0]csr_tcfg_initval;
//TVAL
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
reg [31:0] timer_cnt;
//TICLR
wire csr_ticlr_clr;
wire ipi_int_in = 1'b0;

assign ex_entry = {csr_eentry_va,6'b0};
assign era_pc = csr_era_pc;
//CRMD
always @(posedge clk)
begin
	if (reset)
		csr_crmd_plv <= 2'b0;
	else if (wb_ex)
		csr_crmd_plv <= 2'b0;
	else if (ertn_flush)
		csr_crmd_plv <= csr_prmd_pplv;
	else if (csr_we && csr_num==`CSR_CRMD)
		csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]
					| ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
end

always @(posedge clk)
begin
	if (reset)
		csr_crmd_ie <= 1'b0;
	else if (wb_ex)
		csr_crmd_ie <= 1'b0;
	else if (ertn_flush)
		csr_crmd_ie <= csr_prmd_pie;
	else if (csr_we && csr_num==`CSR_CRMD)
		csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE]&csr_wvalue[`CSR_CRMD_IE]
					| ~csr_wmask[`CSR_CRMD_IE]&csr_crmd_ie;
end

assign csr_crmd_da = 1'b1; 
assign csr_crmd_pg = 1'b0; 
assign csr_crmd_datf = 2'b00; 
assign csr_crmd_datm = 2'b00;
//PRMD
always @(posedge clk) begin
	if (wb_ex) begin
		csr_prmd_pplv <= csr_crmd_plv;
		csr_prmd_pie <= csr_crmd_ie;
	end
	else if (csr_we && csr_num==`CSR_PRMD) begin
		csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]
		| ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
		csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]
		| ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
	end
end
//ECFG
always @(posedge clk) begin
	if (reset)
		csr_ecfg_lie <= 13'b0;
	else if (csr_we && csr_num==`CSR_ECFG)
		csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_wvalue[`CSR_ECFG_LIE]
		| ~csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_ecfg_lie;
end
//ESTAT
always @(posedge clk) begin
	if (reset)
		csr_estat_is[1:0] <= 2'b0;
	else if (csr_we && csr_num==`CSR_ESTAT)
		csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10]
		| ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
	csr_estat_is[9:2] <= hw_int_in[7:0];
	csr_estat_is[10] <= 1'b0;
	if (timer_cnt[31:0]==32'b0)
	csr_estat_is[11] <= 1'b1;
	else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]
	&& csr_wvalue[`CSR_TICLR_CLR])
		csr_estat_is[11] <= 1'b0;

	csr_estat_is[12] <= ipi_int_in;
end
always @(posedge clk) begin
	if (wb_ex) begin
		csr_estat_ecode <= wb_ecode;
		csr_estat_esubcode <= wb_esubcode;
	end
end
//ERA
always @(posedge clk) begin
	if (wb_ex)
		csr_era_pc <= wb_pc;
	else if (csr_we && csr_num==`CSR_ERA)begin
		csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC]
		| ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
	end
end
//BADV
wire wb_ex_addr_err;
assign wb_ex_addr_err = (wb_ecode == `ECODE_ADE || wb_ecode == `ECODE_ALE);
always @(posedge clk) begin
	if (wb_ex && wb_ex_addr_err)
		csr_badv_vaddr <= (wb_ecode==`ECODE_ADE &&
		wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
end
//EENTRY
always @(posedge clk) begin
	if (csr_we && csr_num==`CSR_EENTRY)begin
		csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA]
		| ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
	end
end
//SAVE0~3
always @(posedge clk) begin
	if (csr_we && csr_num==`CSR_SAVE0)begin
	csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
	| ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
	end
	if (csr_we && csr_num==`CSR_SAVE1)
	csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
	| ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
	if (csr_we && csr_num==`CSR_SAVE2)
	csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
	| ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
	if (csr_we && csr_num==`CSR_SAVE3)
	csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
	| ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
end

//TID
always @(posedge clk) begin
	if (reset)
		csr_tid_tid <= coreid_in;
	else if (csr_we && csr_num==`CSR_TID)
		csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]
		| ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
end
//TCFG
always @(posedge clk) begin
	if (reset)
		csr_tcfg_en <= 1'b0;
	else if (csr_we && csr_num==`CSR_TCFG)
		csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN]
		| ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
	if (csr_we && csr_num==`CSR_TCFG) begin
		csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]&csr_wvalue[`CSR_TCFG_PERIOD]
		| ~csr_wmask[`CSR_TCFG_PERIOD]&csr_tcfg_periodic;
		csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV]&csr_wvalue[`CSR_TCFG_INITV]
		| ~csr_wmask[`CSR_TCFG_INITV]&csr_tcfg_initval;
	end
end
//TVAL
assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0]
| ~csr_wmask[31:0]&{csr_tcfg_initval,csr_tcfg_periodic, csr_tcfg_en};

always @(posedge clk) begin
	if (reset)
		timer_cnt <= 32'hffffffff;
	else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
		timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
	else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
		if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
			timer_cnt <= {csr_tcfg_initval, 2'b0};
		else
			timer_cnt <= timer_cnt - 1'b1;
	end
end
assign csr_tval = timer_cnt[31:0];
//TICLR
assign csr_ticlr_clr = 1'b0;

assign has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1);

wire [31:0] csr_crmd_rvalue = {23'b0,csr_crmd_datm,csr_crmd_datf,csr_crmd_pg,csr_crmd_da,csr_crmd_ie,csr_crmd_plv};
wire [31:0] csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
wire [31:0] csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};
wire [31:0] csr_estat_rvalue = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is[12:11],1'b0,csr_estat_is[9:0]};
wire [31:0] csr_era_rvalue = {csr_era_pc};
wire [31:0] csr_eentry_rvalue = {csr_eentry_va,6'b0};
wire [31:0] csr_save0_rvalue = {csr_save0_data};
wire [31:0] csr_save1_rvalue = {csr_save1_data};
wire [31:0] csr_save2_rvalue = {csr_save2_data};
wire [31:0] csr_save3_rvalue = {csr_save3_data};


assign csr_rvalue = {32{csr_num==`CSR_CRMD}} & csr_crmd_rvalue
			| {32{csr_num==`CSR_PRMD}} & csr_prmd_rvalue
			| {32{csr_num==`CSR_ESTAT}} & csr_estat_rvalue
			| {32{csr_num == `CSR_ERA}} & csr_era_rvalue
			| {32{csr_num == `CSR_EENTRY}} & csr_eentry_rvalue
			| {32{csr_num == `CSR_SAVE0}} & csr_save0_rvalue
			| {32{csr_num == `CSR_SAVE1}} & csr_save1_rvalue
			| {32{csr_num == `CSR_SAVE2}} & csr_save2_rvalue
			| {32{csr_num == `CSR_SAVE3}} & csr_save3_rvalue;


endmodule