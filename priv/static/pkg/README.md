# Image Processor WASM Web Component

A high-performance image processing web component built with Rust and compiled to WebAssembly. This component provides a complete UI for image manipulation including scaling, cropping, rotation, flipping, and format conversion.

## Features

- **🔍 Image Scaling** - Resize images with multiple filtering algorithms
  - Scale to exact dimensions
  - Scale to width/height maintaining aspect ratio
  - Scale by factor
  - Filters: Nearest, Triangle, CatmullRom, Gaussian, Lanczos3

- **✂️ Cropping** - Flexible cropping options
  - Crop to specific coordinates and dimensions
  - Crop from center
  - Crop to aspect ratio

- **🔄 Rotation** - Rotate images in 90° increments
  - 90°, 180°, 270° rotation
  - Lossless rotation

- **🔃 Flipping** - Mirror images
  - Horizontal flip
  - Vertical flip

- **💾 Format Conversion** - Export to multiple formats
  - PNG
  - JPEG (with quality control)
  - WebP (with quality control)
  - BMP
  - GIF

- **⚡ Performance** - Native-speed processing powered by Rust and WebAssembly
  - Web Worker architecture for non-blocking UI
  - Proxy image system for minimal memory usage
  - Handles images up to 50MB efficiently
  - Real-time preview updates with loading indicators

## Architecture

```
┌─────────────────────────────────────────┐
│         Web Component (UI)              │
│  - Shadow DOM                           │
│  - File upload (drag & drop)            │
│  - Canvas preview                       │
│  - Control panel                        │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│      WASM Bindings (wasm-bindgen)       │
│  - WasmImageProcessor wrapper           │
│  - JS/Rust boundary                     │
│  - Error handling                       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│    Core Image Processing (Rust)         │
│  - ImageProcessor struct                │
│  - Operations modules                   │
│    • scale.rs                           │
│    • crop.rs                            │
│    • rotate.rs                          │
│    • flip.rs                            │
│    • format.rs                          │
│    • quality.rs                         │
└─────────────────────────────────────────┘
```

## Project Structure

```
.
├── Cargo.toml              # Rust project configuration
├── src/
│   ├── lib.rs             # Library root
│   ├── error.rs           # Error handling
│   ├── wasm.rs            # WASM bindings
│   └── operations/        # Image processing modules
│       ├── mod.rs
│       ├── scale.rs
│       ├── crop.rs
│       ├── rotate.rs
│       ├── flip.rs
│       ├── format.rs
│       └── quality.rs
├── tests/
│   └── integration_tests.rs  # Test suite (32 tests)
├── web/
│   ├── index.html         # Demo page
│   └── image-processor.js # Web component
├── pkg/                   # WASM build output
│   ├── *.wasm            # Compiled WASM module
│   ├── *.js              # JS glue code
│   └── *.d.ts            # TypeScript definitions
└── PROJECT_PLAN.md        # Detailed project plan
```

## Getting Started

### Prerequisites

- Rust (latest stable)
- Node.js (v18 or later)
- wasm-pack (`cargo install wasm-pack`)
- A modern web browser with WASM support

### Building the Project

⚠️ **IMPORTANT:** After pulling new changes, you MUST rebuild WASM for the proxy image system to work!

1. **Quick start:**
   ```bash
   ./build.sh
   ```

2. **Or build manually:**
   ```bash
   # Install dependencies
   npm install

   # Build everything (WASM + optimized web assets)
   npm run build

   # Or build steps individually:
   npm run build:wasm  # Build Rust to WASM (REQUIRED for createPreview method)
   npm run build:web   # Build web assets with esbuild & Lightning CSS
   ```

3. **Run tests:**
   ```bash
   cargo test
   ```

4. **Serve the demo:**
   ```bash
   npm run serve
   # Or use the convenience script:
   ./serve.sh
   ```

5. **Open in browser:**
   Navigate to `http://localhost:8000`

6. **Verify proxy system is working:**
   - Load a large image (>800px)
   - Check browser console: Should see `Canvas: 800×XXXpx (preview)`
   - Inspect canvas element: Should have width/height ≤800px
   - See [TESTING.md](./TESTING.md) for comprehensive testing guide

### Build System

The project uses a modern build pipeline:

- **wasm-pack** - Compiles Rust to WebAssembly
- **esbuild** - Fast JavaScript bundling and minification
- **Lightning CSS** - Advanced CSS processing and optimization
- **Build output** - Optimized dist/ directory ready for deployment

## Usage

### Basic Usage

Include the web component in your HTML:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Image Processor Demo</title>
</head>
<body>
    <image-processor></image-processor>

    <script type="module" src="./image-processor.js"></script>
</body>
</html>
```

### JavaScript API

The web component can also be controlled programmatically:

```javascript
import init, { WasmImageProcessor } from './pkg/image_processor_wasm_web_component.js';

// Initialize WASM
await init();

// Load image from bytes
const response = await fetch('image.jpg');
const arrayBuffer = await response.arrayBuffer();
const imageData = new Uint8Array(arrayBuffer);

// Create processor
const processor = new WasmImageProcessor(imageData);

// Get dimensions
console.log(processor.getWidth(), processor.getHeight());

// Scale image
processor.scaleToWidth(800, 'lanczos3');

// Rotate
processor.rotate90();

// Flip
processor.flipHorizontal();

// Crop
processor.cropFromCenter(400, 400);

// Export to JPEG with quality
const jpegData = processor.toJpegWithQuality(85);

