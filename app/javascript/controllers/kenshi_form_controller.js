import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static get targets() {
    return ['details'];
  }

  connect() {
    this.showOrHidePersonalDetailsForm();
  }

  handleProductChange() {
    this.showOrHidePersonalDetailsForm();
  }

  showOrHidePersonalDetailsForm() {
    const checkboxes = this.element
      .querySelectorAll('input:checked[type=checkbox][data-require-personal-details=true]');
    if (checkboxes.length > 0) {
      this.showPersonalDetailsForm();
    } else {
      this.hidePersonalDetailsForm();
    }
  }

  showPersonalDetailsForm() {
    this.detailsTarget.classList.remove('hidden');
    this.detailsTarget
      .querySelectorAll('input, select, checkbox, textarea')
      .forEach((element) => {
        // eslint-disable-next-line no-param-reassign
        element.disabled = false;
        element.classList.remove('disabled');
      });
  }

  hidePersonalDetailsForm() {
    this.detailsTarget.classList.add('hidden');
    this.detailsTarget
      .querySelectorAll('input, select, checkbox, textarea')
      .forEach((element) => {
        // eslint-disable-next-line no-param-reassign
        element.disabled = true;
        element.classList.add('disabled');
      });
  }
}
