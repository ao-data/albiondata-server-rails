// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

function updateScrollPadding() {
  const header = document.querySelector('.site-header');
  if (header) {
    document.documentElement.style.scrollPaddingTop = `${header.offsetHeight}px`;
  }
}

document.addEventListener('DOMContentLoaded', updateScrollPadding);
document.addEventListener('turbo:load', updateScrollPadding);
