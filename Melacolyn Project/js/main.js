import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

// ============================================
// State
// ============================================
let scene, camera, renderer, controls;
let currentModel = null;
let autoRotate = true;
let rotationSpeed = 1;
let zoomLevel = 1;
let lightIntensity = 1;
let raycaster, mouse;
let hoveredObject = null;
let selectedObject = null;
let lights = {};
let interactableObjects = [];

// ============================================
// Initialize
// ============================================
function init() {
    const container = document.getElementById('canvas-container');

    // Scene
    scene = new THREE.Scene();
    scene.background = new THREE.Color('#0a0a0f');

    // Camera
    camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 1000);
    camera.position.set(3, 2, 5);

    // Renderer
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.2;
    container.appendChild(renderer.domElement);

    // Controls
    controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.05;
    controls.autoRotate = true;
    controls.autoRotateSpeed = 1;
    controls.minDistance = 1;
    controls.maxDistance = 20;

    // Lights
    setupLights();

    // Grid
    const gridHelper = new THREE.GridHelper(20, 40, 0x333333, 0x1a1a1a);
    gridHelper.position.y = -1.5;
    scene.add(gridHelper);

    // Raycaster
    raycaster = new THREE.Raycaster();
    mouse = new THREE.Vector2();

    // Load default demo scene
    loadDefaultModel();

    // Events
    window.addEventListener('resize', onWindowResize);
    renderer.domElement.addEventListener('mousemove', onMouseMove);
    renderer.domElement.addEventListener('click', onClick);

    // UI
    setupUI();

    // Start loop
    animate();
}

function setupLights() {
    lights.ambient = new THREE.AmbientLight(0xffffff, 0.4);
    scene.add(lights.ambient);

    lights.directional = new THREE.DirectionalLight(0xffffff, 1.5);
    lights.directional.position.set(5, 10, 7);
    lights.directional.castShadow = true;
    lights.directional.shadow.mapSize.width = 2048;
    lights.directional.shadow.mapSize.height = 2048;
    lights.directional.shadow.camera.near = 0.5;
    lights.directional.shadow.camera.far = 50;
    scene.add(lights.directional);

    lights.fill = new THREE.DirectionalLight(0x6c5ce7, 0.3);
    lights.fill.position.set(-5, 0, -5);
    scene.add(lights.fill);

    lights.rim = new THREE.DirectionalLight(0x74b9ff, 0.2);
    lights.rim.position.set(0, -5, 5);
    scene.add(lights.rim);
}

// ============================================
// Default Demo Model
// ============================================
function loadDefaultModel() {
    const group = new THREE.Group();
    group.name = 'DemoScene';

    // Main torus knot
    const torusKnotGeo = new THREE.TorusKnotGeometry(0.8, 0.25, 128, 32);
    const torusKnotMat = new THREE.MeshStandardMaterial({
        color: 0x6c5ce7,
        metalness: 0.3,
        roughness: 0.4,
    });
    const torusKnot = new THREE.Mesh(torusKnotGeo, torusKnotMat);
    torusKnot.position.y = 0.5;
    torusKnot.castShadow = true;
    torusKnot.receiveShadow = true;
    torusKnot.name = 'Torus Knot';
    group.add(torusKnot);
    interactableObjects.push(torusKnot);

    // Floating spheres
    const sphereGeo = new THREE.SphereGeometry(0.3, 32, 32);
    const colors = [0x00b894, 0xe17055, 0xfdcb6e, 0x74b9ff];
    const names = ['Emerald Sphere', 'Coral Sphere', 'Gold Sphere', 'Sky Sphere'];

    for (let i = 0; i < 4; i++) {
        const mat = new THREE.MeshStandardMaterial({
            color: colors[i],
            metalness: 0.5,
            roughness: 0.3,
        });
        const sphere = new THREE.Mesh(sphereGeo, mat);
        const angle = (i / 4) * Math.PI * 2;
        sphere.position.set(
            Math.cos(angle) * 2,
            0.5 + Math.sin(i * 1.5) * 0.5,
            Math.sin(angle) * 2
        );
        sphere.castShadow = true;
        sphere.name = names[i];
        group.add(sphere);
        interactableObjects.push(sphere);
    }

    // Icosahedron
    const icoGeo = new THREE.IcosahedronGeometry(0.5, 0);
    const icoMat = new THREE.MeshStandardMaterial({
        color: 0xa29bfe,
        metalness: 0.6,
        roughness: 0.2,
        flatShading: true,
    });
    const ico = new THREE.Mesh(icoGeo, icoMat);
    ico.position.set(0, 2, 0);
    ico.castShadow = true;
    ico.name = 'Icosahedron';
    group.add(ico);
    interactableObjects.push(ico);

    scene.add(group);
    currentModel = group;

    // Update object list
    updateObjectList();
}

