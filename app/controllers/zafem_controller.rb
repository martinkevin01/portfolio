# Utilisation d'une variable globale pour stocker les billets en mémoire.
# Elle persiste entre les rechargements de code en environnement de développement.
$scanned_tickets ||= Set.new
# Un Mutex pour garantir que les accès concurrents à $scanned_tickets sont thread-safe.
$ticket_mutex ||= Mutex.new

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
    response_data = {}
    status_code = :ok

    $ticket_mutex.synchronize do
      if $scanned_tickets.include?(ticket_number)
        response_data = { status: 'error', message: 'Billet déjà scanné', ticket_type: get_ticket_type(ticket_number) }
        status_code = :unprocessable_entity
      elsif valid_ticket?(ticket_number)
        $scanned_tickets.add(ticket_number)
        response_data = { status: 'success', message: 'Validé', ticket_type: get_ticket_type(ticket_number) }
        # Diffuse le nouveau statut complet à tous les clients connectés
        ActionCable.server.broadcast "zafem_count_channel", get_current_status
      else
        response_data = { status: 'error', message: 'Billet invalide' }
        status_code = :not_found
      end
    end

    render json: response_data, status: status_code
  end

  def status
    current_status = $ticket_mutex.synchronize do
      get_current_status
    end
    render json: current_status
  end

  def reset
    status_after_reset = {}
    $ticket_mutex.synchronize do
      $scanned_tickets.clear
      status_after_reset = get_current_status
    end
    # Diffuse le nouveau statut (vide) à tous les clients connectés
    ActionCable.server.broadcast "zafem_count_channel", status_after_reset

    render json: { status: 'success', message: 'Mémoire des billets réinitialisée.', count: status_after_reset[:total_count] }
  end

  private

  def get_current_status
    # NOTE: Cette méthode doit être appelée à l'intérieur d'un bloc $ticket_mutex.synchronize
    # Initialise le décompte avec toutes les catégories à 0
    breakdown = TICKET_RANGES.keys.to_h { |key| [key, 0] }

    # Itère sur les billets scannés pour les compter par catégorie
    $scanned_tickets.each do |ticket_number|
      ticket_type = get_ticket_type(ticket_number)
      breakdown[ticket_type] += 1 if ticket_type
    end

    { total_count: $scanned_tickets.size, breakdown: breakdown }
  end

  def valid_ticket?(number)
    TICKET_RANGES.values.any? { |range| range.cover?(number) }
  end

  def get_ticket_type(number)
    TICKET_RANGES.find { |_type, range| range.cover?(number) }&.first
  end
end
