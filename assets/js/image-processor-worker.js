// Web Worker for image processing operations
// This runs in a separate thread to keep the UI responsive

import init, {
  WasmImageProcessor,
} from "/pkg/image_processor_wasm_web_component.js";

let wasmReady = false;
let processor = null;

// Initialize WASM module
async function initializeWasm() {
  if (!wasmReady) {
    await init();
    wasmReady = true;
  }
}

// Helper function to calculate preview dimensions and generate preview
function getPreviewData() {
  const fullWidth = processor.getWidth();
  const fullHeight = processor.getHeight();
  const preview = processor.createPreview(800);

  // Calculate preview dimensions (max 800px, maintaining aspect ratio)
  const maxDim = 800;
  let previewWidth, previewHeight;
  if (fullWidth <= maxDim && fullHeight <= maxDim) {
    previewWidth = fullWidth;
    previewHeight = fullHeight;
  } else if (fullWidth > fullHeight) {
    previewWidth = maxDim;
    previewHeight = Math.round(fullHeight * (maxDim / fullWidth));
  } else {
    previewHeight = maxDim;
    previewWidth = Math.round(fullWidth * (maxDim / fullHeight));
  }

  return {
    fullWidth,
    fullHeight,
    previewWidth,
    previewHeight,
    preview,
  };
}

// Message handler
self.onmessage = async function (e) {
  const { type, data, id } = e.data;

  try {
    // Ensure WASM is initialized
    await initializeWasm();

    switch (type) {
      case "load":
        processor = new WasmImageProcessor(data.imageData);
        self.postMessage({
          type: "loaded",
          id,
          data: getPreviewData(),
        });
        break;

      case "scale":
        if (!processor) throw new Error("No image loaded");
        processor.scaleByFactor(data.factor, data.filter || "lanczos3");
        self.postMessage({
          type: "scaled",
          id,
          data: getPreviewData(),
        });
        break;

      case "scaleExact":
        if (!processor) throw new Error("No image loaded");
        processor.scaleExact(
          data.width,
          data.height,
          data.filter || "lanczos3",
        );
        self.postMessage({
          type: "scaled",
          id,
          data: getPreviewData(),
        });
        break;

      case "crop":
        if (!processor) throw new Error("No image loaded");
        processor.crop(data.x, data.y, data.width, data.height);
        self.postMessage({
          type: "cropped",
          id,
          data: getPreviewData(),
        });
        break;

      case "cropCenter":
        if (!processor) throw new Error("No image loaded");
        processor.cropFromCenter(data.width, data.height);
        self.postMessage({
          type: "cropped",
          id,
          data: getPreviewData(),
        });
        break;

      case "cropAspect":
        if (!processor) throw new Error("No image loaded");
        processor.cropToAspectRatio(data.aspectWidth, data.aspectHeight);
        self.postMessage({
          type: "cropped",
          id,
          data: getPreviewData(),
        });
        break;

      case "rotate":
        if (!processor) throw new Error("No image loaded");
        processor.rotate(data.degrees);
        self.postMessage({
          type: "rotated",
          id,
          data: getPreviewData(),
        });
        break;

      case "flipHorizontal":
        if (!processor) throw new Error("No image loaded");
        processor.flipHorizontal();
        self.postMessage({
          type: "flipped",
          id,
          data: getPreviewData(),
        });
        break;

      case "flipVertical":
        if (!processor) throw new Error("No image loaded");
        processor.flipVertical();
        self.postMessage({
          type: "flipped",
          id,
          data: getPreviewData(),
        });
        break;

      case "export":
        if (!processor) throw new Error("No image loaded");
        let imageData;
        if (data.quality !== undefined) {
          imageData = processor.toFormatWithQuality(data.format, data.quality);
        } else {
          imageData = processor.toFormat(data.format);
        }
        self.postMessage({
          type: "exported",
          id,
          data: { imageData, format: data.format },
        });
        break;

      case "exportDual":
        if (!processor) throw new Error("No image loaded");
        const result = processor.exportDual(
          data.thumbCropX,
          data.thumbCropY,
          data.thumbCropWidth,
          data.thumbCropHeight,
          data.thumbWidth,
          data.thumbHeight,
          data.thumbFormat,
          data.thumbQuality,
          data.largeMaxDimension,
          data.largeFormat,
          data.largeQuality,
        );
        self.postMessage({
          type: "dualExported",
          id,
          data: {
            thumbnail: result.thumbnail,
            large: result.large,
            thumbFormat: data.thumbFormat,
            largeFormat: data.largeFormat,
          },
        });
        break;

      case "reset":
        processor = new WasmImageProcessor(data.originalImageData);
        self.postMessage({
          type: "reset",
          id,
          data: getPreviewData(),
        });
        break;

      case "getPreview":
        if (!processor) throw new Error("No image loaded");
        self.postMessage({
          type: "preview",
          id,
          data: {
            preview: processor.createPreview(800),
          },
        });
        break;

      default:
        throw new Error(`Unknown operation: ${type}`);
    }
  } catch (error) {
    self.postMessage({
      type: "error",
      id,
      error: error.message || "Unknown error occurred",
    });
  }
};
