# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Ls < Base
        def run(args)
          root = FileRules::CONFIG_ROOT
          all = false
          long = false
          args = parse_options(args) do |o|
            o.on("-r", "--root ROOT", t(:"common.root_option")) { |v| root = v }
            o.on("-a", "--all", t(:"ls.all_option")) { all = true }
            o.on("-l", "--long", t(:"ls.long_option")) { long = true }
          end
          return 0 unless args

          check_no_arguments!(args)

          entries = client.list_files(root).sort_by(&:path).filter_map do |info|
            reason = FileRules.exclusion(root, info)
            [info, reason] if all || reason.nil?
          end
          long ? print_long(entries) : entries.map(&:first).each { |info| out.puts info.path }
          0
        end

        private

        def print_long(entries)
          size_width = entries.map { |info, _| info.size.to_s.size }.max
          entries.each do |info, reason|
            line = format("%-2s  %*d  %s  %s",
                          info.permissions, size_width, info.size,
                          Time.at(info.modified).strftime("%Y-%m-%d %H:%M:%S"), info.path)
            line += "  #{t(:"ls.excluded", reason: FileRules.reason_text(reason))}" if reason
            out.puts line
          end
        end
      end
    end
  end
end
