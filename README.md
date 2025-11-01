# UCAS-CAlAB-2025
中国科学院大学CALab项目，FPGA箱号13
task12:注意CSR指令是运行在特权态，因此执行CSR指令时必须CRMD的PLV位值为00，若为11，则会触发指令特权级错例外，但是现在暂未实现，需要后面实现。
task13:
inst_rdcntid 要视为CSR特权指令，不然仿真不通过。