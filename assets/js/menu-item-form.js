/**
 * Menu Item Form Manager
 *
 * Handles dynamic management of prices and variants in the menu item form.
 * Uses vanilla JavaScript with semantic HTML and progressive enhancement.
 */

class MenuItemFormManager {
  constructor() {
    this.pricesManager = null;
    this.variantsManager = null;
    this.prices = [];
    this.variants = [];

    this.init();
  }

  init() {
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setup());
    } else {
      this.setup();
    }
  }

  setup() {
    this.pricesManager = document.getElementById('prices-manager');
    this.variantsManager = document.getElementById('variants-manager');

    if (this.pricesManager) {
      this.setupPricesManager();
    }

    if (this.variantsManager) {
      this.setupVariantsManager();
    }
  }

  // ========== Prices Management ==========

  setupPricesManager() {
    const pricesData = this.pricesManager.dataset.prices;
    this.prices = pricesData ? JSON.parse(pricesData) : [];

    const addButton = this.pricesManager.querySelector('.add-price-btn');
    if (addButton) {
      addButton.addEventListener('click', () => this.addPrice());
    }

    this.renderPrices();
  }

  renderPrices() {
    const container = this.pricesManager?.querySelector('.prices-list');
    if (!container) return;

    if (this.prices.length === 0) {
      container.innerHTML = '<p class="empty-state">No prices added yet. Add at least one price.</p>';
      return;
    }

    container.innerHTML = this.prices
      .map((price, idx) => this.createPriceItemHTML(price, idx))
      .join('');

    // Attach event listeners to new elements
    this.prices.forEach((_, idx) => {
      this.attachPriceListeners(idx);
    });

    this.updatePricesInput();
  }

  createPriceItemHTML(price, idx) {
    const amountInDollars = price.amount ? (price.amount / 100).toFixed(2) : '0.00';

    return `
      <div class="price-item" data-index="${idx}">
        <div class="price-item-fields">
          <div class="form-field">
            <label for="price-label-${idx}">Label (optional)</label>
            <input
              type="text"
              id="price-label-${idx}"
              class="price-label-input"
              placeholder="e.g., Small, Large"
              value="${price.label || ''}"
              data-index="${idx}"
            />
            <span class="field-hint">Leave blank for single-price items</span>
          </div>
          <div class="form-field">
            <label for="price-amount-${idx}">Price</label>
            <div class="price-input-wrapper">
              <span class="currency-symbol">$</span>
              <input
                type="number"
                id="price-amount-${idx}"
                class="price-amount-input"
                placeholder="0.00"
                value="${amountInDollars}"
                step="0.01"
                min="0"
                data-index="${idx}"
              />
            </div>
          </div>
        </div>
        <button
          type="button"
          class="btn-remove remove-price-btn"
          data-index="${idx}"
          aria-label="Remove price"
        >
          Remove
        </button>
      </div>
    `;
  }

  attachPriceListeners(idx) {
    const labelInput = this.pricesManager.querySelector(`.price-label-input[data-index="${idx}"]`);
    const amountInput = this.pricesManager.querySelector(`.price-amount-input[data-index="${idx}"]`);
    const removeBtn = this.pricesManager.querySelector(`.remove-price-btn[data-index="${idx}"]`);

    if (labelInput) {
      labelInput.addEventListener('input', (e) => {
        this.prices[idx].label = e.target.value || null;
        this.updatePricesInput();
      });
    }

    if (amountInput) {
      amountInput.addEventListener('input', (e) => {
        const dollars = parseFloat(e.target.value) || 0;
        this.prices[idx].amount = Math.round(dollars * 100);
        this.updatePricesInput();
      });
    }

    if (removeBtn) {
      removeBtn.addEventListener('click', () => this.removePrice(idx));
    }
  }

  addPrice() {
    this.prices.push({
      label: null,
      amount: 0,
      position: this.prices.length
    });
    this.renderPrices();
  }

  removePrice(idx) {
    this.prices.splice(idx, 1);
    // Reindex positions
    this.prices.forEach((p, i) => p.position = i);
    this.renderPrices();
  }

  updatePricesInput() {
    const input = document.getElementById('menu_item_prices');
    if (input) {
      input.value = JSON.stringify(this.prices);
    }
  }

  // ========== Variants Management ==========

  setupVariantsManager() {
    const variantsData = this.variantsManager.dataset.variants;
    this.variants = variantsData ? JSON.parse(variantsData) : [];

    const addButton = this.variantsManager.querySelector('.add-variant-btn');
    if (addButton) {
      addButton.addEventListener('click', () => this.addVariant());
    }

    this.renderVariants();
  }

  renderVariants() {
    const container = this.variantsManager?.querySelector('.variants-list');
    if (!container) return;

    if (this.variants.length === 0) {
      container.innerHTML = '<p class="empty-state">No variants added yet. Variants are optional.</p>';
      return;
    }

    container.innerHTML = this.variants
      .map((variant, idx) => this.createVariantItemHTML(variant, idx))
      .join('');

    // Attach event listeners to new elements
    this.variants.forEach((_, idx) => {
      this.attachVariantListeners(idx);
    });

    this.updateVariantsInput();
  }

  createVariantItemHTML(variant, idx) {
    const priceInDollars = variant.price ? (variant.price / 100).toFixed(2) : '0.00';

    return `
      <div class="variant-item" data-index="${idx}">
        <div class="variant-item-fields">
          <div class="form-field">
            <label for="variant-name-${idx}">Name</label>
            <input
              type="text"
              id="variant-name-${idx}"
              class="variant-name-input"
              placeholder="e.g., Extra Cheese, No Onion"
              value="${variant.name || ''}"
              data-index="${idx}"
            />
          </div>
          <div class="form-field">
            <label for="variant-price-${idx}">Price</label>
            <div class="price-input-wrapper">
              <span class="currency-symbol">$</span>
              <input
                type="number"
                id="variant-price-${idx}"
                class="variant-price-input"
                placeholder="0.00"
                value="${priceInDollars}"
                step="0.01"
                min="0"
                data-index="${idx}"
              />
            </div>
            <span class="field-hint">Set to $0.00 for free options</span>
          </div>
        </div>
        <button
          type="button"
          class="btn-remove remove-variant-btn"
          data-index="${idx}"
          aria-label="Remove variant"
        >
          Remove
        </button>
      </div>
    `;
  }

  attachVariantListeners(idx) {
    const nameInput = this.variantsManager.querySelector(`.variant-name-input[data-index="${idx}"]`);
    const priceInput = this.variantsManager.querySelector(`.variant-price-input[data-index="${idx}"]`);
    const removeBtn = this.variantsManager.querySelector(`.remove-variant-btn[data-index="${idx}"]`);

    if (nameInput) {
      nameInput.addEventListener('input', (e) => {
        this.variants[idx].name = e.target.value;
        this.updateVariantsInput();
      });
    }

    if (priceInput) {
      priceInput.addEventListener('input', (e) => {
        const dollars = parseFloat(e.target.value) || 0;
        this.variants[idx].price = Math.round(dollars * 100);
        this.updateVariantsInput();
      });
    }

    if (removeBtn) {
      removeBtn.addEventListener('click', () => this.removeVariant(idx));
    }
  }

  addVariant() {
    this.variants.push({
      name: '',
      price: 0,
      position: this.variants.length
    });
    this.renderVariants();
  }

  removeVariant(idx) {
    this.variants.splice(idx, 1);
    // Reindex positions
    this.variants.forEach((v, i) => v.position = i);
    this.renderVariants();
  }

  updateVariantsInput() {
    const input = document.getElementById('menu_item_variants');
    if (input) {
      input.value = JSON.stringify(this.variants);
    }
  }
}

// Initialize when script loads
new MenuItemFormManager();
