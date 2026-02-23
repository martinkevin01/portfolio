# Configure une connexion globale à Redis.
# En production sur Heroku, elle utilisera automatiquement la variable d'environnement REDIS_URL.
# En développement, elle se connectera à un Redis local (si installé) ou vous devrez spécifier une URL.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")

redis_config = { url: redis_url }

# Ajoute les options SSL uniquement pour les URL Redis sécurisées (comme sur Heroku)
if redis_url.start_with?("rediss://")
  redis_config[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
end

$redis = Redis.new(redis_config)
