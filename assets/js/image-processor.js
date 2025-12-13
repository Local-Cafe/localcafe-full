import { S3Uploader } from "./uploader.js";

class ImageProcessorElement extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this.worker = null;
    this.originalImageData = null;
    this.messageId = 0;
    this.pendingMessages = new Map();
    this.isProcessing = false;
    this.uploader = new S3Uploader();
    // Crop selection state
    this.cropSelection = { x: 0, y: 0, width: 0, height: 0 };
    this.isDragging = false;
    this.dragStart = { x: 0, y: 0 };
    this.dragMode = null; // 'move', 'nw', 'ne', 'sw', 'se'
    this.initialCrop = null;
    this.fullWidth = 0;
    this.fullHeight = 0;
    this.previewWidth = 0;
    this.previewHeight = 0;
  }

  connectedCallback() {
    this.initializeWorker();
    this.render();
    this.attachEventListeners();
  }

  disconnectedCallback() {
    if (this.worker) {
      this.worker.terminate();
    }
  }

  initializeWorker() {
    try {
      this.worker = new Worker("/assets/js/image-processor-worker.js", {
        type: "module",
      });
    } catch (error) {
      this.showError(`Worker initialization failed: ${error.message}`);
      return;
    }

    this.worker.onmessage = (e) => {
      const { type, id, data, error } = e.data;

      if (error) {
        this.showError(error);
        this.setLoading(false);
        const resolve = this.pendingMessages.get(id);
        if (resolve) {
          resolve.reject(new Error(error));
          this.pendingMessages.delete(id);
        }
        return;
      }

      const callback = this.pendingMessages.get(id);
      if (callback) {
        callback.resolve(data);
        this.pendingMessages.delete(id);
      }
    };

    this.worker.onerror = (error) => {
      this.showError(`Worker error: ${error.message}`);
      this.setLoading(false);
    };
  }

  sendToWorker(type, data = {}) {
    return new Promise((resolve, reject) => {
      const id = ++this.messageId;
      this.pendingMessages.set(id, { resolve, reject });
      this.worker.postMessage({ type, data, id });
    });
  }

  render() {
    this.shadowRoot.innerHTML = `
            <style>
                :host {
                    display: block;
                    font-family: var(--font-sans, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif);
                    max-width: 1400px;
                    margin: 0 auto;
                    padding: 20px;
                    color: var(--color-text-primary, #000);
                }

                .container {
                    display: grid;
                    grid-template-columns: 1fr 350px;
                    gap: 20px;
                    min-height: 600px;
                }

                .preview-section {
                    background: var(--color-surface-secondary, #f5f5f5);
                    border: 1px solid var(--color-border, #000);
                    border-radius: 0;
                    padding: 20px;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    position: relative;
                }

                .controls-section {
                    background: var(--color-surface-primary, white);
                    border: 1px solid var(--color-border, #000);
                    border-radius: 0;
                    padding: 20px;
                    overflow-y: auto;
                }

                .upload-zone {
                    border: 2px dashed var(--color-border, #000);
                    border-radius: 0;
                    padding: 60px 20px;
                    text-align: center;
                    cursor: pointer;
                    transition: all 0.2s;
                    width: 100%;
                }

                .upload-zone:hover,
                .upload-zone.drag-over {
                    border-color: var(--color-gold, #DAA520);
                    background: color-mix(in srgb, var(--color-gold, #DAA520) 10%, transparent);
                }

                .upload-zone input {
                    display: none;
                }

                .canvas-container {
                    position: relative;
                    display: inline-block;
                }

                #canvas {
                    display: block;
                    max-width: 100%;
                    max-height: 500px;
                    border-radius: 0;
                    box-shadow: var(--shadow-sm, 0 1px 2px rgba(0,0,0,0.05));
                    cursor: default;
                }

                #canvas.crop-mode {
                    cursor: crosshair;
                }

                #cropOverlay {
                    position: absolute;
                    top: 0;
                    left: 0;
                    pointer-events: none;
                    display: none;
                    max-width: 100%;
                    max-height: 500px;
                }

                #cropOverlay.active {
                    display: block;
                }

                .control-group {
                    margin-bottom: 20px;
                }

                .control-group label {
                    display: block;
                    font-weight: 600;
                    margin-bottom: 8px;
                    color: var(--color-text-primary, #000);
                }

                .control-group input,
                .control-group select {
                    width: 100%;
                    padding: 8px 12px;
                    border: 1px solid var(--color-border, #000);
                    border-radius: 0;
                    font-size: 14px;
                    background: var(--color-surface-primary, white);
                    color: var(--color-text-primary, #000);
                }

                .control-group input[type="range"] {
                    padding: 0;
                }

                .btn-group {
                    display: grid;
                    grid-template-columns: 1fr 1fr;
                    gap: 8px;
                    margin-bottom: 12px;
                }

                button {
                    padding: 10px 16px;
                    background: var(--color-black, #000);
                    color: var(--color-gold, #DAA520);
                    border: 1px solid var(--color-black, #000);
                    border-radius: 0;
                    cursor: pointer;
                    font-size: 14px;
                    font-weight: 500;
                    transition: all 0.2s;
                }

                button:hover:not(:disabled) {
                    background: var(--color-gold, #DAA520);
                    color: var(--color-black, #000);
                }

                button:disabled {
                    background: var(--color-gray-300, #ccc);
                    color: var(--color-gray-500, #666);
                    border-color: var(--color-gray-300, #ccc);
                    cursor: not-allowed;
                    opacity: 0.6;
                }

                button.secondary {
                    background: var(--color-surface-primary, white);
                    color: var(--color-text-primary, #000);
                    border: 1px solid var(--color-border, #000);
                }

                button.secondary:hover:not(:disabled) {
                    background: var(--color-surface-secondary, #f5f5f5);
                    border-color: var(--color-gold, #DAA520);
                }

                .section-title {
                    font-size: 16px;
                    font-weight: 700;
                    margin: 20px 0 12px 0;
                    padding-bottom: 8px;
                    border-bottom: 2px solid var(--color-border, #000);
                }

                .info-text {
                    color: var(--color-text-secondary, #666);
                    font-size: 14px;
                    margin-top: 4px;
                }

                .dimensions {
                    background: var(--color-surface-secondary, #f5f5f5);
                    padding: 12px;
                    border-radius: 0;
                    margin-bottom: 16px;
                    font-size: 14px;
                    border: 1px solid var(--color-border, #000);
                }

                .loading-overlay {
                    position: absolute;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background: color-mix(in srgb, var(--color-surface-primary, white) 90%, transparent);
                    display: none;
                    align-items: center;
                    justify-content: center;
                    border-radius: 0;
                    z-index: 10;
                }

                .loading-overlay.active {
                    display: flex;
                }

                .spinner {
                    border: 4px solid var(--color-border, #e0e0e0);
                    border-top: 4px solid var(--color-gold, #DAA520);
                    border-radius: 50%;
                    width: 40px;
                    height: 40px;
                    animation: spin 1s linear infinite;
                }

                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }

                .error-message {
                    background: var(--color-error-light, #ffebee);
                    color: var(--color-error, #c62828);
                    padding: 12px;
                    border: 1px solid var(--color-error, #c62828);
                    border-radius: 0;
                    margin-bottom: 16px;
                    display: none;
                    font-size: 14px;
                }

                .error-message.active {
                    display: block;
                }

                .success-message {
                    background: var(--color-success-light, #e8f5e9);
                    color: var(--color-success, #2e7d32);
                    padding: 12px;
                    border: 1px solid var(--color-success, #2e7d32);
                    border-radius: 0;
                    margin-bottom: 16px;
                    display: none;
                    font-size: 14px;
                }

                .success-message.active {
                    display: block;
                }

                .upload-progress {
                    margin-top: 12px;
                    padding: 12px;
                    background: var(--color-surface-secondary, #f5f5f5);
                    border: 1px solid var(--color-border, #000);
                    border-radius: 0;
                }

                .progress-item {
                    display: grid;
                    grid-template-columns: 80px 1fr 50px;
                    gap: 8px;
                    align-items: center;
                    margin-bottom: 8px;
                }

                .progress-item:last-child {
                    margin-bottom: 0;
                }

                .progress-bar {
                    height: 20px;
                    background: var(--color-border, #e0e0e0);
                    border: 1px solid var(--color-border, #000);
                    border-radius: 0;
                    overflow: hidden;
                }

                .progress-fill {
                    height: 100%;
                    background: var(--color-gold, #DAA520);
                    width: 0%;
                    transition: width 0.3s ease;
                }

                .memory-info {
                    background: var(--color-success-light, #e8f5e9);
                    padding: 8px 12px;
                    border: 1px solid var(--color-success, #2e7d32);
                    border-radius: 0;
                    margin-bottom: 16px;
                    font-size: 12px;
                    color: var(--color-success, #2e7d32);
                    display: none;
                }

                .memory-info.active {
                    display: block;
                }

                @media (max-width: 768px) {
                    .container {
                        grid-template-columns: 1fr;
                    }
                }
            </style>

            <div class="container">
                <div class="preview-section">
                    <div class="loading-overlay" id="loadingOverlay">
                        <div class="spinner"></div>
                    </div>
                    <div class="upload-zone" id="uploadZone">
                        <input type="file" id="fileInput" accept="image/*">
                        <p>📸 Drop image here or click to upload</p>
                        <p class="info-text">Supports: PNG, JPEG, WebP, GIF, BMP</p>
                        <p class="info-text">Using proxy rendering for better performance</p>
                    </div>
                    <div class="canvas-container" id="canvasContainer" style="display: none;">
                        <canvas id="canvas"></canvas>
                        <canvas id="cropOverlay" class="crop-overlay"></canvas>
                    </div>
                </div>

                <div class="controls-section">
                    <div class="error-message" id="errorMessage"></div>
                    <div class="success-message" id="successMessage"></div>

                    <button id="uploadButton" disabled>Upload & Insert Images</button>
                    <div id="uploadProgress" class="upload-progress" style="display: none;">
                        <div class="progress-item">
                            <span>Thumbnail:</span>
                            <div class="progress-bar">
                                <div id="thumbProgress" class="progress-fill"></div>
                            </div>
                            <span id="thumbPercent">0%</span>
                        </div>
                        <div class="progress-item">
                            <span>Large:</span>
                            <div class="progress-bar">
                                <div id="largeProgress" class="progress-fill"></div>
                            </div>
                            <span id="largePercent">0%</span>
                        </div>
                    </div>
                    <div class="btn-group" style="margin-top: 12px;">
                        <button id="reset" class="secondary" disabled>Reset to Original</button>
                        <button id="clearImage" class="secondary" disabled>Clear Image</button>
                    </div>
                </div>
            </div>
        `;
  }

  attachEventListeners() {
    const uploadZone = this.shadowRoot.getElementById("uploadZone");
    const fileInput = this.shadowRoot.getElementById("fileInput");

    uploadZone.addEventListener("click", () => fileInput.click());

    uploadZone.addEventListener("dragover", (e) => {
      e.preventDefault();
      uploadZone.classList.add("drag-over");
    });

    uploadZone.addEventListener("dragleave", () => {
      uploadZone.classList.remove("drag-over");
    });

    uploadZone.addEventListener("drop", (e) => {
      e.preventDefault();
      uploadZone.classList.remove("drag-over");
      const file = e.dataTransfer.files[0];
      if (file && file.type.startsWith("image/")) {
        this.loadImage(file);
      }
    });

    fileInput.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (file) {
        this.loadImage(file);
      }
    });

    this.shadowRoot
      .getElementById("uploadButton")
      .addEventListener("click", () => this.uploadAndInsert());
    this.shadowRoot
      .getElementById("reset")
      .addEventListener("click", () => this.reset());
    this.shadowRoot
      .getElementById("clearImage")
      .addEventListener("click", () => this.clearImage());

    // Crop selection canvas events
    this.attachCropCanvasListeners();
  }

  async loadImage(file) {
    try {
      // Validate file size (max 50MB)
      const MAX_SIZE = 50 * 1024 * 1024;
      if (file.size > MAX_SIZE) {
        this.showError("File too large. Maximum size is 50MB.");
        return;
      }

      this.setLoading(true);
      this.hideError();

      const arrayBuffer = await file.arrayBuffer();
      const uint8Array = new Uint8Array(arrayBuffer);

      this.originalImageData = uint8Array;

      // Load image in worker and get preview
      const result = await this.sendToWorker("load", {
        imageData: uint8Array,
      });

      this.updatePreview(
        result.preview,
        result.previewWidth,
        result.previewHeight,
      );
      this.enableControls();
      this.updateDimensions(result.fullWidth, result.fullHeight);

      this.setLoading(false);
    } catch (error) {
      this.showError(`Failed to load image: ${error.message}`);
      this.setLoading(false);
    }
  }

  updatePreview(previewData, previewWidth, previewHeight) {
    // Store preview dimensions for crop calculations
    this.previewWidth = previewWidth;
    this.previewHeight = previewHeight;

    const blob = new Blob([previewData], { type: "image/png" });
    const url = URL.createObjectURL(blob);

    const canvas = this.shadowRoot.getElementById("canvas");
    const canvasContainer = this.shadowRoot.getElementById("canvasContainer");
    const uploadZone = this.shadowRoot.getElementById("uploadZone");
    const img = new Image();

    img.onload = () => {
      // Use preview dimensions for canvas (not full resolution)
      // This keeps memory usage low while maintaining visual quality
      canvas.width = previewWidth;
      canvas.height = previewHeight;
      const ctx = canvas.getContext("2d");
      ctx.drawImage(img, 0, 0, previewWidth, previewHeight);
      URL.revokeObjectURL(url);

      uploadZone.style.display = "none";
      canvasContainer.style.display = "block";

      // Initialize and enable crop selection automatically
      this.initializeCropSelection();
      this.enableCropSelection();
    };

    img.onerror = () => {
      URL.revokeObjectURL(url);
      this.showError("Failed to render preview");
    };

    img.src = url;
  }

  updateDimensions(width, height) {
    this.fullWidth = width;
    this.fullHeight = height;
    // this.shadowRoot.getElementById("dimensions").style.display = "block";
  }

  enableControls() {
    const controls = this.shadowRoot.querySelectorAll("button, input, select");
    controls.forEach((control) => (control.disabled = false));
  }

  async applyScale() {
    if (this.isProcessing) return;

    try {
      this.setLoading(true);
      this.hideError();
      this.isProcessing = true;

      const scaleFactor = parseFloat(
        this.shadowRoot.getElementById("scaleFactor").value,
      );

      const result = await this.sendToWorker("scale", {
        factor: scaleFactor,
        filter: "lanczos3",
      });

      this.updatePreview(
        result.preview,
        result.previewWidth,
        result.previewHeight,
      );
      this.updateDimensions(result.fullWidth, result.fullHeight);

      this.setLoading(false);
      this.isProcessing = false;
    } catch (error) {
      this.showError(`Scale failed: ${error.message}`);
      this.setLoading(false);
      this.isProcessing = false;
    }
  }

  initializeCropSelection() {
    // Set initial crop to center square that's 50% of smaller dimension
    const size = Math.min(this.fullWidth, this.fullHeight) * 0.5;
    const x = (this.fullWidth - size) / 2;
    const y = (this.fullHeight - size) / 2;

    this.cropSelection = {
      x: Math.round(x),
      y: Math.round(y),
      width: Math.round(size),
      height: Math.round(size),
    };
  }

  enableCropSelection() {
    const overlay = this.shadowRoot.getElementById("cropOverlay");
    const canvas = this.shadowRoot.getElementById("canvas");

    overlay.classList.add("active");
    canvas.style.cursor = "crosshair";
    this.drawCurrentCropSelection();
  }

  attachCropCanvasListeners() {
    const canvas = this.shadowRoot.getElementById("canvas");

    canvas.addEventListener("mousedown", (e) => {
      const overlay = this.shadowRoot.getElementById("cropOverlay");
      if (!overlay.classList.contains("active")) return;

      const rect = canvas.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;

      // Scale mouse position to canvas internal coordinates
      const scaleToCanvas = canvas.width / rect.width;
      const canvasX = mouseX * scaleToCanvas;
      const canvasY = mouseY * scaleToCanvas;

      // Convert crop selection to preview coordinates
      const scaleX = this.previewWidth / this.fullWidth;
      const scaleY = this.previewHeight / this.fullHeight;
      const previewCrop = {
        x: this.cropSelection.x * scaleX,
        y: this.cropSelection.y * scaleY,
        width: this.cropSelection.width * scaleX,
        height: this.cropSelection.height * scaleY,
      };

      // Check if clicking on a handle or inside the selection
      const handleSize = 12;
      const handle = this.getHandleAt(
        canvasX,
        canvasY,
        previewCrop,
        handleSize,
      );

      if (handle) {
        this.dragMode = handle;
        this.isDragging = true;
        this.dragStart = { x: canvasX, y: canvasY };
        this.initialCrop = { ...this.cropSelection };
        canvas.style.cursor = this.getHandleCursor(handle);
      } else if (this.isInsideSelection(canvasX, canvasY, previewCrop)) {
        this.dragMode = "move";
        this.isDragging = true;
        this.dragStart = { x: canvasX, y: canvasY };
        this.initialCrop = { ...this.cropSelection };
        canvas.style.cursor = "move";
      } else {
        // Click outside selection - start creating new selection
        this.dragMode = "create";
        this.isDragging = true;
        this.dragStart = { x: canvasX, y: canvasY };
        canvas.style.cursor = "crosshair";
      }
    });

    canvas.addEventListener("mousemove", (e) => {
      const overlay = this.shadowRoot.getElementById("cropOverlay");
      if (!overlay.classList.contains("active")) return;

      const rect = canvas.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;

      // Scale mouse position to canvas internal coordinates
      const scaleToCanvas = canvas.width / rect.width;
      const canvasX = mouseX * scaleToCanvas;
      const canvasY = mouseY * scaleToCanvas;

      if (this.isDragging) {
        const dx = canvasX - this.dragStart.x;
        const dy = canvasY - this.dragStart.y;

        // Convert to full resolution
        const scaleX = this.fullWidth / this.previewWidth;
        const scaleY = this.fullHeight / this.previewHeight;
        const fullDx = dx * scaleX;
        const fullDy = dy * scaleY;

        if (this.dragMode === "create") {
          this.createCropSelection(canvasX, canvasY);
        } else if (this.dragMode === "move") {
          this.moveCropSelection(fullDx, fullDy);
        } else {
          this.resizeCropSelection(this.dragMode, fullDx, fullDy);
        }

        this.drawCurrentCropSelection();
      } else {
        // Update cursor based on hover position
        const scaleX = this.previewWidth / this.fullWidth;
        const scaleY = this.previewHeight / this.fullHeight;
        const previewCrop = {
          x: this.cropSelection.x * scaleX,
          y: this.cropSelection.y * scaleY,
          width: this.cropSelection.width * scaleX,
          height: this.cropSelection.height * scaleY,
        };

        const handleSize = 12;
        const handle = this.getHandleAt(
          canvasX,
          canvasY,
          previewCrop,
          handleSize,
        );

        if (handle) {
          canvas.style.cursor = this.getHandleCursor(handle);
        } else if (this.isInsideSelection(canvasX, canvasY, previewCrop)) {
          canvas.style.cursor = "move";
        } else {
          canvas.style.cursor = "crosshair";
        }
      }
    });

    canvas.addEventListener("mouseup", () => {
      this.isDragging = false;
      this.dragMode = null;
      this.initialCrop = null;
    });

    canvas.addEventListener("mouseleave", () => {
      this.isDragging = false;
      this.dragMode = null;
      this.initialCrop = null;
    });
  }

  getHandleAt(mouseX, mouseY, crop, handleSize) {
    const handles = {
      nw: { x: crop.x, y: crop.y },
      ne: { x: crop.x + crop.width, y: crop.y },
      sw: { x: crop.x, y: crop.y + crop.height },
      se: { x: crop.x + crop.width, y: crop.y + crop.height },
    };

    for (const [name, pos] of Object.entries(handles)) {
      const dist = Math.sqrt(
        Math.pow(mouseX - pos.x, 2) + Math.pow(mouseY - pos.y, 2),
      );
      if (dist <= handleSize) {
        return name;
      }
    }
    return null;
  }

  getHandleCursor(handle) {
    const cursors = {
      nw: "nwse-resize",
      ne: "nesw-resize",
      sw: "nesw-resize",
      se: "nwse-resize",
    };
    return cursors[handle] || "crosshair";
  }

  isInsideSelection(mouseX, mouseY, crop) {
    return (
      mouseX >= crop.x &&
      mouseX <= crop.x + crop.width &&
      mouseY >= crop.y &&
      mouseY <= crop.y + crop.height
    );
  }

  createCropSelection(mouseX, mouseY) {
    // Create new selection from drag start to current position
    const previewX = Math.min(this.dragStart.x, mouseX);
    const previewY = Math.min(this.dragStart.y, mouseY);
    const previewW = Math.abs(mouseX - this.dragStart.x);
    const previewH = Math.abs(mouseY - this.dragStart.y);

    // Make it square (use smaller dimension)
    const size = Math.min(previewW, previewH);

    // Convert to full resolution coordinates
    const scaleX = this.fullWidth / this.previewWidth;
    const scaleY = this.fullHeight / this.previewHeight;

    let fullX = Math.round(previewX * scaleX);
    let fullY = Math.round(previewY * scaleY);
    let fullSize = Math.round(size * scaleX);

    // Enforce minimum size of 400x400
    const minSize = 400;
    fullSize = Math.max(minSize, fullSize);

    // Constrain to image bounds
    fullX = Math.max(0, Math.min(fullX, this.fullWidth - fullSize));
    fullY = Math.max(0, Math.min(fullY, this.fullHeight - fullSize));
    fullSize = Math.min(
      fullSize,
      this.fullWidth - fullX,
      this.fullHeight - fullY,
    );

    this.cropSelection = {
      x: fullX,
      y: fullY,
      width: fullSize,
      height: fullSize,
    };
  }

  moveCropSelection(dx, dy) {
    let newX = this.initialCrop.x + dx;
    let newY = this.initialCrop.y + dy;

    // Constrain to image bounds
    newX = Math.max(
      0,
      Math.min(newX, this.fullWidth - this.cropSelection.width),
    );
    newY = Math.max(
      0,
      Math.min(newY, this.fullHeight - this.cropSelection.height),
    );

    this.cropSelection.x = Math.round(newX);
    this.cropSelection.y = Math.round(newY);
  }

  resizeCropSelection(handle, dx, dy) {
    // Use the larger absolute delta to keep it square
    const absDx = Math.abs(dx);
    const absDy = Math.abs(dy);
    const delta = Math.max(absDx, absDy);

    let newX = this.initialCrop.x;
    let newY = this.initialCrop.y;
    let newSize = this.initialCrop.width;

    // Calculate resize based on handle position and drag direction
    switch (handle) {
      case "se": // Bottom-right: increase size when dragging down-right
        newSize = this.initialCrop.width + delta * Math.sign(dx + dy);
        break;

      case "sw": // Bottom-left: drag left increases size
        const swDelta = delta * Math.sign(-dx + dy);
        newSize = this.initialCrop.width + swDelta;
        newX = this.initialCrop.x - swDelta;
        break;

      case "ne": // Top-right: drag right-up increases size
        const neDelta = delta * Math.sign(dx - dy);
        newSize = this.initialCrop.width + neDelta;
        newY = this.initialCrop.y - neDelta;
        break;

      case "nw": // Top-left: drag left-up increases size
        const nwDelta = delta * Math.sign(-dx - dy);
        newSize = this.initialCrop.width + nwDelta;
        newX = this.initialCrop.x - nwDelta;
        newY = this.initialCrop.y - nwDelta;
        break;
    }

    // Constrain minimum size to 400x400 (same as thumbnail output)
    const minSize = 400;
    if (newSize < minSize) {
      // Adjust position when hitting minimum size
      const sizeDiff = minSize - newSize;
      if (handle === "sw" || handle === "nw") {
        newX -= sizeDiff;
      }
      if (handle === "ne" || handle === "nw") {
        newY -= sizeDiff;
      }
      newSize = minSize;
    }

    // Constrain to image bounds
    if (newX < 0) {
      newSize = newSize + newX; // Reduce size by overflow amount
      newX = 0;
    }
    if (newY < 0) {
      newSize = newSize + newY;
      newY = 0;
    }
    if (newX + newSize > this.fullWidth) {
      newSize = this.fullWidth - newX;
    }
    if (newY + newSize > this.fullHeight) {
      newSize = this.fullHeight - newY;
    }

    // Final minimum size check
    newSize = Math.max(minSize, newSize);

    this.cropSelection = {
      x: Math.round(newX),
      y: Math.round(newY),
      width: Math.round(newSize),
      height: Math.round(newSize),
    };
  }

  toggleCropSelection() {
    const overlay = this.shadowRoot.getElementById("cropOverlay");
    const canvas = this.shadowRoot.getElementById("canvas");
    const btn = this.shadowRoot.getElementById("selectCropBtn");
    const resetBtn = this.shadowRoot.getElementById("resetCropBtn");
    const coordsDiv = this.shadowRoot.getElementById("cropCoords");

    if (overlay.classList.contains("active")) {
      overlay.classList.remove("active");
      resetBtn.style.display = "none";
      coordsDiv.style.display = "none";
      canvas.style.cursor = "default";
      this.clearCropOverlay();
    } else {
      overlay.classList.add("active");
      resetBtn.style.display = "inline-block";
      coordsDiv.style.display = "block";
      canvas.style.cursor = "crosshair";
      this.drawCurrentCropSelection();
    }
  }

  resetCropSelection() {
    this.initializeCropSelection();
    this.drawCurrentCropSelection();
  }

  drawCurrentCropSelection() {
    // Convert full res coordinates to preview coordinates
    const scaleX = this.previewWidth / this.fullWidth;
    const scaleY = this.previewHeight / this.fullHeight;

    const previewX = this.cropSelection.x * scaleX;
    const previewY = this.cropSelection.y * scaleY;
    const previewW = this.cropSelection.width * scaleX;
    const previewH = this.cropSelection.height * scaleY;

    this.drawCropOverlay(previewX, previewY, previewW, previewH);
  }

  drawCropOverlay(x, y, width, height) {
    const overlay = this.shadowRoot.getElementById("cropOverlay");
    const canvas = this.shadowRoot.getElementById("canvas");

    // Set canvas internal dimensions to match the main canvas
    overlay.width = canvas.width;
    overlay.height = canvas.height;

    // Set CSS dimensions to match the main canvas
    overlay.style.width = canvas.offsetWidth + "px";
    overlay.style.height = canvas.offsetHeight + "px";

    const ctx = overlay.getContext("2d");
    ctx.clearRect(0, 0, overlay.width, overlay.height);

    // Draw semi-transparent overlay
    ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
    ctx.fillRect(0, 0, overlay.width, overlay.height);

    // Clear the selection area
    ctx.clearRect(x, y, width, height);

    // Draw selection border - gold color
    ctx.strokeStyle = "#DAA520";
    ctx.lineWidth = 3;
    ctx.strokeRect(x, y, width, height);

    // Draw corner handles
    const handleSize = 12;
    ctx.fillStyle = "#fff";
    ctx.strokeStyle = "#DAA520";
    ctx.lineWidth = 2;

    // Helper to draw a handle
    const drawHandle = (hx, hy) => {
      ctx.fillRect(
        hx - handleSize / 2,
        hy - handleSize / 2,
        handleSize,
        handleSize,
      );
      ctx.strokeRect(
        hx - handleSize / 2,
        hy - handleSize / 2,
        handleSize,
        handleSize,
      );
    };

    drawHandle(x, y); // NW
    drawHandle(x + width, y); // NE
    drawHandle(x, y + height); // SW
    drawHandle(x + width, y + height); // SE
  }

  clearCropOverlay() {
    const overlay = this.shadowRoot.getElementById("cropOverlay");
    const ctx = overlay.getContext("2d");
    ctx.clearRect(0, 0, overlay.width, overlay.height);
  }

  async rotate(degrees) {
    if (this.isProcessing) return;

    try {
      this.setLoading(true);
      this.hideError();
      this.isProcessing = true;

      const result = await this.sendToWorker("rotate", { degrees });

      this.updatePreview(
        result.preview,
        result.previewWidth,
        result.previewHeight,
      );
      this.updateDimensions(result.fullWidth, result.fullHeight);

      this.setLoading(false);
      this.isProcessing = false;
    } catch (error) {
      this.showError(`Rotate failed: ${error.message}`);
      this.setLoading(false);
      this.isProcessing = false;
    }
  }

  async flipHorizontal() {
    if (this.isProcessing) return;

    try {
      this.setLoading(true);
      this.hideError();
      this.isProcessing = true;

      const result = await this.sendToWorker("flipHorizontal");

      this.updatePreview(
        result.preview,
        result.previewWidth,
        result.previewHeight,
      );

      this.setLoading(false);
      this.isProcessing = false;
    } catch (error) {
      this.showError(`Flip failed: ${error.message}`);
      this.setLoading(false);
      this.isProcessing = false;
    }
  }

  async flipVertical() {
    if (this.isProcessing) return;

    try {
      this.setLoading(true);
      this.hideError();
      this.isProcessing = true;

      const result = await this.sendToWorker("flipVertical");

      this.updatePreview(
        result.preview,
        result.previewWidth,
        result.previewHeight,
      );

      this.setLoading(false);
      this.isProcessing = false;
    } catch (error) {
      this.showError(`Flip failed: ${error.message}`);
      this.setLoading(false);
      this.isProcessing = false;
    }
  }

  async uploadAndInsert() {
    if (this.isProcessing) return;

    try {
      this.setLoading(true);
      this.hideError();
      this.hideSuccess();
      this.isProcessing = true;

      // Validate crop selection
      if (this.cropSelection.width === 0 || this.cropSelection.height === 0) {
        this.showError("Please select a crop region first");
        this.setLoading(false);
        this.isProcessing = false;
        return;
      }

      // Show upload progress
      this.showUploadProgress();

      // Hardcoded values: WebP format, thumb quality 90, large quality 100
      const thumbFormat = "webp";
      const thumbQuality = 90;
      const largeFormat = "webp";
      const largeQuality = 100;

      // Process images in worker
      const result = await this.sendToWorker("exportDual", {
        thumbCropX: this.cropSelection.x,
        thumbCropY: this.cropSelection.y,
        thumbCropWidth: this.cropSelection.width,
        thumbCropHeight: this.cropSelection.height,
        thumbWidth: 400,
        thumbHeight: 400,
        thumbFormat: thumbFormat,
        thumbQuality: thumbQuality,
        largeMaxDimension: 1400,
        largeFormat: largeFormat,
        largeQuality: largeQuality,
      });

      // Upload both images to S3
      const { thumbnailUrl, largeUrl } = await this.uploader.uploadBoth(
        result.thumbnail,
        result.large,
        thumbFormat,
        (progress) => {
          this.updateUploadProgress(progress.thumbnail, progress.large);
        },
      );

      // Update form fields
      this.updateFormFields(thumbnailUrl, largeUrl);

      // Dispatch custom event for components that need to listen
      this.dispatchEvent(
        new CustomEvent("image-uploaded", {
          bubbles: true,
          detail: {
            fullUrl: largeUrl,
            thumbUrl: thumbnailUrl,
          },
        }),
      );

      // Hide progress and show success
      this.hideUploadProgress();
      this.showSuccess(
        `Images uploaded successfully! URLs have been inserted into the form.`,
      );

      this.setLoading(false);
      this.isProcessing = false;
    } catch (error) {
      this.hideUploadProgress();
      this.showError(`Upload failed: ${error.message}`);
      this.setLoading(false);
      this.isProcessing = false;
    }
  }

  updateFormFields(thumbnailUrl, largeUrl) {
    // Find the form fields outside the shadow DOM
    const form = document.querySelector("form");
    if (!form) {
      console.warn("Form not found");
      return;
    }

    // Update thumbnail field
    const thumbField = form.querySelector('input[name="photo[thumb_image]"]');
    if (thumbField) {
      thumbField.value = thumbnailUrl;
      // Trigger change event for any listeners
      thumbField.dispatchEvent(new Event("change", { bubbles: true }));
    }

    // Update full image field
    const fullField = form.querySelector('input[name="photo[full_image]"]');
    if (fullField) {
      fullField.value = largeUrl;
      // Trigger change event for any listeners
      fullField.dispatchEvent(new Event("change", { bubbles: true }));
    }
  }

  showUploadProgress() {
    const progressEl = this.shadowRoot.getElementById("uploadProgress");
    if (progressEl) {
      progressEl.style.display = "block";
    }
  }

  hideUploadProgress() {
    const progressEl = this.shadowRoot.getElementById("uploadProgress");
    if (progressEl) {
      progressEl.style.display = "none";
    }
  }

  updateUploadProgress(thumbPercent, largePercent) {
    const thumbFill = this.shadowRoot.getElementById("thumbProgress");
    const thumbText = this.shadowRoot.getElementById("thumbPercent");
    const largeFill = this.shadowRoot.getElementById("largeProgress");
    const largeText = this.shadowRoot.getElementById("largePercent");

    if (thumbFill && thumbText) {
      thumbFill.style.width = `${thumbPercent}%`;
      thumbText.textContent = `${Math.round(thumbPercent)}%`;
    }

    if (largeFill && largeText) {
      largeFill.style.width = `${largePercent}%`;
      largeText.textContent = `${Math.round(largePercent)}%`;
    }
  }

  async reset() {
    if (!this.originalImageData || this.isProcessing) return;

    try {
      this.setLoading(true);
      this.hideError();
      this.isProcessing = true;

      const result = await this.sendToWorker("reset", {
        originalImageData: this.originalImageData,
      });

      this.updatePreview(
        result.preview,
        result.previewWidth,
        result.previewHeight,
      );
      this.updateDimensions(result.fullWidth, result.fullHeight);

      this.setLoading(false);
      this.isProcessing = false;
    } catch (error) {
      this.showError(`Reset failed: ${error.message}`);
      this.setLoading(false);
      this.isProcessing = false;
    }
  }

  clearImage() {
    if (this.isProcessing) return;

    // Reset all state
    this.originalImageData = null;
    this.cropSelection = { x: 0, y: 0, width: 0, height: 0 };
    this.fullWidth = 0;
    this.fullHeight = 0;
    this.previewWidth = 0;
    this.previewHeight = 0;

    // Hide canvas, show upload zone
    const canvasContainer = this.shadowRoot.getElementById("canvasContainer");
    const uploadZone = this.shadowRoot.getElementById("uploadZone");
    const canvas = this.shadowRoot.getElementById("canvas");

    canvasContainer.style.display = "none";
    uploadZone.style.display = "block";

    // Clear canvas
    const ctx = canvas.getContext("2d");
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Disable crop selection
    const overlay = this.shadowRoot.getElementById("cropOverlay");
    overlay.classList.remove("active");
    this.clearCropOverlay();

    // Disable all controls
    const controls = this.shadowRoot.querySelectorAll("button, input, select");
    controls.forEach((control) => {
      if (control.id !== "fileInput") {
        control.disabled = true;
      }
    });

    // Hide dimensions and memory info
    this.shadowRoot.getElementById("dimensions").style.display = "none";
    this.shadowRoot.getElementById("memoryInfo").classList.remove("active");

    // Clear file input
    this.shadowRoot.getElementById("fileInput").value = "";

    this.hideError();
  }

  setLoading(loading) {
    const overlay = this.shadowRoot.getElementById("loadingOverlay");
    if (loading) {
      overlay.classList.add("active");
    } else {
      overlay.classList.remove("active");
    }
  }

  showError(message) {
    const errorEl = this.shadowRoot.getElementById("errorMessage");
    errorEl.textContent = message;
    errorEl.classList.add("active");
  }

  hideError() {
    const errorEl = this.shadowRoot.getElementById("errorMessage");
    errorEl.classList.remove("active");
  }

  showSuccess(message) {
    const successEl = this.shadowRoot.getElementById("successMessage");
    successEl.textContent = message;
    successEl.classList.add("active");
  }

  hideSuccess() {
    const successEl = this.shadowRoot.getElementById("successMessage");
    successEl.classList.remove("active");
  }
}

customElements.define("image-processor", ImageProcessorElement);
