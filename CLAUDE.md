# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目定位

PoseAI 是一个 HarmonyOS 客户端与 Flask 后端组成的体态自评应用：客户端采集正面、侧面、背面照片；后端用 MediaPipe 几何规则计算指标，再用 GLM-4-Flash 生成解读和运动建议。输出只供自测参考，不是医疗诊断。

## 常用命令

### Flask 后端

```bash
cd backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
copy .env.example .env
.venv\Scripts\python.exe app.py
```

服务监听 `http://0.0.0.0:5000`。`ZHIPU_API_KEY` 可不配置：AI 内容会走确定性兜底。

```bash
# 唯一现有的离线响应契约检查（当前没有 pytest/unittest 测试运行器）
cd backend
.venv\Scripts\python.exe test_upload_fields.py

# 验证 MediaPipe 世界坐标轴约定
.venv\Scripts\python.exe axis_check.py
```

### HarmonyOS 客户端

用 DevEco Studio 打开 `harmonyos/harmonyos/`，先将 `entry/src/main/ets/common/Constants.ets` 的 `SERVER_URL` 改成可被设备访问的后端地址。

```bash
# 在已配置 DevEco Studio / SDK / HDC 的 Windows 环境中
cd harmonyos
node build_deploy.js
```

`build_deploy.js` 和 `deploy_hap.js` 内含本机 DevEco Studio、SDK 与 HDC 的绝对路径；换机器前先更新脚本配置。标准 HAP 构建目标是 `harmonyos/entry` 模块的 `assembleHap`。

### 知识图谱与架构文档

```bash
# 代码库问题先查图谱
 graphify query "问题"

# 修改代码或文档后增量更新图谱
 graphify update .
```

架构与算法说明位于 `docs/system_architecture.md`、`docs/algorithm_principles.md`；`docs/diagrams/` 中保存 Archify 源规格和生成图。

## 运行时架构

```text
HarmonyOS Index
  └─ 压缩并缓存三张照片
      └─ HttpService: multipart/form-data
          front_image / side_image / back_image
              └─ Flask POST /upload
                  ├─ IP 滑动窗口限流、扩展名和大小校验
                  ├─ 并行调用前视图 / 侧视图 / 后视图几何分析
                  ├─ 计算总分、雷达图和健康风险
                  ├─ GLM-4 生成 AI 内容，失败时使用规则兜底
                  └─ 返回 JSON 后删除临时上传文件
                      └─ ResultPage 展示并可保存到 Preferences / 分布式 KV
```

- `backend/app.py` 是 HTTP 边界和分析编排层。`/upload` 至少接受一张图，客户端流程要求三张；不要把客户端校验当作后端校验替代。
- `backend/pose_metrics.py` 管理全局 MediaPipe `PoseLandmarker`，提取关键点、按比例阈值分级并计算总分。Windows 中文路径会使 MediaPipe C 层加载失败，因此模型会复制到 `%ProgramData%\titaifenxi\models\`。
- 后端当前产出 9 项指标：正面为高低肩、骨盆侧倾、肘关节对称、长短腿；侧面为头前伸、圆肩、骨盆前倾、膝盖超伸；背面为脊柱侧弯趋势。`unknown` 指标不参与 `compute_overall_score()`。
- `generate_full_ai_content()` 只负责生成性内容；指标、评分、雷达图和健康风险必须保持本地确定性。AI 响应无法解析、模板回声或 API 不可用时必须保留兜底内容。

## 跨端契约

后端 `METRIC_LABELS`、雷达图构造、ArkTS `AnalysisResult`、`METRIC_DEFS` 和 `ResultPage` 的解析逻辑共同定义返回协议。新增或改名指标时必须同步这些位置，并更新 `backend/test_upload_fields.py`。

2026-10-31 起该契约已全链路统一为 9 项（后端 `METRIC_LABELS`/`_build_radar_data`、ArkTS `AnalysisResult`/`METRIC_DEFS`/`ResultPage.parseAnalysisResult`、`test_upload_fields.py`）。历史记录中旧 6 项快照的指标缺失属预期；再次修改报告协议时仍须全链路同步这些位置，避免“后端返回但页面未展示”的静默丢失。

## 客户端边界

- `pages/Index.ets` 负责照片来源、压缩、缓存与发起分析；网络协议集中在 `service/HttpService.ets`，不要在页面中复制 HTTP 调用。
- `pages/ResultPage.ets` 负责报告、雷达图和保存；`pages/HistoryPage.ets` 从 `PreferencesUtil` 读取历史并绘制趋势。
- `Constants.ets` 是后端地址、超时、图像限制、存储键和主题色的单一来源。

## 图谱使用约定

项目已有 `graphify-out/graph.json`。定位实现前先运行 `graphify query`、`graphify explain` 或 `graphify path`；只在需要精确修改或调试时读取源码。图谱曾包含 `oh_modules` 依赖节点，查询结果出现 Hypium/Hamock 时优先聚焦 `backend/` 与 `harmonyos/harmonyos/entry/` 自有代码。
