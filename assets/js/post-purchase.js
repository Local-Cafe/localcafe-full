/**
 * Post Purchase (Paywall) Integration
 * Handles one-time post purchase payments using Stripe Payment Element
 */

import { loadStripe } from '@stripe/stripe-js';

export async function initPostPurchase() {
  const publishableKeyEl = document.getElementById('stripe-publishable-key');
  const postDataEl = document.getElementById('post-data');
  const initButton = document.getElementById('initialize-purchase-button');
  const paymentFormContainer = document.getElementById('payment-form-container');
  const form = document.getElementById('post-purchase-form');
  const errorContainer = document.getElementById('payment-errors');

  if (!publishableKeyEl || !postDataEl || !initButton || !form) {
    console.error('Required elements not found');
    return;
  }

  const publishableKey = publishableKeyEl.dataset.key;
  const postId = postDataEl.dataset.postId;
  const postSlug = postDataEl.dataset.postSlug;
  const postPrice = parseFloat(postDataEl.dataset.postPrice);

  if (!publishableKey) {
    console.error('No Stripe publishable key found');
    return;
  }

  let stripe;
  let elements;
  let clientSecret;

  // Initialize purchase when button is clicked
  initButton.addEventListener('click', async () => {
    setInitializing(true);

    try {
      // Create payment intent
      const response = await fetch(`/posts/${postSlug}/purchase/initialize`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content'),
        },
        body: JSON.stringify({ post_id: postId }),
      });

      const data = await response.json();

      if (data.error) {
        showError(data.error);
        setInitializing(false);
        return;
      }

      clientSecret = data.client_secret;

      // Initialize Stripe
      stripe = await loadStripe(publishableKey);

      // Create Stripe Elements instance
      elements = stripe.elements({
        clientSecret: clientSecret,
        appearance: {
          theme: 'stripe',
          variables: {
            colorPrimary: '#0066cc',
            fontFamily: 'system-ui, -apple-system, sans-serif',
          }
        }
      });

      // Create and mount the Payment Element
      const paymentElement = elements.create('payment');
      paymentElement.mount('#payment-element');

      // Show payment form, hide initialize button
      initButton.style.display = 'none';
      paymentFormContainer.style.display = 'block';

    } catch (error) {
      console.error('Error initializing purchase:', error);
      showError('There was an error initializing the purchase. Please try again.');
      setInitializing(false);
    }
  });

  // Handle form submission
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    if (!stripe || !elements) {
      showError('Payment not initialized. Please refresh and try again.');
      return;
    }

    setLoading(true);

    // Confirm the payment with Stripe
    const { error, paymentIntent } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: window.location.origin + `/posts/${postSlug}`,
      },
      redirect: 'if_required',
    });

    if (error) {
      // Payment failed - show error message
      showError(error.message);
      setLoading(false);
    } else if (paymentIntent && paymentIntent.status === 'succeeded') {
      // Payment succeeded - complete the purchase on server
      completePurchase(paymentIntent.id);
    } else {
      // Payment requires additional action or is processing
      showError('Payment is being processed. Please wait...');
      setLoading(false);
    }
  });

  // Complete purchase on server
  async function completePurchase(paymentIntentId) {
    try {
      const response = await fetch(`/posts/${postSlug}/purchase/complete`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content'),
        },
        body: JSON.stringify({
          payment_intent_id: paymentIntentId,
          post_id: postId,
        }),
      });

      // Check if server redirected (successful purchase)
      if (response.redirected) {
        window.location.href = response.url;
        return;
      }

      // Check content type before parsing JSON
      const contentType = response.headers.get('content-type');
      if (contentType && contentType.includes('application/json')) {
        const data = await response.json();

        if (data.error) {
          showError(data.error);
          setLoading(false);
        } else if (data.redirect_url) {
          window.location.href = data.redirect_url;
        }
      } else {
        // Non-JSON response - likely a redirect we should follow
        window.location.reload();
      }

    } catch (error) {
      console.error('Error completing purchase:', error);
      showError('There was an error completing your purchase. Please contact support.');
      setLoading(false);
    }
  }

  // Show error message
  function showError(message) {
    errorContainer.textContent = message;
    errorContainer.style.display = 'block';

    setTimeout(() => {
      errorContainer.style.display = 'none';
      errorContainer.textContent = '';
    }, 5000);
  }

  // Show/hide initializing state
  function setInitializing(isInitializing) {
    initButton.disabled = isInitializing;
    initButton.textContent = isInitializing ? 'Initializing...' : 'Proceed to Purchase';
  }

  // Show/hide loading state on submit button
  function setLoading(isLoading) {
    const submitButton = document.querySelector('#submit-button');
    const btnText = document.querySelector('#btn-text');
    const btnSpinner = document.querySelector('#btn-spinner');

    if (isLoading) {
      submitButton.disabled = true;
      btnText.style.display = 'none';
      btnSpinner.style.display = 'inline-block';
    } else {
      submitButton.disabled = false;
      btnText.style.display = 'inline';
      btnSpinner.style.display = 'none';
    }
  }
}
