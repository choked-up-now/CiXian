/// 艾宾浩斯遗忘曲线
/// 关键节点（天级）：
///   1 天  → 0.33
///   2 天  → 0.28
///   6 天  → 0.25
///   31 天 → 0.21
/// 节点之间线性插值，>31 天沿用 0.21。
class Ebbinghaus {
  /// 保持率 y ∈ (0, 1]
  static double retention(int days) {
    if (days <= 0) return 1.0;
    if (days >= 31) return 0.21;
    if (days == 1) return 0.33;
    if (days == 2) return 0.28;
    if (days == 6) return 0.25;
    if (days < 2) return _lerp(0.33, 0.28, (days - 1) / 1.0);
    if (days < 6) return _lerp(0.28, 0.25, (days - 2) / 4.0);
    return _lerp(0.25, 0.21, (days - 6) / 25.0);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
