# frozen_string_literal: true

require 'openssl'
require 'base64'
require 'scrypt'

# References
#  http://ruby-doc.org/stdlib-2.0.0/libdoc/openssl/rdoc/OpenSSL/Cipher.html
#  http://stuff-things.net/2015/02/12/symmetric-encryption-with-ruby-and-rails/
#  https://adamcaudill.com/2016/09/19/ruby-gcm-nonce-reuse-language-sets-fail/

module Orchestrator
    module Encryption
        def self.encode_setting(id, key, clear_text)
            return clear_text if clear_text[0] == "\e"

            # Always use a new random salt for each encoding (protects the password)
            salt = ::SCrypt::Engine.generate_salt

            # Cipher is authenticated by the keys where it is stored
            cipher = ::OpenSSL::Cipher::AES.new(256, :GCM)
            cipher.encrypt
            cipher.key = self.get_password(salt)
            iv = cipher.random_iv
            cipher.auth_data = "#{id}|#{key}"

            encrypted = cipher.update(clear_text) + cipher.final
            tag = cipher.auth_tag

            # All this information is OK to be public
            "\e#{salt}|#{::Base64.encode64(iv)}|#{::Base64.encode64(tag)}|#{::Base64.encode64(encrypted)}"
        end

        def self.decode_setting(id, key, data)
            return data unless data[0] == "\e"
            salt, iv, tag, encrypted = data[1..-1].split('|', 4)

            decipher = ::OpenSSL::Cipher::AES.new(256, :GCM)
            decipher.decrypt
            decipher.key = self.get_password(salt)
            decipher.iv = ::Base64.decode64(iv)
            decipher.auth_tag = ::Base64.decode64(tag)
            decipher.auth_data = "#{id}|#{key}"

            "#{decipher.update(::Base64.decode64(encrypted))}#{decipher.final}"
        end

        def self.get_password(salt)
            pass = ::SCrypt::Engine.hash_secret(::Rails.application.secrets.secret_key_base, salt)
            ::Digest::SHA256.digest(pass)
        end
    end
end
