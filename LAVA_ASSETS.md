# 底部 Lava 素材规范

本游戏岩浆是 **屏幕 HUD 贴边**，不是世界里的 3D 场景。素材和判定必须按下面方式对齐。

## 为什么「带天空/灰底」的视频不合适

| 问题 | 说明 |
|------|------|
| 透视场景 | AI 视频多是「远处地平线 + 天空」，适合背景，不适合 HUD 条带 |
| 空白占比大 | 灰/白底抠掉后，只剩底部一条熔岩，**上面 80% 危险区仍是空的** |
| 判定线在上沿 | 代码里 **死亡线 = Lava 控件顶边**（屏幕 75% 处），不是熔岩纹理的顶边 |
| 结果 | 玩家脚还没碰到「看见的熔岩」就死了，像凭空消失 |

## 正确素材长什么样

```
┌────────────────────────────  ← 液面亮边（必须与控件顶边重合）
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  ← 整块都是熔岩（越往下越深）
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
└────────────────────────────  ← 屏幕底边
```

**要点：**

1. **宽高比**：建议 **宽 ≥ 1080，高 ≈ 480–640**（约屏幕底部 25–33%）
2. **顶边**：一条清晰、水平的 **亮黄/橙液面**，用于和死亡线对齐
3. **向下填满**：顶边以下 **全部是熔岩**，不要留天空、灰底、透视远景
4. **可循环**：水平方向可无缝平铺；动画只做 **液面波动 / 光晕**，不要做「镜头里岩浆从远处涨上来」
5. **背景**：透明 PNG，或可直接当 HUD 用的不透明熔岩色块

## 当前实现（无需素材也能玩）

| 层 | 作用 |
|----|------|
| `LavaFill` + shader | 填满底部 25%，**顶边 = 液面** |
| `SurfaceLine` | 顶边 6px 高亮，标出「烫线」 |
| `lava.gd` | 液面上方 **110px 预警带** → 史莱姆变橙；没过液面 **~0.45s** 才淘汰 |

调参位置：

- **MainArena → ArenaCamera**：`lava_screen_fraction`（危险区占屏比例，默认 0.25）
- **ScrollHazard（lava.gd）**：`warning_margin`、`burn_seconds`
- **LavaOverlay（lava_visual.gd）**：`base_intensity` / `scroll_intensity`

## 若以后换自定义贴图/视频

1. 只替换 **LavaFill** 区域内容，保持控件 `anchor_top = 0.75` 不变  
2. 素材 **第一行像素 = 液面**，与 `SurfaceLine` 对齐  
3. 用 **横条循环动画**，不要用带大面积留白的竖屏视频  
4. 导入后检查：脚碰到 **亮边** 才开始发烫，没入熔岩不会秒死  

## 推荐 AI 提示词方向（供重新生成）

> 2D game UI lava hazard strip, top-down horizontal cross-section, bright molten surface line at the **top edge**, solid lava filling downward, no sky no gray background, seamless tile, 1080x480, transparent or dark red fill

---

技术调参见 [README.md](README.md)；玩法含义见 [DESIGN.md](DESIGN.md)。
