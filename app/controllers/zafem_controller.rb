# Utilisation d'une variable globale pour stocker les billets en mémoire.
# Elle persiste entre les rechargements de code en environnement de développement.
$scanned_tickets ||= Set.new

class ZafemController < ApplicationController

  TICKET_RANGES = {
    "VIP COURTOISIE" => 1001..1200,
    "Courtoisie" => 1201..1300,
    "Billet 80$" => 1301..1800,
    "Billet 90$" => 12701..13000
  }.freeze

  def index
    # Affiche la page principale pour le scanner
  end

  def verify
    ticket_number = params[:ticket_number].to_i

    if $scanned_tickets.include?(ticket_number)
      render json: { status: 'error', message: 'Billet déjà scanné', ticket_type: get_ticket_type(ticket_number) }, status: :unprocessable_entity
    elsif valid_ticket?(ticket_number)
      $scanned_tickets.add(ticket_number)
      render json: { status: 'success', message: 'Validé', ticket_type: get_ticket_type(ticket_number) }
    else
      render json: { status: 'error', message: 'Billet invalide' }, status: :not_found
    end
  end

  def status
    render json: { count: $scanned_tickets.size }
  end

  def reset
    $scanned_tickets.clear
    render json: { status: 'success', message: 'Mémoire des billets réinitialisée.', count: $scanned_tickets.size }
  end

  private

  def valid_ticket?(number)
    TICKET_RANGES.values.any? { |range| range.cover?(number) }
  end

  def get_ticket_type(number)
    TICKET_RANGES.find { |_type, range| range.cover?(number) }&.first
  end
end
