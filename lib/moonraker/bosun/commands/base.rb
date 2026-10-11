# frozen_string_literal: true

require "optparse"

module Moonraker
  module Bosun
    module Commands
      class Base
        include Messages

        class << self
          # 一覧に表示する説明(<コマンド名>.summary)
          def summary = Messages.t(:"#{command_name}.summary")

          def command_name = name.split("::").last.downcase
        end

        def initialize(context)
          @context = context
        end

        private

        def out = @context.out
        def client = @context.client

        # オプションを解析する。--help を表示した場合はnilを返す
        def parse_options(args)
          parser = OptionParser.new
          parser.banner = t(:"#{self.class.command_name}.usage")
          yield parser if block_given?
          parser.on("-h", "--help", t(:"common.help_option")) do
            out.print parser.help
            return nil
          end
          parser.parse!(args)
          args
        rescue OptionParser::ParseError => e
          raise Error, t(:"common.invalid_option", message: e.message)
        end

        # 引数を取らないコマンドで、引数が指定されていないことを確認する
        def check_no_arguments!(args, command = self.class.command_name)
          raise Error, t(:"common.no_arguments", command: command, args: args.join(" ")) unless args.empty?
        end

        # 手順の案内を、1行ずつ「→」を付けて表示する
        def print_guide(guide)
          guide.each_line(chomp: true) { |line| out.puts "  → #{line}" }
        end

        def validate_path!(path)
          segments = path.split("/")
          return unless path.empty? || path.start_with?("/") || segments.include?("..")

          raise Error, t(:"common.invalid_path", path: path)
        end
      end
    end
  end
end
