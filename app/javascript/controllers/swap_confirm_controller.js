import { Controller } from '@hotwired/stimulus';

// Carries the encounter panel's swap form between "just do it" and "ask first".
//
// The form cannot let the server decide, the way the drag path does: the
// partner encounter is only known once a team is picked from the dropdown, and
// by then the prompt has to be in the page already. So the server writes each
// option's verdict into it (EncounterTeamSwap#confirmation_for) and this moves
// the selected one onto the form.
//
// force rides along with the prompt, not ahead of it. Submitting a swap that
// needed no confirmation leaves force false, so a page drawn before someone
// else entered a lineup is still refused by the server rather than driven
// through it — which is what the old unconditional force: true did.
export default class extends Controller {
  static targets = ['select', 'force'];

  update() {
    const message = this.selectTarget.selectedOptions[0]?.dataset.confirmMessage;
    if (message) {
      this.element.setAttribute('data-turbo-confirm', message);
      this.forceTarget.value = 'true';
    } else {
      this.element.removeAttribute('data-turbo-confirm');
      this.forceTarget.value = 'false';
    }
  }
}
