import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ai-annotation-form"
export default class extends Controller {
  static targets = ["text", "prompt", "submit"]

  connect() {
    this.updateSubmitButton()
  }

  updateSubmitButton() {
    const textField = this.hasTextTarget ? this.textTarget.value.trim() : true
    const promptField = this.promptTarget.value.trim()
    const apiKeySelect = document.querySelector('[data-llm-selector-target="apiKeySelect"]')
    const modelSelect = document.querySelector('[data-llm-selector-target="modelSelect"]')

    const apiKeySelected = apiKeySelect && apiKeySelect.value
    const modelSelected = modelSelect && modelSelect.value && !modelSelect.disabled

    const isValid = textField && promptField && apiKeySelected && modelSelected

    this.submitTarget.disabled = !isValid
  }
}
