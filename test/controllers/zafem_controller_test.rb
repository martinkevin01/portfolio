require "test_helper"
require "concurrent-ruby"

class ZafemControllerTest < ActionDispatch::IntegrationTest
  # This test class interacts with Redis, not the database.
  # By calling `fixtures` with no arguments, we tell Rails not to load any fixtures for these tests.
  # This prevents the test runner from trying to connect to the test database, which is useful
  # when running tests without a database server (e.g., locally if postgres isn't running).
  fixtures

  def setup
    # Vider Redis et configurer l'authentification avant chaque test
    $redis.del("scanned_tickets")
    @auth_headers = {
      'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials(
        ENV.fetch("ZAFEM_USER", "admin"),
        ENV.fetch("ZAFEM_PASSWORD", "laulita0726")
      )
    }
  end

  # --- Tests de base ---

  test "should return success for a valid, unscanned ticket" do
    post zafem_verify_url, params: { ticket_number: 1001 }, headers: @auth_headers
    assert_response :ok
    response_body = JSON.parse(response.body)
    assert_equal "success", response_body["status"]
    assert_equal "Validé", response_body["message"]
    assert_equal "VIP COURTOISIE", response_body["ticket_type"]
    assert_equal 1, $redis.scard("scanned_tickets")
  end

  test "should return error for an already scanned ticket" do
    ticket_number = 1002
    # Premier scan
    post zafem_verify_url, params: { ticket_number: ticket_number }, headers: @auth_headers
    assert_response :ok

    # Deuxième scan
    post zafem_verify_url, params: { ticket_number: ticket_number }, headers: @auth_headers
    assert_response :unprocessable_entity
    response_body = JSON.parse(response.body)
    assert_equal "error", response_body["status"]
    assert_equal "Billet déjà scanné", response_body["message"]
    assert_equal 1, $redis.scard("scanned_tickets") # Le compteur ne doit pas augmenter
  end

  test "should return error for an invalid ticket number" do
    post zafem_verify_url, params: { ticket_number: 99999 }, headers: @auth_headers
    assert_response :not_found
    response_body = JSON.parse(response.body)
    assert_equal "error", response_body["status"]
    assert_equal "Billet invalide", response_body["message"]
    assert_equal 0, $redis.scard("scanned_tickets")
  end

  test "should reset scanned tickets" do
    post zafem_verify_url, params: { ticket_number: 1001 }, headers: @auth_headers
    assert_equal 1, $redis.scard("scanned_tickets")

    post zafem_reset_url, headers: @auth_headers
    assert_response :ok
    assert_equal 0, $redis.scard("scanned_tickets")
  end

  # --- Test de concurrence (simili-Stress Test) ---

  test "stress test simulating two concurrent scanners" do
    # Nous allons scanner 100 billets, avec deux scanners qui essaient de tous les scanner en même temps.
    # Cela testera la gestion des race conditions grâce à l'atomicité de Redis.
    num_scanners = 2
    tickets_to_scan = (1301..1400).to_a # 100 billets "Billet 80$"

    # Une barrière pour synchroniser le démarrage des threads pour une meilleure simulation de concurrence.
    barrier = Concurrent::CyclicBarrier.new(num_scanners)

    # Un tableau thread-safe pour stocker les résultats des deux threads.
    results = Concurrent::Array.new

    # Simule N scanners en parallèle
    threads = Array.new(num_scanners) do
      Thread.new do
        s = open_session # Chaque thread a sa propre session de test
        barrier.wait # Attend que tous les threads soient prêts
        tickets_to_scan.each do |ticket|
          s.post zafem_verify_url, params: { ticket_number: ticket }, headers: @auth_headers
          results << { status: s.response.status, body: JSON.parse(s.response.body) }
        end
      end
    end

    threads.each(&:join)

    # --- Vérifications ---
    assert_equal 100, $redis.scard("scanned_tickets"), "Redis doit contenir exactement 100 billets uniques."

    successful_scans = results.select { |r| r[:status] == 200 }
    failed_scans = results.select { |r| r[:status] == 422 }

    assert_equal 100, successful_scans.count, "Il devrait y avoir exactement 100 scans réussis (200 OK)."
    assert_equal 100, failed_scans.count, "Il devrait y avoir exactement 100 scans échoués (422 Unprocessable Entity)."

    success_messages = successful_scans.map { |r| r[:body]["message"] }
    assert success_messages.all? { |m| m == "Validé" }

    error_messages = failed_scans.map { |r| r[:body]["message"] }
    assert error_messages.all? { |m| m == "Billet déjà scanné" }
  end
end
