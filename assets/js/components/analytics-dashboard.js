/**
 * Real-time Analytics Dashboard
 * Connects to Phoenix Channel and updates analytics in real-time
 */

import { Socket } from "phoenix";

export function initAnalyticsDashboard() {
  const dashboard = document.querySelector(".admin-analytics");
  if (!dashboard) return;

  // Get CSRF token for socket authentication
  const csrfToken = document
    .querySelector("meta[name='csrf-token']")
    ?.getAttribute("content");

  if (!csrfToken) {
    console.error("CSRF token not found");
    return;
  }

  // Initialize hourly traffic chart
  const chartCanvas = document.getElementById("hourly-traffic-chart");
  let hourlyChart = null;
  if (chartCanvas) {
    hourlyChart = new HourlyTrafficChart(chartCanvas);
  }

  // Create socket connection
  const socket = new Socket("/socket", {
    params: { token: window.userToken },
  });

  socket.connect();

  // Join analytics channel
  const channel = socket.channel("analytics:dashboard", {});

  // Update connection status
  const statusIndicator = document.querySelector(".status-indicator");
  const statusText = document.querySelector(".status-text");

  channel
    .join()
    .receive("ok", (resp) => {
      console.log("Joined analytics channel successfully", resp);
      statusIndicator.className = "status-indicator status-connected";
      statusText.textContent = "Connected";
    })
    .receive("error", (resp) => {
      console.error("Unable to join analytics channel", resp);
      statusIndicator.className = "status-indicator status-error";
      statusText.textContent = "Connection Error";
    });

  // Handle initial state
  channel.on("initial_state", (payload) => {
    updateMetrics(payload);
    updateActivityFeed(payload.activity_buffer);
    updateTopPages(payload.top_pages);
    updateGeographic(payload.geographic);
    updateTopReferrers(payload.top_referrers);
    updateBotCounts(payload.bot_counts);
    updateOSCounts(payload.os_counts);
    updateBrowserCounts(payload.browser_counts);
  });

  // Handle new visit events
  channel.on("new_visit", (payload) => {
    addToActivityFeed(payload);
  });

  // Handle stats updates (real-time, no chart updates)
  channel.on("stats_update", (payload) => {
    updateMetrics(payload);
    updateTopPages(payload.top_pages);
    updateGeographic(payload.geographic);
    updateTopReferrers(payload.top_referrers);
    updateBotCounts(payload.bot_counts);
    updateOSCounts(payload.os_counts);
    updateBrowserCounts(payload.browser_counts);
  });

  // Handle hourly traffic updates (once per minute from ClickHouse)
  channel.on("hourly_traffic_update", (payload) => {
    if (hourlyChart && payload.hourly_traffic) {
      hourlyChart.updateFromCounts(payload.hourly_traffic);
    }
  });

  // Handle disconnection
  socket.onError(() => {
    statusIndicator.className = "status-indicator status-disconnected";
    statusText.textContent = "Disconnected";
  });

  socket.onClose(() => {
    statusIndicator.className = "status-indicator status-disconnected";
    statusText.textContent = "Disconnected";
  });
}

function updateMetrics(data) {
  const lastMinuteCount = document.getElementById("last-minute-count");
  const last30MinutesCount = document.getElementById("last-30-minutes-count");
  const lastHourCount = document.getElementById("last-hour-count");
  const last6HoursCount = document.getElementById("last-6-hours-count");
  const last12HoursCount = document.getElementById("last-12-hours-count");
  const last24HoursCount = document.getElementById("last-24-hours-count");

  if (lastMinuteCount) lastMinuteCount.textContent = data.last_minute_count || 0;
  if (last30MinutesCount) last30MinutesCount.textContent = data.last_30_minutes_count || 0;
  if (lastHourCount) lastHourCount.textContent = data.last_hour_count || 0;
  if (last6HoursCount) last6HoursCount.textContent = data.last_6_hours_count || 0;
  if (last12HoursCount) last12HoursCount.textContent = data.last_12_hours_count || 0;
  if (last24HoursCount) last24HoursCount.textContent = data.last_24_hours_count || 0;
}

function updateActivityFeed(activities) {
  const feed = document.getElementById("activity-feed");
  if (!feed || !activities || activities.length === 0) return;

  // Clear empty state
  feed.innerHTML = "";

  // Populate with activity buffer
  activities.forEach((activity) => {
    const item = document.createElement("div");
    item.className = "activity-item";
    item.innerHTML = createActivityItemHTML(activity);
    feed.appendChild(item);
  });
}

function updateTopPages(pages) {
  const container = document.getElementById("top-pages");
  if (!container || !pages || pages.length === 0) return;

  container.innerHTML = pages
    .map(
      (page) => `
    <div class="page-item">
      <span class="page-path">${escapeHtml(page.path)}</span>
      <span class="page-count">${page.count}</span>
    </div>
  `
    )
    .join("");
}

