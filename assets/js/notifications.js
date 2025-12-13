// Push Notifications Client
// Handles service worker registration and push subscription management
// Based on MDN Web Push API: https://developer.mozilla.org/en-US/docs/Web/API/Push_API

const VAPID_PUBLIC_KEY = window.VAPID_PUBLIC_KEY || '';

// Convert base64 VAPID key to Uint8Array
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

// Register service worker
async function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) {
    console.log('Service workers are not supported');
    return null;
  }

  try {
    const registration = await navigator.serviceWorker.register('/sw.js', {
      scope: '/'
    });
    console.log('Service Worker registered:', registration);
    return registration;
  } catch (error) {
    console.error('Service Worker registration failed:', error);
    return null;
  }
}

// Request notification permission
async function requestNotificationPermission() {
  if (!('Notification' in window)) {
    console.log('Notifications are not supported');
    return false;
  }

  if (Notification.permission === 'granted') {
    return true;
  }

  if (Notification.permission !== 'denied') {
    const permission = await Notification.requestPermission();
    return permission === 'granted';
  }

  return false;
}

// Subscribe to push notifications
async function subscribeToPush(registration) {
  try {
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY)
    });

    console.log('Push subscription created:', subscription);

    // Send subscription to server
    const response = await fetch('/api/notifications/subscribe', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
      },
      body: JSON.stringify({ subscription: subscription.toJSON() })
    });

    if (!response.ok) {
      throw new Error('Failed to send subscription to server');
    }

    console.log('Subscription sent to server');
    return subscription;
  } catch (error) {
    console.error('Failed to subscribe to push:', error);
    return null;
  }
}

// Unsubscribe from push notifications
async function unsubscribeFromPush(registration) {
  try {
    const subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      console.log('No subscription found');
      return true;
    }

    // Unsubscribe on client
    await subscription.unsubscribe();

    // Notify server
    await fetch('/api/notifications/unsubscribe', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
      },
      body: JSON.stringify({ endpoint: subscription.endpoint })
    });

    console.log('Unsubscribed from push');
    return true;
  } catch (error) {
    console.error('Failed to unsubscribe:', error);
    return false;
  }
}

// Check if user is subscribed
async function isSubscribed(registration) {
  const subscription = await registration.pushManager.getSubscription();
  return subscription !== null;
}

// Initialize push notifications
async function initializePushNotifications() {
  // Only initialize if user is logged in (check for presence of notification button)
  if (!document.querySelector('.nav-notification')) {
    return;
  }

  const registration = await registerServiceWorker();
  if (!registration) {
    return;
  }

  // Check if already subscribed
  const subscribed = await isSubscribed(registration);
  console.log('Already subscribed:', subscribed);

  // Auto-subscribe if permission already granted and not subscribed
  if (Notification.permission === 'granted' && !subscribed) {
    await subscribeToPush(registration);
  }
}

// Poll for notification count updates
async function pollNotificationCount() {
  try {
    const response = await fetch('/api/notifications/count', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
      }
    });

    if (!response.ok) {
      console.error('Failed to fetch notification count');
      return;
    }

    const data = await response.json();
    updateNotificationBadges(data.count);
  } catch (error) {
    console.error('Error polling notification count:', error);
  }
}

// Update notification badge elements
function updateNotificationBadges(count) {
  // Update nav bell badge
  const navBadge = document.querySelector('.nav-notification-badge');
  const navNotification = document.querySelector('.nav-notification');

  if (navNotification) {
    if (count > 0) {
      if (navBadge) {
        navBadge.textContent = count;
      } else {
        // Create badge if it doesn't exist
        const newBadge = document.createElement('span');
        newBadge.className = 'nav-notification-badge';
        newBadge.textContent = count;
        navNotification.appendChild(newBadge);
      }
    } else {
      // Remove badge if count is 0
      if (navBadge) {
        navBadge.remove();
      }
    }
  }

  // Update dropdown badge
  const dropdownBadge = document.querySelector('.dropdown-badge');
  const dropdownItem = document.querySelector('.nav-dropdown-item[href="/notifications"]');

  if (dropdownItem) {
    if (count > 0) {
      if (dropdownBadge) {
        dropdownBadge.textContent = count;
      } else {
        // Create badge if it doesn't exist
        const newBadge = document.createElement('span');
        newBadge.className = 'dropdown-badge';
        newBadge.textContent = count;
        dropdownItem.appendChild(newBadge);
      }
    } else {
      // Remove badge if count is 0
      if (dropdownBadge) {
        dropdownBadge.remove();
      }
    }
  }
}

// Start polling for notification count
function startNotificationPolling() {
  // Only poll if user is logged in (check for presence of notification button)
  if (!document.querySelector('.nav-notification')) {
    return;
  }

  // Poll immediately on start
  pollNotificationCount();

  // Then poll every 5 seconds
  setInterval(pollNotificationCount, 5000);
}

// Setup notification bell button handler
function setupNotificationButton() {
  const button = document.querySelector('.nav-notification');
  if (!button) {
    return;
  }

  button.addEventListener('click', async (e) => {
    e.preventDefault();

    const registration = await navigator.serviceWorker.getRegistration();
    if (!registration) {
      console.error('No service worker registration found');
      return;
    }

    const subscribed = await isSubscribed(registration);

    if (!subscribed) {
      const hasPermission = await requestNotificationPermission();
      if (hasPermission) {
        await subscribeToPush(registration);
      }
    }

    // Navigate to notifications page
    window.location.href = '/notifications';
  });
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    initializePushNotifications();
    setupNotificationButton();
    startNotificationPolling();
  });
} else {
  initializePushNotifications();
  setupNotificationButton();
  startNotificationPolling();
}

// Export for manual control if needed
export {
  registerServiceWorker,
  requestNotificationPermission,
  subscribeToPush,
  unsubscribeFromPush,
  isSubscribed,
  pollNotificationCount,
  startNotificationPolling
};
