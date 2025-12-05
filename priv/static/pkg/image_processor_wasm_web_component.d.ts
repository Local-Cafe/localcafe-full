/* tslint:disable */
/* eslint-disable */
export function set_panic_hook(): void;
/**
 * Chroma subsampling format
 */
export enum ChromaSampling {
  /**
   * Both vertically and horizontally subsampled.
   */
  Cs420 = 0,
  /**
   * Horizontally subsampled.
   */
  Cs422 = 1,
  /**
   * Not subsampled.
   */
  Cs444 = 2,
  /**
   * Monochrome.
   */
  Cs400 = 3,
}
export class WasmImageProcessor {
  free(): void;
  [Symbol.dispose](): void;
  constructor(image_data: Uint8Array);
  getWidth(): number;
  getHeight(): number;
  scaleExact(width: number, height: number, filter?: string | null): void;
  scaleToWidth(width: number, filter?: string | null): void;
  scaleToHeight(height: number, filter?: string | null): void;
  scaleByFactor(factor: number, filter?: string | null): void;
  crop(x: number, y: number, width: number, height: number): void;
  cropFromCenter(width: number, height: number): void;
  cropToAspectRatio(aspect_width: number, aspect_height: number): void;
  rotate(degrees: number): void;
  rotate90(): void;
  rotate180(): void;
  rotate270(): void;
  flipHorizontal(): void;
  flipVertical(): void;
  toFormat(format: string): Uint8Array;
  toFormatWithQuality(format: string, quality: number): Uint8Array;
  toPng(): Uint8Array;
  toJpeg(): Uint8Array;
  toJpegWithQuality(quality: number): Uint8Array;
  toWebp(): Uint8Array;
  /**
   * Creates a preview-sized version of the image for UI display
   * This significantly reduces memory usage for large images
   * @param max_dimension - Maximum width or height for the preview (default: 800)
   */
  createPreview(max_dimension?: number | null): Uint8Array;
  /**
   * Exports both a thumbnail and large version of the image
   *
   * Returns a JavaScript object with `thumbnail` and `large` properties, each containing image bytes
   *
   * @param thumb_crop_x - X coordinate for thumbnail crop
   * @param thumb_crop_y - Y coordinate for thumbnail crop
   * @param thumb_crop_width - Width of thumbnail crop region
   * @param thumb_crop_height - Height of thumbnail crop region
   * @param thumb_width - Output width for thumbnail (e.g., 400)
   * @param thumb_height - Output height for thumbnail (e.g., 400)
   * @param thumb_format - Format for thumbnail (e.g., "webp", "jpeg")
   * @param thumb_quality - Optional quality for thumbnail (1-100)
   * @param large_max_dimension - Max dimension for large version (e.g., 1400)
   * @param large_format - Format for large version
   * @param large_quality - Optional quality for large version (1-100)
   */
  exportDual(thumb_crop_x: number, thumb_crop_y: number, thumb_crop_width: number, thumb_crop_height: number, thumb_width: number, thumb_height: number, thumb_format: string, thumb_quality: number | null | undefined, large_max_dimension: number, large_format: string, large_quality?: number | null): any;
}

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
  readonly memory: WebAssembly.Memory;
  readonly set_panic_hook: () => void;
  readonly __wbg_wasmimageprocessor_free: (a: number, b: number) => void;
  readonly wasmimageprocessor_new: (a: number, b: number) => [number, number, number];
  readonly wasmimageprocessor_getWidth: (a: number) => number;
  readonly wasmimageprocessor_getHeight: (a: number) => number;
  readonly wasmimageprocessor_scaleExact: (a: number, b: number, c: number, d: number, e: number) => [number, number];
  readonly wasmimageprocessor_scaleToWidth: (a: number, b: number, c: number, d: number) => [number, number];
  readonly wasmimageprocessor_scaleToHeight: (a: number, b: number, c: number, d: number) => [number, number];
  readonly wasmimageprocessor_scaleByFactor: (a: number, b: number, c: number, d: number) => [number, number];
  readonly wasmimageprocessor_crop: (a: number, b: number, c: number, d: number, e: number) => [number, number];
  readonly wasmimageprocessor_cropFromCenter: (a: number, b: number, c: number) => [number, number];
  readonly wasmimageprocessor_cropToAspectRatio: (a: number, b: number, c: number) => [number, number];
  readonly wasmimageprocessor_rotate: (a: number, b: number) => [number, number];
  readonly wasmimageprocessor_rotate90: (a: number) => [number, number];
  readonly wasmimageprocessor_rotate180: (a: number) => [number, number];
  readonly wasmimageprocessor_rotate270: (a: number) => [number, number];
  readonly wasmimageprocessor_flipHorizontal: (a: number) => [number, number];
  readonly wasmimageprocessor_flipVertical: (a: number) => [number, number];
  readonly wasmimageprocessor_toFormat: (a: number, b: number, c: number) => [number, number, number, number];
  readonly wasmimageprocessor_toFormatWithQuality: (a: number, b: number, c: number, d: number) => [number, number, number, number];
  readonly wasmimageprocessor_toPng: (a: number) => [number, number, number, number];
  readonly wasmimageprocessor_toJpeg: (a: number) => [number, number, number, number];
  readonly wasmimageprocessor_toJpegWithQuality: (a: number, b: number) => [number, number, number, number];
  readonly wasmimageprocessor_toWebp: (a: number) => [number, number, number, number];
  readonly wasmimageprocessor_createPreview: (a: number, b: number) => [number, number, number, number];
  readonly wasmimageprocessor_exportDual: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: number, m: number, n: number) => [number, number, number];
  readonly __wbindgen_free: (a: number, b: number, c: number) => void;
  readonly __wbindgen_exn_store: (a: number) => void;
  readonly __externref_table_alloc: () => number;
  readonly __wbindgen_externrefs: WebAssembly.Table;
  readonly __wbindgen_malloc: (a: number, b: number) => number;
  readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
  readonly __externref_table_dealloc: (a: number) => void;
  readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;
/**
* Instantiates the given `module`, which can either be bytes or
* a precompiled `WebAssembly.Module`.
*
* @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
*
* @returns {InitOutput}
*/
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
* If `module_or_path` is {RequestInfo} or {URL}, makes a request and
* for everything else, calls `WebAssembly.instantiate` directly.
*
* @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
*
* @returns {Promise<InitOutput>}
*/
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
