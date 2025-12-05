/**
 * Theme Toggle
 *
 * Simple theme management that cycles through: system → light → dark → system
 * Syncs with localStorage and listens for storage events across tabs.
 */

const THEMES = ["system", "light", "dark"];
const STORAGE_KEY = "phx:theme";

const THEME_ICONS = {
  light: `
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
      <path d="M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z" stroke-linecap="round" stroke-linejoin="round" />
    </svg>
  `,
  dark: `
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
      <path d="M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z" stroke-linecap="round" stroke-linejoin="round" />
    </svg>
  `,
  system: `
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
      <path d="M9 17.25v1.007a3 3 0 0 1-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0 1 15 18.257V17.25m6-12V15a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 15V5.25m18 0A2.25 2.25 0 0 0 18.75 3H5.25A2.25 2.25 0 0 0 3 5.25m18 0V12a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 12V5.25" stroke-linecap="round" stroke-linejoin="round" />
    </svg>
  `,
};

const THEME_LABELS = {
  light: "Light",
  dark: "Dark",
  system: "System",
};

/**
 * Get current theme from localStorage
 */
function getCurrentTheme() {
  return localStorage.getItem(STORAGE_KEY) || "system";
}

/**
 * Get next theme in the cycle
 */
function getNextTheme(currentTheme) {
  const currentIndex = THEMES.indexOf(currentTheme);
  const nextIndex = (currentIndex + 1) % THEMES.length;
  return THEMES[nextIndex];
}

/**
 * Update a single button's icon and label
 */
function updateButton(button, theme) {
  const icon = button.querySelector(".theme-toggle-icon");
  const labelElement = button.querySelector(".theme-toggle-label");
  const label = THEME_LABELS[theme];

  if (icon) {
    icon.innerHTML = THEME_ICONS[theme];
  }

  // Update label text for mobile variant
  if (labelElement) {
    labelElement.textContent = label;
  }

  button.setAttribute("aria-label", `Toggle theme (current: ${label})`);
  button.setAttribute("title", `Current theme: ${label}`);
}

/**
 * Update all theme toggle buttons on the page
 */
function updateAllButtons(theme) {
  const buttons = document.querySelectorAll(".theme-toggle");
  buttons.forEach((button) => updateButton(button, theme));
}

/**
 * Toggle to the next theme
 */
function toggleTheme() {
  const currentTheme = getCurrentTheme();
  const nextTheme = getNextTheme(currentTheme);

  // Update all buttons immediately for visual feedback
  updateAllButtons(nextTheme);

  // Dispatch the theme change event for the theme script in the head
  window.dispatchEvent(
    new CustomEvent("phx:set-theme", {
      detail: { theme: nextTheme },
      target: { dataset: { phxTheme: nextTheme } },
    })
  );
}

/**
 * Initialize theme toggle functionality
 */
function initThemeToggle() {
  const currentTheme = getCurrentTheme();

  // Update all buttons with current theme
  updateAllButtons(currentTheme);

  // Attach click handlers to all theme toggle buttons
  const buttons = document.querySelectorAll(".theme-toggle");
  buttons.forEach((button) => {
    button.addEventListener("click", toggleTheme);
  });

  // Listen for storage changes from other tabs
  window.addEventListener("storage", (e) => {
    if (e.key === STORAGE_KEY) {
      const newTheme = e.newValue || "system";
      updateAllButtons(newTheme);
    }
  });
}

// Initialize on DOM load
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initThemeToggle);
} else {
  initThemeToggle();
}
