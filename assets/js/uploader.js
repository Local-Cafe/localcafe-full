/**
 * S3 Uploader using presigned URLs
 * Handles fetching presigned URLs and uploading blobs to S3
 */

export class S3Uploader {
  constructor() {
    this.presignedUrlEndpoint = "/api/presigned-url";
  }

  /**
   * Generate a unique filename with timestamp
   * @param {string} prefix - Prefix for the filename (e.g., 'thumb', 'large')
   * @param {string} extension - File extension (e.g., 'webp', 'jpg')
   * @returns {string} - Unique filename
   */
  generateFilename(prefix, extension) {
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 8);
    return `${prefix}-${timestamp}-${random}.${extension}`;
  }

  /**
   * Fetch a presigned URL from the API
   * @param {string} key - S3 object key (filename/path)
   * @returns {Promise<{signedUrl: string, publicUrl: string}>}
   */
  async getPresignedUrl(key) {
    const response = await fetch(this.presignedUrlEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ key }),
      credentials: "same-origin", // Include cookies for authentication
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || `Failed to get presigned URL: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Upload a blob to S3 using a presigned URL
   * @param {string} signedUrl - Presigned URL for PUT request
   * @param {Blob} blob - Blob to upload
   * @param {string} contentType - MIME type of the blob
   * @param {Function} onProgress - Optional progress callback
   * @returns {Promise<void>}
   */
  async uploadToS3(signedUrl, blob, contentType, onProgress = null) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      xhr.open("PUT", signedUrl, true);
      xhr.setRequestHeader("Content-Type", contentType);
      xhr.setRequestHeader("Cache-Control", "max-age=31536000"); // 1 year cache

      if (onProgress) {
        xhr.upload.addEventListener("progress", (e) => {
          if (e.lengthComputable) {
            const percentComplete = (e.loaded / e.total) * 100;
            onProgress(percentComplete);
          }
        });
      }

      xhr.addEventListener("load", () => {
        if (xhr.status === 200) {
          resolve();
        } else {
          reject(new Error(`Upload failed with status ${xhr.status}`));
        }
      });

      xhr.addEventListener("error", () => {
        reject(new Error("Network error during upload"));
      });

      xhr.addEventListener("abort", () => {
        reject(new Error("Upload aborted"));
      });

      xhr.send(blob);
    });
  }

  /**
   * Upload an image blob to S3
   * @param {Uint8Array} imageData - Image data as Uint8Array
   * @param {string} prefix - Filename prefix
   * @param {string} format - Image format (webp, jpg, png)
   * @param {Function} onProgress - Optional progress callback
   * @returns {Promise<string>} - Public URL of uploaded image
   */
  async uploadImage(imageData, prefix, format = "webp", onProgress = null) {
    const filename = this.generateFilename(prefix, format);
    const key = `photos/${filename}`;

    // Get presigned URL
    const { signed_url, public_url } = await this.getPresignedUrl(key);

    // Create blob from image data
    const blob = new Blob([imageData], { type: `image/${format}` });

    // Upload to S3
    await this.uploadToS3(signed_url, blob, `image/${format}`, onProgress);

    return public_url;
  }

  /**
   * Upload both thumbnail and large images
   * @param {Uint8Array} thumbnailData - Thumbnail image data
   * @param {Uint8Array} largeData - Large image data
   * @param {string} format - Image format
   * @param {Function} onProgress - Optional progress callback (receives {thumbnail: number, large: number})
   * @returns {Promise<{thumbnailUrl: string, largeUrl: string}>}
   */
  async uploadBoth(thumbnailData, largeData, format = "webp", onProgress = null) {
    const progress = { thumbnail: 0, large: 0 };

    const updateProgress = () => {
      if (onProgress) {
        onProgress({ ...progress });
      }
    };

    // Upload both in parallel
    const [thumbnailUrl, largeUrl] = await Promise.all([
      this.uploadImage(thumbnailData, "thumb", format, (percent) => {
        progress.thumbnail = percent;
        updateProgress();
      }),
      this.uploadImage(largeData, "large", format, (percent) => {
        progress.large = percent;
        updateProgress();
      }),
    ]);

    return { thumbnailUrl, largeUrl };
  }
}
