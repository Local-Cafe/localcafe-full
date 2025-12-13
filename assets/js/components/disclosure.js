/**
 * Disclosure Component
 *
 * Handles <el-disclosure> elements for expandable/collapsible content.
 * Used for mobile menu and other show/hide patterns.
 */

/**
 * Initializes all disclosure components on the page
 */
export function initDisclosures() {
  const disclosures = document.querySelectorAll("[command='--toggle']");
  disclosures.forEach((button) => enhanceDisclosure(button));
}

/**
 * Enhances a disclosure toggle button
 * @param {HTMLElement} button - The toggle button
 */
function enhanceDisclosure(button) {
  const targetId = button.getAttribute("commandfor");
  if (!targetId) {
    console.warn("Disclosure button missing commandfor attribute", button);
    return;
  }

  const target = document.getElementById(targetId);
  if (!target) {
    console.warn(`Disclosure target not found: ${targetId}`, button);
    return;
  }

  // Set initial ARIA attributes
  const isHidden = target.hasAttribute("hidden");
  button.setAttribute("aria-expanded", isHidden ? "false" : "true");
  button.setAttribute("aria-controls", targetId);

  // Toggle on click
  button.addEventListener("click", () => {
    const isExpanded = button.getAttribute("aria-expanded") === "true";

    if (isExpanded) {
      closeDisclosure(button, target);
    } else {
      openDisclosure(button, target);
    }
  });

  // Close on Escape key
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      const isExpanded = button.getAttribute("aria-expanded") === "true";
      if (isExpanded) {
        closeDisclosure(button, target);
        button.focus();
      }
    }
  });
}

/**
 * Opens a disclosure target with animation
 */
function openDisclosure(button, target) {
  button.setAttribute("aria-expanded", "true");
  target.removeAttribute("hidden");

  // Trigger reflow to ensure animation plays
  target.offsetHeight;

  // Add opening class for animation
  target.classList.add("disclosure-opening");
  target.classList.remove("disclosure-closing");

  // Remove opening class after animation completes
  setTimeout(() => {
    target.classList.remove("disclosure-opening");
    target.classList.add("disclosure-open");
  }, 300); // Match CSS transition duration
}

/**
 * Closes a disclosure target with animation
 */
function closeDisclosure(button, target) {
  button.setAttribute("aria-expanded", "false");
  target.classList.add("disclosure-closing");
  target.classList.remove("disclosure-open", "disclosure-opening");

  // Wait for animation to complete before hiding
  setTimeout(() => {
    target.setAttribute("hidden", "");
    target.classList.remove("disclosure-closing");
  }, 300); // Match CSS transition duration
}

/**
 * Observe DOM for new disclosure buttons (for LiveView patches)
 */
export function observeDisclosures() {
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === 1) {
          // Check if the node itself is a disclosure button
          if (node.getAttribute("command") === "--toggle") {
            enhanceDisclosure(node);
          }
          // Also check children
          const buttons = node.querySelectorAll?.("[command='--toggle']");
          buttons?.forEach(enhanceDisclosure);
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
    initDisclosures();
    observeDisclosures();
  });
} else {
  // DOM already loaded
  initDisclosures();
  observeDisclosures();
}
