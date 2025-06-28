# zig-sts

基于 `zig` 实现的 STS（Statistical Test Suite）测试套件，支持多种统计测试方法，适用于密码学和数据分析领域。
全覆盖 NIST SP 800-22a, GMT 0005-2021 两套标准。

## 目录结构

适合扩展和维护，便于添加新的测试方法：


```
src/
  main.zig                // 程序入口，命令行解析、主流程
  suite.zig               // TestSuite 定义与管理
  detect.zig              // Test trait/interface 及通用数据结构
  params.zig              // 测试参数结构体、参数解析
  result.zig              // 测试结果结构体、统计分析
  io.zig                  // 数据输入输出、文件操作
  utils.zig               // 通用工具函数
  detects/
    frequency.zig         // 频率测试实现
    block_frequency.zig   // 块频率测试实现
    runs.zig              // Runs 测试实现
    ...                   // 其他测试方法，每个测试一个文件
README.md                 // 项目说明
build.zig                 // Zig 构建脚本
```

**说明：**

- `src/main.zig`：程序入口，负责初始化、参数解析、调度 TestSuite。
- `src/suite.zig`：TestSuite 结构体，负责注册和运行所有测试。
- `src/detect.zig`：定义 Test 接口（trait）和所有测试通用的类型。
- `src/params.zig`：参数结构体和参数解析逻辑。
- `src/result.zig`：测试结果结构体、统计分析相关代码。
- `src/io.zig`：数据读取、结果输出等 I/O 相关代码。
- `src/utils.zig`：通用辅助函数。
- `src/tests/`：每个测试方法一个文件，便于独立开发和扩展。

**扩展新测试方法时：**

- 在 `src/detects/` 下新建 `xxx.zig`，实现 `Test` 接口。
- 在 `suite.zig` 注册即可。

## 注意

1. `test` 这个名字在 Zig 中是保留字，不能作为文件名或变量名。 采用 `detect` 作为测试相关文件名。
