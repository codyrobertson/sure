import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="app-layout"
export default class extends Controller {
  static targets = ["leftSidebar", "rightSidebar", "mobileSidebar", "resizeHandle"];
  static classes = [
    "expandedSidebar",
    "collapsedSidebar",
    "expandedTransition",
    "collapsedTransition",
  ];
  static values = {
    userId: String,
  };

  // Fixed width snap points for resize
  static WIDTHS = {
    default: 400,
    expanded: 600,
  };

  connect() {
    this.isResizing = false;
    this.startX = 0;
    this.startWidth = 0;

    // Bind handlers for cleanup
    this.boundMouseMove = this.#handleMouseMove.bind(this);
    this.boundMouseUp = this.#handleMouseUp.bind(this);
  }

  disconnect() {
    document.removeEventListener("mousemove", this.boundMouseMove);
    document.removeEventListener("mouseup", this.boundMouseUp);
  }

  openMobileSidebar() {
    this.mobileSidebarTarget.classList.remove("hidden");
  }

  closeMobileSidebar() {
    this.mobileSidebarTarget.classList.add("hidden");
  }

  toggleLeftSidebar() {
    const isOpen = this.leftSidebarTarget.classList.contains("w-full");
    this.#updateUserPreference("show_sidebar", !isOpen);
    this.#toggleSidebarWidth(this.leftSidebarTarget, isOpen);
  }

  toggleRightSidebar() {
    const isOpen = this.rightSidebarTarget.classList.contains("w-full");
    this.#updateUserPreference("show_ai_sidebar", !isOpen);
    this.#toggleSidebarWidth(this.rightSidebarTarget, isOpen);
  }

  // Start resizing when user drags the resize handle
  startResize(event) {
    if (!this.hasRightSidebarTarget) return;

    event.preventDefault();
    this.isResizing = true;
    this.startX = event.clientX;

    // Get current width from computed style or data attribute
    const computedStyle = window.getComputedStyle(this.rightSidebarTarget);
    this.startWidth = parseInt(computedStyle.width, 10) || this.constructor.WIDTHS.default;

    // Add listeners for drag
    document.addEventListener("mousemove", this.boundMouseMove);
    document.addEventListener("mouseup", this.boundMouseUp);

    // Add resizing cursor to body
    document.body.style.cursor = "ew-resize";
    document.body.style.userSelect = "none";

    // Disable transitions during resize for smooth dragging
    this.rightSidebarTarget.style.transition = "none";
  }

  #handleMouseMove(event) {
    if (!this.isResizing) return;

    // Calculate new width (dragging left increases width since sidebar is on right)
    const deltaX = this.startX - event.clientX;
    let newWidth = this.startWidth + deltaX;

    // Clamp between min and max
    const minWidth = this.constructor.WIDTHS.default;
    const maxWidth = this.constructor.WIDTHS.expanded;
    newWidth = Math.max(minWidth, Math.min(maxWidth, newWidth));

    // Apply width directly
    this.rightSidebarTarget.style.maxWidth = `${newWidth}px`;
  }

  #handleMouseUp() {
    if (!this.isResizing) return;

    this.isResizing = false;

    // Remove listeners
    document.removeEventListener("mousemove", this.boundMouseMove);
    document.removeEventListener("mouseup", this.boundMouseUp);

    // Reset cursor
    document.body.style.cursor = "";
    document.body.style.userSelect = "";

    // Re-enable transitions
    this.rightSidebarTarget.style.transition = "";

    // Snap to nearest fixed width
    const computedStyle = window.getComputedStyle(this.rightSidebarTarget);
    const currentWidth = parseInt(computedStyle.width, 10);
    const midpoint = (this.constructor.WIDTHS.default + this.constructor.WIDTHS.expanded) / 2;

    const snapWidth = currentWidth > midpoint
      ? this.constructor.WIDTHS.expanded
      : this.constructor.WIDTHS.default;

    this.rightSidebarTarget.style.maxWidth = `${snapWidth}px`;

    // Save preference
    this.#updateUserPreference("ai_sidebar_width", snapWidth);
  }

  #toggleSidebarWidth(el, isCurrentlyOpen) {
    if (isCurrentlyOpen) {
      el.classList.remove(...this.expandedSidebarClasses);
      el.classList.add(...this.collapsedSidebarClasses);
    } else {
      el.classList.add(...this.expandedSidebarClasses);
      el.classList.remove(...this.collapsedSidebarClasses);
    }
  }

  #updateUserPreference(field, value) {
    fetch(`/users/${this.userIdValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
        Accept: "application/json",
      },
      body: new URLSearchParams({
        [`user[${field}]`]: value,
      }).toString(),
    });
  }
}
