# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Roots < Base
        def run(args)
          long = false
          args = parse_options(args) do |o|
            o.on("-l", "--long", t(:"roots.long_option")) { long = true }
          end
          return 0 unless args

          check_no_arguments!(args)

          # Moonrakerが返す順(configが先頭)のまま表示する
          roots = client.roots
          if long
            name_width = roots.map { |root| root.name.size }.max
            roots.each do |root|
              out.puts format("%-2s  %-*s  %s", root.permissions, name_width, root.name, root.path)
            end
          else
            roots.each { |root| out.puts root.name }
          end
          0
        end
      end
    end
  end
end
