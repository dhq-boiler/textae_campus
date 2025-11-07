class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: %i[google_oauth2]

  validates :email, presence: true, uniqueness: true
  validates :google_id, presence: true, uniqueness: true

  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.google_id = auth.uid
    end
  end

  # JWT認証トークンを生成
  def jwt_token
    payload = {
      google_id: google_id,
      exp: Time.now.to_i + 3600 # トークンの有効期限を1時間に設定
    }

    # JWT秘密鍵の取得（環境変数から、またはデフォルト値）
    secret_key = ENV["JWT_SECRET_KEY"] || Rails.application.secret_key_base

    JWT.encode(payload, secret_key, "HS256")
  end
end
