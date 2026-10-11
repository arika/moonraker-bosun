# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Forget < Base
        include Fetching
        include Removing

        def run(args)
          args = parse_options(args)
          return 0 unless args
          raise Error, t(:"forget.no_files") if args.empty?

          paths = args.uniq
          check_removable!(paths)

          commit_and_merge("forget", [], removed: paths.map { |path| HostTracking.repo_path(path) })
          out.puts
          out.puts t(:"forget.kept")
          0
        end
      end
    end
  end
end
