import { Controller } from '@hotwired/stimulus';
import { Turbo } from '@hotwired/turbo-rails';

export default class extends Controller {
  static get values() { return { url: String }; }

  connect() {
    this.element.addEventListener('turbo:before-morph-attribute', this.preserveOpenAttribute);
    document.addEventListener('click', this.closeOnOutsideClick);
  }

  disconnect() {
    this.element.removeEventListener('turbo:before-morph-attribute', this.preserveOpenAttribute);
    document.removeEventListener('click', this.closeOnOutsideClick);
  }

  closeOnOutsideClick = (event) => {
    if (!this.element.open) return;
    if (this.element.contains(event.target)) return;
    this.element.open = false;
  };

  // Turbo morphs would clobber the locally-held `open` attribute every time
  // we refresh the tree after a points/winner change, collapsing the form
  // mid-edit. Cancel the morph of this attribute so the open state is driven
  // only by user clicks on the summary.
  preserveOpenAttribute = (event) => {
    if (event.target === this.element && event.detail.attributeName === 'open') {
      event.preventDefault();
    }
  };

  detectExistingSelection(event) {
    this.wasChecked = event.currentTarget.checked;
  }

  async submit(event) {
    const input = event.currentTarget;
    let winnerId = input.value;
    if (this.wasChecked) {
      input.checked = false;
      winnerId = '';
    }
    this.wasChecked = false;

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    const body = new URLSearchParams();
    body.append('fight[winner_id]', winnerId);

    try {
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': csrfToken || '',
        },
        body,
      });

      if (!response.ok) {
        console.error('fight-winner submit failed:', response.status, await response.text());
        return;
      }
      Turbo.renderStreamMessage(await response.text());
    } catch (error) {
      console.error('fight-winner submit error:', error);
    }
  }
}
