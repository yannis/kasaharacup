import { Controller } from '@hotwired/stimulus';

// Close button for the encounter editor panel below the bracket tree.
// Emptying the enclosing turbo-frame hides the editor without a server
// round-trip. The src attribute must also be cleared: if it survived, Turbo
// could treat a later click on the same encounter as a no-op navigation and
// leave the panel empty.
export default class extends Controller {
  close() {
    const frame = this.element.closest('turbo-frame');
    if (!frame) return;
    frame.removeAttribute('src');
    frame.innerHTML = '';
  }
}
