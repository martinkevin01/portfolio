import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="navbar"
export default class extends Controller {
  static targets = ["platform"]
  toggleSelection(event) {
    const navlink = event.currentTarget;
    navlink.ClassList.toggle("active")
    console.log(test);

  }
}
