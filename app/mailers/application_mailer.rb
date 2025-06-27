# frozen_string_literal: true

# ApplicationMailer is the base mailer from which all mailers inherit.
# It sets the default from address and layout for emails.
class ApplicationMailer < ActionMailer::Base
  default from: 'from@example.com'
  layout 'mailer'
end
