# frozen_string_literal: true

require "open3"

module Moonraker
  module Bosun
    # gitコマンドの実行
    class Git
      # パスにglobなどを含んでいても、そのまま扱わせる
      BASE_ENV = { "GIT_LITERAL_PATHSPECS" => "1" }.freeze

      Result = Data.define(:stdout, :stderr, :status) do
        def success? = status.success?
      end

      def self.open(dir)
        stdout, _, status = Open3.capture3(BASE_ENV, "git", "-C", dir, "rev-parse", "--show-toplevel")
        raise Error, Messages.t(:"git.not_repository", dir: dir) unless status.success?

        new(stdout.chomp)
      end

      attr_reader :root

      def initialize(root)
        @root = root
      end

      # 失敗した場合はErrorを発生させ、標準出力を返す
      def run(*args, stdin: nil, env: {})
        result = capture(*args, stdin: stdin, env: env)
        raise Error, Messages.t(:"git.failed", command: args.first, message: result.stderr.strip) unless result.success?

        result.stdout
      end

      # 失敗しても例外を発生させず、Resultを返す
      def capture(*, stdin: nil, env: {})
        stdout, stderr, status = Open3.capture3(
          BASE_ENV.merge(env), "git", "-C", @root, *,
          stdin_data: stdin.to_s, binmode: true
        )
        Result.new(stdout: utf8(stdout), stderr: utf8(stderr), status: status)
      end

      # コミットを指すrevならSHA-1を返し、なければnilを返す
      def rev_parse(rev)
        result = capture("rev-parse", "--verify", "--quiet", "#{rev}^{commit}")
        result.success? ? result.stdout.strip : nil
      end

      def tree_of(rev) = run("rev-parse", "#{rev}^{tree}").strip

      # 現在のブランチ名。detached HEADならnil
      def current_branch
        result = capture("symbolic-ref", "--quiet", "--short", "HEAD")
        result.success? ? result.stdout.strip : nil
      end

      def merge_in_progress? = !rev_parse("MERGE_HEAD").nil?

      # indexにHEADからの変更(ステージ済みの変更)があるか
      def staged_changes?
        !capture("diff", "--cached", "--quiet").success?
      end

      def ancestor?(ancestor, descendant)
        capture("merge-base", "--is-ancestor", ancestor, descendant).success?
      end

      def merge_base(a, b)
        result = capture("merge-base", a, b)
        result.success? ? result.stdout.strip : nil
      end

      # ファイルの内容をそのままblobとして書き込む(フィルタは適用しない)
      def hash_object(content, write: true)
        args = ["hash-object", "--no-filters", "--stdin"]
        args.insert(1, "-w") if write
        run(*args, stdin: content).strip
      end

      # パスとblobのSHA-1の対応
      def ls_tree(rev, *paths)
        run("ls-tree", "-r", "-z", rev, "--", *paths).split("\0").to_h do |entry|
          meta, path = entry.split("\t", 2)
          [path, meta.split[2]]
        end
      end

      # パスとモード(100644、100755、120000など)の対応
      def ls_tree_modes(rev, *paths)
        run("ls-tree", "-r", "-z", rev, "--", *paths).split("\0").to_h do |entry|
          meta, path = entry.split("\t", 2)
          [path, meta.split[0]]
        end
      end

      def blob_size(blob) = run("cat-file", "-s", blob).to_i
      def cat_blob(blob) = run("cat-file", "blob", blob).b

      # パスと[blobのSHA-1, サイズ]の対応
      def ls_tree_with_size(rev)
        run("ls-tree", "-r", "-z", "-l", rev).split("\0").to_h do |entry|
          meta, path = entry.split("\t", 2)
          _mode, _type, blob, size = meta.split
          [path, [blob, size.to_i]]
        end
      end

      def ls_tree_paths(rev, *paths)
        run("ls-tree", "-r", "-z", "--name-only", rev, "--", *paths).split("\0")
      end

      def diff_paths(from, to)
        run("diff", "--name-only", "-z", "--no-renames", from, to).split("\0")
      end

      # 作業ツリーやindexに変更があるパス(git管理外のファイルを含む)
      def dirty_paths(paths)
        return [] if paths.empty?

        entries = run("status", "--porcelain=v1", "-z", "--untracked-files=all", "--", *paths).split("\0")
        paths = []
        until entries.empty?
          entry = entries.shift
          paths << entry[3..]
          # 名前の変更とコピーは、元のパスが続く
          paths << entries.shift if entry.start_with?("R", "C")
        end
        paths
      end

      private

      def utf8(string) = string.force_encoding(Encoding::UTF_8)
    end
  end
end
