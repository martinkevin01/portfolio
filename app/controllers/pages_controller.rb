class PagesController < ApplicationController
  def home
  end

  def download
    send_file "#{Rails.root}/app/assets/docs/MartinKevinGapieResumeFrench.pdf", type: "application/pdf", x_sendfile: true
  end
end
