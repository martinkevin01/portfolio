class ZafemCountChannel < ApplicationCable::Channel
  def subscribed
    # Crée un flux public auquel tout client peut s'abonner.
    stream_from "zafem_count_channel"
  end

  def unsubscribed
    # Tout nettoyage nécessaire lorsque le canal est désabonné
  end
end
