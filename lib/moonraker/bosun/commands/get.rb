# frozen_string_literal: true

module Moonraker
  module Bosun
    module Commands
      class Get < Base
        def run(args)
          root = FileRules::CONFIG_ROOT
          args = parse_options(args) do |o|
            o.on("-r", "--root ROOT", t(:"common.root_option")) { |v| root = v }
          end
          return 0 unless args
          raise Error, t(:"get.no_files") if args.empty?

          targets = args.map do |path|
            validate_path!(path)
            [path, File.basename(path)]
          end
          check_destinations!(targets.map(&:last))

          # 途中で失敗したときに一部のファイルだけが残らないよう、すべて取得してから書き込む
          contents = targets.map { |path, name| [name, download(root, path)] }
          contents.each do |name, body|
            File.open(File.join(@context.cwd, name), File::WRONLY | File::CREAT | File::EXCL | File::BINARY) do |f|
              f.write(body)
            end
            out.puts t(:"common.fetched", path: name)
          end
          0
        end

        private

        def check_destinations!(names)
          duplicated = names.tally.select { |_, count| count > 1 }.keys
          raise Error, t(:"get.duplicated", names: duplicated.join(", ")) unless duplicated.empty?

          existing = names.select do |name|
            path = File.join(@context.cwd, name)
            File.exist?(path) || File.symlink?(path)
          end
          return if existing.empty?

          raise Error, t(:"get.exists", names: existing.join(", "))
        end

        def download(root, path)
          client.download(root, path)
        rescue Client::APIError => e
          raise unless e.code == 404

          raise Error, t(:"common.file_not_on_host", path: "#{root}/#{path}")
        end
      end
    end
  end
end