// ============================================
// Model Loading
// ============================================
function loadModelFromFile(file) {
    showLoading(true);

    const reader = new FileReader();
    reader.onload = function(e) {
        const contents = e.target.result;
        const loader = new GLTFLoader();

        loader.parse(contents, '', function(gltf) {
            // Clear current
            clearCurrentModel();

            currentModel = gltf.scene;

            // Center and scale
            const box = new THREE.Box3().setFromObject(currentModel);
            const center = box.getCenter(new THREE.Vector3());
            const size = box.getSize(new THREE.Vector3());
            const maxDim = Math.max(size.x, size.y, size.z);
            const scale = 3 / maxDim;

            currentModel.scale.setScalar(scale);
            currentModel.position.sub(center.multiplyScalar(scale));
            currentModel.position.y += 1;

            // Enable shadows & collect interactables
            interactableObjects = [];
            currentModel.traverse(function(child) {
                if (child.isMesh) {
                    child.castShadow = true;
                    child.receiveShadow = true;
                    if (child.name) {
                        interactableObjects.push(child);
                    }
                }
            });

            scene.add(currentModel);

            // Reset camera
            controls.reset();
            camera.position.set(3, 2, 5);

            // Update UI
            updateObjectList();
            hideLoading();
            closeModal();

            // Show inspector with model info
            showModelInfo(file.name);
        }, function(error) {
            console.error('Error loading model:', error);
            hideLoading();
            alert('Error loading model. Make sure it\'s a valid .glb or .gltf file.');
        });
    };

    reader.readAsArrayBuffer(file);
}

function clearCurrentModel() {
    if (currentModel) {
        scene.remove(currentModel);
        currentModel.traverse(function(child) {
            if (child.isMesh) {
                child.geometry.dispose();
                if (Array.isArray(child.material)) {
                    child.material.forEach(m => m.dispose());
                } else {
                    child.material.dispose();
                }
            }
        });
    }
    interactableObjects = [];
}

// ============================================
// Interaction
// ============================================
function onMouseMove(event) {
    mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
    mouse.y = -(event.clientY / window.innerHeight) * 2 + 1;

    raycaster.setFromCamera(mouse, camera);
    const intersects = raycaster.intersectObjects(interactableObjects, false);

    const tooltip = document.getElementById('tooltip');

    if (intersects.length > 0) {
        const obj = intersects[0].object;
        if (obj && obj.name) {
            tooltip.textContent = obj.name;
            tooltip.style.left = event.clientX + 14 + 'px';
            tooltip.style.top = event.clientY + 14 + 'px';
            tooltip.classList.add('visible');
            document.body.style.cursor = 'pointer';
            hoveredObject = obj;
        } else {
            tooltip.classList.remove('visible');
            document.body.style.cursor = 'default';
            hoveredObject = null;
        }
    } else {
        tooltip.classList.remove('visible');
        document.body.style.cursor = 'default';
        hoveredObject = null;
    }
}

function onClick(event) {
    if (hoveredObject) {
        selectObject(hoveredObject);
    }
}

function selectObject(obj) {
    // Deselect previous
    if (selectedObject && selectedObject.material.emissive) {
        selectedObject.material.emissive.setHex(0x000000);
        selectedObject.material.emissiveIntensity = 0;
    }

    selectedObject = obj;

    // Highlight
    if (obj.material.emissive) {
        obj.material.emissive.setHex(0x6c5ce7);
        obj.material.emissiveIntensity = 0.3;
    }

    // Update inspector
    showObjectInfo(obj);

    // Update object list
    document.querySelectorAll('.object-chip').forEach(chip => {
        chip.classList.toggle('active', chip.dataset.name === obj.name);
    });

    // Focus camera on object
    focusOnObject(obj);
}

