`include "defines.vh"
module id_stage(
    input     wire                     clk           ,
    input     wire                      reset         ,
    input      wire                     EX_allow    ,
    output     wire                     ID_allow    ,
    input       wire                    IF_to_ID_valid,
    input wire  [`IF2ID_BUS_LEN -1:0] IF_to_ID_bus  ,
    output       wire                   ID_to_EX_valid,
    output wire [`ID2EX_BUS_LEN -1:0] ID_to_EX_bus  ,
    output wire [`ID2IF_BUS_LEN -1:0] ID_to_IF_bus        ,
    input  wire [`WB2ID_BUS_LEN-1:0] WB_to_ID_bus,
    input   wire        EX_to_ID_load_up,
    input  wire [`MEM_BYPASS_LEN-1:0] MEM_to_ID_forward,
    input  wire [`EX_BYPASS_LEN-1:0] EX_to_ID_forward,
    input  wire [`WB_BYPASS_LEN-1:0] WB_to_ID_forward,
	input  wire has_int,
    input  wire [15:0] EX_tlb_stall_bus,
    input  wire [15:0] MEM_tlb_stall_bus
);

wire        br_taken;
wire [31:0] br_target;
wire        br_stall;
wire [31:0] ID_pc;
wire [31:0] ID_inst;
reg         ID_valid   ;
wire        ID_ready_go;

wire [14:0] alu_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;
wire 	  inst_slti;    //task_10
wire 	  inst_sltui;   //task_10
wire 	  inst_andi;    //task_10
wire 	  inst_ori;     //task_10
wire 	  inst_xori;    //task_10
wire        inst_sll;    //task_10
wire        inst_srl;    //task_10
wire        inst_sra;    //task_10
wire        inst_pcaddu12i; //task_10
wire        inst_mul_w;    //task_10
wire        inst_mulh_w;   //task_10
wire        inst_mulh_wu;  //task_10
wire        inst_div_w;    //task_10
wire        inst_mod_w;    //task_10
wire        inst_div_wu;   //task_10
wire        inst_mod_wu;  //task_10
wire        inst_blt;    //task_11
wire        inst_bge;    //task_11
wire        inst_bltu;   //task_11
wire        inst_bgeu;   //task_11
wire        inst_ld_b;   //task_11
wire        inst_ld_h;   //task_11
wire        inst_ld_bu;  //task_11
wire        inst_ld_hu;  //task_11
wire        inst_st_b;   //task_11
wire        inst_st_h;   //task_11
//task12
wire inst_csrrd;
wire inst_csrwr;
wire inst_csrxchg;
wire inst_ertn;
wire inst_syscall;
//task13
wire inst_break;
wire inst_rdcntvl_w;
wire inst_rdcntvh_w;
wire inst_rdcntid;

// task 18
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;
wire [ 4:0] invtlb_op;
wire        id_refetch_flag;
wire [10:0] ID_tlb_bus;
wire        es_tlb_stall;
wire        es_inst_tlbrd;
wire [13:0] es_csr_num;
wire        es_csr_we;
wire        ms_tlb_blk;
wire        ms_inst_tlbrd;
wire [13:0] ms_csr_num;
wire        ms_csr_we;
wire        tlb_stall;

// task 19
wire [7:0] ID_exc_tlb;

wire        need_ui5;
wire 		need_ui12;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;

wire [31:0] mem_result;
wire [31:0] final_result;


wire no_rj;
wire no_rk;
wire no_rd;
wire rj_wait;
wire rk_wait;
wire rd_wait;
wire load_stall;

wire [4:0]   EX_to_ID_dest;
wire [4:0]   MEM_to_ID_dest;
wire [4:0]   WB_to_ID_dest;
wire [31:0] EX_to_ID_result;
wire [31:0] WB_to_ID_result;
wire [31:0] MEM_to_ID_result;
wire  EX_to_ID_we;
wire WB_to_ID_we;
wire MEM_to_ID_we;
wire WB_res_from_csr;
wire EX_res_from_csr;
wire MEM_res_from_csr;
wire EX_to_ID_req;
wire        data_ok_mem_id;
wire [4:0]EX_to_ID_dest_dest;
assign op_31_26  = ID_inst[31:26];
assign op_25_22  = ID_inst[25:22];
assign op_21_20  = ID_inst[21:20];
assign op_19_15  = ID_inst[19:15];


