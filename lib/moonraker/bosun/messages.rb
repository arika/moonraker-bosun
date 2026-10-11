# frozen_string_literal: true

module Moonraker
  module Bosun
    # 表示するメッセージ(日本語と英語)
    #
    # 言語は、CLIの実行中だけスレッドごとに設定する(テストを並列に実行するため)。
    # 設定していないときは英語になる。
    module Messages
      DEFAULT_LOCALE = :en
      # POSIXと同じく、この順に見て最初に設定されているものを使う
      LOCALE_VARIABLES = %w[LC_ALL LC_MESSAGES LANG].freeze
      THREAD_KEY = :moonraker_bosun_locale
      PLACEHOLDER = /%\{(\w+)\}/

      module_function

      def locale_from_env(env)
        value = LOCALE_VARIABLES.map { |name| env[name] }.find { |v| v && !v.empty? }
        value&.start_with?("ja") ? :ja : DEFAULT_LOCALE
      end

      # Thread#[]はファイバーごとの値になるので、スレッドの中で共有するthread_variableを使う
      def locale = Thread.current.thread_variable_get(THREAD_KEY) || DEFAULT_LOCALE

      def with_locale(locale)
        previous = Thread.current.thread_variable_get(THREAD_KEY)
        Thread.current.thread_variable_set(THREAD_KEY, locale)
        yield
      ensure
        Thread.current.thread_variable_set(THREAD_KEY, previous)
      end

      # %{name}をparamsの値で置き換える
      def t(key, **params)
        CATALOG.fetch(key).fetch(locale).gsub(PLACEHOLDER) { params.fetch(Regexp.last_match(1).to_sym).to_s }
      end
    end
  end
end

require_relative "messages/catalog"
