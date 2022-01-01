import { Controller } from '@hotwired/stimulus';
import $ from 'jquery';
import select2 from 'select2';

select2($);

export default class extends Controller {
  connect() {
    if (this.element != null) {
      $(this.element).select2({
        tags: true,
        placeholder: 'Please select',
        createTag(params) {
          const term = $.trim(params.term);

          return {
            id: term,
            text: term,
          };
        },
      });
    }
  }
}
