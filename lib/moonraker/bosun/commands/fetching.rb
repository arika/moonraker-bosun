# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      # ホストから取得してhost-trackingにコミットし、現在のブランチにマージする処理
      module Fetching
        private

        def tracking
          @tracking ||= HostTracking.new(@context.git)
        end

        def list_config_files
          client.list_files(FileRules::CONFIG_ROOT).to_h { |info| [info.path, info] }
        end

        # pathsはRoot configからのパス
        def fetch(paths, infos)
          paths.map do |path|
            fetched = HostTracking::Fetched.new(
              repo_path: HostTracking.repo_path(path),
              content: client.download(FileRules::CONFIG_ROOT, path),
              info: infos.fetch(path)
            )
            out.puts t(:"common.fetched", path: fetched.repo_path)
            fetched
          end
        end

        # removedはリポジトリ上のパス
        def commit_and_merge(op, fetched, removed: [])
          parent = tracking.tip
          commit = fetched.empty? && removed.empty? ? nil : tracking.commit(op, fetched, removed: removed)
          if commit
            changed = parent ? @context.git.diff_paths(parent, commit) : fetched.map(&:repo_path).sort
            out.puts t(:"tracking.committed", branch: HostTracking::BRANCH, commit: commit[0, 7])
            changed.each do |path|
              out.puts t(removed.include?(path) ? :"tracking.removed" : :"tracking.changed", path: path)
            end
          else
            changed = []
            out.puts t(:"tracking.no_change", branch: HostTracking::BRANCH)
          end
          merge(op, changed)
        end

        def check_not_printing!
          state = client.print_state
          return unless %w[printing paused].include?(state)

          raise Error, t(:"common.printing", state: state)
        end

        # トラッキング中のファイル(Root configからのパス)
        def tracked_paths
          tip = tracking.tip
          raise Error, t(:"common.no_tracked_files") unless tip

          @context.git.ls_tree_paths(tip, HostTracking::CONFIG_DIR).map { |path| HostTracking.host_path(path) }
        end

        def merge(op, changed)
          detail = changed.empty? ? op : "#{op}: #{changed.join(', ')}"
          # gitに記録するメッセージなので、表示の言語によらず英語にする
          return unless tracking.merge("Merge #{HostTracking::BRANCH} (#{detail})")

          out.puts t(:"tracking.merged", branch: @context.git.current_branch)
        rescue HostTracking::MergeError => e
          @context.err.puts "bosun: #{e.message}"
          raise Error, t(:"tracking.merge_incomplete")
        end
      end
    end
  end
end
