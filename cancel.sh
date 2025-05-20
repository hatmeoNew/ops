#!/bin/bash

# cancel_orders.sh - 批量执行 ./cancel.py 取消订单

# 使用方法：
# 1. 直接传递ID列表：./cancel_orders.sh 1001 1002 1003
# 2. 从文件读取ID：./cancel_orders.sh -f id_list.txt
# 3. 使用ID范围：./cancel_orders.sh -r 1001-1005

usage() {
    echo "用法:"
    echo "  $0 [ID1 ID2 ID3...]    # 直接传递ID列表"
    echo "  $0 -f filename         # 从文件读取ID列表"
    echo "  $0 -r start-end        # 使用ID范围"
    echo "  $0 -h                  # 显示帮助"
    exit 1
}

# 检查Python脚本是否存在
if [ ! -f "./cancel.py" ]; then
    echo "错误: 在当前目录找不到 cancel.py 脚本"
    exit 1
fi

# 处理无参数情况
if [ $# -eq 0 ]; then
    usage
fi

# 处理不同输入模式
case "$1" in
    -f|--file)
        # 从文件读取模式
        if [ ! -f "$2" ]; then
            echo "错误: 文件 $2 不存在"
            exit 1
        fi
        ids=$(cat "$2")
        ;;
    -r|--range)
        # ID范围模式
        IFS='-' read -ra range <<< "$2"
        if [ ${#range[@]} -ne 2 ]; then
            echo "错误: 范围格式应为 start-end"
            exit 1
        fi
        ids=$(seq ${range[0]} ${range[1]})
        ;;
    -h|--help)
        usage
        ;;
    *)
        # 直接传递ID模式
        ids="$@"
        ;;
esac

# 执行取消操作
total=0
success=0
fail=0

echo "开始处理订单取消..."
echo "----------------------"

for id in $ids; do
    # 跳过空行和非数字ID
    if [ -z "$id" ] || ! [[ $id =~ ^[0-9]+$ ]]; then
        continue
    fi

    echo -n "正在取消订单 $id ... "
    
    # 执行Python脚本并捕获输出
    output=$(./cancel.py -m sale.order -i "$id" 2>&1)
    status=$?
    
    if [ $status -eq 0 ]; then
        echo "成功"
        ((success++))
    else
        echo "失败"
        echo "  错误信息: $output"
        ((fail++))
    fi
    
    ((total++))
    sleep 0.5  # 避免请求过于频繁
done

echo "----------------------"
echo "处理完成. 总计: $total, 成功: $success, 失败: $fail"

# 如果有失败记录，以非0状态退出
if [ $fail -gt 0 ]; then
    exit 1
else
    exit 0
fi
