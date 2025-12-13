/**
 * Menu Item Image Slideshow
 *
 * Auto-plays through multiple images with fade transitions.
 * Only runs if there are multiple images.
 */

function initMenuItemSlideshow() {
  const slideshow = document.querySelector('.menu-item-detail-image-section[data-slideshow="true"]');
  if (!slideshow) return;

  const slides = slideshow.querySelectorAll('.menu-item-detail-image');
  if (slides.length <= 1) return;

  let currentIndex = 0;
  const interval = 4000; // 4 seconds per slide

  function showNextSlide() {
    // Remove active class from current slide
    slides[currentIndex].classList.remove('slide-active');

    // Move to next slide (loop back to start)
    currentIndex = (currentIndex + 1) % slides.length;

    // Add active class to new slide
    slides[currentIndex].classList.add('slide-active');
  }

  // Start the slideshow
  setInterval(showNextSlide, interval);
}

// Initialize on page load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initMenuItemSlideshow);
} else {
  initMenuItemSlideshow();
}

// Export for re-initialization if needed
export { initMenuItemSlideshow };
