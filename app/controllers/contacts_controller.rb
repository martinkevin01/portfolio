class ContactsController < ApplicationController
  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(contact_params)
    @contact.request = request

    #to block robot
    if params[:contact][:nickname].present?
      redirect_to "/#portfolio", notice: "Message not sent"
      return
    end

    if @contact.deliver
      # flash.now[:success] = 'Message sent!'
      redirect_to root_path, notice: "Message sent!"
    else
      # flash.now[:error] = 'Could not send message'
      redirect_to "/#portfolio", notice: "Message not sent"
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:name, :email, :message, :nickname)
  end
end