assign rd   = ID_inst[ 4: 0];
assign rj   = ID_inst[ 9: 5];
assign rk   = ID_inst[14:10];

assign i12  = ID_inst[21:10];
assign i20  = ID_inst[24: 5];
assign i16  = ID_inst[25:10];
assign i26  = {ID_inst[ 9: 0], ID_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ID_inst[25];
//task_10 Add the following instructions
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];  // opcode[31:22] = 0000001000b
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];  // opcode[31:22] = 0000001001b
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hD];  // opcode[31:22] = 0000001101b
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'hE];  // opcode[31:22] = 0000001110b
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hF];  // opcode[31:22] = 0000001111b

assign inst_sll    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0E];  
assign inst_srl    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0F]; 
assign inst_sra    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];  

assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ID_inst[25]; 

assign inst_mul_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19]; 
assign inst_mulh_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1A]; 
assign inst_div_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00]; 
assign inst_mod_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01]; 
assign inst_div_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02]; 
assign inst_mod_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03]; 

//task_11 Add the following instructions
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1A];
assign inst_bgeu   = op_31_26_d[6'h1B];

assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];

//task_12 Add the following instructions
assign inst_csrrd   = op_31_26_d[6'h01] & ~(|op_25_22[3:2]) & (rj == 5'b0);
assign inst_csrwr   = op_31_26_d[6'h01] & ~(|op_25_22[3:2]) & (rj == 5'b1);
assign inst_csrxchg = op_31_26_d[6'h01] & ~(|op_25_22[3:2]) & (|rj[4:1]);
assign inst_syscall  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_ertn    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0e) & ~(|rj) & ~(|rd);
//task_13 add the following instructions
assign inst_break = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_rdcntvl_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk ==5'h18) & ~(|rj);
assign inst_rdcntvh_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk ==5'h19) & ~(|rj);
assign inst_rdcntid     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk ==5'h18) & ~(|rd);

// task 18 tlb insts
assign inst_tlbsrch = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0a;
assign inst_tlbrd   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0b;
assign inst_tlbwr   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0c;
assign inst_tlbfill = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0d;
assign inst_invtlb  = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];


assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_st_b | inst_st_h
                    | inst_jirl | inst_bl |inst_pcaddu12i | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h; 
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll;
assign alu_op[ 9] = inst_srli_w | inst_srl;
assign alu_op[10] = inst_srai_w | inst_sra;
assign alu_op[11] = inst_lu12i_w ;
assign alu_op[12]  = inst_mul_w ;
assign alu_op[13]  = inst_mulh_w;
assign alu_op[14]  = inst_mulh_wu;

wire is_div_mod_s = inst_div_w | inst_mod_w ;
wire is_div_mod_u = inst_div_wu | inst_mod_wu;
wire div_or_mod = inst_div_w | inst_div_wu;//若为除法，置�?1，否则为mod,置为0

wire is_ld_b = inst_ld_b;
wire is_ld_h = inst_ld_h;
wire is_ld_bu = inst_ld_bu;
wire is_ld_hu = inst_ld_hu;
wire is_st_b = inst_st_b;
wire is_st_h = inst_st_h;
wire is_st_w = inst_st_w;
wire is_tlb = inst_tlbfill || inst_tlbrd || inst_tlbsrch || inst_tlbwr || inst_invtlb && invtlb_op < 5'h07;


assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;


assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_st_b | inst_st_h
				| inst_slti | inst_sltui | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;


assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
			 need_ui12 ? {20'b0, i12[11:0]} :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                              {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};
//源操作数是rd的指令
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_st_b | inst_st_h | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_csrwr |inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w   |
                       inst_srli_w   |
                       inst_srai_w   |
                       inst_addi_w   |
                       inst_ld_w     |
                       inst_st_w     |
                       inst_st_b     |
                       inst_st_h     |
                       inst_lu12i_w  |
                       inst_jirl     |
                       inst_bl       |
                       inst_slti     | 
                       inst_sltui    | 
                       inst_andi     |
                       inst_ori      |
                       inst_xori     |
                       inst_pcaddu12i|
                       inst_ld_b     |
                       inst_ld_h     |
                       inst_ld_bu    |
                       inst_ld_hu;
//是load指令，需要暂停流水
assign res_from_mem  = inst_ld_w |
                       inst_ld_b |
                       inst_ld_h |
                       inst_ld_bu|
                       inst_ld_hu;
assign dst_is_r1     = inst_bl;
//是否写寄存器
assign gr_we         = ~inst_st_w & ~inst_st_b & ~inst_st_h & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt 
					 & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_syscall & ~inst_ertn & ~inst_break
                     & ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_invtlb;
//是store指令
assign mem_we        = inst_st_w | inst_st_b | inst_st_h;
assign dest          = dst_is_r1 ? 5'd1 :
					inst_rdcntid?rj :
						rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),    
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rj_value  = rj_wait ? ((rj == EX_to_ID_dest && EX_to_ID_we) ? EX_to_ID_result :
                             (rj == MEM_to_ID_dest && MEM_to_ID_we) ? MEM_to_ID_result :
                             (rj == WB_to_ID_dest && WB_to_ID_we) ? WB_to_ID_result :rf_rdata1)
                        : rf_rdata1;
assign rkd_value = rk_wait ? ((rk == EX_to_ID_dest && EX_to_ID_we) ? EX_to_ID_result :
                             (rk == MEM_to_ID_dest && MEM_to_ID_we) ? MEM_to_ID_result :
                             (rk == WB_to_ID_dest && WB_to_ID_we) ? WB_to_ID_result : rf_rdata2) :
                    rd_wait ? ((rd == EX_to_ID_dest && EX_to_ID_we) ? EX_to_ID_result :
                             (rd == MEM_to_ID_dest && MEM_to_ID_we) ? MEM_to_ID_result :
                             (rd == WB_to_ID_dest && WB_to_ID_we) ? WB_to_ID_result : rf_rdata2) :
                            rf_rdata2[31:0];
assign rj_eq_rd = (rj_value == rkd_value);



wire [31:0] br_adder_result;
wire        br_adder_cout;

assign {br_adder_cout, br_adder_result} = {1'b0, rj_value} + {1'b0, (~rkd_value)} + 33'b1;
assign rj_sltu_rd = ~br_adder_cout;

assign rj_slt_rd =
        ( rj_value[31] & ~rkd_value[31] )
    | ((rj_value[31] ~^ rkd_value[31]) & br_adder_result[31]);


assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && ~rj_eq_rd
                   || inst_blt  &&  rj_slt_rd
                   || inst_bge  && ~rj_slt_rd
                   || inst_bltu &&  rj_sltu_rd
                   || inst_bgeu && ~rj_sltu_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b    
)  && ID_valid && ~load_stall && ~EX_to_ID_dest_dest_stall;


assign br_stall = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && ~rj_eq_rd
                   || inst_blt  &&  rj_slt_rd
                   || inst_bge  && ~rj_slt_rd
                   || inst_bltu &&  rj_sltu_rd
                   || inst_bgeu && ~rj_sltu_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b    
)  && ID_valid && load_stall;

assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (ID_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);
assign alu_src1 = src1_is_pc  ? ID_pc : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;
//CSR interface
wire [`EXC_WIDTH-1:0]exc_last;
wire [`EXC_WIDTH-1:0]exc_now;
wire [13:0] csr_num = inst_rdcntid ? `CSR_TID :ID_inst[23:10];
wire csr_we = inst_csrwr | inst_csrxchg;
wire csr_re = inst_csrrd | inst_csrxchg | inst_csrwr | inst_rdcntid;
wire [31:0] csr_wvalue = rkd_value;
wire [31:0] csr_wmask = inst_csrxchg ? rj_value : 32'hFFFFFFFF;
wire res_from_csr = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid;//???ertn????????flush
wire is_sys = inst_syscall;
wire is_break = inst_break;
wire ertn_flush = inst_ertn;

wire [79:0]csr_access = {csr_num, csr_re, csr_we, csr_wvalue, csr_wmask};
// {14, 1, 65} = 80

assign ID_to_IF_bus = {br_stall, br_taken, br_target};

reg  [`IF2ID_BUS_LEN -1:0] IF_to_ID_bus_reg;

