`define IF2ID_BUS_LEN   88

`define ID2EX_BUS_LEN  280
`define EX2MEM_BUS_LEN  192
`define MEM2WB_BUS_LEN  218
`define WB2ID_BUS_LEN  38
`define ID2IF_BUS_LEN  34

`define EX_BYPASS_LEN   45
`define MEM_BYPASS_LEN  40
`define WB_BYPASS_LEN   39

`define EXC_INT 0
`define EXC_PIL 1
`define EXC_PIS 2
`define EXC_PIF 3
`define EXC_PME 4
`define EXC_PPI 5
`define EXC_ADEF 6
`define EXC_ADEM 7
`define EXC_ALE 8
`define EXC_SYS 9
`define EXC_BRK 10
`define EXC_INE 11
`define EXC_IPE 12
`define EXC_FPD 13
`define EXC_FPE 14
`define EXC_TLBR 15
`define EXC_WIDTH 16

`define WB2CSR_BUS_LEN 81

//CSR related
`define CSR_CRMD 13'h0
`define CSR_PRMD 13'h1
`define CSR_EUEN 13'h02
`define CSR_ECFG 13'h4
`define CSR_ESTAT 13'h5
`define CSR_ERA 13'h6
`define CSR_BADV 13'h7
`define CSR_TLBIDX    14'h0010
`define CSR_TLBEHI    14'h0011
`define CSR_TLBELO0   14'h0012
`define CSR_TLBELO1   14'h0013
`define CSR_ASID      14'h0018
`define CSR_EENTRY 13'hc
`define CSR_SAVE0 13'h30
`define CSR_SAVE1 13'h31
`define CSR_SAVE2 13'h32
`define CSR_SAVE3 13'h33
`define CSR_TID 13'h40 
`define CSR_TCFG 13'h41
`define CSR_TVAL 13'h42
`define CSR_TICLR 13'h44
`define CSR_LLBCTL 13'h60
`define CSR_TLBRENTRY 13'h88
`define CSR_CTAG 13'h98
`define CSR_DMW0 13'h180
`define CSR_DMW1 13'h181


`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE  2
`define CSR_CRMD_DA  3
`define CSR_CRMD_PG  4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7

`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE  2

`define CSR_ESTAT_IS10 1:0
`define CSR_ESTAT_ECODE 21:16
`define CSR_ESTAT_ESUBCODE 30:22

`define CSR_ERA_PC 31:0

`define CSR_EENTRY_VA 31:6

`define CSR_SAVE_DATA 31:0

`define CSR_ECFG_LIE 12:0

`define CSR_BADV_ADDR 31:0

`define CSR_TID_TID 31:0

`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV 31:2

`define CSR_TICLR_CLR 0

// task 17
`define TLBNUM 16

// task 18
`define CSR_CRMD_PIE    2
`define CSR_TCFG_INITVAL 31:2
`define CSR_TLBIDX_INDEX 3:0
`define CSR_TLBIDX_PS 29:24
`define CSR_TLBIDX_NE 31
`define CSR_TLBEHI_VPPN 31:13
`define CSR_TLBELO_V  0
`define CSR_TLBELO_D  1
`define CSR_TLBELO_PLV 3:2
`define CSR_TLBELO_MAT 5:4
`define CSR_TLBELO_G  6
`define CSR_TLBELO_PPN 27:8
`define CSR_ASID_ASID 9:0
`define CSR_ASID_ASIDBITS 23:16
`define CSR_TLBRENTRY_PA 31:6
`define CSR_DMW_PLV0  0
`define CSR_DMW_PLV3  3
`define CSR_DMW_MAT   5:4
`define CSR_DMW_PSEG  27:25
`define CSR_DMW_VSEG  31:29

// task 19
`define EARRAY_TLBR_FETCH 0     // tlb refill
`define EARRAY_PIL 1            // load page fault
`define EARRAY_PIS 2            // store page fault
`define EARRAY_PIF 3            // fetch page fault
`define EARRAY_PME 4            // modify page fault
`define EARRAY_PPI_FETCH 5      // priv page fault
`define EARRAY_TLBR_MEM 6       // tlb refill
`define EARRAY_PPI_MEM 7        // priv page fault

// CSR Exception Code
`define ECODE_INT  6'h00
`define ECODE_PIL  6'h01
`define ECODE_PIS  6'h02
`define ECODE_PIF  6'h03
`define ECODE_PME  6'h04
`define ECODE_PPI  6'h07
`define ECODE_ADE  6'h08
`define ECODE_ALE  6'h09
`define ECODE_SYS  6'h0b
`define ECODE_BRK  6'h0c
`define ECODE_INE  6'h0d
`define ECODE_IPE  6'h0e
`define ECODE_FPD  6'h0f
`define ECODE_FPE  6'h12
`define ECODE_TLBR 6'h3f
`define ESUBCODE_ADEF 9'h00
`define ESUBCODE_ADEM 9'h01