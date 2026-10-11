# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Diff < Base
        def run(args)
          stat = false
          args = parse_options(args) do |o|
            o.on("--stat", t(:"diff.stat_option")) { stat = true }
          end
          return 0 unless args

          args.each { |path| validate_path!(path) }
          git = @context.git
          tip = HostTracking.new(git).tip
          raise Error, t(:"common.no_tracked_files") unless tip

          paths = args.empty? ? [HostTracking::CONFIG_DIR] : args.map { |path| HostTracking.repo_path(path) }
          options = ["--no-ext-diff", "--no-renames"]
          options << "--stat" if stat
          options << "--color=always" if out.respond_to?(:tty?) && out.tty?
          out.print git.run("diff", *options, HostTracking::BRANCH, "HEAD", "--", *paths)
          0
        end
      end
    end
  end
end
