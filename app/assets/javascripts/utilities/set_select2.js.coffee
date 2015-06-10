$ ->
  console.log "set select2 CALLED"
  $("input[data-behaviour='select2']").select2

    query: (query)->
      data = {results: @element.data('options')}
      query.callback(data) if query
    createSearchChoice: (term)->
      {id:term, text:term}
    initSelection : (element, callback) ->
      data = {id: element.val(), text: element.val()}
      callback(data)
    allowClear: true
    placeholder: "Please select"
