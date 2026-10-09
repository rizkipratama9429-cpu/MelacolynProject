# 🎨 Melacolyn — Interactive 3D Studio

> *Drop a 3D model into your browser and play with it like a full-fledged studio — no install, no build step, just pure WebGL magic.*

Melacolyn is a sleek, browser-based 3D model viewer built with [Three.js](https://threejs.org/). Upload any `.glb` or `.gltf` file, orbit around it, tweak the lighting, repaint materials, inspect every mesh — and snap a screenshot when it looks perfect.

---

## ✨ Features

| | Feature | What it does |
|---|---------|--------------|
| 📂 | **Drag & Drop Upload** | Drop a `.glb`/`.gltf` file straight onto the canvas (or browse files) |
| 🔄 | **Auto-Rotate** | Smooth turntable rotation with adjustable speed (0.1x – 5x) |
| 🔍 | **Zoom & Orbit** | Damped orbit controls with a zoom slider (0.3x – 3x) |
| 💡 | **Light Studio** | Dial light intensity from moody darkness to full studio glow |
| 🎨 | **Material Tint** | Recolor your model on the fly with one-click swatches |
| 🌆 | **Backgrounds** | Swap the scene backdrop to match your model's mood |
| 🔎 | **Object Inspector** | Click any mesh to reveal its name, type, and properties |
| 📸 | **Screenshot** | Capture the current view as an image with a camera-flash effect |
| 🧭 | **Reset Camera** | Snap back to the default viewpoint anytime |
| 📱 | **Responsive** | Glassmorphism UI adapts from desktop down to mobile |

## 🚀 Quick Start

No dependencies, no bundler, no `npm install`. Just serve the folder and open it:

```bash
# Option 1: Python
python -m http.server 8000

# Option 2: Node
npx serve .
```

Then visit **http://localhost:8000** and start playing. 🕹️

> 💡 **Tip:** Opening `index.html` directly via `file://` won't work because ES modules require HTTP. Use one of the servers above.

## 📁 Project Structure

```
Melacolyn Project/
├── index.html          # App shell — UI panels, modal, import map
├── css/
│   └── style.css       # Dark glassmorphism theme & responsive layout
├── js/
│   └── main.js         # Three.js scene, loaders, raycasting, UI logic
└── 3d model web.html   # Standalone single-file demo version
```

## 🎮 How to Use

1. **Upload** — Click *Upload Model*, then drag in a `.glb` or `.gltf` file exported from Blender (`File → Export → glTF 2.0 (.glb)`).
2. **Explore** — Left-click and drag to orbit, scroll to zoom, right-click and drag to pan.
3. **Tweak** — Use the left **Scene** panel to control rotation, zoom, lighting, background, and material tint.
4. **Inspect** — Click any object in the scene (or use the chips in the bottom bar) to see its details in the right **Inspector** panel.
5. **Capture** — Hit *Capture* to save a screenshot of your current view. Hit *Reset* to return the camera home.

## 🛠️ Tech Stack

- **[Three.js](https://threejs.org/) v0.160** — rendering, GLTF loading, orbit controls (loaded via CDN import map)
- **Vanilla JavaScript (ES Modules)** — zero framework overhead
- **Vanilla CSS** — custom properties, glassmorphism panels, smooth transitions
- **Google Fonts (Inter)** — crisp, modern typography

## 📸 Model Formats

| Format | Support |
|--------|---------|
| `.glb` | ✅ Full support (recommended) |
| `.gltf` | ✅ Full support |
| `.obj` / `.fbx` / others | ❌ Not yet — convert to glTF first |

## 📄 License

Feel free to use, modify, and learn from this project.

---

Made with 💜 and a lot of `requestAnimationFrame`.