function updateGeographic(geographic) {
  const container = document.getElementById("geographic-data");
  if (!container || !geographic || geographic.length === 0) return;

  container.innerHTML = geographic
    .map(
      (geo) => `
    <div class="geo-item">
      <span class="geo-country">${escapeHtml(geo.country)}</span>
      <span class="geo-count">${geo.count}</span>
    </div>
  `
    )
    .join("");
}

function updateTopReferrers(referrers) {
  const container = document.getElementById("top-referrers");
  if (!container || !referrers || referrers.length === 0) return;

  container.innerHTML = referrers
    .map(
      (ref) => `
    <div class="referrer-item">
      <a href="${escapeHtml(ref.referrer)}" target="_blank" rel="noopener noreferrer" class="referrer-url">
        ${escapeHtml(shortenUrl(ref.referrer))}
      </a>
      <span class="referrer-count">${ref.count}</span>
    </div>
  `
    )
    .join("");
}

function updateBotCounts(bots) {
  const container = document.getElementById("bot-counts");
  if (!container) return;

  if (!bots || bots.length === 0) {
    container.innerHTML = '<p class="empty-state">No bots detected</p>';
    return;
  }

  container.innerHTML = bots
    .map(
      (bot) => `
    <div class="count-item">
      <span class="count-name">${escapeHtml(bot.name)}</span>
      <span class="count-value">${bot.count}</span>
    </div>
  `
    )
    .join("");
}

function updateOSCounts(oses) {
  const container = document.getElementById("os-counts");
  if (!container) return;

  if (!oses || oses.length === 0) {
    container.innerHTML = '<p class="empty-state">No data yet</p>';
    return;
  }

  container.innerHTML = oses
    .map(
      (os) => `
    <div class="count-item">
      <span class="count-name">${escapeHtml(os.name)}</span>
      <span class="count-value">${os.count}</span>
    </div>
  `
    )
    .join("");
}

function updateBrowserCounts(browsers) {
  const container = document.getElementById("browser-counts");
  if (!container) return;

  if (!browsers || browsers.length === 0) {
    container.innerHTML = '<p class="empty-state">No data yet</p>';
    return;
  }

  container.innerHTML = browsers
    .map(
      (browser) => `
    <div class="count-item">
      <span class="count-name">${escapeHtml(browser.name)}</span>
      <span class="count-value">${browser.count}</span>
    </div>
  `
    )
    .join("");
}

function addToActivityFeed(visit) {
  const feed = document.getElementById("activity-feed");
  if (!feed) return;

  // Remove empty state if present
  const emptyState = feed.querySelector(".empty-state");
  if (emptyState) {
    emptyState.remove();
  }

  const item = document.createElement("div");
  item.className = "activity-item activity-item-new";
  item.innerHTML = createActivityItemHTML(visit);

  // Add to top of feed
  feed.insertBefore(item, feed.firstChild);

  // Remove 'new' class after animation
  setTimeout(() => {
    item.classList.remove("activity-item-new");
  }, 500);

  // Keep only last 50 items
  const items = feed.querySelectorAll(".activity-item");
  if (items.length > 50) {
    items[items.length - 1].remove();
  }
}

function createActivityItemHTML(visit) {
  return `
    <div class="activity-row">
      <span class="activity-label">Path:</span>
      <span class="activity-value">${escapeHtml(visit.path)}</span>
    </div>
    <div class="activity-row">
      <span class="activity-label">Time:</span>
      <span class="activity-value">${formatTime(visit.timestamp)}</span>
    </div>
    ${visit.country && visit.country !== "Unknown" ? `
    <div class="activity-row">
      <span class="activity-label">Country:</span>
      <span class="activity-value">${escapeHtml(visit.country)}</span>
    </div>` : ""}
    ${visit.ip && visit.ip !== "Unknown" ? `
    <div class="activity-row">
      <span class="activity-label">IP:</span>
      <span class="activity-value">${escapeHtml(visit.ip)}</span>
    </div>` : ""}
    ${visit.session_id && visit.session_id !== "Unknown" ? `
    <div class="activity-row">
      <span class="activity-label">Session:</span>
      <span class="activity-value">${escapeHtml(visit.session_id)}</span>
    </div>` : ""}
    ${visit.bot ? `
    <div class="activity-row activity-bot">
      <span class="activity-label">Bot:</span>
      <span class="activity-value">${escapeHtml(visit.bot)}</span>
    </div>` : `
    ${visit.browser && visit.browser !== "Unknown" ? `
    <div class="activity-row">
      <span class="activity-label">Browser:</span>
      <span class="activity-value">${escapeHtml(visit.browser)}</span>
    </div>` : ""}
    ${visit.os && visit.os !== "Unknown" ? `
    <div class="activity-row">
      <span class="activity-label">OS:</span>
      <span class="activity-value">${escapeHtml(visit.os)}</span>
    </div>` : ""}
    ${visit.device && visit.device !== "Unknown" ? `
    <div class="activity-row">
      <span class="activity-label">Device:</span>
      <span class="activity-value">${escapeHtml(visit.device)}</span>
    </div>` : ""}`}
    ${visit.agent && visit.agent !== "" && !visit.bot ? `
    <div class="activity-row activity-agent-raw">
      <span class="activity-label">User Agent:</span>
      <span class="activity-value">${escapeHtml(visit.agent)}</span>
    </div>` : ""}
  `;
}

