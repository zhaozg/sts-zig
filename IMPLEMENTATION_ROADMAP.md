# 技术实施路线图

## P0 级任务详细实施方案

### 1. 解决构建依赖问题

#### 1.1 分析当前 GSL 依赖
当前项目依赖 GSL 主要用于以下数学函数：
```zig
// src/math.zig
pub fn igamc(a: f64, x: f64) f64 {
    const c = @cImport({
        @cInclude("gsl/gsl_sf.h");
    });
    return c.gsl_sf_gamma_inc_Q(a, x);
}
```

#### 1.2 实施步骤
1. **实现纯 Zig 数学函数库** (2天)
   - 实现 `igamc` (不完全伽马函数)
   - 实现 `poisson` 概率质量函数
   - 添加其他必要的统计函数
   - 创建单元测试验证精度

2. **修改构建脚本** (1天)
   - 移除 GSL 依赖
   - 添加条件编译支持
   - 改进跨平台兼容性

3. **验证所有测试通过** (1天)
   - 运行完整测试套件
   - 比较输出结果一致性
   - 修复任何精度差异

#### 1.3 代码示例
```zig
// 新的纯 Zig 实现
pub fn igamc(a: f64, x: f64) f64 {
    // 使用连分数或级数展开实现
    // 基于 Numerical Recipes 或类似算法
    return igamc_impl(a, x);
}
```

### 2. 完善错误处理机制

#### 2.1 当前问题分析
```zig
// src/matrix.zig:103 - 存在 panic
@panic("matrix[i][i] should be 0 or 1");

// src/detects/longest_run.zig:33 - 存在 FIXME
//FIXME: return zsts.errors.Error.InvalidBlockSize;
```

#### 2.2 实施步骤
1. **定义统一错误类型** (0.5天)
```zig
// src/errors.zig
pub const StsError = error{
    InvalidInput,
    InvalidBlockSize,
    InsufficientData,
    MemoryAllocation,
    MathematicalError,
    IOError,
};
```

2. **替换 panic 调用** (1天)
```zig
// 修改前
@panic("matrix[i][i] should be 0 or 1");

// 修改后
if (matrix[i][i] != 0 and matrix[i][i] != 1) {
    return StsError.MathematicalError;
}
```

3. **改进错误传播** (0.5天)
   - 确保所有函数适当处理错误
   - 添加错误上下文信息
   - 实现用户友好的错误消息

## P1 级任务实施方案

### 3. 提升测试覆盖率

#### 3.1 当前测试分析
- GMT0005 测试: 9个测试用例
- SP800-22r1 测试: 10个测试用例
- 缺少单元测试和边界条件测试

#### 3.2 实施计划
1. **单元测试开发** (1周)
   - 为每个检测算法创建独立测试
   - 测试正常输入、边界条件、异常输入
   - 添加性能回归测试

2. **集成测试改进** (3天)
   - 添加大数据集测试
   - 跨平台测试验证
   - 内存泄漏检测

3. **测试自动化** (2天)
   - 集成代码覆盖率工具
   - 自动生成测试报告
   - 添加性能基准对比

### 4. 文档系统改进

#### 4.1 文档结构规划
```
docs/
├── README.md (English)
├── README_CN.md (Chinese)
├── API.md
├── ALGORITHMS.md
├── CONTRIBUTING.md
├── EXAMPLES.md
└── BENCHMARK.md
```

#### 4.2 实施步骤
1. **英文文档** (2天)
   - 翻译现有 README
   - 添加国际化支持说明
   - 完善安装和使用指南

2. **API 文档** (2天)
   - 生成自动化 API 文档
   - 添加代码示例
   - 说明各个参数含义

3. **算法文档** (1天)
   - 详细说明每个算法的数学背景
   - 添加参考文献
   - 解释参数选择原则

## 实施时间线

### Week 1: P0 任务
- Day 1-2: 实现纯 Zig 数学函数
- Day 3: 修改构建脚本
- Day 4: 完善错误处理
- Day 5: 验证和测试

### Week 2-3: P1 任务  
- Week 2: 大幅提升测试覆盖率
- Week 3: 完善文档系统

### Week 4: 质量保证
- 代码审查和重构
- 性能优化
- 发布准备

## 成功指标

### P0 任务成功指标:
- [ ] 项目可以无外部依赖构建
- [ ] 所有测试通过且结果一致  
- [ ] 消除所有 panic 调用
- [ ] 改进错误消息的可读性

### P1 任务成功指标:
- [ ] 测试覆盖率达到 80%+
- [ ] 完整的英文文档
- [ ] API 文档自动生成
- [ ] 所有主要算法有详细注释

## 风险评估

### 高风险:
- 数学函数实现精度问题
- 性能回归风险

### 中风险:  
- 测试数据兼容性
- 文档翻译准确性

### 缓解措施:
- 严格的数值验证测试
- 基准性能对比
- 渐进式迁移策略