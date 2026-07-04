# Web 部署（方案 A · Vercel 静态托管）

## 1. 本地导出

```bash
./scripts/export-web.sh
```

或：

```bash
godot --headless --export-release "Web" web/index.html
```

产物在 `web/` 目录（`index.html`、`.wasm`、`.pck` 等）。

### Godot 4.6.2 导出模板

若报错找不到 `web_nothreads_*.zip`，在终端执行一次（本机已配置可跳过）：

```bash
TPL="$HOME/Library/Application Support/Godot/export_templates/4.6.2.stable"
for f in web_nothreads_debug.zip web_nothreads_release.zip; do
  ln -sf "../4.6.stable/templates/$f" "$TPL/$f"
done
```

或在 Godot 编辑器：**Editor → Manage Export Templates** 安装与引擎同版本的模板。

## 2. 提交并推送

```bash
git add web/ export_presets.cfg vercel.json
git commit -m "Update web build"
git push
```

## 3. Vercel 项目设置

在 [vercel.com](https://vercel.com) 导入 GitHub 仓库后：

| 项 | 值 |
|----|-----|
| Framework Preset | **Other** |
| Root Directory | `.`（仓库根） |
| Build Command | **留空** |
| Output Directory | **web** |

根目录已有 `vercel.json`，通常会自动识别 `outputDirectory: web`。

## 4. 更新线上版本

改完游戏 → 再跑 `./scripts/export-web.sh` → commit `web/` → push → Vercel 自动部署。

## 说明

- 当前为**单线程 Web 导出**，无需额外 COOP/COEP 响应头。
- 双人同键盘在浏览器可用；竖屏 1080×1920，手机竖屏体验较好。
- 实验玩法在 `experiment/anchor-impulse-one-shot` 分支；部署前确认要上线的分支。
