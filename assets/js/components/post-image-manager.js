/**
 * Post Image Manager Component
 *
 * Manages multiple images for blog posts with:
 * - Single shared image-processor that opens on "Add Image"
 * - Automatically creates image rows when upload completes
 * - Drag-and-drop reordering
 * - Primary image selection
 */

class PostImageManager extends HTMLElement {
  constructor() {
    super();
    this.images = [];
    this.draggedElement = null;
    this.formName = this.getAttribute('form-name') || 'post';
    this.maxImages = parseInt(this.getAttribute('max-images')) || null;
    this.showUploader = false;
  }

  connectedCallback() {
    this.render();
    this.attachEventListeners();
    this.loadExistingImages();
  }

  loadExistingImages() {
    // Load existing images from hidden fields if editing
    const existingData = this.getAttribute('images-data');
    if (existingData) {
      try {
        const parsed = JSON.parse(existingData);
        // Filter out any images without URLs and add IDs for UI management
        this.images = parsed
          .filter(img => img.full_url && img.thumb_url)
          .map((img, index) => ({
            ...img,
            id: img.id || `img-existing-${Date.now()}-${index}`
          }));
        this.render();
      } catch (e) {
        console.error('Failed to parse existing images:', e);
      }
    }
  }

  async showImageUploader() {
    this.showUploader = true;
    this.render();

    // Dynamically import the image-processor component if not already loaded
    if (!customElements.get('image-processor')) {
      try {
        await import('../image-processor.js');
      } catch (error) {
        console.error('Failed to load image processor:', error);
        return;
      }
    }

    // Focus on the image processor after render
    setTimeout(() => {
      const processor = this.querySelector('image-processor');
      if (processor) {
        processor.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      }
    }, 100);
  }

  hideImageUploader() {
    this.showUploader = false;
    this.render();
  }

  addImageFromUpload(fullUrl, thumbUrl) {
    const newImage = {
      id: `img-${Date.now()}`,
      full_url: fullUrl,
      thumb_url: thumbUrl,
      position: this.images.length,
      is_primary: this.images.length === 0 // First image is primary by default
    };
    this.images.push(newImage);
    this.updateHiddenFields();
    this.hideImageUploader();
  }

  removeImage(id) {
    const index = this.images.findIndex(img => img.id === id);
    if (index === -1) return;

    const wasPrimary = this.images[index].is_primary;
    this.images.splice(index, 1);

    // If we removed the primary image, make the first one primary
    if (wasPrimary && this.images.length > 0) {
      this.images[0].is_primary = true;
    }

    this.updatePositions();
    this.render();
  }

  setPrimary(id) {
    this.images.forEach(img => {
      img.is_primary = img.id === id;
    });
    this.render();
  }

  updatePositions() {
    this.images.forEach((img, index) => {
      img.position = index;
    });
  }

  updateHiddenFields() {
    // Update the hidden field with all image data
    const hiddenField = this.querySelector('input[name$="[images]"]');
    if (hiddenField) {
      hiddenField.value = JSON.stringify(this.images);
    }
  }

  attachEventListeners() {
    this.addEventListener('click', (e) => {
      if (e.target.matches('[data-action="add-image"]')) {
        this.showImageUploader();
      } else if (e.target.matches('[data-action="remove-image"]')) {
        const id = e.target.closest('[data-image-id]').dataset.imageId;
        this.removeImage(id);
      } else if (e.target.matches('[data-action="set-primary"]')) {
        const id = e.target.closest('[data-image-id]').dataset.imageId;
        this.setPrimary(id);
      } else if (e.target.matches('[data-action="cancel-upload"]')) {
        this.hideImageUploader();
      }
    });

    // Drag event delegation - attach once to the component
    this.addEventListener('dragstart', (e) => {
      const imageRow = e.target.closest('[data-image-id]');
      if (imageRow) {
        this.handleDragStart(e);
      }
    });

    this.addEventListener('dragend', (e) => {
      const imageRow = e.target.closest('[data-image-id]');
      if (imageRow) {
        this.handleDragEnd();
      }
    });

    this.addEventListener('dragover', (e) => {
      const container = e.target.closest('.images-list');
      if (container && this.draggedElement) {
        this.handleDragOver(e);
      }
    });

    // Listen for custom events from image-processor component
    this.addEventListener('image-uploaded', (e) => {
      const { fullUrl, thumbUrl } = e.detail;
      this.addImageFromUpload(fullUrl, thumbUrl);
    });
  }

