# Configure une connexion globale à Redis.
# En production sur Heroku, elle utilisera automatiquement la variable d'environnement REDIS_URL.
# En développement, elle se connectera à un Redis local (si installé) ou vous devrez spécifier une URL.
$redis = Redis.new(
  url: ENV["REDIS_URL"],
  ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
)
