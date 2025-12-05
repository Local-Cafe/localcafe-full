/**
 * Table of Contents Active Section Highlighter
 * Highlights the TOC link corresponding to the currently visible section
 */

export function initTocHighlighter() {
  const toc = document.querySelector('.table-of-contents');
  if (!toc) return;

  const links = Array.from(toc.querySelectorAll('.toc-link'));
  const headings = links
    .map(link => {
      const id = link.getAttribute('href').slice(1); // Remove #
      return document.getElementById(id);
    })
    .filter(Boolean);

  if (headings.length === 0) return;

  // Track currently active heading
  let activeId = null;

  // Create intersection observer
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          // Find the link for this heading
          const id = entry.target.id;
          const link = toc.querySelector(`a[href="#${id}"]`);

          if (link && activeId !== id) {
            // Remove active class from all links
            links.forEach(l => l.classList.remove('toc-link-active'));

            // Add active class to current link
            link.classList.add('toc-link-active');
            activeId = id;
          }
        }
      });
    },
    {
      // Trigger when heading crosses the top 20% of viewport
      rootMargin: '-20% 0px -70% 0px',
      threshold: 0
    }
  );

  // Observe all headings
  headings.forEach(heading => observer.observe(heading));

  // Cleanup on page unload
  window.addEventListener('beforeunload', () => {
    observer.disconnect();
  });
}
