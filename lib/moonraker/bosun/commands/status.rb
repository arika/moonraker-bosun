# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Status < Base
        include StatusReport

        def run(args)
          args = parse_options(args)
          return 0 unless args

          check_no_arguments!(args)

          git = @context.git
          report(git, SyncStatus.new(git: git, client: client, tracking: HostTracking.new(git)))
          0
        end
      end
    end
  end
end
