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
          const term = params.term.trim();

          return {
            id: term,
            text: term,
          };
        },
      });
    }
    $(document).on('select2:open', () => {
      document.querySelector('.select2-search__field').focus();
    });
  }
}
