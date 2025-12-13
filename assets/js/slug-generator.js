/**
 * Slug Generator
 *
 * Auto-generates URL-friendly slugs from title input fields.
 * Users can manually edit the slug field at any time.
 */

function slugify(text) {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, '') // Remove special characters
    .replace(/\s+/g, '-')      // Replace spaces with hyphens
    .replace(/-+/g, '-')       // Replace multiple hyphens with single hyphen
    .replace(/^-+|-+$/g, '');  // Trim hyphens from start/end
}

export function initSlugGenerator() {
  // Find all forms with slug generation
  const forms = document.querySelectorAll('[data-slug-form]');

  forms.forEach(form => {
    const titleInput = form.querySelector('[data-slug-source]');
    const slugInput = form.querySelector('[data-slug-target]');

    if (!titleInput || !slugInput) return;

    let manuallyEdited = false;

    // Check if slug was manually edited
    slugInput.addEventListener('input', () => {
      manuallyEdited = true;
    });

    // Generate slug from title
    titleInput.addEventListener('input', () => {
      // Only auto-generate if user hasn't manually edited the slug
      if (!manuallyEdited) {
        slugInput.value = slugify(titleInput.value);
      }
    });

    // If slug is empty on load and title has value, generate initial slug
    if (!slugInput.value && titleInput.value) {
      slugInput.value = slugify(titleInput.value);
    }
  });
}
