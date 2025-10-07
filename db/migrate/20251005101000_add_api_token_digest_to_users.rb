require "openssl"

class AddApiTokenDigestToUsers < ActiveRecord::Migration[8.0]
  class LegacyUser < ActiveRecord::Base
    self.table_name = "users"
    self.inheritance_column = :_type_disabled
  end

  def up
    add_column :users, :api_token_digest, :string
    add_index :users, :api_token_digest, unique: true

    backfill_api_token_digests
  end

  def down
    remove_index :users, :api_token_digest
    remove_column :users, :api_token_digest
  end

  private

  def backfill_api_token_digests
    say_with_time "Backfilling API token digests" do
      secret = Rails.application.secret_key_base
      digestor = ->(token) { OpenSSL::HMAC.hexdigest("SHA256", secret, "api-token:#{token}") }

      LegacyUser.reset_column_information
      LegacyUser.where.not(api_token: nil).find_each do |user|
        raw_token = user[:api_token].to_s
        next if raw_token.blank?

        digest = digestor.call(raw_token)
        user.update_columns(api_token_digest: digest, api_token: nil)
      end
    end
  end
end