assign {ID_exc_tlb,
        exc_last,
		ID_inst,
        ID_pc  } = IF_to_ID_bus_reg;

// 以后新增指令，只需在这里加上即可
wire inst_valid = inst_add_w   | inst_sub_w   | inst_slt    | inst_sltu  |
                  inst_nor     | inst_and     | inst_or     | inst_xor   |
                  inst_slli_w  | inst_srli_w  | inst_srai_w | inst_addi_w|
                  inst_ld_w    | inst_st_w    | inst_jirl   | inst_b     |
                  inst_bl      | inst_beq     | inst_bne    | inst_lu12i_w |
                  inst_slti    | inst_sltui   | inst_andi   | inst_ori   |
                  inst_xori    | inst_sll     | inst_srl    | inst_sra   |
                  inst_pcaddu12i | inst_mul_w | inst_mulh_w | inst_mulh_wu |
                  inst_div_w   | inst_mod_w   | inst_div_wu | inst_mod_wu |
                  inst_blt     | inst_bge     | inst_bltu   | inst_bgeu  |
                  inst_ld_b    | inst_ld_h    | inst_ld_bu  | inst_ld_hu  |
                  inst_st_b    | inst_st_h    | inst_csrrd  | inst_csrwr |
                  inst_csrxchg | inst_ertn    | inst_syscall | inst_break |
                  inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid | is_tlb;
wire exc_ine;
assign exc_ine = ~inst_valid;
wire [15:0] ID_exc_detected = { {(`EXC_WIDTH-`EXC_SYS-1){1'b0}}, is_sys, {`EXC_SYS{1'b0}} }
                            | { {(`EXC_WIDTH-`EXC_BRK-1){1'b0}}, is_break, {`EXC_BRK{1'b0}} }
                            | { {(`EXC_WIDTH-`EXC_INE-1){1'b0}}, exc_ine, {`EXC_INE{1'b0}} };
