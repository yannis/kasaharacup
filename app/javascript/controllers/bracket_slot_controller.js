import { Controller } from '@hotwired/stimulus';
import { Turbo } from '@hotwired/turbo-rails';
import { carriesDragPayload, readDragPayload, writeDragPayload } from './drag_payload';

// Tags every payload with this and ignores anything else — a team category's
// admin page renders the pool cards beside the bracket and they drag under the
// same type. See drag_payload.js.
const KIND = 'bracket-slot';

// Manual bracket reordering: drag a slot's entry onto another slot, onto a
// bye's empty side, or into the waiting area, and drag it back. Every gesture
// also has a <select> that posts the same request, which is the keyboard and
// touch path.
//
// ONE instance, on a wrapper enclosing the tree AND the waiting panel. Not for
// morph survival — the tree is morphed in place and a controller on it would
// survive — but because a drag now crosses two separate Turbo replace targets,
// and the payload has to be read by the same controller that wrote it.
//
// The server owns every decision. A refusal is 422 {message, confirm}; confirm
// means "this would discard a hand-entered fighter order", and the client asks
// and retries with force=true. A freeze is 403 and carries no confirm, because
// there is no force that gets through one.
export default class extends Controller {
  // --- drag sources ------------------------------------------------------

  dragStart(event) {
    const slot = event.target.closest('[data-slot-id]');
    if (!slot) return;
    const { dataTransfer } = event;
    dataTransfer.effectAllowed = 'move';
    // Named `url` so drag_payload's same-origin check applies to it: a drag
    // from a hostile tab could otherwise name any endpoint, and this page's
    // CSRF token would be sent there.
    writeDragPayload(dataTransfer, KIND, {
      url: slot.dataset.slotUrl,
      sourceSlot: slot.dataset.slotId,
      sourceEntryKey: slot.dataset.entryKey || '',
    });
  }

  dragStartWaiting(event) {
    const row = event.target.closest('[data-entry-key]');
    if (!row) return;
    const { dataTransfer } = event;
    dataTransfer.effectAllowed = 'move';
    writeDragPayload(dataTransfer, KIND, { entryKey: row.dataset.entryKey });
  }

  dragEnd() {
    this.element
      .querySelectorAll('.competition-tree__fighter--drop')
      .forEach((node) => node.classList.remove('competition-tree__fighter--drop'));
    this.element
      .querySelectorAll('.bracket-waiting--over')
      .forEach((node) => node.classList.remove('bracket-waiting--over'));
  }

  // --- slots as drop targets ---------------------------------------------

  dragOver(event) {
    if (!this.canDrop(event.currentTarget)) return;
    event.preventDefault(); // a preventDefault'd dragover is what permits the drop
    const { dataTransfer } = event;
    dataTransfer.dropEffect = 'move';
    event.currentTarget.classList.add('competition-tree__fighter--drop');
  }

  dragLeave(event) {
    // Ignore bubbling from the grip, the select and the name span: only clear
    // when the pointer truly leaves the slot.
    if (event.currentTarget.contains(event.relatedTarget)) return;
    event.currentTarget.classList.remove('competition-tree__fighter--drop');
  }

  drop(event) {
    const target = event.currentTarget;
    target.classList.remove('competition-tree__fighter--drop');
    if (!this.canDrop(target)) return;
    event.preventDefault();

    const source = this.readPayload(event);
    if (!source) return;
    // Any slot of the SAME unit, not just the one dragged: exchanging a unit's
    // two sides only flips which is slot 1, and on an encounter it writes one
    // team id into both columns, which Encounter#teams_differ rejects. The
    // "Move to…" select leaves its own unit out for the same reason. The
    // server refuses it too; suppress it here so a meaningless gesture is
    // silent.
    if (source.sourceSlot && this.unitOf(source.sourceSlot) === this.unitOf(target.dataset.slotId)) {
      return;
    }

    this.submit(target, 'PATCH', target.dataset.slotUrl, {
      source_slot: source.sourceSlot,
      entry: source.entryKey,
      expected_entry: target.dataset.entryKey || '',
      expected_source_entry: source.sourceEntryKey,
    });
  }

  // --- the waiting area as a drop target ---------------------------------

  // Only a drag carrying one of our payloads. getData is unreadable during
  // dragover (the browser protects the drag data until the drop), so the type
  // list is all a zone can test — but it is enough to rule out a file or a
  // selection, which a bare preventDefault would otherwise let the browser
  // OPEN in this tab when #dropToWaiting finds nothing it recognises.
  dragOverWaiting(event) {
    if (!carriesDragPayload(event)) return;
    event.preventDefault();
    const { dataTransfer } = event;
    dataTransfer.dropEffect = 'move';
    event.currentTarget.classList.add('bracket-waiting--over');
  }

  dragLeaveWaiting(event) {
    if (event.currentTarget.contains(event.relatedTarget)) return;
    event.currentTarget.classList.remove('bracket-waiting--over');
  }

