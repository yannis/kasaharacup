#= require active_admin/base
#= require tree
#= require raphael-min
#= require moment
#= require bootstrap-datetimepicker
#= require bootstrap-datetimepicker.fr

$ ->
  $('input.hasDatetimePicker').datetimepicker
    pickTime: false
    format: "DD-MM-YYYY"
