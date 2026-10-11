# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      # forgetとrmで共通の処理
      module Removing
        private

        # 指定したファイルがトラッキング中で、ローカルで変更されていないことを確認する
        def check_removable!(paths)
          paths.each { |path| validate_path!(path) }
          tracked = tracked_paths
          untracked = paths.reject { |path| tracked.include?(path) }
          raise Error, t(:"remove.not_tracked", paths: untracked.join(", ")) unless untracked.empty?

          tracking.check_workspace!(paths.map { |path| HostTracking.repo_path(path) })
          check_not_modified_locally!(paths)
        end

        # マージで変更と削除が衝突するので、ローカル(HEAD)で変更されているファイルは先に中止する
        # (ローカルで削除したファイルは指定できる)
        def check_not_modified_locally!(paths)
          tracked_tree = @context.git.ls_tree(tracking.tip, HostTracking::CONFIG_DIR)
          local_tree = @context.git.ls_tree("HEAD", HostTracking::CONFIG_DIR)
          modified = paths.select do |path|
            repo_path = HostTracking.repo_path(path)
            local_tree.key?(repo_path) && local_tree[repo_path] != tracked_tree[repo_path]
          end
          return if modified.empty?

          raise Error, t(:"remove.locally_modified", paths: modified.join(", "),
                                                     branch: HostTracking::BRANCH, dir: HostTracking::CONFIG_DIR)
        end
      end
    end
  end
end