  dropToWaiting(event) {
    const zone = event.currentTarget;
    zone.classList.remove('bracket-waiting--over');
    if (!carriesDragPayload(event)) return;
    // BEFORE the early return below, not after: dragOverWaiting has already
    // told the browser this zone owns the drop, so bailing without this hands
    // the gesture back to the browser's own drop behaviour.
    event.preventDefault();

    const source = this.readPayload(event);
    // A waiting row dropped back onto the waiting area carries no slot and
    // means nothing.
    if (!source || !source.sourceSlot) return;

    this.submit(zone, 'DELETE', source.url, { expected_entry: source.sourceEntryKey });
  }

  // --- the keyboard path --------------------------------------------------

  // A tree slot's "Move to…". The option value carries both the verb and the
  // url, because "put this entry there" and "take it out" are two different
  // requests against two different slots.
  moveViaSelect(event) {
    const select = event.target;
    const { value } = select;
    if (!value) return;
    const expected = select.selectedOptions[0]?.dataset.expectedEntry ?? '';
    const [verb, url] = this.splitOption(value);
    select.value = '';

    if (verb === 'remove') {
      this.submit(select, 'DELETE', url, { expected_entry: expected });
    } else {
      this.submit(select, 'PATCH', url, {
        source_slot: select.dataset.sourceSlot,
        expected_entry: expected,
        expected_source_entry: select.dataset.sourceEntryKey || '',
      });
    }
  }

  // A waiting row's "Add to…". The option value IS the destination url.
  placeViaSelect(event) {
    const select = event.target;
    const url = select.value;
    if (!url) return;
    const expected = select.selectedOptions[0]?.dataset.expectedEntry ?? '';
    const row = select.closest('[data-entry-key]');
    select.value = '';

    this.submit(select, 'PATCH', url, {
      entry: row.dataset.entryKey,
      expected_entry: expected,
    });
  }

  // --- plumbing -----------------------------------------------------------

  readPayload(event) {
    return readDragPayload(event, KIND);
  }

  // The value is "<verb>:<url>" and a url contains colons, so split ONCE.
  splitOption(value) {
    const index = value.indexOf(':');
    return [value.slice(0, index), value.slice(index + 1)];
  }

  // The record half of a "<record id>-<slot>" slot ref. Two slots of one unit
  // share it, which is what makes a drop between them a no-op gesture.
  unitOf(slotId) {
    return String(slotId).split('-')[0];
  }

  canDrop(target) {
    return Boolean(target?.dataset.slotId) && target.getAttribute('aria-busy') !== 'true';
  }

  async submit(busyElement, method, url, body) {
    if (busyElement.getAttribute('aria-busy') === 'true') return; // ignore a double-drop
    busyElement.setAttribute('aria-busy', 'true');

    try {
      let refusal = await this.post(method, url, body, false);
      // The server owns the confirm decision: a move that would discard a
      // fighter order answers 422 with confirm: true, exactly as a destructive
      // pool move does. Declining leaves the draw untouched and says nothing.
      if (refusal?.confirm) {
        if (!window.confirm(refusal.message)) return;
        refusal = await this.post(method, url, body, true);
      }
      if (refusal?.message) this.report(refusal.message);
    } finally {
      busyElement.removeAttribute('aria-busy');
    }
  }

  // Returns null once the new tree and waiting panel have been rendered, or
  // {message, confirm} when the server refused.
  async post(method, url, body, force) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    const params = new URLSearchParams();
    Object.entries(body).forEach(([key, value]) => {
      if (value !== undefined && value !== null) params.set(key, value);
    });
    params.set('_method', method);
    if (force) params.set('force', 'true');

    try {
      const response = await fetch(url, {
        method: 'POST', // with _method, so one code path serves PATCH and DELETE
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-CSRF-Token': csrfToken || '',
        },
        body: params,
      });

      // 204: the move changed nothing. Nothing to render and nothing to say.
      if (response.status === 204) return null;
      // 403 is a freeze. Returned without `confirm`, so #submit reports it and
      // never offers the retry a 422 would.
      if (response.status === 403 || response.status === 422) return response.json();
      if (!response.ok) {
        console.error('bracket slot move failed:', response.status, await response.text());
        return { message: 'The move could not be saved. Reload and try again.' };
      }
      // Morphs the tree and the waiting panel in place, so this controller,
      // which sits above both, survives.
      Turbo.renderStreamMessage(await response.text());
      return null;
    } catch (error) {
      console.error('bracket slot move error:', error);
      return { message: 'The move could not be saved. Reload and try again.' };
    }
  }

  // A later morph of the tree clears the banner, which is the behaviour we
  // want: the message only describes the draw as it was when the move was
  // refused. It renders inside the TREE, not on this controller's wrapper,
  // which is where it belongs and where it has always been.
  report(message) {
    const tree = this.element.querySelector('.competition-tree') || this.element;
    let banner = tree.querySelector('.competition-tree__swap-error');
    if (!banner) {
      banner = document.createElement('p');
      banner.className = 'competition-tree__swap-error';
      banner.setAttribute('role', 'alert');
      tree.prepend(banner);
    }
    banner.textContent = message;
  }
}