function focusOnObject(obj) {
    const box = new THREE.Box3().setFromObject(obj);
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z);

    const distance = maxDim * 2.5;
    const direction = camera.position.clone().sub(controls.target).normalize();

    // Animate camera (simple lerp target)
    controls.target.copy(center);
    camera.position.copy(center).add(direction.multiplyScalar(distance));
    controls.update();
}

// ============================================
// UI Updates
// ============================================
function showObjectInfo(obj) {
    const container = document.getElementById('inspector-content');

    let geometryInfo = '';
    if (obj.geometry) {
        const geo = obj.geometry;
        const vertices = geo.attributes.position ? geo.attributes.position.count : 0;
        const triangles = geo.index ? geo.index.count / 3 : vertices / 3;
        geometryInfo = `
            <div class="inspector-prop"><span class="prop-key">Vertices</span><span class="prop-value">${vertices.toLocaleString()}</span></div>
            <div class="inspector-prop"><span class="prop-key">Triangles</span><span class="prop-value">${Math.floor(triangles).toLocaleString()}</span></div>
        `;
    }

    let materialInfo = '';
    if (obj.material) {
        const mat = obj.material;
        materialInfo = `
            <div class="inspector-prop"><span class="prop-key">Material</span><span class="prop-value">${mat.type}</span></div>
            <div class="inspector-prop"><span class="prop-key">Color</span><span class="prop-value">#${mat.color.getHexString()}</span></div>
        `;
    }

    container.innerHTML = `
        <div class="inspector-object">
            <div class="inspector-name">${obj.name}</div>
            <span class="inspector-type">${obj.type}</span>
            <div class="inspector-props">
                ${geometryInfo}
                ${materialInfo}
            </div>
        </div>
    `;
}

function showModelInfo(filename) {
    const container = document.getElementById('inspector-content');
    container.innerHTML = `
        <div class="inspector-object">
            <div class="inspector-name">${filename}</div>
            <span class="inspector-type">GLTF Model</span>
            <div class="inspector-props">
                <div class="inspector-prop"><span class="prop-key">Objects</span><span class="prop-value">${interactableObjects.length}</span></div>
                <div class="inspector-prop"><span class="prop-key">Format</span><span class="prop-value">glTF 2.0</span></div>
            </div>
        </div>
    `;
}

function updateObjectList() {
    const list = document.getElementById('object-list');
    list.innerHTML = '';

    interactableObjects.forEach(obj => {
        const chip = document.createElement('div');
        chip.className = 'object-chip';
        chip.textContent = obj.name;
        chip.dataset.name = obj.name;
        chip.addEventListener('click', () => selectObject(obj));
        list.appendChild(chip);
    });
}

