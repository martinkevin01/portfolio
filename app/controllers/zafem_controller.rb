class ZafemController < ApplicationController
  # Protège toutes les actions de ce contrôleur avec une authentification HTTP Basic.
  # En production, assurez-vous de définir les variables d'environnement
  # ZAFEM_USER et ZAFEM_PASSWORD.
  http_basic_authenticate_with name: ENV.fetch("ZAFEM_USER", "admin"),
                               password: ENV.fetch("ZAFEM_PASSWORD", "laulita0726")


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

    unless valid_ticket?(ticket_number)
      return render json: { status: 'error', message: 'Billet invalide' }, status: :not_found
    end

    # $redis.sadd est atomique. Il retourne true si le billet a été ajouté, false s'il existait déjà.
    # Cela remplace le besoin d'un Mutex.
    is_new_scan = $redis.sadd("scanned_tickets", ticket_number)

    if is_new_scan
      response_data = { status: 'success', message: 'Validé', ticket_type: get_ticket_type(ticket_number) }
      # Diffuse le nouveau statut complet à tous les clients connectés
      ActionCable.server.broadcast "zafem_count_channel", get_current_status
      render json: response_data, status: :ok
    else
      response_data = { status: 'error', message: 'Billet déjà scanné', ticket_type: get_ticket_type(ticket_number) }
      render json: response_data, status: :unprocessable_entity
    end
  end

  def status
    render json: get_current_status
  end

  def reset
    $redis.del("scanned_tickets")
    status_after_reset = get_current_status

    # Diffuse le nouveau statut (vide) à tous les clients connectés
    ActionCable.server.broadcast "zafem_count_channel", status_after_reset
    render json: { status: 'success', message: 'Mémoire des billets réinitialisée.', count: status_after_reset[:total_count] }
  end

  private

  def get_current_status
    scanned_ticket_numbers = $redis.smembers("scanned_tickets").map(&:to_i)

    # Initialise le décompte avec toutes les catégories à 0
    breakdown = TICKET_RANGES.keys.to_h { |key| [key, 0] }

    # Itère sur les billets scannés pour les compter par catégorie
    scanned_ticket_numbers.each do |ticket_number|
      ticket_type = get_ticket_type(ticket_number)
      breakdown[ticket_type] += 1 if ticket_type
    end

    { total_count: scanned_ticket_numbers.size, breakdown: breakdown }
  end

  def valid_ticket?(number)
    TICKET_RANGES.values.any? { |range| range.cover?(number) }
  end

  def get_ticket_type(number)
    TICKET_RANGES.find { |_type, range| range.cover?(number) }&.first
  end
end
