import { Controller } from '@hotwired/stimulus';
import { Turbo } from '@hotwired/turbo-rails';

// Auto-saves a team's lineup when a fighter dropdown in the match table
// changes. We POST with fetch and render the returned Turbo Stream ourselves
// — the same approach as fight_winner_controller — rather than submitting the
// form. A real form submission on the Active Admin page can fall back to a full
// navigation, which reloads the page and scrolls to the top; a fetch +
// renderStreamMessage only morphs the panel in place, so scroll is preserved.
//
// FormData(form) includes the <select>s that the table associates with this
// form via their `form=` attribute, plus the hidden team_id and CSRF token.
export default class extends Controller {
  async submit(event) {
    const { form } = event.target;
    if (!form) return;

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    try {
      const response = await fetch(form.action, {
        method: (form.method || 'post').toUpperCase(),
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': csrfToken || '',
        },
        body: new FormData(form),
      });

      if (!response.ok) {
        console.error('lineup submit failed:', response.status, await response.text());
        return;
      }
      Turbo.renderStreamMessage(await response.text());
    } catch (error) {
      console.error('lineup submit error:', error);
    }
  }
}
