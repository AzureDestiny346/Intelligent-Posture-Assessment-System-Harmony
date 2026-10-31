import json
import logging
import os
import re
import time
import uuid
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock

from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_from_directory
from werkzeug.utils import secure_filename
from zhipuai import ZhipuAI

from pose_metrics import (
    SEVERITY_SCORES,
    analyze_back,
    analyze_front,
    analyze_side,
    compute_overall_score,
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(BASE_DIR, ".env"))

ZHIPU_API_KEY = os.getenv("ZHIPU_API_KEY")

# 配置日志系统
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.FileHandler(os.path.join(BASE_DIR, "app.log"), encoding="utf-8"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
_zhipu_client = None

UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp", "bmp"}
MAX_FILE_AGE_HOURS = 24  # 文件最大保留时间（小时）


# ========== 请求限流器 ==========
class RateLimiter:
    """基于IP的滑动窗口限流器"""

    def __init__(self, max_requests: int = 10, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._requests: dict[str, list[float]] = defaultdict(list)
        self._lock = Lock()

    MAX_KEYS = 4096  # 键数上限：超过才触发过期键清扫（摊销 O(1)，防伪造源地址撑爆内存）

    def is_allowed(self, client_ip: str) -> bool:
        now = time.time()
        with self._lock:
            # 只保留窗口内的记录（写回有界列表，键内容不超过 max_requests 条）
            recent = [t for t in self._requests[client_ip] if now - t < self.window_seconds]
            if len(recent) >= self.max_requests:
                self._requests[client_ip] = recent
                return False
            recent.append(now)
            self._requests[client_ip] = recent
            self._sweep_if_needed(now)
            return True

    def _sweep_if_needed(self, now: float) -> None:
        """键数超上限时删除窗口外过期键，防止伪造源地址使键集合无界增长。"""
        if len(self._requests) <= self.MAX_KEYS:
            return
        expired = [
            ip for ip, stamps in self._requests.items()
            if not stamps or now - stamps[-1] >= self.window_seconds
        ]
        for ip in expired:
            del self._requests[ip]


rate_limiter = RateLimiter(max_requests=10, window_seconds=60)
_executor = ThreadPoolExecutor(max_workers=3)  # 模块级单例，避免每次请求创建/销毁

app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
app.config["MAX_CONTENT_LENGTH"] = 32 * 1024 * 1024
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


def cleanup_old_files():
    """清理超过保留时间的旧文件"""
    now = time.time()
    max_age_seconds = MAX_FILE_AGE_HOURS * 3600
    cleaned_count = 0

    for filename in os.listdir(UPLOAD_FOLDER):
        filepath = os.path.join(UPLOAD_FOLDER, filename)
        if os.path.isfile(filepath):
            file_age = now - os.path.getmtime(filepath)
            if file_age > max_age_seconds:
                try:
                    os.remove(filepath)
                    cleaned_count += 1
                except Exception as e:
                    logger.warning("清理旧文件失败 %s: %s", filepath, str(e))

    if cleaned_count > 0:
        logger.info("启动时清理了 %d 个过期文件", cleaned_count)


def get_zhipu_client() -> ZhipuAI:
    global _zhipu_client
    if _zhipu_client is None:
        api_key = os.getenv("ZHIPU_API_KEY")
        if not api_key:
            logger.error("未配置 ZHIPU_API_KEY 环境变量")
            raise ValueError("未配置 ZHIPU_API_KEY")
        _zhipu_client = ZhipuAI(api_key=api_key)
        logger.info("智谱AI客户端初始化成功")
    return _zhipu_client


def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


# 指标键名 → 中文标签（单一数据源，_metrics_summary/_fallback_full_content/_build_health_risks/run_analysis 共用）
METRIC_LABELS = {
    "high_low_shoulder": "高低肩",
    "pelvic_lateral_tilt": "骨盆侧倾",
    "pelvic_anterior_tilt": "骨盆前倾",
    "forward_head": "头前伸",
    "round_shoulder": "圆肩",
    "spinal_asymmetry": "脊柱侧弯趋势",
    "elbow_asymmetry": "肘关节对称",
    "leg_length_diff": "长短腿",
    "knee_hyperextension": "膝盖超伸",
}


def _metrics_summary(metrics: dict) -> str:
    lines = []
    for key, label in METRIC_LABELS.items():
        m = metrics.get(key, {})
        lines.append(f"{label}:{m.get('value', 'unknown')}")
    lines.append(f"总分:{metrics.get('overall_score', 0)}")
    return "；".join(lines)


def _fallback_full_content(metrics: dict) -> dict:
    """AI 调用失败时的完整兜底内容。"""
    score = metrics.get("overall_score", "未知")
    problem_metrics = []
    for key in METRIC_LABELS:
        data = metrics.get(key)
        if isinstance(data, dict) and data.get("value") not in ("无明显异常", None, "unknown"):
            label = METRIC_LABELS.get(key, key)
            severity = data["value"]
            problem_metrics.append((label, severity))

    # 兜底建议
    if problem_metrics:
        labels = "、".join(m[0] for m in problem_metrics)
        advice = [
            f"您的{labels}问题需要关注，建议改善日常坐姿和站姿习惯",
            "建议每天进行15-20分钟的肩颈和背部拉伸运动",
            "如症状持续或加重，建议前往医院骨科或康复科进行专业评估",
        ]
        deep_analysis = (
            f"根据您的体态分析数据，您的整体评分为 {score} 分。"
            f"主要问题集中在{labels}方面。"
            "这些问题可能与日常久坐、缺乏运动或不良姿势习惯有关。"
            "建议通过针对性训练逐步改善，通常坚持4-6周可见明显效果。"
        )
    else:
        advice = [
            "您的体态状况良好，请继续保持良好的日常姿势习惯",
            "建议每周进行3-4次全身运动以维持体态健康",
            "定期进行体态评估，及时发现潜在问题",
        ]
        deep_analysis = (
            f"根据您的体态分析数据，您的整体评分为 {score} 分，"
            "各项指标均在正常范围内。"
            "请继续保持良好的生活习惯和运动频率，"
            "建议每隔一段时间进行一次体态评估以跟踪变化趋势。"
        )

    # 兜底运动处方
    exercise_prescription = [
        {"name": "靠墙站立", "duration": "5分钟", "target": "全身姿态", "tip": "头部、肩部、臀部、脚跟紧贴墙面，收紧腹部"},
        {"name": "猫牛式伸展", "duration": "3组×10次", "target": "脊柱灵活性", "tip": "四点跪姿，交替弓背和塌腰，动作缓慢配合呼吸"},
        {"name": "肩胛骨后缩", "duration": "3组×15次", "target": "肩背肌群", "tip": "双臂自然下垂，用力将肩胛骨向中间挤压，保持3秒"},
    ]

    return {
        "advice": advice,
        "deep_analysis": deep_analysis,
        "exercise_prescription": exercise_prescription,
    }


def _build_radar_data(metrics: dict) -> list[dict]:
    """从已有指标构造雷达图数据（9 项，键序与 METRIC_LABELS 保持一致）。"""
    result = []
    for key, label in METRIC_LABELS.items():
        m = metrics.get(key, {})
        value = m.get("value", "unknown")
        score = SEVERITY_SCORES.get(value)
        if score is None:
            score = 50  # unknown 时给中间值
        result.append({
            "metric": label,
            "score": score,
            "severity": value,
        })
    return result


# 健康风险规则表：仅"轻度"及以上输出
_HEALTH_RISK_TABLE = {
    "spinal_asymmetry": {
        "轻度": ("脊柱不对称风险", "轻度脊柱侧弯可能影响体态平衡，建议关注对称性训练"),
        "中度": ("脊柱侧弯风险", "中度脊柱不对称可能伴随体态问题，建议就医评估"),
        "重度": ("严重脊柱变形", "重度脊柱侧弯需专业康复治疗，可能影响心肺功能"),
    },
    "high_low_shoulder": {
        "轻度": ("肩颈肌肉劳损", "长期高低肩可能导致肩颈疼痛和肌肉不平衡"),
        "中度": ("脊柱侧弯风险", "明显的高低肩可能伴随脊柱侧弯，建议就医检查"),
        "重度": ("严重脊柱问题", "重度高低肩需尽快就医，可能影响心肺功能"),
    },
    "pelvic_lateral_tilt": {
        "轻度": ("骨盆不平衡", "轻度骨盆侧倾可通过拉伸改善，注意坐姿"),
        "中度": ("腰椎压力增大", "骨盆侧倾可能导致腰痛，建议加强核心训练"),
        "重度": ("脊柱变形风险", "重度骨盆侧倾需专业康复治疗"),
    },
    "pelvic_anterior_tilt": {
        "轻度": ("腰椎前凸", "轻度骨盆前倾常见于久坐人群，注意站姿"),
        "中度": ("腰背疼痛风险", "骨盆前倾加重可能导致慢性腰痛"),
        "重度": ("腰椎间盘压力", "重度前倾增加腰椎间盘突出的风险"),
    },
    "forward_head": {
        "轻度": ("颈椎压力", "头前伸增加颈椎负担，注意电脑屏幕高度"),
        "中度": ("颈椎病风险", "中度头前伸可能引发头痛和手臂麻木"),
        "重度": ("颈椎退行性变", "重度头前伸需及时干预，可能造成不可逆损伤"),
    },
    "round_shoulder": {
        "轻度": ("胸肌紧张", "圆肩导致胸肌缩短，建议多做扩胸运动"),
        "中度": ("肩关节问题", "圆肩可能引发肩峰撞击综合征"),
        "重度": ("胸廓变形", "重度圆肩可能影响呼吸功能和上肢活动"),
    },
    "elbow_asymmetry": {
        "轻度": ("上肢不对称", "轻度肘关节不对称可能由单侧用力习惯导致"),
        "中度": ("肩颈代偿风险", "明显的肘关节不对称可能引发肩颈代偿性问题"),
        "重度": ("上肢功能异常", "重度不对称需排查神经或骨骼问题"),
    },
    "leg_length_diff": {
        "轻度": ("步态不对称", "轻度长短腿可能影响步态，建议鞋垫矫正"),
        "中度": ("骨盆代偿", "中度长短腿可能导致骨盆倾斜和腰痛"),
        "重度": ("脊柱侧弯风险", "重度长短腿需就医评估，可能导致脊柱侧弯"),
    },
    "knee_hyperextension": {
        "轻度": ("膝关节压力", "轻度膝盖超伸增加关节磨损，注意站姿"),
        "中度": ("韧带松弛风险", "中度超伸可能导致膝关节不稳定"),
        "重度": ("膝关节损伤", "重度超伸需专业评估，可能影响运动功能"),
    },
}

def _build_health_risks(metrics: dict) -> list[dict]:
    """根据指标严重程度生成健康风险预警。"""
    result = []
    for metric_key, risk_map in _HEALTH_RISK_TABLE.items():
        m = metrics.get(metric_key, {})
        value = m.get("value", "无明显异常")
        if value in risk_map:
            risk, desc = risk_map[value]
            result.append({
                "metric": METRIC_LABELS.get(metric_key, metric_key),
                "severity": value,
                "risk": risk,
                "desc": desc,
            })
    return result


def _parse_advice_json(raw: str) -> list[str] | None:
    text = raw.strip()
    block = re.search(r"\[[\s\S]*\]", text)
    if block:
        text = block.group(0)
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return None
    if isinstance(data, list) and len(data) >= 1:
        return [str(x).strip() for x in data[:3]]
    return None


def _parse_full_content_json(raw: str) -> dict | None:
    """解析 AI 返回的完整内容 JSON（包含 advice + deep_analysis + exercise_prescription）。"""
    text = raw.strip()
    # 尝试提取最外层 JSON 对象
    block = re.search(r"\{[\s\S]*\}", text)
    if block:
        text = block.group(0)
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return None
    if not isinstance(data, dict):
        return None

    result = {}

    # 解析 advice（字符串数组，取前3条）
    advice = data.get("advice")
    if isinstance(advice, list) and len(advice) >= 1:
        result["advice"] = [str(x).strip() for x in advice[:3]]
    else:
        return None  # advice 是必需字段

    # 防 AI 回吐提示词模板（"建议1/建议2"等占位文本通过校验会绕过兜底）
    if all(re.fullmatch(r"建议[0-9一二三（(].*|[0-9]+", item) for item in result["advice"]):
        logger.warning("AI返回疑似模板占位 advice，判定解析失败: %s", result["advice"])
        return None

    # 解析 deep_analysis（字符串）
    deep = data.get("deep_analysis")
    if isinstance(deep, str) and deep.strip():
        result["deep_analysis"] = deep.strip()
    else:
        result["deep_analysis"] = ""

    # 解析 exercise_prescription（对象数组，每个包含 name/duration/target/tip）
    exercises = data.get("exercise_prescription")
    if isinstance(exercises, list) and len(exercises) >= 1:
        parsed_exercises = []
        for ex in exercises[:5]:  # 最多5个运动
            if isinstance(ex, dict) and "name" in ex:
                parsed_exercises.append({
                    "name": str(ex.get("name", "")),
                    "duration": str(ex.get("duration", "30秒")),
                    "target": str(ex.get("target", "")),
                    "tip": str(ex.get("tip", "")),
                })
        result["exercise_prescription"] = parsed_exercises if parsed_exercises else []
    else:
        result["exercise_prescription"] = []

    return result


def generate_full_ai_content(metrics: dict) -> dict:
    """一次 AI 调用生成建议 + 深度解读 + 运动处方。"""
    if not ZHIPU_API_KEY:
        return _fallback_full_content(metrics)

    summary = _metrics_summary(metrics)
    prompt = (
        "你是一位专业的体态评估师和运动康复专家。根据以下体态检测结果，"
        "生成一个JSON对象，包含三个字段，不要markdown，不要其他文字：\n\n"
        f"检测结果：{summary}\n\n"
        "请返回如下JSON格式：\n"
        "{\n"
        '  "advice": ["建议1(20字以内)", "建议2", "建议3"],\n'
        '  "deep_analysis": "对整体体态状况的专业解读，包括问题成因和可能的影响，100-200字",\n'
        '  "exercise_prescription": [\n'
        '    {"name": "动作名称", "duration": "时长/次数", "target": "目标肌群", "tip": "动作要领"}\n'
        "  ]\n"
        "}\n"
    )

    try:
        client = get_zhipu_client()
        response = client.chat.completions.create(
            model="glm-4-flash",
            extra_body={"temperature": 0.7, "max_tokens": 800},
            messages=[{"role": "user", "content": prompt}],
        )
        raw = ""
        if response.choices:
            raw = response.choices[0].message.content or ""
        parsed = _parse_full_content_json(raw)
        if parsed:
            # 确保 advice 至少3条
            while len(parsed["advice"]) < 3:
                parsed["advice"].append("建议保持规律运动")
            parsed["advice"] = parsed["advice"][:3]
            return parsed
        logger.warning("AI返回内容解析失败，使用兜底: raw=%s", raw[:200])
    except Exception as e:
        logger.error("AI完整内容生成失败: %s", str(e))

    return _fallback_full_content(metrics)


# 保持向后兼容
generate_advice = generate_full_ai_content


def run_analysis(front_path: str | None, side_path: str | None, back_path: str | None) -> dict:
    """并行分析三张照片，合并结果后计算评分和生成建议。"""
    metrics = {key: {"value": "unknown", "confidence": 0} for key in METRIC_LABELS}

    # 并行执行三张照片的分析（每张约200-500ms，并行后总耗时约等于最慢的一张）
    tasks = {}
    if front_path:
        tasks["front"] = (analyze_front, front_path)
    if side_path:
        tasks["side"] = (analyze_side, side_path)
    if back_path:
        tasks["back"] = (analyze_back, back_path)

    if tasks:
        futures = {
            _executor.submit(func, path): key
            for key, (func, path) in tasks.items()
        }
        for future in as_completed(futures):
            try:
                result = future.result()
                metrics.update(result)
            except Exception as e:
                key = futures[future]
                logger.error("分析%s照片失败: %s", key, str(e))

    overall = compute_overall_score(metrics)
    metrics["overall_score"] = str(overall)

    # 一次 AI 调用生成建议 + 深度解读 + 运动处方
    ai_content = generate_full_ai_content(metrics)
    metrics["advice"] = ai_content["advice"]
    metrics["deep_analysis"] = ai_content["deep_analysis"]
    metrics["exercise_prescription"] = ai_content["exercise_prescription"]

    # 构建雷达图数据和健康风险
    metrics["radar_data"] = _build_radar_data(metrics)
    metrics["health_risks"] = _build_health_risks(metrics)

    return metrics


def save_upload(file, prefix: str) -> str:
    ext = secure_filename(file.filename).rsplit(".", 1)[-1].lower()
    filename = f"{prefix}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = os.path.join(app.config["UPLOAD_FOLDER"], filename)
    file.save(filepath)
    logger.info("文件已保存: %s", filepath)
    return filepath


def cleanup_files(*file_paths):
    """清理临时上传文件"""
    for path in file_paths:
        if path and os.path.exists(path):
            try:
                os.remove(path)
                logger.info("已清理临时文件: %s", path)
            except Exception as e:
                logger.warning("清理文件失败 %s: %s", path, str(e))


@app.route("/")
def index():
    return send_from_directory(BASE_DIR, "index.html")


@app.route("/health")
def health():
    """健康检查端点"""
    return jsonify({
        "status": "ok",
        "timestamp": int(time.time()),
        "upload_count": len(os.listdir(UPLOAD_FOLDER)) if os.path.isdir(UPLOAD_FOLDER) else 0,
    })


def _validate_and_save(file, prefix: str, label: str) -> str | None:
    """验证并保存上传文件，返回保存路径；文件不存在或无效时返回 None"""
    if not file or not file.filename:
        return None
    if not allowed_file(file.filename):
        logger.warning("%s照片格式不支持: %s", label, file.filename)
        raise ValueError(f"{label}照片格式不支持")
    return save_upload(file, prefix)


@app.route("/upload", methods=["POST"])
def upload():
    client_ip = request.remote_addr
    if not rate_limiter.is_allowed(client_ip):
        logger.warning("请求被限流: %s", client_ip)
        return jsonify({"message": "请求过于频繁，请稍后再试"}), 429

    logger.info("收到上传请求: %s", client_ip)
    front_file = request.files.get("front_image")
    side_file = request.files.get("side_image")
    back_file = request.files.get("back_image")

    if not any(f and f.filename for f in (front_file, side_file, back_file)):
        logger.warning("上传请求缺少照片文件")
        return jsonify({"message": "请至少上传一张照片"}), 400

    front_path = side_path = back_path = None

    try:
        front_path = _validate_and_save(front_file, "front", "正面")
        side_path = _validate_and_save(side_file, "side", "侧面")
        back_path = _validate_and_save(back_file, "back", "背面")
        analysis = run_analysis(front_path, side_path, back_path)

    except ValueError as e:
        # 格式校验失败（_validate_and_save 抛出）
        cleanup_files(front_path, side_path, back_path)
        return jsonify({"message": str(e)}), 400

    except Exception:
        logger.exception("体态分析处理失败")  # 异常详情只进日志，不进响应
        cleanup_files(front_path, side_path, back_path)
        return jsonify(
            {
                "message": "体态分析失败",
                "analysis": {"error": "分析失败"},
            }
        ), 500

    parts = [name for name, path in [("正面", front_path), ("侧面", side_path), ("背面", back_path)] if path]

    response = jsonify(
        {
            "message": f"体态分析完成（{'、'.join(parts)}）",
            "analysis": analysis,
        }
    )

    # 分析完成后清理临时文件
    cleanup_files(front_path, side_path, back_path)

    return response


if __name__ == "__main__":
    logger.info("智能体态分析系统启动中...")
    cleanup_old_files()  # 启动时清理过期文件（不在模块导入时执行）
    app.run(host="0.0.0.0", port=5000, debug=False)
