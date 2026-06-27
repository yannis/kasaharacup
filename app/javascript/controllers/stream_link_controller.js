import { Controller } from '@hotwired/stimulus';
import { Turbo } from '@hotwired/turbo-rails';

// Submits an admin action link via fetch and renders the returned Turbo Stream
// in place. ActiveAdmin's jquery_ujs turns a `data-method` link into a full-page
// form submit, which reloads and scrolls back to the top; intercepting the click
// and POSTing ourselves keeps the admin where they are. Same approach as
// lineup_controller / fight_winner_controller.
//
// The link is a plain <a> (no data-method) so neither jquery_ujs nor Turbo Drive
// navigates on click; preventDefault stops Turbo Drive's own GET visit.
export default class extends Controller {
  static values = { confirm: String };

  async submit(event) {
    event.preventDefault();
    if (this.confirmValue && !window.confirm(this.confirmValue)) return;

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    try {
      const response = await fetch(this.element.href, {
        method: 'POST',
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': csrfToken || '',
        },
      });
      if (!response.ok) {
        console.error('stream-link failed:', response.status, await response.text());
        return;
      }
      Turbo.renderStreamMessage(await response.text());
    } catch (error) {
      console.error('stream-link error:', error);
    }
  }
}
