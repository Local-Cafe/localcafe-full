/**
 * Hero Slideshow
 * Simple JavaScript-based slideshow for hero images and taglines
 */

export function initHeroSlideshow() {
  const hero = document.querySelector('.hero');
  if (!hero) return;

  const slides = hero.querySelectorAll('.hero-slide');
  const taglines = hero.querySelectorAll('.hero-tagline-animated');

  // Only run slideshow if there are multiple slides
  if (slides.length <= 1) return;

  let currentIndex = 0;
  const slideInterval = 5000; // 5 seconds per slide
  const fadeDuration = 600; // 600ms fade transition

  // Show first slide immediately
  if (slides[0]) slides[0].style.opacity = '1';
  if (taglines[0]) taglines[0].style.opacity = '1';

  function showSlide(index) {
    // Fade out all slides and taglines
    slides.forEach(slide => {
      slide.style.opacity = '0';
    });
    taglines.forEach(tagline => {
      tagline.style.opacity = '0';
    });

    // Fade in the current slide and tagline
    if (slides[index]) {
      slides[index].style.opacity = '1';
    }
    if (taglines[index]) {
      taglines[index].style.opacity = '1';
    }
  }

  function nextSlide() {
    currentIndex = (currentIndex + 1) % slides.length;
    showSlide(currentIndex);
  }

  // Start the slideshow
  setInterval(nextSlide, slideInterval);
}
