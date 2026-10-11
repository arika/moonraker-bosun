# frozen_string_literal: true

require "uri"

module Moonraker
  module Bosun
    class Config
      ENV_BASE_URL = "MOONRAKER_BASE_URL"

      attr_reader :base_url

      def self.from_env(env = ENV)
        url = env[ENV_BASE_URL]
        raise Error, Messages.t(:"config.not_set", name: ENV_BASE_URL) if url.nil? || url.empty?

        new(base_url: url)
      end

      def initialize(base_url:)
        uri = URI.parse(base_url)
        unless uri.is_a?(URI::HTTP) && uri.host
          raise Error, Messages.t(:"config.not_http", name: ENV_BASE_URL, url: base_url)
        end

        @base_url = uri
      rescue URI::InvalidURIError
        raise Error, Messages.t(:"config.invalid_url", name: ENV_BASE_URL, url: base_url)
      end
    end
  end
end
