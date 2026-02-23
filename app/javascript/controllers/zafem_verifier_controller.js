import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Se connecte à data-controller="zafem-verifier"
export default class extends Controller {
  static targets = ["input", "result", "count", "breakdown"]

  connect() {
    console.log("Zafem Verifier Controller connected!")
    this.inputTarget.focus()
    this.loadInitialCount()
    this.subscribeToActionCable()
  }

  disconnect() {
    clearTimeout(this.timeout)
    this.unsubscribeFromActionCable()
  }

  // Action déclenchée à chaque saisie dans le champ
  verify() {
    console.log("Verify action triggered.")
    // Annule le précédent timeout et en crée un nouveau.
    // La vérification ne sera effectuée que 300ms après la dernière saisie.
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.performVerification(), 300)
  }

  async performVerification() {
    console.log("Performing verification...")
    const ticketNumber = this.inputTarget.value.trim()
    if (ticketNumber === "") {
      this.clearResult()
      return
    }

    // Ajoute le token CSRF pour la sécurité de Rails
    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

    try {
      const response = await fetch('/zafem/verify', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({ ticket_number: ticketNumber })
      })

      const data = await response.json()

      if (response.ok) {
        this.showSuccess(data.message, data.ticket_type, ticketNumber)
        // Le compteur est maintenant mis à jour via Action Cable pour tous les clients,
        // il n'est plus nécessaire de l'incrémenter localement.
      } else {
        this.showError(data.message, data.ticket_type)
      }
    } catch (error) {
      console.error("Erreur lors de la requête fetch:", error)
      this.showError("Erreur de connexion au serveur.")
    } finally {
      // Efface le champ pour le prochain scan après un court délai
      setTimeout(() => {
        this.inputTarget.value = ""
        this.inputTarget.focus()
      }, 1200)
    }
  }

  showSuccess(message, ticketType, ticketNumber) {
    this.resultTarget.innerHTML = `
      <div class="alert alert-success fs-3 text-center zafem-alert">
        <i class="fas fa-check-circle"></i> ${message}
        <p class="fs-5 mb-0">${ticketType} - #${ticketNumber}</p>
      </div>
    `
  }

  showError(message, ticketType = null) {
    this.resultTarget.innerHTML = `
      <div class="alert alert-danger fs-3 text-center zafem-alert">
        <i class="fas fa-times-circle"></i> ${message}
        ${ticketType ? `<p class="fs-5 mb-0">${ticketType}</p>` : ''}
      </div>
    `
  }

  clearResult() {
    this.resultTarget.innerHTML = ""
  }

  async loadInitialCount() {
    try {
      const response = await fetch('/zafem/status');
      if (response.ok) {
        const data = await response.json();
        this.updateDisplay(data);
      } else {
        console.error("Failed to load initial count.");
        this.countTarget.textContent = "0";
      }
    } catch (error) {
      console.error("Error loading initial count:", error);
      this.countTarget.textContent = "0";
    }
  }

  async resetScanned() {
    if (confirm("Êtes-vous sûr de vouloir réinitialiser la mémoire des billets scannés ?")) {
      const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

      try {
        const response = await fetch('/zafem/reset', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken
          }
        });

        const data = await response.json();

        if (response.ok) {
          // Le compteur et le détail sont mis à jour via Action Cable pour tous les clients.
          // Il n'est pas nécessaire de le faire ici.
          this.clearResult();
          alert(data.message); // Afficher la confirmation
        } else {
          alert("Erreur: Impossible de réinitialiser.");
        }
      } catch (error) {
        console.error("Reset error:", error);
        alert("Erreur de connexion lors de la réinitialisation.");
      }
    }
  }

  subscribeToActionCable() {
    // Crée une connexion au serveur Action Cable.
    // createConsumer() utilise l'URL fournie par la balise meta action_cable_meta_tag.
    this.channel = createConsumer().subscriptions.create("ZafemCountChannel", {
      connected: () => {
        console.log("Connecté au canal ZafemCountChannel.")
      },
      disconnected: () => {
        console.log("Déconnecté du canal ZafemCountChannel.")
      },
      // Appelé lorsque le serveur envoie des données sur ce canal.
      received: (data) => {
        this.updateDisplay(data);
      }
    })
  }

  unsubscribeFromActionCable() {
    if (this.channel) this.channel.unsubscribe()
  }

  updateDisplay(data) {
    // Met à jour le compteur total
    this.countTarget.textContent = data.total_count;

    // Construit et affiche le détail par catégorie sous forme de texte simple
    let breakdownHtml = '';
    for (const [category, count] of Object.entries(data.breakdown)) {
      // Utilise h3 comme demandé, avec un poids de police normal pour un look plus léger.
      breakdownHtml += `<h3 class="mt-2 fw-normal">${category}: ${count}</h3>`;
    }
    this.breakdownTarget.innerHTML = breakdownHtml;
  }
}