  handleDragStart(e) {
    this.draggedElement = e.target.closest('[data-image-id]');
    e.dataTransfer.effectAllowed = 'move';
    this.draggedElement.classList.add('dragging');
  }

  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';

    const afterElement = this.getDragAfterElement(e.clientY);
    const draggable = this.draggedElement;
    const container = this.querySelector('.images-list');

    if (afterElement) {
      container.insertBefore(draggable, afterElement);
    } else {
      container.appendChild(draggable);
    }
  }

  handleDragEnd() {
    if (this.draggedElement) {
      this.draggedElement.classList.remove('dragging');
    }

    // Update positions based on new DOM order
    // Query only within the images-list container to avoid duplicates
    const container = this.querySelector('.images-list');
    if (!container) return;

    const imageElements = container.querySelectorAll('[data-image-id]');
    const newOrder = [];
    const seenIds = new Set();

    imageElements.forEach((el, index) => {
      const id = el.dataset.imageId;

      // Skip if we've already processed this ID (prevents duplicates)
      if (seenIds.has(id)) {
        console.warn(`Duplicate image ID found: ${id}`);
        return;
      }
      seenIds.add(id);

      const image = this.images.find(img => img.id === id);
      if (image) {
        image.position = index;
        newOrder.push(image);
      }
    });

    this.images = newOrder;
    this.updateHiddenFields();
    this.draggedElement = null;
  }

  getDragAfterElement(y) {
    const container = this.querySelector('.images-list');
    if (!container) return null;

    const draggableElements = [...container.querySelectorAll('[data-image-id]:not(.dragging)')];

    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect();
      const offset = y - box.top - box.height / 2;

      if (offset < 0 && offset > closest.offset) {
        return { offset, element: child };
      } else {
        return closest;
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element;
  }

  render() {
    const canAddMore = !this.maxImages || this.images.length < this.maxImages;
    const headerTitle = this.maxImages === 1 ? 'Location Image' : 'Blog Post Images';

    this.innerHTML = `
      <div class="post-image-manager">
        <div class="manager-header">
          <h3>${headerTitle}</h3>
          ${canAddMore ? `
            <button type="button" class="btn-add-image" data-action="add-image">
              + Add Image
            </button>
          ` : ''}
        </div>

        ${this.showUploader ? `
          <div class="image-uploader-panel">
            <div class="uploader-header">
              <h4>Upload New Image</h4>
              <button type="button" class="btn-cancel" data-action="cancel-upload">
                Cancel
              </button>
            </div>
            <image-processor></image-processor>
          </div>
        ` : ''}

        <div class="images-list">
          ${this.images.map(img => this.renderImageRow(img)).join('')}
        </div>

        <!-- Hidden field to store all image data -->
        <input
          type="hidden"
          name="${this.formName}[images]"
          value='${JSON.stringify(this.images)}'
        />
      </div>
    `;

    // Set draggable attribute on image rows (event listeners are handled via delegation)
    // Skip if in single-image mode
    if (!this.maxImages || this.maxImages > 1) {
      this.querySelectorAll('[data-image-id]').forEach(el => {
        el.setAttribute('draggable', 'true');
      });
    }
  }

  renderImageRow(img) {
    const isSingleImageMode = this.maxImages === 1;

    return `
      <div class="image-row" data-image-id="${img.id}">
        ${!isSingleImageMode ? `
          <div class="drag-handle" title="Drag to reorder">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
              <circle cx="5" cy="5" r="1.5"/>
              <circle cx="15" cy="5" r="1.5"/>
              <circle cx="5" cy="10" r="1.5"/>
              <circle cx="15" cy="10" r="1.5"/>
              <circle cx="5" cy="15" r="1.5"/>
              <circle cx="15" cy="15" r="1.5"/>
            </svg>
          </div>
        ` : ''}

        <div class="image-preview">
          <img src="${img.thumb_url}" alt="Image ${img.position + 1}" />
        </div>

        <div class="image-content">
          ${!isSingleImageMode && img.is_primary ? '<span class="primary-badge">Primary</span>' : ''}

          <div class="image-actions">
            ${!isSingleImageMode ? `
              <label class="primary-checkbox">
                <input
                  type="radio"
                  name="primary_image"
                  value="${img.id}"
                  ${img.is_primary ? 'checked' : ''}
                  data-action="set-primary"
                />
                <span>Set as Primary</span>
              </label>
            ` : ''}
            <button
              type="button"
              class="btn-remove"
              data-action="remove-image"
              title="Remove image"
            >
              Remove
            </button>
          </div>
        </div>
      </div>
    `;
  }
}

customElements.define('post-image-manager', PostImageManager);
