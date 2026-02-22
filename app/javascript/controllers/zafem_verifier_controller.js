import { Controller } from "@hotwired/stimulus"

// Se connecte à data-controller="zafem-verifier"
export default class extends Controller {
  static targets = ["input", "result", "count"]

  connect() {
    console.log("Zafem Verifier Controller connected!")
    this.inputTarget.focus()
    this.loadInitialCount()
  }

  disconnect() {
    clearTimeout(this.timeout)
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
        const currentCount = parseInt(this.countTarget.textContent) || 0
        this.countTarget.textContent = currentCount + 1
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
      <div class="alert alert-success fs-3">
        <i class="fas fa-check-circle"></i> ${message}
        <p class="fs-5 mb-0">${ticketType} - #${ticketNumber}</p>
      </div>
    `
  }

  showError(message, ticketType = null) {
    this.resultTarget.innerHTML = `
      <div class="alert alert-danger fs-3">
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
        this.countTarget.textContent = data.count;
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
          this.countTarget.textContent = data.count; // Mettre à jour le compteur à 0
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
}
