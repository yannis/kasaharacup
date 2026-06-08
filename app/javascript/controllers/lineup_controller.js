import { Controller } from '@hotwired/stimulus';

// Auto-submits a team's hidden lineup form when one of its fighter dropdowns
// changes, so an admin sets the lineup straight from the match table — no
// button. The <select> lives in the table but is associated with the form via
// its `form=` attribute, so `event.target.form` resolves to the right team.
export default class extends Controller {
  submit(event) {
    event.target.form?.requestSubmit();
  }
}
