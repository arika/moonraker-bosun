# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Add < Base
        include Fetching

        def run(args)
          args = parse_options(args)
          return 0 unless args
          raise Error, t(:"add.no_files") if args.empty?

          args.each { |path| validate_path!(path) }
          paths = args.uniq
          tracking.check_workspace!(paths.map { |path| HostTracking.repo_path(path) })

          infos = list_config_files
          paths.each { |path| check_target!(path, infos[path]) }

          commit_and_merge("add", fetch(paths, infos))
          0
        end

        private

        def check_target!(path, info)
          raise Error, t(:"common.file_not_on_host", path: "#{FileRules::CONFIG_ROOT}/#{path}") unless info

          reason = FileRules.exclusion(FileRules::CONFIG_ROOT, info)
          return unless reason

          raise Error, t(:"add.excluded", reason: FileRules.reason_text(reason), path: path)
        end
      end
    end
  end
end
