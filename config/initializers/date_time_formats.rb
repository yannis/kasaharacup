Time::DATE_FORMATS.merge!(
  :time_only => '%H:%M',
  :rfc2445 => '%Y%m%dT%H%M00',
  :rfc822 => '%a, %d %b %Y %H:%M:%S +0100',
  :day_month_year => "%e %B %Y",
  :dotted_day_month_year => "%e %B %Y",
  :day_month_year_hour_minute => "%e %B %Y, %H:%M",
  :db_zoned => '%m/%d/%Y %H:%M',
  :timezoned => '%Y-%m-%dT%H:%M:00Z'
)
Date::DATE_FORMATS.merge!( 
  :month => '%B',
  :day_month_year => "%e %B %Y",
  :time_only => '%H:%M'
)