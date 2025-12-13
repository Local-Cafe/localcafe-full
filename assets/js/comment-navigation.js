/**
 * Comment Navigation
 *
 * Scrolls to and highlights a specific comment when navigating via query string
 * Example: /posts/my-post?comment=comment-id
 */

export function initCommentNavigation() {
  // Check if we're on a page with comments
  const commentsSection = document.querySelector('.comments-section');
  if (!commentsSection) return;

  // Get the comment ID from the URL query parameter
  const urlParams = new URLSearchParams(window.location.search);
  const commentId = urlParams.get('comment');

  if (!commentId) return;

  // Find the comment element
  const commentElement = document.getElementById(`comment-${commentId}`);

  if (commentElement) {
    // Scroll to the comment with smooth behavior
    setTimeout(() => {
      commentElement.scrollIntoView({
        behavior: 'smooth',
        block: 'center'
      });

      // Add highlight class
      commentElement.classList.add('comment-highlighted');

      // Remove highlight after animation completes
      setTimeout(() => {
        commentElement.classList.remove('comment-highlighted');
      }, 3000);
    }, 100);
  }
}
