# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Audit < Base
        include StatusReport

        def run(args)
          args = parse_options(args)
          return 0 unless args

          check_no_arguments!(args)

          git = @context.git
          tracking = HostTracking.new(git)
          problems = tracking.check_invariants
          status = SyncStatus.new(git: git, client: client, tracking: tracking, strict: true)

          report(git, status)
          print_invariants(problems)

          # トラッキングしていないファイルは、あえてトラッキングしないこともあるので問題としない
          ok = problems.empty? && !status.unmerged? && status.renames.empty? &&
               status.entries.all? { |entry| %i[synced untracked].include?(entry.state) }
          out.puts
          out.puts ok ? t(:"audit.ok") : t(:"audit.ng")
          ok ? 0 : 1
        end

        private

        def print_invariants(problems)
          out.puts
          if problems.empty?
            out.puts t(:"audit.invariants_ok", branch: HostTracking::BRANCH)
            return
          end

          out.puts t(:"audit.invariants_violated", branch: HostTracking::BRANCH)
          problems.each { |problem| out.puts "  #{problem}" }
          out.puts "  → #{t(:"audit.repair_guide", branch: HostTracking::BRANCH)}"
          out.puts "  → #{t(:"audit.design_guide")}"
        end
      end
    end
  end
end
