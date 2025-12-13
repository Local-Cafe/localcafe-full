/**
 * Flash Message Web Component
 *
 * Progressive enhancement for <flash-message> elements.
 * The component works without JS (displays the message) but JS adds:
 * - Close button functionality
 * - Smooth dismissal animation
 * - LiveView flash clearing integration
 */

/**
 * Initializes all flash messages on the page
 */
export function initFlashMessages() {
  const flashMessages = document.querySelectorAll("flash-message");
  flashMessages.forEach((flash) => enhanceFlashMessage(flash));
}

/**
 * Enhances a single flash message element
 * @param {HTMLElement} flash - The flash-message element
 */
function enhanceFlashMessage(flash) {
  // Find the close button in the light DOM
  const closeButton = flash.querySelector(".flash-close");
  if (!closeButton) {
    console.warn("Flash message missing close button", flash);
    return;
  }

  // Add click handler
  closeButton.addEventListener("click", () => {
    dismissFlash(flash);
  });

  // Optional: Auto-dismiss after a timeout (e.g., 5 seconds for info)
  const kind = flash.dataset.kind;
  if (kind === "info") {
    setTimeout(() => {
      dismissFlash(flash);
    }, 5000);
  }
}

/**
 * Dismisses a flash message with animation
 * @param {HTMLElement} flash - The flash-message element to dismiss
 */
function dismissFlash(flash) {
  // Add closing class for exit animation
  flash.classList.add("closing");

  // If LiveView is present, push the clear-flash event
  if (window.liveSocket?.isConnected()) {
    const flashKey = flash.dataset.phxFlashKey;
    if (flashKey) {
      window.liveSocket.execJS(flash, `[["push",{"event":"lv:clear-flash","value":{"key":"${flashKey}"}}]]`);
    }
  }

  // Wait for animation to complete, then remove element
  setTimeout(() => {
    flash.remove();
  }, 200); // Match animation duration in flash.css
}

/**
 * Observe DOM for new flash messages (for LiveView patches)
 */
export function observeFlashMessages() {
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === 1 && node.tagName === "FLASH-MESSAGE") {
          enhanceFlashMessage(node);
        }
      });
    });
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });

  return observer;
}

// Auto-initialize on DOMContentLoaded
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => {
    initFlashMessages();
    observeFlashMessages();
  });
} else {
  // DOM already loaded
  initFlashMessages();
  observeFlashMessages();
}
