$ ->
  $(".nav-register").on "click", (e)->
    e.preventDefault()
    $("#registrations").slideToggle()

  $(".registrations-signin-link").on "click", (e)->
    e.preventDefault()
    e.stopPropagation()
    $('.dropdown-toggle').dropdown("toggle")
    $("#registrations").slideToggle()
