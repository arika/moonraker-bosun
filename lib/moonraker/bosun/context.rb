# frozen_string_literal: true

module Moonraker
  module Bosun
    # コマンドの実行に必要な入出力や接続先
    class Context
      attr_reader :out, :err, :env, :cwd

      def initialize(out:, err:, env:, cwd: nil, client: nil)
        @out = out
        @err = err
        @env = env
        @cwd = cwd || Dir.pwd
        @client = client
      end

      def client
        @client ||= Client.new(Config.from_env(env).base_url)
      end

      def git
        @git ||= Git.open(cwd)
      end
    end
  end
end
