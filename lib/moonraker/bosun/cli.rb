# frozen_string_literal: true

module Moonraker
  module Bosun
    class CLI
      COMMANDS = {
        "roots" => Commands::Roots,
        "ls" => Commands::Ls,
        "get" => Commands::Get,
        "add" => Commands::Add,
        "pull" => Commands::Pull,
        "status" => Commands::Status,
        "audit" => Commands::Audit,
        "diff" => Commands::Diff,
        "push" => Commands::Push,
        "forget" => Commands::Forget,
        "rm" => Commands::Rm,
        "backup" => Commands::Backup,
        "export" => Commands::Export
      }.freeze

      def initialize(out: $stdout, err: $stderr, env: ENV, cwd: nil, client: nil)
        @context = Context.new(out: out, err: err, env: env, cwd: cwd, client: client)
      end

      # メッセージの言語は、環境変数(LC_ALL、LC_MESSAGES、LANG)で決める
      def run(argv)
        Messages.with_locale(Messages.locale_from_env(@context.env)) { dispatch(argv) }
      end

      private

      def dispatch(argv)
        name, *args = argv
        case name
        when nil, "help", "-h", "--help"
          @context.out.print usage
          0
        else
          command = COMMANDS[name]
          unless command
            @context.err.puts "bosun: #{Messages.t(:"cli.unknown_command", name: name)}"
            @context.err.print usage
            return 1
          end
          command.new(@context).run(args)
        end
      rescue Error, SystemCallError => e
        # ファイルの書き込みの失敗(Errno::EACCESなど)も、スタックトレースではなくメッセージだけを表示する
        @context.err.puts "bosun: #{e.message}"
        1
      rescue Interrupt
        @context.err.puts "bosun: #{Messages.t(:"cli.interrupted")}"
        130
      end

      def usage
        width = COMMANDS.keys.map(&:size).max
        lines = COMMANDS.map { |name, command| format("  %-*s  %s", width, name, command.summary) }
        Messages.t(:"cli.usage", commands: lines.join("\n"))
      end
    end
  end
end
