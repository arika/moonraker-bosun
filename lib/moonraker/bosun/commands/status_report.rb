# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      # SyncStatusの表示(statusとauditで共通)
      module StatusReport
        private

        def report(git, status)
          print_summary(git, status)
          print_entries(status)
          print_renames(status)
          print_dirty(git)
        end

        def print_summary(git, status)
          if status.tip
            date = git.run("log", "-1", "--format=%cd", "--date=format-local:%Y-%m-%d %H:%M:%S", status.tip).strip
            out.puts "#{HostTracking::BRANCH}: #{status.tip[0, 7]} (#{date})"
          else
            out.puts t(:"status.no_tip", branch: HostTracking::BRANCH)
          end
          return unless status.unmerged?

          out.puts
          out.puts t(:"status.unmerged", branch: HostTracking::BRANCH)
          out.puts "  → #{t(:"status.unmerged_guide", branch: HostTracking::BRANCH)}"
        end

        def print_entries(status)
          SyncStatus::STATES.each do |state|
            next if state == :synced

            entries = status.by_state(state)
            next if entries.empty?

            out.puts
            out.puts "#{SyncStatus.label(state)}:"
            entries.each { |entry| out.puts "  #{entry.path}" }
            print_guide(SyncStatus.guide(state))
          end

          synced = status.by_state(:synced).size
          out.puts
          if synced == status.entries.size && synced.positive?
            out.puts t(:"status.all_synced", count: synced)
          else
            out.puts t(:"status.synced_count", count: synced)
          end
        end

        def print_renames(status)
          return if status.renames.empty?

          out.puts
          out.puts t(:"status.renames")
          status.renames.each do |rename|
            out.puts "  #{rename.from} → #{rename.to}"
            out.puts "  → #{t(:"status.rename_guide", to: rename.to, from: rename.from)}"
          end
        end

        def print_dirty(git)
          dirty = git.dirty_paths([HostTracking::CONFIG_DIR])
          return if dirty.empty?

          out.puts
          out.puts t(:"status.dirty")
          dirty.each { |path| out.puts "  #{path}" }
        end
      end
    end
  end
end
