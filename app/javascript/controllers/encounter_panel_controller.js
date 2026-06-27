import { Controller } from '@hotwired/stimulus';

// Controls the encounter editor panel below the bracket tree. This controller
// rides on the Close button, which only exists once an encounter has loaded
// into the panel — so connect() fires exactly when a tree card opens one.
export default class extends Controller {
  // Bring the freshly-loaded editor into view: a tree card sits well above the
  // panel, so clicking one would otherwise leave the editor off-screen below.
  // Turbo's frame `autoscroll` proved unreliable here, so scroll explicitly.
  connect() {
    const frame = this.element.closest('turbo-frame');
    if (frame) frame.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // Emptying the enclosing turbo-frame hides the editor without a server
  // round-trip. The src attribute must also be cleared: if it survived, Turbo
  // could treat a later click on the same encounter as a no-op navigation and
  // leave the panel empty.
  close() {
    const frame = this.element.closest('turbo-frame');
    if (!frame) return;
    frame.removeAttribute('src');
    frame.innerHTML = '';
  }
}