// Create blob and download
const blob = new Blob([jpegData], { type: 'image/jpeg' });
const url = URL.createObjectURL(blob);
```

### Available Methods

#### Scaling
- `scaleExact(width, height, filter?)` - Scale to exact dimensions
- `scaleToWidth(width, filter?)` - Scale to width, maintain aspect ratio
- `scaleToHeight(height, filter?)` - Scale to height, maintain aspect ratio
- `scaleByFactor(factor, filter?)` - Scale by a factor (e.g., 0.5, 2.0)

**Filters:** `"nearest"`, `"triangle"`, `"catmullrom"`, `"gaussian"`, `"lanczos3"` (default)

#### Cropping
- `crop(x, y, width, height)` - Crop to specific coordinates
- `cropFromCenter(width, height)` - Crop from center
- `cropToAspectRatio(aspectWidth, aspectHeight)` - Crop to aspect ratio

#### Rotation
- `rotate(degrees)` - Rotate by 90, 180, or 270 degrees
- `rotate90()` - Rotate 90° clockwise
- `rotate180()` - Rotate 180°
- `rotate270()` - Rotate 270° clockwise

#### Flipping
- `flipHorizontal()` - Flip horizontally
- `flipVertical()` - Flip vertically

#### Format Conversion
- `toFormat(format)` - Convert to format (`"png"`, `"jpeg"`, `"webp"`, `"bmp"`)
- `toFormatWithQuality(format, quality)` - Convert with quality (1-100)
- `toPng()` - Convert to PNG
- `toJpeg()` - Convert to JPEG
- `toJpegWithQuality(quality)` - Convert to JPEG with quality
- `toWebp()` - Convert to WebP

#### Information
- `getWidth()` - Get current width
- `getHeight()` - Get current height

## Performance

- **WASM Bundle Size:** ~2.4 MB (optimized)
- **Image Processing:** Near-native performance in Web Worker (non-blocking UI)
- **Memory Efficiency:** ~98% reduction for large images via proxy rendering
- **Max Image Size:** 50MB file size limit
- **Preview System:** Lightweight 800px proxy for UI (full resolution preserved for export)
- **32 Comprehensive Tests:** All passing

### Performance Highlights

- **Zero UI freeze** - All processing happens in Web Worker threads
- **Minimal memory footprint** - Only ~2MB for UI preview regardless of source image size
- **Fast preview updates** - Triangle filter for responsive UI
- **High-quality exports** - Full resolution with Lanczos3 filter preserved

See [PERFORMANCE_IMPROVEMENTS.md](./PERFORMANCE_IMPROVEMENTS.md) for detailed metrics and architecture.

### Optimization Settings

The release build uses aggressive optimization:

```toml
[profile.release]
opt-level = "z"        # Optimize for size
lto = true             # Link-time optimization
codegen-units = 1      # Better optimization
panic = "abort"        # Smaller binary
```

## Testing

Run the test suite:

```bash
cargo test
```

The project includes 32 comprehensive tests covering:
- Scale operations (8 tests)
- Crop operations (6 tests)
- Rotate operations (4 tests)
- Flip operations (3 tests)
- Format conversion (6 tests)
- Quality adjustment (3 tests)
- Integration tests (2 tests)

## Browser Compatibility

This web component works in all modern browsers with WebAssembly support:

- ✅ Chrome/Edge (Chromium)
- ✅ Firefox
- ✅ Safari
- ✅ Opera

Requires:
- ES6 Modules
- WebAssembly
- Custom Elements v1
- Shadow DOM v1

## Development

### Running in Development Mode

```bash
# Build with debug info
wasm-pack build --target web --dev

# Watch for changes (requires cargo-watch)
cargo watch -s 'wasm-pack build --target web --dev'
```

### Checking Code Quality

```bash
# Run clippy for linting
cargo clippy

# Format code
cargo fmt

# Check without building
cargo check
```

## Technology Stack

- **Rust** - Core image processing logic
- **image** - Image manipulation library
- **imageproc** - Advanced image processing
- **wasm-bindgen** - Rust/JavaScript interop
- **wasm-pack** - WASM build tool
- **Web Components** - Custom elements
- **Shadow DOM** - Encapsulated styling

## License

This project structure and code are provided as-is for educational and development purposes.

## Contributing

Contributions are welcome! Areas for improvement:

- Additional image filters (blur, sharpen, brightness, contrast)
- Batch processing multiple images
- History/undo functionality
- Advanced cropping UI with visual selection
- Image comparison view
- Performance metrics dashboard
- Additional export formats (TIFF, ICO, etc.)

## Troubleshooting

### WASM module fails to load
- Ensure you're serving the files over HTTP (not file://)
- Check that the `pkg/` directory contains the built WASM files

### Performance issues
- For large images, consider reducing quality or dimensions
- Use appropriate scale filters (nearest is fastest, lanczos3 is highest quality)

### Browser compatibility issues
- Verify WebAssembly support: `typeof WebAssembly === 'object'`
- Check console for CORS or module loading errors

## Resources

- [Rust Book](https://doc.rust-lang.org/book/)
- [wasm-bindgen Guide](https://rustwasm.github.io/docs/wasm-bindgen/)
- [Web Components Documentation](https://developer.mozilla.org/en-US/docs/Web/Web_Components)
- [image crate Documentation](https://docs.rs/image/)

## Acknowledgments

Built with the excellent Rust image processing ecosystem and WebAssembly tooling.
