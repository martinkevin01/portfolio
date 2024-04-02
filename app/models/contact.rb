class Contact < MailForm::Base
  attribute :name, length: { minimum: 3 }, presence: true
  attribute :email, presence: true, format: { with: /\A\S+@.+\.\S+\z/ }
  attribute :message, presence: true
  attribute :nickname, absence: true

  # Declare the e-mail headers. It accepts anything the mail method
  # in ActionMailer accepts.

  def headers
    mail = "postmaster@mkgapie.com"
    {
      subject: "Contact Form Portfolio",
      to: "martinkevingapie@gmail.com",
      from: %("#{name}" <#{mail}>)
    }
  end
end
