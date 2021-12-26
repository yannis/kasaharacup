import { Controller } from '@hotwired/stimulus';
import { useTransition, useClickOutside } from 'stimulus-use';

export default class extends Controller {
  static get targets() { return ['menu']; }

  connect() {
    useTransition(this, { element: this.menuTarget });
    useClickOutside(this);
  }

  toggle() {
    this.toggleTransition();
  }

  clickOutside(event) {
    if (this.transitioned) {
      event.preventDefault();
      this.leave();
    }
  }
}
