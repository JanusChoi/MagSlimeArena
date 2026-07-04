# 玩法实验分支说明

## 分支树

| 分支 | 玩法 |
|------|------|
| `master` | 原版：按住 F/Shift 持续磁力 + 锚点续跳 |
| `experiment/anchor-impulse-one-shot` | 单次冲量锚点；F/Shift 仅锚点；无 PvP 磁力 |
| **`experiment/dual-key-pvp-impulse`**（当前） | 模型2+4：双键 + 双强度对抗 |

## 当前分支：双键 + 双强度

### 操作

| 玩家 | 锚点（强） | 钩对手（弱） | 移动 | 跳 |
|------|-----------|-------------|------|-----|
| P1 蓝 N | **F** | **G** | A/D | W |
| P2 红 S | **Shift** | **/**（问号键） | ←/→ | ↑ |

- **F / Shift**：只对锚点，大冲量（`Impulse Attract Speed` 等）
- **G / ?**：只对对手，短距弱钩（`Player Impulse *` 参数）
- 蓝 N + 红 S 异极 → 钩人始终相吸
- 钩人有冷却（默认 0.45s）

### Inspector（MainArena）

| 组 | 关键项 |
|----|--------|
| Magnet Gameplay | `Pvp Dual Key Impulse` 开关（关则回到仅锚点） |
| Anchor Impulse | 锚点射程 / **Attract Speed 1960** / 上偏 |
| Guaranteed Routes | **Route Vert Step**（360，越大越疏）/ Route Top Y |
| Player Impulse | 对手射程（280）/ 速度（520）/ 冷却 |

### 回滚

```bash
# 回到「只有锚点冲量、无 PvP 钩」
git checkout experiment/anchor-impulse-one-shot

# 回到最初按住磁力版
git checkout master
```

或在 Inspector 关闭 **Pvp Dual Key Impulse**（不删代码，仅禁用钩人键）。

## Web 部署

见 `DEPLOY.md`（方案 A：本地 `./scripts/export-web.sh` → push `web/` → Vercel）。
