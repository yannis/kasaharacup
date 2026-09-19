import { Controller } from '@hotwired/stimulus';
import { Turbo } from '@hotwired/turbo-rails';

// Reorders an individual category's seeds: a row's grip is dragged onto the
// row whose position it should take, and the server renumbers the list back to
// a contiguous 1..N (SeedOrderMove).
//
// ONE instance on the panel, unlike pool_membership_controller's per-card
// instances: every row is both a drag source and a drop target, and the
// response replaces the whole panel. The dragged row's identity still travels
// through the native dataTransfer payload, which survives that replacement.
//
// This is an insert-at-position reorder, not a swap: the drop sends the target
// row's CURRENT position, and the server's insert rule makes that read
// correctly whether the row moved up or down.
// The seeding panel and the pool cards are rendered on the same admin page and
// both carry their payload as application/json, so each one tags its payload
// with a kind and ignores the other's. Without that, a row dropped on the wrong
// panel is PATCHed with the wrong parameter name, which every one of these
// endpoints reads as "clear it": a pool row dropped here would un-pool the
// participant and wipe that pool's fights, silently.
const KIND = 'seed-order';

export default class extends Controller {
  static values = { nextPosition: Number };

  dragStart(event) {
    const row = event.target.closest('[data-seed-url]');
    if (!row) return;
    const { dataTransfer } = event;
    dataTransfer.effectAllowed = 'move';
    dataTransfer.setData('application/json', JSON.stringify({ kind: KIND, url: row.dataset.seedUrl }));
  }

  dragOver(event) {
    event.preventDefault(); // a preventDefault'd dragover is what permits the drop
    const { dataTransfer } = event;
    dataTransfer.dropEffect = 'move';
    event.currentTarget.classList.add('seed-panel__row--drop');
  }

  dragLeave(event) {
    // Ignore bubbling from children: only clear when the pointer truly leaves the row.
    if (!event.currentTarget.contains(event.relatedTarget)) {
      event.currentTarget.classList.remove('seed-panel__row--drop');
    }
  }

  drop(event) {
    event.preventDefault();
    const row = event.currentTarget;
    row.classList.remove('seed-panel__row--drop');
    const payload = this.readPayload(event);
    if (!payload) return;
    if (payload.url === row.dataset.seedUrl) return; // dropped back on itself
    this.move(payload.url, Number(row.dataset.position));
  }

  // Accessible fallback: choosing a position in a row's "Move to position" select.
  moveViaSelect(event) {
    const select = event.target;
    const position = Number(select.value);
    if (!position) return;
    const row = select.closest('[data-seed-url]');
    this.move(row.dataset.seedUrl, position);
  }

  // The add select carries each unseeded participant's own seed URL; a new
  // seed goes to the end of the list.
  seedViaSelect(event) {
    const url = event.target.value;
    if (!url) return;
    this.move(url, this.nextPositionValue);
  }

  readPayload(event) {
    try {
      const payload = JSON.parse(event.dataTransfer.getData('application/json'));
      return payload?.kind === KIND ? payload : null;
    } catch {
      return null;
    }
  }

  async move(url, position) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    try {
      const response = await fetch(url, {
        method: 'PATCH',
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-CSRF-Token': csrfToken || '',
        },
        body: new URLSearchParams({ to_position: position }),
      });
      if (!response.ok) {
        console.error('seed move failed:', response.status, await response.text());
        this.report('The seed order could not be saved. Reload and try again.');
        return;
      }
      Turbo.renderStreamMessage(await response.text());
    } catch (error) {
      console.error('seed move error:', error);
      this.report('The seed order could not be saved. Reload and try again.');
    }
  }

  // Nothing in the panel moves until the server's stream comes back, so a
  // failed drag is indistinguishable from a missed drop target unless we say
  // so. Same banner bracket_swap_controller raises for the same reason. The
  // next successful stream replaces the panel and takes the banner with it,
  // which is what we want: it only describes the attempt that failed.
  report(message) {
    let banner = this.element.querySelector('.seed-panel__error');
    if (!banner) {
      banner = document.createElement('p');
      banner.className = 'seed-panel__error';
      banner.setAttribute('role', 'alert');
      this.element.prepend(banner);
    }
    banner.textContent = message;
  }
}
