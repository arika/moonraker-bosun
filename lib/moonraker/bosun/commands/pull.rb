# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Pull < Base
        include Fetching

        def run(args)
          args = parse_options(args)
          return 0 unless args

          check_no_arguments!(args)

          tip = tracking.tip
          raise Error, t(:"common.no_tracked_files") unless tip

          tracked = @context.git.ls_tree_paths(tip, HostTracking::CONFIG_DIR).map { |path| HostTracking.host_path(path) }
          tracking.check_workspace!(tracked.map { |path| HostTracking.repo_path(path) })

          infos = list_config_files
          deleted = tracked.reject { |path| infos.key?(path) }
          read_only = tracked.select { |path| infos.key?(path) && !infos[path].writable? }
          targets = tracked - deleted - read_only
          untracked = infos.keys.sort.select do |path|
            !tracked.include?(path) && FileRules.exclusion(FileRules::CONFIG_ROOT, infos[path]).nil?
          end

          fetched = fetch(targets, infos)
          # マージで衝突した場合でも確認できるよう、マージの前に表示する
          warn_skipped(:host_deleted, deleted)
          warn_skipped(:host_read_only, read_only)
          warn_skipped(:untracked, untracked)
          commit_and_merge("pull", fetched)
          0
        end

        private

        def warn_skipped(state, paths)
          return if paths.empty?

          out.puts
          out.puts t(:"common.not_fetched", label: SyncStatus.label(state))
          paths.each { |path| out.puts "  #{path}" }
          print_guide(SyncStatus.guide(state))
          out.puts
        end
      end
    end
  end
end
