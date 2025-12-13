/**
 * Stripe Checkout Integration
 * Handles payment processing using Stripe Payment Element
 */

import { loadStripe } from '@stripe/stripe-js';

export async function initStripeCheckout() {
  const form = document.getElementById('checkout-form');
  if (!form) return;

  const clientSecret = form.dataset.clientSecret;
  if (!clientSecret) {
    console.error('No client secret found');
    return;
  }

  // Initialize Stripe (using npm package)
  const stripe = await loadStripe(window.stripePublishableKey);

  // Create Stripe Elements instance
  const elements = stripe.elements({
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

  // Handle form submission
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    setLoading(true);

    // Confirm the payment with Stripe
    const { error, paymentIntent } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: window.location.origin + '/checkout/complete',
      },
      redirect: 'if_required',
    });

    if (error) {
      // Payment failed - show error message
      showMessage(error.message);
      setLoading(false);
    } else if (paymentIntent && paymentIntent.status === 'succeeded') {
      // Payment succeeded - submit the form to create the order
      submitOrder(paymentIntent.id);
    } else {
      // Payment requires additional action or is processing
      showMessage('Payment is being processed. Please wait...');
      setLoading(false);
    }
  });

  // Submit order to server
  function submitOrder(paymentIntentId) {
    // Get form data
    const formData = new FormData(form);
    formData.append('payment_intent_id', paymentIntentId);

    // Get CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');

    // Submit to server
    fetch('/checkout', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': csrfToken,
      },
      body: formData,
    })
      .then(response => {
        // If server redirected (successful order), navigate to the redirect URL
        if (response.redirected) {
          window.location.href = response.url;
          return null;
        }

        // Check content type before parsing JSON
        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('application/json')) {
          return response.json();
        }

        // Non-JSON response without redirect - something unexpected
        return null;
      })
      .then(data => {
        if (data && data.error) {
          showMessage(data.error);
          setLoading(false);
        }
      })
      .catch(error => {
        console.error('Error submitting order:', error);
        showMessage('There was an error processing your order. Please try again.');
        setLoading(false);
      });
  }

  // Show a message to the customer
  function showMessage(messageText) {
    const messageContainer = document.querySelector('#payment-message');
    messageContainer.classList.remove('hidden');
    messageContainer.textContent = messageText;

    setTimeout(() => {
      messageContainer.classList.add('hidden');
      messageContainer.textContent = '';
    }, 5000);
  }

  // Show/hide loading state on submit button
  function setLoading(isLoading) {
    const submitButton = document.querySelector('#submit-button');
    const spinner = document.querySelector('#spinner');
    const buttonText = document.querySelector('#button-text');

    if (isLoading) {
      submitButton.disabled = true;
      spinner.classList.remove('hidden');
      buttonText.classList.add('hidden');
    } else {
      submitButton.disabled = false;
      spinner.classList.add('hidden');
      buttonText.classList.remove('hidden');
    }
  }
}