// ============================================
// UI Setup
// ============================================
function setupUI() {
    // Upload modal
    const modal = document.getElementById('upload-modal');
    const dropZone = document.getElementById('drop-zone');
    const fileInput = document.getElementById('file-input');

    document.getElementById('btn-upload').addEventListener('click', openModal);
    document.getElementById('modal-close').addEventListener('click', closeModal);
    modal.addEventListener('click', (e) => {
        if (e.target === modal) closeModal();
    });

    document.getElementById('btn-browse').addEventListener('click', () => fileInput.click());
    dropZone.addEventListener('click', () => fileInput.click());

    fileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) loadModelFromFile(e.target.files[0]);
    });

    // Drag & drop
    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('dragover');
    });
    dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));
    dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropZone.classList.remove('dragover');
        if (e.dataTransfer.files.length > 0) loadModelFromFile(e.dataTransfer.files[0]);
    });

    // Toggle rotate
    document.getElementById('toggle-rotate').addEventListener('click', function() {
        this.classList.toggle('active');
        autoRotate = this.classList.contains('active');
        controls.autoRotate = autoRotate;
    });

    // Speed slider
    document.getElementById('slider-speed').addEventListener('input', function() {
        rotationSpeed = parseFloat(this.value);
        controls.autoRotateSpeed = rotationSpeed;
        document.getElementById('speed-value').textContent = rotationSpeed.toFixed(1) + 'x';
    });

    // Zoom slider
    document.getElementById('slider-zoom').addEventListener('input', function() {
        zoomLevel = parseFloat(this.value);
        const dist = 5 / zoomLevel;
        const dir = camera.position.clone().sub(controls.target).normalize();
        camera.position.copy(controls.target).add(dir.multiplyScalar(dist));
        document.getElementById('zoom-value').textContent = zoomLevel.toFixed(1) + 'x';
    });

    // Light slider
    document.getElementById('slider-light').addEventListener('input', function() {
        lightIntensity = parseFloat(this.value);
        lights.ambient.intensity = 0.4 * lightIntensity;
        lights.directional.intensity = 1.5 * lightIntensity;
        lights.fill.intensity = 0.3 * lightIntensity;
        lights.rim.intensity = 0.2 * lightIntensity;
        document.getElementById('light-value').textContent = lightIntensity.toFixed(1) + 'x';
    });

    // Background colors
    document.querySelectorAll('#bg-colors .color-swatch').forEach(swatch => {
        swatch.addEventListener('click', function() {
            scene.background = new THREE.Color(this.dataset.color);
            document.querySelectorAll('#bg-colors .color-swatch').forEach(s => s.classList.remove('active'));
            this.classList.add('active');
        });
    });

    // Material colors
    document.querySelectorAll('#material-colors .color-swatch').forEach(swatch => {
        swatch.addEventListener('click', function() {
            const color = new THREE.Color(this.dataset.color);
            if (selectedObject && selectedObject.material.color) {
                selectedObject.material.color.copy(color);
            } else if (currentModel) {
                currentModel.traverse(child => {
                    if (child.isMesh && child.material.color) {
                        child.material.color.copy(color);
                    }
                });
            }
            document.querySelectorAll('#material-colors .color-swatch').forEach(s => s.classList.remove('active'));
            this.classList.add('active');
        });
    });

    // Reset
    document.getElementById('btn-reset').addEventListener('click', () => {
        controls.reset();
        camera.position.set(3, 2, 5);
        zoomLevel = 1;
        document.getElementById('slider-zoom').value = 1;
        document.getElementById('zoom-value').textContent = '1.0x';

        // Deselect
        if (selectedObject && selectedObject.material.emissive) {
            selectedObject.material.emissive.setHex(0x000000);
            selectedObject.material.emissiveIntensity = 0;
        }
        selectedObject = null;
        document.getElementById('inspector-content').innerHTML = '<div class="inspector-empty"><p>Click any object in the scene to inspect it</p></div>';
        document.querySelectorAll('.object-chip').forEach(c => c.classList.remove('active'));
    });

    // Screenshot
    document.getElementById('btn-screenshot').addEventListener('click', takeScreenshot);

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') closeModal();
        if (e.key === 'r' || e.key === 'R') document.getElementById('btn-reset').click();
    });
}

function openModal() {
    document.getElementById('upload-modal').classList.add('visible');
}

function closeModal() {
    document.getElementById('upload-modal').classList.remove('visible');
}

function showLoading(show) {
    document.getElementById('loading').classList.toggle('visible', show);
}

function takeScreenshot() {
    // Flash effect
    const flash = document.getElementById('flash');
    flash.classList.add('active');
    setTimeout(() => flash.classList.remove('active'), 150);

    // Capture
    renderer.render(scene, camera);
    const dataURL = renderer.domElement.toDataURL('image/png');

    // Download
    const link = document.createElement('a');
    link.download = 'melacolyn-screenshot.png';
    link.href = dataURL;
    link.click();
}

// ============================================
// Loop
// ============================================
function onWindowResize() {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
}

function animate() {
    requestAnimationFrame(animate);
    controls.update();

    // Animate objects
    if (currentModel) {
        const time = Date.now() * 0.001;
        currentModel.children.forEach((child, i) => {
            if (child.name && child.name !== 'Torus Knot') {
                child.position.y += Math.sin(time * 2 + i) * 0.002;
                child.rotation.x += 0.005;
                child.rotation.y += 0.005;
            }
        });
    }

    renderer.render(scene, camera);
}

// ============================================
// Start
// ============================================
init();
