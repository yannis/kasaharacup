import { Controller } from '@hotwired/stimulus';
import { Turbo } from '@hotwired/turbo-rails';

// Moves a team into another pool. Each pool card is its own controller
// instance; a team row is dragged from its source card and dropped on a
// destination card, so the dragged team's identity travels through the native
// dataTransfer payload (cross-instance) rather than instance state. The
// per-row "Move to" <select> is an accessible, mouse-free path to the same
// move() call.
//
// The server owns the confirm decision: a destructive move (recorded results
// or an existing bracket) answers 422 with a message; we confirm and retry
// with force=true. On success we render the returned Turbo Stream, which
// replaces the affected pool cards (or removes an emptied one).
export default class extends Controller {
  static values = { poolNumber: Number };

  dragStart(event) {
    const row = event.target.closest('[data-move-url]');
    if (!row) return;
    const { dataTransfer } = event;
    dataTransfer.effectAllowed = 'move';
    dataTransfer.setData(
      'application/json',
      JSON.stringify({ url: row.dataset.moveUrl, fromPool: Number(row.dataset.fromPool) }),
    );
  }

  dragOver(event) {
    event.preventDefault(); // a preventDefault'd dragover is what permits the drop
    const { dataTransfer } = event;
    dataTransfer.dropEffect = 'move';
    this.element.classList.add('pool-card--drop');
  }

  dragLeave(event) {
    // Ignore bubbling from children: only clear when the pointer truly leaves the card.
    if (!this.element.contains(event.relatedTarget)) this.element.classList.remove('pool-card--drop');
  }

  drop(event) {
    event.preventDefault();
    this.element.classList.remove('pool-card--drop');
    const payload = this.readPayload(event);
    if (!payload) return;
    if (payload.fromPool === this.poolNumberValue) return; // dropped back on its own pool
    this.move(payload.url, this.poolNumberValue);
  }

  // Dropping a pooled team on the unpooled panel removes it from its pool (the
  // server treats a blank destination as un-pool). A team already unpooled has
  // no source pool, so it is a no-op.
  dropUnpool(event) {
    event.preventDefault();
    this.element.classList.remove('pool-card--drop');
    const payload = this.readPayload(event);
    if (!payload || payload.fromPool == null) return;
    this.move(payload.url, '');
  }

  // Accessible fallback: choosing a pool in a row's "Move to" select.
  moveViaSelect(event) {
    const select = event.target;
    const toPool = Number(select.value);
    if (!toPool) return;
    const row = select.closest('[data-move-url]');
    this.move(row.dataset.moveUrl, toPool);
  }

  readPayload(event) {
    try {
      return JSON.parse(event.dataTransfer.getData('application/json'));
    } catch {
      return null;
    }
  }

  async move(url, toPool, force = false) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    const body = new URLSearchParams({ to_pool_number: toPool });
    if (force) body.set('force', 'true');
    try {
      const response = await fetch(url, {
        method: 'PATCH',
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-CSRF-Token': csrfToken || '',
        },
        body,
      });
      if (response.status === 422) {
        const { message } = await response.json();
        if (window.confirm(message)) this.move(url, toPool, true);
        return;
      }
      if (response.status === 204) return; // no-op (same pool)
      if (!response.ok) {
        console.error('pool move failed:', response.status, await response.text());
        return;
      }
      Turbo.renderStreamMessage(await response.text());
    } catch (error) {
      console.error('pool move error:', error);
    }
  }
}