assign exc_now = has_int? { {(`EXC_WIDTH-`EXC_INT-1){1'b0}}, has_int, {`EXC_INT{1'b0}} } & {`EXC_WIDTH{ID_valid}}:
				(|exc_last) ? exc_last : ID_exc_detected;




// task 18
wire type_ld_st = inst_ld_b   | inst_ld_h   | inst_ld_w   | inst_ld_bu | inst_ld_hu  | inst_st_b  | inst_st_h   | inst_st_w;

assign id_refetch_flag = inst_invtlb || inst_tlbrd || inst_tlbwr || inst_tlbfill 
                         || (csr_we && (csr_num == `CSR_CRMD && (|csr_wmask[4:3]) || csr_num == `CSR_DMW0 || csr_num == `CSR_DMW1 || csr_num == `CSR_ASID));  // 当前指令造成下一条指令需要Refetch
                        // 虚实转换需要读取CSR.ASID; CSR.CRMD; ID_csr_num == `CSR_DMW因此修改后必须Refetch
assign ID_tlb_bus = {id_refetch_flag, inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb, invtlb_op};
assign invtlb_op = ID_inst[4:0];
//tlb冲突，当exe,mem级有csr写入，进行阻塞
assign {es_inst_tlbrd, es_csr_we, es_csr_num} = EX_tlb_stall_bus;
assign {ms_inst_tlbrd, ms_csr_we, ms_csr_num} = MEM_tlb_stall_bus;
assign tlb_stall = ms_tlb_blk || es_tlb_stall;
assign es_tlb_stall = type_ld_st && (
                                    es_inst_tlbrd ||
                                    (es_csr_we && (es_csr_num == `CSR_ASID || es_csr_num == `CSR_CRMD || es_csr_num == `CSR_DMW0 || es_csr_num == `CSR_DMW1)) // 修改CSR.ASID或直接映射相�?
                    ) || inst_tlbsrch && (
                                    es_inst_tlbrd || 
                                    (es_csr_we && (es_csr_num == `CSR_ASID || es_csr_num == `CSR_TLBEHI))
                );
assign ms_tlb_blk = type_ld_st && (
                                    ms_inst_tlbrd ||
                                    (ms_csr_we && (ms_csr_num == `CSR_ASID || ms_csr_num == `CSR_CRMD || ms_csr_num == `CSR_DMW0 || ms_csr_num == `CSR_DMW1)) // 修改CSR.ASID或直接映射相�?
                    ) || inst_tlbsrch && (
                                    ms_inst_tlbrd || 
                                    (ms_csr_we && (ms_csr_num == `CSR_ASID || ms_csr_num == `CSR_TLBEHI))
                );





// assign exc_now = exc_last 	|{ {(`EXC_WIDTH-`EXC_INT-1){1'b0}}, has_int, {`EXC_INT{1'b0}} } & {`EXC_WIDTH{ID_valid}}
// 							|{ {(`EXC_WIDTH-`EXC_SYS-1){1'b0}}, is_sys, {`EXC_SYS{1'b0}} }
// 							| { {(`EXC_WIDTH-`EXC_BRK-1){1'b0}}, is_break, {`EXC_BRK{1'b0}} }
// 							| { {(`EXC_WIDTH-`EXC_INE-1){1'b0}}, exc_ine, {`EXC_INE{1'b0}} };

//WB->ID，写回阶段传回的寄存器堆写使能，写地址，写数据
assign {rf_we   ,  
        rf_waddr,  
        rf_wdata   
       } = WB_to_ID_bus;

assign ID_to_EX_bus = { ID_exc_tlb,
                        ID_tlb_bus,
                        alu_op       ,   
                       alu_src1     , 
                       alu_src2     , 
                       gr_we        ,   
                       mem_we       ,   
                       dest         ,  
                       rkd_value    ,   
                       ID_pc        ,   
                       res_from_mem ,
					   is_div_mod_s ,
					   is_div_mod_u ,
					   div_or_mod   ,
                       is_ld_b      ,
                       is_ld_h      ,
                       is_ld_hu     ,
                       is_ld_bu     ,
                       is_st_b      ,
                       is_st_h	,
                       is_st_w      ,
					   exc_now,
					   csr_access,
					   ertn_flush,
					   res_from_csr,
					   inst_rdcntvl_w,
					   inst_rdcntvh_w

	};

assign {EX_to_ID_we,
        EX_to_ID_dest,
        EX_to_ID_result,
		EX_res_from_csr,
        EX_to_ID_req,
        EX_to_ID_dest_dest
       } = EX_to_ID_forward;

assign {MEM_to_ID_we,
        MEM_to_ID_dest,
        MEM_to_ID_result,
		MEM_res_from_csr,
        data_ok_mem_id
       } = MEM_to_ID_forward;

assign {WB_to_ID_we,
        WB_to_ID_dest,
        WB_to_ID_result,
		WB_res_from_csr
       } = WB_to_ID_forward;

assign ID_ready_go    = ~load_stall  && ~EX_to_ID_dest_dest_stall;
assign ID_allow     = !ID_valid || ID_ready_go && EX_allow;
assign ID_to_EX_valid = ID_valid && ID_ready_go;
              

assign no_rj    = inst_b | inst_bl | inst_lu12i_w | inst_pcaddu12i | inst_csrrd |inst_csrwr|inst_syscall|inst_ertn|inst_break|inst_rdcntid|inst_rdcntvh_w|inst_rdcntvl_w;
assign no_rk    = inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w |inst_st_b | inst_st_h | inst_jirl | 
                inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w| 
				inst_slti | inst_sltui
                | inst_andi | inst_ori | inst_xori
                | inst_pcaddu12i
                | inst_blt | inst_bge | inst_bltu | inst_bgeu
                | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu
				|inst_csrrd |inst_csrwr|inst_csrxchg|inst_syscall|inst_ertn
				|inst_break|inst_rdcntid|inst_rdcntvh_w|inst_rdcntvl_w;
assign no_rd    = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_csrwr & ~inst_csrxchg;//?????rd??????????

assign rj_wait = ~no_rj && (rj != 5'b00000) && ((rj == EX_to_ID_dest) || (rj == MEM_to_ID_dest) || (rj == WB_to_ID_dest));
assign rk_wait = ~no_rk && (rk != 5'b00000) && ((rk == EX_to_ID_dest) || (rk == MEM_to_ID_dest) || (rk == WB_to_ID_dest));
assign rd_wait = ~no_rd && (rd != 5'b00000) && ((rd == EX_to_ID_dest) || (rd == MEM_to_ID_dest) || (rd == WB_to_ID_dest));


assign load_stall = 
    ((EX_to_ID_load_up | EX_res_from_csr) &&
       (((rj == EX_to_ID_dest) && rj_wait) ||
        ((rk == EX_to_ID_dest) && rk_wait) ||
        ((rd == EX_to_ID_dest) && rd_wait))) ||

    ((MEM_res_from_csr) &&
       (((rj == MEM_to_ID_dest) && rj_wait) ||
        ((rk == MEM_to_ID_dest) && rk_wait) ||
        ((rd == MEM_to_ID_dest) && rd_wait))) ||

    ((WB_res_from_csr) &&
       (((rj == WB_to_ID_dest) && rj_wait) ||
        ((rk == WB_to_ID_dest) && rk_wait) ||
        ((rd == WB_to_ID_dest) && rd_wait))) ||
    
    tlb_stall;


always @(posedge clk) begin
    if (reset) begin
        ID_valid <= 1'b0;
        IF_to_ID_bus_reg <= {`IF2ID_BUS_LEN{1'b0}};
    end
    else if (ID_allow) begin
        ID_valid <= IF_to_ID_valid;
        if (IF_to_ID_valid)
            IF_to_ID_bus_reg <= IF_to_ID_bus;
        else begin
			
		end

    end
end


//当ex阶段是load指令的时候，直接阻塞id，因为在多拍取指读数的影响下，有可能在原有的阻塞指令生效前，id当前指令已经进ex了
//EX_to_ID_dest是&了valid的，但是EX_to_ID_dest_dest是新加的，就是exdest自身，比&valid的持续更长
//但是直接把EX_to_ID_dest中的&valid去掉会出问题
//所以加了一个新的信号EX_to_ID_dest_dest，专门用来处理load指令的暂停
//EX_to_ID_req_reg其实和EX_to_ID_req没有关系
//EX_to_ID_req_reg只是用来标记当前周期if阶段是否有指令进入id阶段
//有新指令进入id之后就可以进行寄存器比价了，如果发现目的寄存器和源寄存器不冲突了，就可以解除暂停
//否则一直暂停到数据返回为止
reg EX_to_ID_dest_dest_stall;
reg EX_to_ID_req_reg;
always @(posedge clk) begin
    if(reset) begin
        EX_to_ID_dest_dest_stall <= 1'b0;
    end
    else if (EX_to_ID_req )  begin
        EX_to_ID_dest_dest_stall <= 1'b1;
    end
    else if (~(EX_to_ID_dest_dest == rj[4:0] && rj!=5'b00000) && EX_to_ID_req_reg && EX_to_ID_dest_dest_stall) begin
        EX_to_ID_dest_dest_stall <= 1'b0;
    end
    else if (EX_to_ID_dest_dest_stall &&  data_ok_mem_id) begin
        EX_to_ID_dest_dest_stall <= 1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        EX_to_ID_req_reg<=1'b0;
    end
    else if (ID_allow && IF_to_ID_valid) begin
        EX_to_ID_req_reg<=1'b1;
    end
    else  begin
        EX_to_ID_req_reg<=1'b0;
    end
end
endmodule
