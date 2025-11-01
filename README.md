# UCAS-CAlAB-2025
中国科学院大学CALab项目，FPGA箱号13
[info]
task12:注意CSR指令是运行在特权态，因此执行CSR指令时必须CRMD的PLV位值为00，若为11，则会触发指令特权级错例外，但是现在暂未实现，需要后面实现。
[info]
task13:
inst_rdcntid 要视为CSR特权指令，不然仿真不通过。

我生成了一个run.sh脚本，可以直接生成作业提交的文件，详见run.sh的注释：
# 用法: ./run.sh <prj号> <上一个任务名> <当前任务名>
# 示例: ./run.sh 4 exp12 exp13
需要将该脚本放在任务文件夹下，如/exp13下