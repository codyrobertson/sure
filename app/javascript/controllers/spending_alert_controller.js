import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="spending-alert"
export default class extends Controller {
  static values = { id: String };

  async dismiss() {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;

    try {
      const response = await fetch(`/spending_alerts/${this.idValue}/dismiss`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          Accept: "text/vnd.turbo-stream.html",
        },
      });

      if (response.ok) {
        // Animate removal
        this.element.style.transition = "opacity 0.2s ease-out, transform 0.2s ease-out";
        this.element.style.opacity = "0";
        this.element.style.transform = "translateX(10px)";

        setTimeout(() => {
          this.element.remove();

          // Check if there are any alerts left
          const alertsContainer = document.querySelector(
            "#spending-alerts-section .space-y-3"
          );
          if (alertsContainer && alertsContainer.children.length === 0) {
            // Reload the section to show empty state
            window.Turbo.visit(window.location.href, { action: "replace" });
          }
        }, 200);
      }
    } catch (error) {
      console.error("Failed to dismiss alert:", error);
    }
  }
}
