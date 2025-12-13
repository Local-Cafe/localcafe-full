/**
 * Order Form - Dynamic subtotal calculation
 *
 * Calculates and updates the order subtotal based on:
 * - Selected price option (if multiple)
 * - Selected variant options
 */

function initOrderForm() {
  const form = document.querySelector('[data-order-form]');
  if (!form) return;

  const subtotalDisplay = form.querySelector('[data-subtotal]');
  if (!subtotalDisplay) return;

  // Calculate and update subtotal
  function updateSubtotal() {
    let subtotal = 0;

    // Get selected base price
    const selectedPriceRadio = form.querySelector('[data-price-radio]:checked');
    if (selectedPriceRadio) {
      subtotal += parseInt(selectedPriceRadio.dataset.amount || 0);
    } else {
      // If no radio buttons (single price), get the base price from hidden input
      const hiddenPrice = form.querySelector('input[name="cart[price_index]"]');
      if (hiddenPrice && hiddenPrice.dataset.basePrice) {
        subtotal = parseInt(hiddenPrice.dataset.basePrice);
      }
    }

    // Add selected variant prices
    const selectedVariants = form.querySelectorAll('[data-variant-checkbox]:checked');
    selectedVariants.forEach(checkbox => {
      subtotal += parseInt(checkbox.dataset.price || 0);
    });

    // Format and display
    const formatted = (subtotal / 100).toFixed(2);
    subtotalDisplay.textContent = `$${formatted}`;
  }

  // Listen for price selection changes
  const priceRadios = form.querySelectorAll('[data-price-radio]');
  priceRadios.forEach(radio => {
    radio.addEventListener('change', updateSubtotal);
  });

  // Listen for variant selection changes
  const variantCheckboxes = form.querySelectorAll('[data-variant-checkbox]');
  variantCheckboxes.forEach(checkbox => {
    checkbox.addEventListener('change', updateSubtotal);
  });

  // Initial calculation
  updateSubtotal();
}

// Initialize on page load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initOrderForm);
} else {
  initOrderForm();
}

// Re-initialize on navigation (for single-page app behavior)
export { initOrderForm };
