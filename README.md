# zig-sts

基于 `zig` 实现的 STS（Statistical Test Suite）测试套件，支持多种统计测试方法，适用于密码学和数据分析领域。
全覆盖 NIST SP 800-22a, GMT 0005-2021 两套标准。

## 目的

- 学习 STS 的实现原理，了解 STS 的应用场景。
- 了解 Zig 语言的特性和优势，学习如何使用 Zig 实现高性能的统计测试。
- 尝试使用 AI 进行代码生成和优化，探索 AI 在编程中的应用。

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
- `src/detects/`：每个测试方法一个文件，便于独立开发和扩展。

**扩展新测试方法时：**

- 在 `src/detects/` 下新建 `xxx.zig`，实现 `Test` 接口。
- 在 `suite.zig` 注册即可。
- `test` 这个名字在 Zig 中是保留字，不能作为文件名或变量名。 采用 `detect` 作为测试相关文件名。


## **标准兼容性声明**

- **GM/T 0005-2021**（中国国密最新标准）
- **NIST SP800-22**（美国标准）


| GMT 0005 检测项       | 英文 NIST SP800-22           | 适用 | NIST P | GMT 参数          |
| -------------------   | ---                          | ---- | --     | ----------------- |
| 1. 单比特频数检测     | 1. Frequency                 | 🇺🇸🇨🇳 |        |                   |
| 2. 块内频数检测       | 2. Block Frequency           | 🇺🇸🇨🇳 | 16384  | 1000:10000:100000 |
| 3. 扑克检测           | YY Poker                     | 🇨🇳   |        | 4:8               |
| 4. 重叠子序列检测     | YY Overlapping Sequency      | 🇨🇳   |        | 3:5:7             |
| 5. 游程总数检测       | 3. Runs                      | 🇺🇸🇨🇳 |        |                   |
| 6. 游程分布检测       | YY Run Distribution          | 🇨🇳   |        |                   |
| 7. 块内最大游程检测   | 4. Longest Run               | 🇺🇸🇨🇳 |        |                   |
| 8. 二元推导检测       | YY Binary Derivative         | 🇨🇳   |        | 3:7:15            |
| 9. 自相关检测         | YY Autocorrelation           | 🇺🇸🇨🇳 |        | 1:2:8:16:32       |
| 10.矩阵秩检测         | 5. Rank                      | 🇺🇸🇨🇳 |        |                   |
| 11.累加和检测         | 13.Cumulative Sums           | 🇺🇸🇨🇳 |        |                   |
| 12.近似熵检测         | 12.Approx Entropy            | 🇺🇸🇨🇳 | 10     | 5:7               |
| 13.线性复杂度检测     | 10.Linear Complexity         | 🇺🇸🇨🇳 | 500    | 1000:5000         |
| 14.通用统计检测       | 9. Maurer Universal          | 🇺🇸🇨🇳 |        |                   |
| 15.离散傅立叶检测     | 6. DFT                       | 🇺🇸🇨🇳 |        |                   |
| XX 非重叠模板匹配检测 | 7. Non-overlapping Template  | 🇺🇸   |        |                   |
| XX 随机偏移检测       | 14.Random Excursions         | 🇺🇸   |        |                   |
| XX 随机偏移变体测试   | 15.Random Excursions Variant | 🇺🇸   |        |                   |
| XX 序列测试           | 11.Serial                    | 🇺🇸   | 16     |                   |
| XX 重叠子模板检测     | 8. Overlapping Template      | 🇺🇸   |        |                   |

