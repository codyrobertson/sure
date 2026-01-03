import { Controller } from "@hotwired/stimulus";

// Toggles visibility of hidden list items with smooth animation
export default class extends Controller {
  static targets = ["hiddenItem", "toggleButton", "buttonText", "chevron"];

  connect() {
    this.expanded = false;
  }

  toggle() {
    this.expanded = !this.expanded;

    this.hiddenItemTargets.forEach((item) => {
      item.classList.toggle("hidden", !this.expanded);
    });

    // Update button text
    if (this.hasButtonTextTarget) {
      const totalCount = this.element.querySelectorAll("[data-list-expander-target='hiddenItem']").length +
                         this.element.querySelectorAll("[data-list-expander-target='']").length;
      this.buttonTextTarget.textContent = this.expanded ? "Show less" : `Show all ${this.hiddenItemTargets.length + 10} categories`;
    }

    // Rotate chevron
    if (this.hasChevronTarget) {
      this.chevronTarget.style.transform = this.expanded ? "rotate(180deg)" : "rotate(0deg)";
      this.chevronTarget.style.transition = "transform 0.2s ease";
    }
  }
}
