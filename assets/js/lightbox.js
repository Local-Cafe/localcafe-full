/**
 * Simple Lightbox for viewing images
 *
 * Usage: Add data-lightbox attribute to images
 */

class Lightbox {
  constructor() {
    this.currentImage = null;
    this.overlay = null;
    this.createOverlay();
    this.attachEventListeners();
  }

  createOverlay() {
    this.overlay = document.createElement('div');
    this.overlay.className = 'lightbox-overlay';
    this.overlay.innerHTML = `
      <div class="lightbox-container">
        <button class="lightbox-close" aria-label="Close lightbox">&times;</button>
        <img class="lightbox-image" src="" alt="">
      </div>
    `;
    document.body.appendChild(this.overlay);
  }

  attachEventListeners() {
    // Close on overlay click
    this.overlay.addEventListener('click', (e) => {
      if (e.target === this.overlay || e.target.matches('.lightbox-close')) {
        this.close();
      }
    });

    // Close on escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.overlay.classList.contains('active')) {
        this.close();
      }
    });

    // Delegate click events for lightbox triggers
    document.addEventListener('click', (e) => {
      const trigger = e.target.closest('[data-lightbox]');
      if (trigger) {
        e.preventDefault();
        const imageSrc = trigger.dataset.lightbox || trigger.src || trigger.href;
        const imageAlt = trigger.alt || trigger.dataset.lightboxAlt || 'Image';
        this.open(imageSrc, imageAlt);
      }
    });
  }

  open(src, alt = 'Image') {
    const img = this.overlay.querySelector('.lightbox-image');
    img.src = src;
    img.alt = alt;
    this.overlay.classList.add('active');
    document.body.style.overflow = 'hidden';
  }

  close() {
    this.overlay.classList.remove('active');
    document.body.style.overflow = '';
  }
}

// Initialize lightbox when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => new Lightbox());
} else {
  new Lightbox();
}

export function initLightbox() {
  // Exported for consistency with other modules
  // Actual initialization happens above
}
