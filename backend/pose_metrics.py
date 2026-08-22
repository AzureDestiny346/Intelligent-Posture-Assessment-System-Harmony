"""MediaPipe 关键点提取与体态指标计算（仅使用肩/耳/髋）。"""

import logging
import math
import os

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_tasks
from mediapipe.tasks.python import vision

logger = logging.getLogger(__name__)

# 仅使用这 6 个关键点
LANDMARK = {
    "left_ear": 7,
    "right_ear": 8,
    "left_shoulder": 11,
    "right_shoulder": 12,
    "left_hip": 23,
    "right_hip": 24,
}

VISIBILITY_MIN = 0.5

SEVERITY_SCORES = {
    "无明显异常": 100,
    "轻度": 90,
    "中度": 75,
    "重度": 40,
    "unknown": None,
}

_BASE_DIR = os.path.dirname(os.path.abspath(__file__))
_BUNDLED_MODEL = os.path.join(_BASE_DIR, "models", "pose_landmarker_full.task")


def _resolve_model_path() -> str:
    """MediaPipe C 层在 Windows 上无法打开含非 ASCII 字符的路径。"""
    if not os.path.isfile(_BUNDLED_MODEL):
        raise FileNotFoundError(
            f"未找到姿态模型，请下载到: {_BUNDLED_MODEL}"
        )
    if os.name == "nt" and any(ord(c) > 127 for c in _BUNDLED_MODEL):
        # 避开用户目录中的中文路径（MediaPipe C API 在 Windows 上不支持）
        cache_dir = os.path.join(
            os.environ.get("ProgramData", "C:\\ProgramData"),
            "titaifenxi",
            "models",
        )
        os.makedirs(cache_dir, exist_ok=True)
        cache_path = os.path.join(cache_dir, "pose_landmarker_full.task")
        if (
            not os.path.isfile(cache_path)
            or os.path.getsize(cache_path) != os.path.getsize(_BUNDLED_MODEL)
        ):
            import shutil

            shutil.copy2(_BUNDLED_MODEL, cache_path)
        return cache_path
    return _BUNDLED_MODEL


_MODEL_PATH = _resolve_model_path()

_pose = vision.PoseLandmarker.create_from_options(
    vision.PoseLandmarkerOptions(
        base_options=mp_tasks.BaseOptions(model_asset_path=_MODEL_PATH),
        running_mode=vision.RunningMode.IMAGE,
        num_poses=1,
        min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5,
        min_tracking_confidence=0.5,
    )
)


def _landmark_visibility(lm) -> float:
    if lm.visibility is not None:
        return lm.visibility
    if lm.presence is not None:
        return lm.presence
    return 1.0


def _get_lm(landmarks, name: str):
    idx = LANDMARK[name]
    lm = landmarks[idx]
    vis = _landmark_visibility(lm)
    if vis < VISIBILITY_MIN:
        return None
    return {"x": lm.x, "y": lm.y, "v": vis}


def _unknown_metric():
    return {"value": "unknown", "confidence": 0}


def _metric(value: str, confidence: int):
    return {"value": value, "confidence": max(0, min(100, int(confidence)))}


def _level_from_ratio(ratio: float, t1=0.025, t2=0.05, t3=0.08):
    if ratio < t1:
        return "无明显异常"
    if ratio < t2:
        return "轻度"
    if ratio < t3:
        return "中度"
    return "重度"


def _shoulder_width(landmarks) -> float | None:
    ls = _get_lm(landmarks, "left_shoulder")
    rs = _get_lm(landmarks, "right_shoulder")
    if not ls or not rs:
        return None
    w = abs(ls["x"] - rs["x"])
    return w if w > 0.05 else None


def _confidence_from_points(*points) -> int:
    if not points:
        return 0
    return int(min(p["v"] for p in points) * 100)


def _vec3(lm) -> tuple[float, float, float]:
    return (lm.x, lm.y, lm.z)


def _vec_sub(a, b) -> tuple[float, float, float]:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _vec_norm(v) -> float:
    return math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])


def _vec_dot(a, b) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _perpendicular_magnitude(point_vec, axis_vec) -> float:
    """point_vec 在 axis_vec 垂直方向上的分量长度。"""
    axis_len = _vec_norm(axis_vec)
    if axis_len < 1e-6:
        return _vec_norm(point_vec)
    scale = _vec_dot(point_vec, axis_vec) / (axis_len * axis_len)
    parallel = (scale * axis_vec[0], scale * axis_vec[1], scale * axis_vec[2])
    perp = (
        point_vec[0] - parallel[0],
        point_vec[1] - parallel[1],
        point_vec[2] - parallel[2],
    )
    return _vec_norm(perp)


