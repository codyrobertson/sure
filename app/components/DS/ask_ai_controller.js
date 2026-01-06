import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="DS--ask-ai"
// A reusable AI interaction trigger that can be placed throughout the app.
// Opens a modal overlay with an input field, submits to chats#create.
export default class extends Controller {
  static targets = ["button", "overlay", "panel", "form", "input", "submitButton", "loading"];

  static values = {
    expanded: { type: Boolean, default: false },
    context: String,
    metadata: String,
  };

  connect() {
    this.boundHandleGlobalKeydown = this.handleGlobalKeydown.bind(this);
    document.addEventListener("keydown", this.boundHandleGlobalKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleGlobalKeydown);
  }

  handleGlobalKeydown(event) {
    // Cmd+K or Ctrl+K to open
    if ((event.metaKey || event.ctrlKey) && event.key === "k") {
      event.preventDefault();
      this.expand();
    }
  }

  expand() {
    if (this.expandedValue) return;

    this.expandedValue = true;
    this.buttonTarget.setAttribute("aria-expanded", "true");
    this.overlayTarget.classList.remove("hidden");
    document.body.style.overflow = "hidden";

    // Focus input after animation
    requestAnimationFrame(() => {
      if (this.hasInputTarget) {
        this.inputTarget.focus();
      }
    });
  }

  collapse() {
    if (!this.expandedValue) return;

    this.expandedValue = false;
    this.buttonTarget.setAttribute("aria-expanded", "false");
    this.overlayTarget.classList.add("hidden");
    document.body.style.overflow = "";

    // Reset state
    this.hideLoading();
    if (this.hasInputTarget) {
      this.inputTarget.value = "";
      this.inputTarget.style.height = "auto";
    }
  }

  handleOverlayClick(event) {
    // Only close if clicking on the overlay itself, not the panel
    if (event.target === this.overlayTarget) {
      this.collapse();
    }
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      this.submit();
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.collapse();
    }
  }

  autoResize() {
    const input = this.inputTarget;
    const lineHeight = 20;
    const maxLines = 5;

    input.style.height = "auto";
    input.style.height = `${Math.min(input.scrollHeight, lineHeight * maxLines)}px`;
    input.style.overflowY =
      input.scrollHeight > lineHeight * maxLines ? "auto" : "hidden";
  }

  submit() {
    const content = this.inputTarget.value.trim();
    if (!content) return;

    this.showLoading();

    // Submit the form - this will navigate to the chat page
    this.formTarget.requestSubmit();
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden");
    }
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true;
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden");
    }
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false;
    }
  }
}
