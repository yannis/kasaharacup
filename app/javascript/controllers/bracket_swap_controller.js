import { Controller } from '@hotwired/stimulus';
import { Turbo } from '@hotwired/turbo-rails';

// Swaps two round-1 teams of a pool-less draw by dragging one slot's grip onto
// another slot.
//
// ONE instance on the tree container, unlike pool_membership_controller's
// per-card instances: the whole tree is a single Turbo morph target, so a
// per-node controller would be torn down and rebuilt on every redraw. The
// dragged slot's identity travels through the native dataTransfer payload,
// which survives the morph.
//
// The response carries the redrawn tree and we render it, so the acting admin
// does not wait on a background job. Other open sessions are redrawn by
// Encounter#broadcast_bracket_tree.
export default class extends Controller {
  dragStart(event) {
    const slot = event.target.closest('[data-encounter-id]');
    if (!slot) return;
    const { dataTransfer } = event;
    dataTransfer.effectAllowed = 'move';
    dataTransfer.setData('application/json', JSON.stringify({
      encounterId: slot.dataset.encounterId,
      teamId: slot.dataset.teamId,
    }));
  }

  dragEnd() {
    this.element
      .querySelectorAll('.competition-tree__fighter--drop')
      .forEach((slot) => slot.classList.remove('competition-tree__fighter--drop'));
  }

  dragOver(event) {
    if (!this.canDrop(event.currentTarget)) return;
    event.preventDefault(); // a preventDefault'd dragover is what permits the drop
    const { dataTransfer } = event;
    dataTransfer.dropEffect = 'move';
    event.currentTarget.classList.add('competition-tree__fighter--drop');
  }

  dragLeave(event) {
    // Ignore bubbling from the grip and the name span: only clear when the
    // pointer truly leaves the slot.
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
    // Same encounter: swapping a match's two sides only flips which is team_1.
    // The server rejects it; suppress it here so a meaningless gesture is silent.
    if (source.encounterId === target.dataset.encounterId) return;

    // Drop team A onto slot B: B receives A, and A's slot receives B's old
    // occupant. Post against the TARGET slot, so expected_team_id describes it.
    this.submit(target, source);
  }

  canDrop(target) {
    return Boolean(target?.dataset.encounterId) && target.getAttribute('aria-busy') !== 'true';
  }

  readPayload(event) {
    try {
      return JSON.parse(event.dataTransfer.getData('application/json'));
    } catch {
      return null;
    }
  }

  async submit(slot, source) {
    if (slot.getAttribute('aria-busy') === 'true') return; // ignore a double-drop
    slot.setAttribute('aria-busy', 'true');

    try {
      let refusal = await this.post(slot, source, false);
      // The server owns the confirm decision: a swap that would discard a
      // fighter order answers 422 with confirm: true, exactly as a destructive
      // pool move does. Declining leaves the draw untouched and says nothing.
      if (refusal?.confirm) {
        if (!window.confirm(refusal.message)) return;
        refusal = await this.post(slot, source, true);
      }
      if (refusal?.message) this.report(refusal.message);
    } finally {
      slot.removeAttribute('aria-busy');
    }
  }

  // Returns null once the new tree has been rendered, or {message, confirm}
  // when the server refused the swap.
  async post(slot, source, force) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    const body = new URLSearchParams({
      slot: slot.dataset.slot,
      team_id: source.teamId,
      // BOTH ends of the swap, so a drop issued against a tree drawn before
      // someone else's swap landed is refused rather than silently re-aimed at
      // wherever the dragged team sits now.
      expected_team_id: slot.dataset.teamId,
      expected_encounter_id: source.encounterId,
    });
    if (force) body.set('force', 'true');

    try {
      const response = await fetch(slot.dataset.swapUrl, {
        method: 'POST',
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-CSRF-Token': csrfToken || '',
        },
        body,
      });

      if (response.status === 422) return await response.json();
      if (!response.ok) {
        console.error('bracket swap failed:', response.status, await response.text());
        return { message: 'The swap could not be saved. Reload and try again.' };
      }
      // Morphs the tree in place, so the grips and this controller survive.
      Turbo.renderStreamMessage(await response.text());
      return null;
    } catch (error) {
      console.error('bracket swap error:', error);
      return { message: 'The swap could not be saved. Reload and try again.' };
    }
  }

  // A later morph of the tree clears the banner, which is the behaviour we want:
  // the message only describes the draw as it was when the drop was refused.
  report(message) {
    let banner = this.element.querySelector('.competition-tree__swap-error');
    if (!banner) {
      banner = document.createElement('p');
      banner.className = 'competition-tree__swap-error';
      banner.setAttribute('role', 'alert');
      this.element.prepend(banner);
    }
    banner.textContent = message;
  }
}