def _side_chain(landmarks, world, prefix: str):
    ear = _get_lm(landmarks, f"{prefix}_ear")
    shoulder = _get_lm(landmarks, f"{prefix}_shoulder")
    hip = _get_lm(landmarks, f"{prefix}_hip")
    if not (ear and shoulder and hip):
        return None
    idx_ear = LANDMARK[f"{prefix}_ear"]
    idx_shoulder = LANDMARK[f"{prefix}_shoulder"]
    idx_hip = LANDMARK[f"{prefix}_hip"]
    return {
        "norm": (ear, shoulder, hip),
        "world": (
            _vec3(world[idx_ear]),
            _vec3(world[idx_shoulder]),
            _vec3(world[idx_hip]),
        ),
        "confidence": min(ear["v"], shoulder["v"], hip["v"]),
    }


def _best_side_chain(landmarks, world):
    chains = [
        _side_chain(landmarks, world, "left"),
        _side_chain(landmarks, world, "right"),
    ]
    chains = [c for c in chains if c is not None]
    if not chains:
        return None
    return max(chains, key=lambda c: c["confidence"])


def _forward_head_ratio_world(ear_w, shoulder_w, hip_w) -> float:
    """耳相对肩-髋躯干线的矢状面前伸量（世界坐标，米）。"""
    torso = _vec_sub(shoulder_w, hip_w)
    head = _vec_sub(ear_w, shoulder_w)
    torso_len = _vec_norm(torso)
    if torso_len < 0.12:
        return 0.0
    return _perpendicular_magnitude(head, torso) / torso_len


def _round_shoulder_ratio_world(shoulder_w, hip_w) -> float:
    """肩-髋连线在矢状面的前倾占比（圆肩时躯干前倾、肩更靠前）。"""
    torso = _vec_sub(shoulder_w, hip_w)
    total = _vec_norm(torso)
    if total < 0.12:
        return 0.0
    sagittal = math.hypot(torso[0], torso[2])
    return sagittal / total


def _pelvic_anterior_tilt_level(shoulder_w, hip_w) -> str:
    """
    计算骨盆前倾程度。

    参数:
        shoulder_w: 肩膀世界坐标 (x, y, z)
        hip_w: 臀部世界坐标 (x, y, z)

    返回:
        "无明显异常" | "轻度" | "中度" | "重度"

    算法:
    - 计算肩-髋向量 torso = shoulder_w - hip_w
    - 计算 torso 在垂直方向（z轴）的投影比例
    - 如果 torso 接近水平（垂直分量很小），说明躯干前倾严重
    - 阈值：垂直比例 > 0.85 无明显异常，0.75-0.85 轻度，0.65-0.75 中度，< 0.65 重度
    """
    torso = _vec_sub(shoulder_w, hip_w)
    torso_length = _vec_norm(torso)
    if torso_length == 0:
        return "重度"

    # 垂直分量（z轴）的比例
    vertical_ratio = abs(torso[2]) / torso_length

    if vertical_ratio > 0.85:
        return "无明显异常"
    elif vertical_ratio > 0.75:
        return "轻度"
    elif vertical_ratio > 0.65:
        return "中度"
    else:
        return "重度"


def extract_landmarks(image_path: str):
    """从图片中提取姿态关键点。返回 (landmarks, world_landmarks) 或 (None, None)。"""
    # cv2.imread 在 Windows 上不支持中文路径，改用 imdecode 绕过
    buf = np.fromfile(image_path, dtype=np.uint8)
    if buf.size == 0:
        logger.warning("图片文件为空或不存在: %s", image_path)
        return None, None
    image = cv2.imdecode(buf, cv2.IMREAD_COLOR)
    if image is None:
        logger.warning("图片解码失败: %s", image_path)
        return None, None
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    result = _pose.detect(mp_image)
    if not result.pose_landmarks:
        logger.warning("未检测到人体姿态: %s (图片尺寸: %s)", image_path, image.shape[:2])
        return None, None
    world = result.pose_world_landmarks[0] if result.pose_world_landmarks else None
    logger.info("姿态检测成功: %s, 关键点数: %d", image_path, len(result.pose_landmarks[0]))
    return result.pose_landmarks[0], world


