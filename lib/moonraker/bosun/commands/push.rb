# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Push < Base
        include Fetching

        def run(args)
          dry_run = false
          args = parse_options(args) do |o|
            o.on("-n", "--dry-run", t(:"push.dry_run_option")) { dry_run = true }
          end
          return 0 unless args

          check_no_arguments!(args)

          git = @context.git
          raise Error, t(:"common.no_tracked_files") unless tracking.tip

          # 反映の後にhost-trackingをマージするので、addやpullと同じ状態であることを確認する
          tracking.check_workspace!([HostTracking::CONFIG_DIR])
          check_not_printing!

          plan = PushPlan.new(SyncStatus.new(git: git, client: client, tracking: tracking))
          print_plan(plan)
          unless plan.ok?
            out.puts
            out.puts t(:"push.aborted")
            return 1
          end
          return 0 if plan.actions.empty?

          if dry_run
            out.puts
            out.puts t(:"push.dry_run")
            return 0
          end

          out.puts
          execute(plan.actions)
          out.puts
          out.puts t(:"push.restart")
          0
        end

        private

        def execute(actions)
          check_unchanged_since_plan!(actions)

          uploaded = []
          begin
            actions.each do |action|
              client.upload(FileRules::CONFIG_ROOT, action.path, @context.git.cat_blob(action.blob))
              uploaded << action
              out.puts t(:"push.uploaded", path: action.path)
            end
          rescue StandardError, SignalException
            # Ctrl-Cなどで中断した場合も、反映できたファイルを記録する
            rest = actions - uploaded
            @context.err.puts "bosun: #{t(:"push.upload_failed", paths: rest.map(&:path).join(', '))}"
            # 反映できたファイルだけでも記録し、host-trackingが実際のホストとずれないようにする
            begin
              record(uploaded) unless uploaded.empty?
            rescue StandardError, SignalException => e
              @context.err.puts "bosun: #{t(:"push.record_failed", message: e.message)}"
            end
            raise
          end
          record(uploaded)
        end

        # 計画を立てた後にホストで変更されていないかを、書き込む直前の一覧で確認する
        def check_unchanged_since_plan!(actions)
          infos = list_config_files
          changed = actions.reject do |action|
            info = infos[action.path]
            if action.kind == :create
              info.nil?
            else
              info&.writable? && info.modified == action.host.modified && info.size == action.host.size
            end
          end
          return if changed.empty?

          raise Error, t(:"push.changed_since_plan", paths: changed.map(&:path).join(", "))
        end

        # アップロードしたファイルを取得し直して、host-trackingにコミットする
        def record(actions)
          infos = list_config_files
          paths = actions.map(&:path)
          missing = paths.reject { |path| infos.key?(path) }
          raise Error, t(:"push.uploaded_missing", paths: missing.join(", ")) unless missing.empty?

          fetched = fetch(paths, infos)
          actions.zip(fetched).each do |action, f|
            next if @context.git.hash_object(f.content, write: false) == action.blob

            @context.err.puts "bosun: #{t(:"push.content_mismatch", path: action.path)}"
          end
          commit_and_merge("push", fetched)
        end

        def print_plan(plan)
          if plan.actions.empty? && plan.ok?
            out.puts t(:"push.nothing")
          else
            plan.actions.each { |action| out.puts t(:"push.#{action.kind}", path: action.path) }
          end

          unless plan.problems.empty?
            out.puts
            out.puts t(:"push.problems")
            plan.problems.each do |problem|
              out.puts "  #{problem.path}: #{problem.reason}"
              out.puts "    → #{problem.guide}"
            end
          end

          print_skipped(plan.skipped)
        end

        def print_skipped(skipped)
          skipped.group_by(&:state).each do |state, entries|
            out.puts
            out.puts t(:"push.skipped", label: SyncStatus.label(state))
            entries.each { |entry| out.puts "  #{entry.path}" }
            print_guide(SyncStatus.guide(state))
          end
        end
      end
    end
  end
end
