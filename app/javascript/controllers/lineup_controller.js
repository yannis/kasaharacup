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
  static values = { seedUrl: String };

  // A freshly-opened editor with an unset side carries a seed URL: POST once to
  // lay down the suggested order (persisted but unconfirmed) so the fighters
  // become real and draggable. The response morphs the panel without the seed
  // URL, so a reconnect after the morph won't fire again; clearing the value is
  // a belt-and-braces guard against re-entrancy before the morph lands.
  //
  // In the pool view every encounter editor lives inside a collapsed <details>,
  // whose content still connects its Stimulus controllers while hidden. Seeding
  // on connect would auto-POST a seed for every bout panel just by opening the
  // pool page. So when we're inside a <details>, defer the seed until it's
  // actually opened; a standalone editor (no <details>) seeds immediately.
  connect() {
    if (!this.hasSeedUrlValue || !this.seedUrlValue) return;

    const details = this.element.closest('details');
    if (!details || details.open) {
      this.seed();
      return;
    }
    this.onToggle = () => { if (details.open) this.seed(); };
    details.addEventListener('toggle', this.onToggle);
  }

  disconnect() {
    if (!this.onToggle) return;
    this.element.closest('details')?.removeEventListener('toggle', this.onToggle);
    this.onToggle = null;
  }

  async seed() {
    const url = this.seedUrlValue;
    if (!url) return;
    this.seedUrlValue = '';
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': csrfToken || '',
        },
      });
      if (!response.ok) {
        console.error('lineup seed failed:', response.status, await response.text());
        return;
      }
      Turbo.renderStreamMessage(await response.text());
    } catch (error) {
      console.error('lineup seed error:', error);
    }
  }

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

  // --- Drag-to-reorder (swap) ----------------------------------------------
  // Each fighter card has a drag handle. Dropping one fighter onto another card
  // IN THE SAME TEAM COLUMN swaps just those two picks — swap, not insert: only
  // the two slots change, everyone else stays put. We exchange the two <select>
  // values and fire one change; both selects share the team's form, so submit()
  // posts the whole reordered lineup in a single request.
  dragStart(event) {
    this.source = event.target.closest('[data-reorder-form]');
    const { dataTransfer } = event;
    dataTransfer.effectAllowed = 'move';
    dataTransfer.setData('text/plain', ''); // Firefox needs a payload to drag
  }

  dragEnd() {
    this.source = null;
    this.element
      .querySelectorAll('.pool-match__row--drop')
      .forEach((row) => row.classList.remove('pool-match__row--drop'));
  }

  dragOver(event) {
    if (!this.canDrop(event.currentTarget)) return;
    event.preventDefault(); // a preventDefault'd dragover is what permits the drop
    event.currentTarget.classList.add('pool-match__row--drop');
  }

  dragLeave(event) {
    event.currentTarget.classList.remove('pool-match__row--drop');
  }

  drop(event) {
    const target = event.currentTarget;
    target.classList.remove('pool-match__row--drop');
    if (!this.canDrop(target)) return;
    event.preventDefault();

    const from = this.source.querySelector('select');
    const to = target.querySelector('select');
    this.source = null;
    if (!from || !to) return;

    [from.value, to.value] = [to.value, from.value];
    from.dispatchEvent(new Event('change', { bubbles: true }));
  }

  // A drop is valid onto another card of the same team column. Scored bouts are
  // allowed too — reordering one resets it server-side (its points are cleared).
  canDrop(target) {
    return (
      this.source
      && target !== this.source
      && target.dataset.reorderForm === this.source.dataset.reorderForm
    );
  }
}
