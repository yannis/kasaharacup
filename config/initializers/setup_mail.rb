ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  address: "smtp.gmail.com",
  port: 587,
  domain: "heroku.com",
  authentication: "plain",
  enable_starttls_auto: true,
  user_name: Figaro.env.gmail_username,
  password: Figaro.env.gmail_password
}
