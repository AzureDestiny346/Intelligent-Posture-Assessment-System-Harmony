# -*- coding: utf-8 -*-
"""
最小响应契约检查：POST /upload 后 analysis 必须包含全部 6 项指标 + 4 个 AI 字段。
不依赖网络与真实照片（1x1 JPEG 走"未检出人体"路径），随时可跑：
    .venv/Scripts/python.exe test_upload_fields.py
"""
import base64
import io
import os
import sys

# 屏蔽真实 AI key，强制走确定性的 _fallback_full_content，保证检查离线可跑
os.environ["ZHIPU_API_KEY"] = ""

import app as app_module  # noqa: E402  (需先设环境变量再导入)

# 1x1 白色 JPEG
TINY_JPEG = base64.b64decode(
    "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a"
    "HBwcJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAA"
    "AAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q=="
)

METRICS = [
    "high_low_shoulder", "pelvic_lateral_tilt", "pelvic_anterior_tilt",
    "forward_head", "round_shoulder", "spinal_asymmetry",
]
AI_FIELDS = ["advice", "deep_analysis", "exercise_prescription"]


def main() -> int:
    client = app_module.app.test_client()
    resp = client.post(
        "/upload",
        data={
            "front_image": (io.BytesIO(TINY_JPEG), "front.jpg"),
            "side_image": (io.BytesIO(TINY_JPEG), "side.jpg"),
            "back_image": (io.BytesIO(TINY_JPEG), "back.jpg"),
        },
        content_type="multipart/form-data",
    )
    assert resp.status_code == 200, f"状态码异常: {resp.status_code} -> {resp.get_data(as_text=True)[:300]}"

    analysis = resp.get_json()["analysis"]

    for key in METRICS:
        assert key in analysis, f"缺少指标: {key}"
        assert "value" in analysis[key] and "confidence" in analysis[key], f"{key} 结构不完整"
    for key in AI_FIELDS:
        assert key in analysis and analysis[key], f"缺少或为空的 AI 字段: {key}"

    radar = analysis["radar_data"]
    assert isinstance(radar, list) and len(radar) == 6, f"雷达图应为 6 项，实际 {len(radar) if isinstance(radar, list) else radar}"
    assert {r["metric"] for r in radar} == {"高低肩", "骨盆侧倾", "骨盆前倾", "头前伸", "圆肩", "脊柱侧弯趋势"}, "雷达图标签不符"

    risks = analysis["health_risks"]
    assert isinstance(risks, list), "health_risks 应为列表"
    assert "overall_score" in analysis, "缺少 overall_score"

    print(f"PASS: 6 指标齐全, radar_data=6 项, health_risks={len(risks)} 条, "
          f"overall_score={analysis['overall_score']}, advice={len(analysis['advice'])} 条")

    # 回归：AI 回吐提示词模板（"建议1/建议2"占位文本）必须被解析器拒绝走兜底
    template_echo = '{"advice": ["建议1", "建议2", "建议3"], "deep_analysis": "x", "exercise_prescription": []}'
    assert app_module._parse_full_content_json(template_echo) is None, "模板回声未被拒绝"
    good = ('{"advice": ["每天靠墙站立5分钟", "加强核心训练", "避免久坐"], '
            '"deep_analysis": "整体体态轻度异常。", "exercise_prescription": '
            '[{"name": "猫牛式", "duration": "3组x10次", "target": "脊柱", "tip": "缓慢"}]}')
    assert app_module._parse_full_content_json(good) is not None, "正常内容被误拒"
    print("PASS: 模板回声拒绝 + 正常内容放行")

    # 回归：限流器空窗口必须记录请求（曾经的 bug：不 append 导致永不拦截）
    rl = app_module.RateLimiter(max_requests=2, window_seconds=60)
    results = [rl.is_allowed("1.2.3.4") for _ in range(5)]
    assert results == [True, True, False, False, False], f"限流器失效: {results}"
    print("PASS: 限流器第3次起拦截")

    # 领域契约：severity 值域必须是五个法定值（防止前后端字符串错位）
    allowed_severity = {"无明显异常", "轻度", "中度", "重度", "unknown"}
    for key in METRICS:
        value = analysis[key]["value"]
        assert value in allowed_severity, f"{key} 非法 severity: {value}"
    print("PASS: severity 值域受控")
    return 0


if __name__ == "__main__":
    sys.exit(main())
