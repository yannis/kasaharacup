import { Controller } from '@hotwired/stimulus';
import { useTransition } from 'stimulus-use';

export default class extends Controller {
  static get targets() { return ['mobileMenu']; }

  connect() {
    useTransition(this, {
      element: this.mobileMenuTarget,
    });
  }

  toggle() {
    this.toggleTransition();
  }
}