function formatTime(timestamp) {
  const date = new Date(timestamp);
  return date.toLocaleTimeString();
}

function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

function shortenUrl(url) {
  try {
    const urlObj = new URL(url);
    // Return domain + path (without protocol and query params)
    let shortened = urlObj.hostname + urlObj.pathname;
    if (shortened.length > 50) {
      return shortened.slice(0, 47) + "...";
    }
    return shortened;
  } catch {
    // If URL is invalid, just truncate it
    return url.length > 50 ? url.slice(0, 47) + "..." : url;
  }
}

/**
 * Hourly Traffic Chart
 * Displays a bar chart of unique visitors per minute over the last hour
 */
class HourlyTrafficChart {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");

    // Store counts (60 integers, one per minute)
    this.counts = new Array(60).fill(0);

    // Chart styling
    this.barColor = "#3b82f6";
    this.gridColor = "#e5e7eb";
    this.textColor = "#6b7280";
    this.padding = { top: 20, right: 20, bottom: 30, left: 50 };

    // Set canvas size
    this.resize();
    window.addEventListener("resize", () => this.resize());

    this.draw();
  }

  resize() {
    const container = this.canvas.parentElement;
    const dpr = window.devicePixelRatio || 1;

    // Set display size
    this.canvas.style.width = "100%";
    this.canvas.style.height = "300px";

    // Set actual size in memory (scaled for retina)
    const rect = this.canvas.getBoundingClientRect();
    this.canvas.width = rect.width * dpr;
    this.canvas.height = rect.height * dpr;

    // Scale context to match
    this.ctx.scale(dpr, dpr);

    // Store display dimensions
    this.width = rect.width;
    this.height = rect.height;

    this.draw();
  }

  updateFromCounts(counts) {
    // Update counts from server (60 integers)
    if (counts && counts.length === 60) {
      this.counts = counts;
      this.draw();
    }
  }

  draw() {
    const { ctx, width, height, padding } = this;

    // Clear canvas
    ctx.clearRect(0, 0, width, height);

    // Calculate chart area
    const chartWidth = width - padding.left - padding.right;
    const chartHeight = height - padding.top - padding.bottom;

    // Use counts from server
    const maxCount = Math.max(...this.counts, 1);

    // Calculate Y-axis scale with whole positive integers only
    const step = Math.max(1, Math.ceil(maxCount / 5));
    const displayMax = Math.floor(step * 5);

    // Bar width
    const barWidth = chartWidth / 60;
    const barSpacing = 1;

    // Draw grid lines
    ctx.strokeStyle = this.gridColor;
    ctx.lineWidth = 1;
    for (let i = 0; i <= 5; i++) {
      const y = padding.top + (chartHeight / 5) * i;
      ctx.beginPath();
      ctx.moveTo(padding.left, y);
      ctx.lineTo(padding.left + chartWidth, y);
      ctx.stroke();
    }

    // Draw Y-axis labels
    ctx.fillStyle = this.textColor;
    ctx.font = "11px sans-serif";
    ctx.textAlign = "right";
    ctx.textBaseline = "middle";
    for (let i = 0; i <= 5; i++) {
      const value = Math.floor(displayMax - (step * i));
      const y = padding.top + (chartHeight / 5) * i;
      ctx.fillText(value, padding.left - 10, y);
    }

    // Draw bars (most recent on the left)
    for (let i = 0; i < 60; i++) {
      const count = this.counts[i]; // Left to right: now to -60m
      const barHeight = (count / displayMax) * chartHeight;
      const x = padding.left + i * barWidth;
      const y = padding.top + chartHeight - barHeight;

      ctx.fillStyle = this.barColor;
      ctx.fillRect(
        x + barSpacing / 2,
        y,
        barWidth - barSpacing,
        barHeight
      );
    }

    // Draw X-axis labels (every 10 minutes)
    ctx.fillStyle = this.textColor;
    ctx.textAlign = "center";
    ctx.textBaseline = "top";
    for (let i = 0; i <= 60; i += 10) {
      const x = padding.left + i * barWidth;
      const label = i === 0 ? "now" : `-${i}m`;
      ctx.fillText(label, x, padding.top + chartHeight + 5);
    }
  }
}
