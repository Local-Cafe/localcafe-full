/**
 * Dropdown Menu
 *
 * Simple dropdown functionality for navigation menus.
 * Works with regular HTML elements using data attributes.
 * Handles keyboard navigation, intelligent positioning, and click-outside-to-close.
 */

/**
 * Initialize all dropdowns on the page
 */
function initDropdowns() {
  const dropdowns = document.querySelectorAll("[data-dropdown]");
  dropdowns.forEach((dropdown) => enhanceDropdown(dropdown));
}

/**
 * Enhance a single dropdown element
 */
function enhanceDropdown(dropdown) {
  const button = dropdown.querySelector("[data-dropdown-button]");
  const menu = dropdown.querySelector("[data-dropdown-menu]");

  if (!button || !menu) {
    console.warn("Dropdown missing button or menu", { dropdown });
    return;
  }

  // Set initial ARIA attributes
  button.setAttribute("aria-haspopup", "true");
  button.setAttribute("aria-expanded", "false");
  menu.setAttribute("role", "menu");
  menu.setAttribute("data-closed", "");

  // Toggle dropdown on button click
  button.addEventListener("click", (e) => {
    e.stopPropagation();
    const isOpen = button.getAttribute("aria-expanded") === "true";

    if (isOpen) {
      closeDropdown(button, menu);
    } else {
      // Close any other open dropdowns first
      closeAllDropdowns();
      openDropdown(button, menu);
    }
  });

  // Close dropdown when clicking outside
  document.addEventListener("click", (e) => {
    if (!dropdown.contains(e.target)) {
      closeDropdown(button, menu);
    }
  });

  // Close dropdown on Escape key
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      const isOpen = button.getAttribute("aria-expanded") === "true";
      if (isOpen) {
        closeDropdown(button, menu);
        button.focus();
      }
    }
  });

  // Reposition menu on window resize if open
  window.addEventListener("resize", () => {
    const isOpen = button.getAttribute("aria-expanded") === "true";
    if (isOpen) {
      positionMenu(button, menu);
    }
  });

  // Handle keyboard navigation within menu
  menu.addEventListener("keydown", (e) => {
    const menuItems = Array.from(menu.querySelectorAll("a, button"));
    const currentIndex = menuItems.indexOf(document.activeElement);

    switch (e.key) {
      case "ArrowDown":
        e.preventDefault();
        const nextIndex = (currentIndex + 1) % menuItems.length;
        menuItems[nextIndex]?.focus();
        break;
      case "ArrowUp":
        e.preventDefault();
        const prevIndex =
          currentIndex <= 0 ? menuItems.length - 1 : currentIndex - 1;
        menuItems[prevIndex]?.focus();
        break;
      case "Home":
        e.preventDefault();
        menuItems[0]?.focus();
        break;
      case "End":
        e.preventDefault();
        menuItems[menuItems.length - 1]?.focus();
        break;
    }
  });
}

/**
 * Open a dropdown menu
 */
function openDropdown(button, menu) {
  button.setAttribute("aria-expanded", "true");
  menu.removeAttribute("hidden");

  // Position the menu intelligently based on available space
  positionMenu(button, menu);

  // Trigger animation by removing data-closed on next frame
  requestAnimationFrame(() => {
    menu.removeAttribute("data-closed");
  });

  // Focus first menu item after animation
  setTimeout(() => {
    const firstItem = menu.querySelector("a, button");
    firstItem?.focus();
  }, 10);
}

/**
 * Position a dropdown menu intelligently based on viewport space
 */
function positionMenu(button, menu) {
  const buttonRect = button.getBoundingClientRect();
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;

  const menuRect = menu.getBoundingClientRect();
  const menuWidth = menuRect.width || 192; // 12rem default
  const menuHeight = menuRect.height || 200; // estimate

  // Calculate space on each side
  const spaceRight = viewportWidth - buttonRect.right;
  const spaceBottom = viewportHeight - buttonRect.bottom;
  const spaceTop = buttonRect.top;

  // Reset positioning classes
  menu.classList.remove("menu-left", "menu-right", "menu-top", "menu-bottom");

  // Horizontal positioning - check if button is on the right side
  const isRightSide = buttonRect.right > viewportWidth / 2;

  if (isRightSide && spaceRight < menuWidth) {
    // Align menu's right edge with button's right edge
    menu.classList.add("menu-left");
  } else if (isRightSide) {
    // Default right alignment for right side
    menu.classList.add("menu-left");
  } else {
    // Default left alignment for left side
    menu.classList.add("menu-right");
  }

  // Vertical positioning
  if (spaceBottom < menuHeight && spaceTop > menuHeight) {
    menu.classList.add("menu-top");
  } else {
    menu.classList.add("menu-bottom");
  }
}

/**
 * Close a dropdown menu
 */
function closeDropdown(button, menu) {
  button.setAttribute("aria-expanded", "false");
  menu.setAttribute("data-closed", "");

  // Wait for animation to complete before hiding
  setTimeout(() => {
    if (menu.hasAttribute("data-closed")) {
      menu.setAttribute("hidden", "");
    }
  }, 100); // Match transition duration
}

/**
 * Close all open dropdowns
 */
function closeAllDropdowns() {
  const dropdowns = document.querySelectorAll("[data-dropdown]");
  dropdowns.forEach((dropdown) => {
    const button = dropdown.querySelector("[data-dropdown-button]");
    const menu = dropdown.querySelector("[data-dropdown-menu]");
    if (button && menu) {
      closeDropdown(button, menu);
    }
  });
}

// Initialize on DOM load
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initDropdowns);
} else {
  initDropdowns();
}
