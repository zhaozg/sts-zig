# sts-zig 智能体提示

## 目标
  1. fft 算法实现, 目前采用 `gsl` 中的 fft 运算
    - zig 语言实现 zig, 去除 gsl 依赖
    - 大数据量的运算支持
    - 正确性与精度要求
## 条件与限制
  1. zig 0.14.1 and 0.15.1 可以从 https://ziglang.org/download/index.json 提取下载URL
  1. `zig fmt` 之后提交代码
  2. `zig build test`, `zig build`, `zig-out/bin/zsts data/data.sha1` 运行正常
  4. you can use `zig-out/bin/zsts -t dft data/data.sha1` to pick dft to run for save time

