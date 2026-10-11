# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Rm < Base
        include Fetching
        include Removing

        def run(args)
          dry_run = false
          args = parse_options(args) do |o|
            o.on("-n", "--dry-run", t(:"rm.dry_run_option")) { dry_run = true }
          end
          return 0 unless args
          raise Error, t(:"rm.no_files") if args.empty?

          paths = args.uniq
          check_removable!(paths)
          check_not_printing!
          infos = check_host!(paths)

          paths.each { |path| out.puts t(:"rm.plan", path: path) }
          if dry_run
            out.puts
            out.puts t(:"rm.dry_run")
            return 0
          end

          out.puts
          execute(paths, infos)
          0
        end

        private

        # ホストのファイルが、最後に取得した内容と一致することを厳密に確認する
        def check_host!(paths)
          infos = list_config_files
          tracked_tree = @context.git.ls_tree(tracking.tip, HostTracking::CONFIG_DIR)
          problems = paths.filter_map do |path|
            info = infos[path]
            if info.nil?
              t(:"rm.host_deleted", path: path)
            elsif !info.writable?
              t(:"rm.not_writable", path: path)
            elsif host_blob(path) != tracked_tree[HostTracking.repo_path(path)]
              # 最後に取得した後のホストでの変更を、確認せずに失わないようにする
              t(:"rm.host_modified", path: path)
            end
          end
          return infos if problems.empty?

          details = problems.map { |problem| "  #{problem}" }.join("\n")
          raise Error, t(:"rm.aborted", details: details)
        end

        def host_blob(path)
          @context.git.hash_object(client.download(FileRules::CONFIG_ROOT, path), write: false)
        end

        def execute(paths, infos)
          check_unchanged_since_check!(paths, infos)

          deleted = []
          begin
            paths.each do |path|
              client.delete_file(FileRules::CONFIG_ROOT, path)
              deleted << path
              out.puts t(:"rm.deleted", path: path)
            end
          rescue StandardError, SignalException
            # Ctrl-Cなどで中断した場合も、削除できたファイルを記録する
            rest = paths - deleted
            @context.err.puts "bosun: #{t(:"rm.delete_failed", paths: rest.join(', '))}"
            # 削除できたファイルだけでも記録し、host-trackingが実際のホストとずれないようにする
            begin
              record(deleted) unless deleted.empty?
            rescue StandardError, SignalException => e
              @context.err.puts "bosun: #{t(:"rm.record_failed", message: e.message)}"
            end
            raise
          end
          record(deleted)
        end

        # 確認の後にホストで変更されていないかを、削除する直前の一覧で確認する
        def check_unchanged_since_check!(paths, infos)
          current = list_config_files
          changed = paths.reject do |path|
            now = current[path]
            now&.writable? && now.modified == infos[path].modified && now.size == infos[path].size
          end
          return if changed.empty?

          raise Error, t(:"rm.changed_since_check", paths: changed.join(", "))
        end

        def record(paths)
          commit_and_merge("rm", [], removed: paths.map { |path| HostTracking.repo_path(path) })
        end
      end
    end
  end
end
