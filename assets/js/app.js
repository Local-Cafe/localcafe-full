// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";

// Web Components
import "./components/flash-message.js";
import "./components/disclosure.js";

// Simple JS modules (not web components)
import "./dropdown.js";
import "./notifications.js";

// Dynamic imports - only load when needed
// Slug generator component (currently not implemented)
if (document.querySelector("[data-slug-form]")) {
  import("./slug-generator.js").then((module) => {
    module.initSlugGenerator();
  });
}

// Comment navigation (currently not implemented)
if (document.querySelector(".comments-section")) {
  import("./comment-navigation.js").then((module) => {
    module.initCommentNavigation();
  });
}

// Image processor web component (dynamically loaded for photo forms)
if (document.querySelector("image-processor")) {
  import("./image-processor.js").catch((error) => {
    console.error("Failed to load image processor:", error);
  });
}

// Post image manager (for blog post forms)
if (document.querySelector("post-image-manager")) {
  import("./components/post-image-manager.js").catch((error) => {
    console.error("Failed to load post image manager:", error);
  });
}

// Lightbox for image galleries
if (document.querySelector("[data-lightbox]")) {
  import("./lightbox.js").catch((error) => {
    console.error("Failed to load lightbox:", error);
  });
}

// Table of Contents active section highlighter
if (document.querySelector(".table-of-contents")) {
  import("./components/toc-highlighter.js").then((module) => {
    module.initTocHighlighter();
  });
}

// Order form subtotal calculator
if (document.querySelector("[data-order-form]")) {
  import("./order-form.js").then((module) => {
    module.initOrderForm();
  });
}

// Menu item form manager (for admin menu item forms)
if (document.querySelector("#prices-manager") || document.querySelector("#variants-manager")) {
  import("./menu-item-form.js").catch((error) => {
    console.error("Failed to load menu item form manager:", error);
  });
}

// Menu item image slideshow (for menu item show page with multiple images)
if (document.querySelector('.menu-item-detail-image-section[data-slideshow="true"]')) {
  import("./menu-item-gallery.js").catch((error) => {
    console.error("Failed to load menu item slideshow:", error);
  });
}

// Real-time Analytics Dashboard
if (document.querySelector(".admin-analytics")) {
  import("./components/analytics-dashboard.js").then((module) => {
    module.initAnalyticsDashboard();
  });
}

// Hero slideshow
if (document.querySelector(".hero")) {
  import("./hero-slideshow.js").then((module) => {
    module.initHeroSlideshow();
  });
}

// Stripe checkout
if (document.querySelector("#checkout-form")) {
  import("./checkout.js").then((module) => {
    module.initStripeCheckout();
  });
}

// Post purchase (paywall)
if (document.querySelector("#post-purchase-form")) {
  import("./post-purchase.js").then((module) => {
    module.initPostPurchase();
  });
}

// Establish Phoenix Socket and LiveView configuration.
// import { Socket } from "phoenix";
// import { LiveSocket } from "phoenix_live_view";
// import { hooks as colocatedHooks } from "phoenix-colocated/local_cafe";

// const csrfToken = document
//   .querySelector("meta[name='csrf-token']")
//   .getAttribute("content");
// const liveSocket = new LiveSocket("/live", Socket, {
//   longPollFallbackMs: 2500,
//   params: { _csrf_token: csrfToken },
//   hooks: { ...colocatedHooks },
// });

// connect if there are any LiveViews on the page
// liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
// window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true,
      );

      window.liveReloader = reloader;
    },
  );
}
