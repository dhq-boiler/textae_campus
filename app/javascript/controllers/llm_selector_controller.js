import { Controller } from "@hotwired/stimulus"

// LLM API Keys選択コントローラー
// 外部API (http://localhost:3000/api/llm_api_keys/) からデータを取得
// 注意: 外部サーバー側でCORS設定が必要
export default class extends Controller {
  static targets = ["apiKeySelect", "modelSelect"]
  static values = { url: String, jwtToken: String }

  connect() {
    this.loadApiKeys()
  }

  async loadApiKeys() {
    try {
      const headers = {
        'Content-Type': 'application/json',
      }

      // JWTトークンがある場合はAuthorizationヘッダーに追加
      if (this.jwtTokenValue) {
        headers['Authorization'] = `Bearer ${this.jwtTokenValue}`
      }

      const response = await fetch(this.urlValue || "/api/llm_api_keys/", {
        method: 'GET',
        mode: 'cors',
        headers: headers,
        credentials: 'omit' // クロスオリジンなのでクレデンシャルは送信しない
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()
      this.populateApiKeySelect(data.llm_api_keys)
    } catch (error) {
      console.error("Failed to load API keys:", error)
      // エラータイプに応じたメッセージを表示
      let errorMessage = 'APIキーの読み込みに失敗しました'
      if (error.message.includes('401')) {
        errorMessage = '認証エラー: JWTトークンが無効または期限切れです'
      } else if (error.message.includes('CORS')) {
        errorMessage = 'CORS設定エラー: 外部サーバーでCORS設定が必要です'
      } else if (error.message.includes('Failed to fetch')) {
        errorMessage = 'ネットワークエラー: 外部APIサーバー (localhost:3000) が起動していません'
      }
      this.apiKeySelectTarget.innerHTML = `<option value="">${errorMessage}</option>`
    }
  }

  populateApiKeySelect(apiKeys) {
    this.apiKeySelectTarget.innerHTML = '<option value="">APIキーを選択してください</option>'

    apiKeys.forEach(apiKey => {
      const option = document.createElement("option")
      option.value = apiKey.uuid
      option.textContent = apiKey.description
      option.dataset.models = JSON.stringify(apiKey.available_models)
      this.apiKeySelectTarget.appendChild(option)
    })
  }

  apiKeyChanged() {
    const selectedOption = this.apiKeySelectTarget.options[this.apiKeySelectTarget.selectedIndex]

    if (selectedOption && selectedOption.dataset.models) {
      const models = JSON.parse(selectedOption.dataset.models)
      this.populateModelSelect(models)
    } else {
      this.clearModelSelect()
    }
  }

  populateModelSelect(models) {
    this.modelSelectTarget.innerHTML = '<option value="">モデルを選択してください</option>'
    this.modelSelectTarget.disabled = false

    models.forEach(model => {
      const option = document.createElement("option")
      option.value = model.value
      option.textContent = model.label
      this.modelSelectTarget.appendChild(option)
    })

    this.updateFormSubmitButton()
  }

  clearModelSelect() {
    this.modelSelectTarget.innerHTML = '<option value="">APIキーを先に選択してください</option>'
    this.modelSelectTarget.disabled = true
    this.updateFormSubmitButton()
  }

  updateFormSubmitButton() {
    // AIアノテーションフォームコントローラーの送信ボタン状態を更新
    const formController = this.application.getControllerForElementAndIdentifier(
      this.element.closest('[data-controller*="ai-annotation-form"]'),
      "ai-annotation-form"
    )
    if (formController && typeof formController.updateSubmitButton === 'function') {
      formController.updateSubmitButton()
    }
  }
}