def analyze_front(image_path: str) -> dict:
    landmarks, _world = extract_landmarks(image_path)
    if landmarks is None:
        return {
            "high_low_shoulder": _unknown_metric(),
            "pelvic_lateral_tilt": _unknown_metric(),
        }

    ls = _get_lm(landmarks, "left_shoulder")
    rs = _get_lm(landmarks, "right_shoulder")
    lh = _get_lm(landmarks, "left_hip")
    rh = _get_lm(landmarks, "right_hip")
    width = _shoulder_width(landmarks)

    out = {}
    if ls and rs and width:
        ratio = abs(ls["y"] - rs["y"]) / width
        out["high_low_shoulder"] = _metric(
            _level_from_ratio(ratio), _confidence_from_points(ls, rs)
        )
    else:
        out["high_low_shoulder"] = _unknown_metric()

    if lh and rh and width:
        ratio = abs(lh["y"] - rh["y"]) / width
        out["pelvic_lateral_tilt"] = _metric(
            _level_from_ratio(ratio), _confidence_from_points(lh, rh)
        )
    else:
        out["pelvic_lateral_tilt"] = _unknown_metric()

    return out


def analyze_side(image_path: str) -> dict:
    landmarks, world = extract_landmarks(image_path)
    if landmarks is None or world is None:
        return {
            "forward_head": _unknown_metric(),
            "round_shoulder": _unknown_metric(),
            "pelvic_anterior_tilt": _unknown_metric(),
        }

    chain = _best_side_chain(landmarks, world)
    if chain is None:
        return {
            "forward_head": _unknown_metric(),
            "round_shoulder": _unknown_metric(),
            "pelvic_anterior_tilt": _unknown_metric(),
        }

    ear_w, shoulder_w, hip_w = chain["world"]
    conf = int(chain["confidence"] * 100)

    forward_ratio = _forward_head_ratio_world(ear_w, shoulder_w, hip_w)
    round_ratio = _round_shoulder_ratio_world(shoulder_w, hip_w)
    pelvic_tilt_level = _pelvic_anterior_tilt_level(shoulder_w, hip_w)

    return {
        "forward_head": _metric(
            _level_from_ratio(forward_ratio, 0.06, 0.11, 0.18), conf
        ),
        "round_shoulder": _metric(
            _level_from_ratio(round_ratio, 0.08, 0.16, 0.28), conf
        ),
        "pelvic_anterior_tilt": {
            "value": pelvic_tilt_level,
            "confidence": conf,
        },
    }


def analyze_back(image_path: str) -> dict:
    """背面：用肩/髋高度差近似脊柱不对称趋势。"""
    landmarks, _world = extract_landmarks(image_path)
    if landmarks is None:
        return {"spinal_asymmetry": _unknown_metric()}

    ls = _get_lm(landmarks, "left_shoulder")
    rs = _get_lm(landmarks, "right_shoulder")
    lh = _get_lm(landmarks, "left_hip")
    rh = _get_lm(landmarks, "right_hip")

    # 需要至少一组有效关键点
    has_shoulder = ls is not None and rs is not None
    has_hip = lh is not None and rh is not None
    if not has_shoulder and not has_hip:
        return {"spinal_asymmetry": _unknown_metric()}

    sw = _shoulder_width(landmarks)

    # 计算高低肩和骨盆倾斜的严重度
    severity_order = ["重度", "中度", "轻度", "无明显异常", "unknown"]
    worst = "无明显异常"
    max_conf = 0

    if has_shoulder:
        shoulder_ratio = abs(ls["y"] - rs["y"]) / sw if sw else 0
        shoulder_level = _level_from_ratio(shoulder_ratio)
        max_conf = max(max_conf, int(ls["v"] * 100), int(rs["v"] * 100))

    if has_hip:
        hip_ratio = abs(lh["y"] - rh["y"]) / sw if sw else 0
        hip_level = _level_from_ratio(hip_ratio)
        max_conf = max(max_conf, int(lh["v"] * 100), int(rh["v"] * 100))

    # 取较严重的等级
    levels = []
    if has_shoulder:
        levels.append(shoulder_level)
    if has_hip:
        levels.append(hip_level)

    for s in severity_order:
        if s in levels:
            worst = s
            break

    return {"spinal_asymmetry": _metric(worst, max_conf)}


def compute_overall_score(metrics: dict) -> int:
    keys = [
        "high_low_shoulder",
        "pelvic_lateral_tilt",
        "pelvic_anterior_tilt",
        "forward_head",
        "round_shoulder",
        "spinal_asymmetry",
    ]
    scores = []
    for key in keys:
        m = metrics.get(key, {})
        val = m.get("value", "unknown")
        if val == "unknown" or m.get("confidence", 0) <= 0:
            continue
        s = SEVERITY_SCORES.get(val)
        if s is not None:
            scores.append(s)
    if not scores:
        return 0
    return round(sum(scores) / len(scores))
