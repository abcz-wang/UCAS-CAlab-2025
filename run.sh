#!/bin/bash
# 用法: ./run.sh <prj号> <上一个任务名> <当前任务名>
# 示例: ./run.sh 4 exp12 exp13

# 获取参数
PRJ=$1
PREV_TASK=$2
CUR_TASK=$3

if [ -z "$PREV_TASK" ] || [ -z "$CUR_TASK" ]; then
    echo "Usage: $0 <previous_task> <current_task>"
    exit 1
fi

# 生成 patch 文件
mkdir -p ./patch
PATCH_FILE="./patch/update_${PREV_TASK}_to_${CUR_TASK}_$(date +%Y%m%d_%H%M%S).patch"
diff -ruN /d/CALab/cdp_ede_local/output/$PREV_TASK/myCPU /d/CALab/cdp_ede_local/output/$CUR_TASK/myCPU > "$PATCH_FILE"
echo "Patch generated: $PATCH_FILE"

# 创建 prj 文件夹，固定箱子号为13
PRJ_DIR="prj${PRJ}_${CUR_TASK}_13"
mkdir -p "$PRJ_DIR"

# 复制 myCPU 和 patch
cp -r myCPU "$PRJ_DIR/"
cp -r patch "$PRJ_DIR/"

# 复制 bit 文件
cp soc_verify/soc_bram/run_vivado/project/loongson.runs/impl_1/soc_lite_top.bit "$PRJ_DIR/"

echo "All tasks done. Project folder: $PRJ_DIR"
