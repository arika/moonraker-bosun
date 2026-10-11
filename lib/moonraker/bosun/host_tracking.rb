# frozen_string_literal: true

require "tmpdir"

module Moonraker
  module Bosun
    # host-trackingブランチの操作
    #
    # docs/design.md を参照。
    class HostTracking
      include Messages

      BRANCH = "host-tracking"
      REF = "refs/heads/#{BRANCH}".freeze

      # Moonrakerのroot configに対応するリポジトリのディレクトリ
      CONFIG_DIR = "config"
      # Moonraker DBのバックアップを置くディレクトリ
      DB_BACKUP_DIR = "backup/moonraker-db"

      # ホストから取得したファイル
      #
      # infoはファイル一覧の情報(Client::FileInfo)。Moonraker DBのバックアップの場合はnil
      Fetched = Data.define(:repo_path, :content, :info)

      class MergeError < Error; end

      ZERO_OID = "0" * 40

      def self.repo_path(host_path) = "#{CONFIG_DIR}/#{host_path}"
      def self.host_path(repo_path) = repo_path.delete_prefix("#{CONFIG_DIR}/")

      # コミットメッセージに記録した、取得時のホスト側の値
      Recorded = Data.define(:modified, :size)

      HOST_FILE = /^Host-File: (?<path>.+) modified=(?<modified>\S+) size=(?<size>\d+)$/
      HOST_FILE_DELETED = /^Host-File: (?<path>.+) deleted$/
      HOST_DB = /^Host-DB: (?<path>.+)$/

      def initialize(git)
        @git = git
      end

      def tip = @git.rev_parse(REF)

      # host-trackingへのコミットや、そのマージを行える状態かを確認する
      #
      # paths: 今回取得するファイルのリポジトリ上のパス
      def check_workspace!(paths)
        branch = @git.current_branch
        raise Error, t(:"tracking.detached_head") unless branch
        raise Error, t(:"tracking.on_tracking_branch", branch: BRANCH) if branch == BRANCH
        raise Error, t(:"tracking.no_head") unless @git.rev_parse("HEAD")
        raise Error, t(:"tracking.merge_in_progress") if @git.merge_in_progress?
        # git mergeは、indexに変更があると対象のファイルと関係がなくても中止する
        raise Error, t(:"tracking.staged_changes") if @git.staged_changes?

        dirty = @git.dirty_paths((paths + unmerged_paths).uniq)
        return if dirty.empty?

        raise Error, t(:"tracking.dirty", paths: dirty.map { |path| "  #{path}" }.join("\n"))
      end

      OPS = %w[add pull push backup forget rm].freeze
      TOP_DIRS = %w[config backup].freeze

      # 不変条件(docs/design.md)を検査し、違反の説明の配列を返す
      def check_invariants
        commit = tip
        return [] unless commit

        @git.run("rev-list", "--parents", commit).lines(chomp: true).flat_map do |line|
          sha, *parents = line.split
          check_commit(sha, parents)
        end
      end

      # 取得したファイルと、除くファイル(リポジトリ上のパス)をhost-trackingにコミットする
      #
      # 作業ツリーとindexは使わない。ツリーが変わらない場合はコミットせずにnilを返す。
      def commit(op, fetched, removed: [])
        parent = tip
        Dir.mktmpdir("bosun-index") do |dir|
          env = { "GIT_INDEX_FILE" => File.join(dir, "index") }
          @git.run("read-tree", parent, env: env) if parent
          entries = fetched.map { |f| "100644 #{@git.hash_object(f.content)}\t#{f.repo_path}\0" }
          # モードが0の行は、indexからそのパスを除く
          entries += removed.map { |path| "0 #{ZERO_OID}\t#{path}\0" }
          @git.run("update-index", "-z", "--index-info", stdin: entries.join, env: env)
          tree = @git.run("write-tree", env: env).strip
          return nil if parent && tree == @git.tree_of(parent)

          args = ["commit-tree", tree, "-F", "-"]
          args += ["-p", parent] if parent
          commit = @git.run(*args, stdin: message(op, fetched, removed)).strip
          # 途中でhost-trackingが変わっていた場合は失敗させる(初回は存在しないことを確認する)
          @git.run("update-ref", "-m", "bosun #{op}", REF, commit, parent || "")
          commit
        end
      end

      # host-trackingを現在のブランチにマージする
      #
      # マージした場合はtrue、すでに取り込まれている場合はfalseを返す。
      def merge(message)
        commit = tip
        return false if commit.nil? || @git.ancestor?(commit, "HEAD")

        # fast-forwardすると現在のブランチのツリーがhost-trackingのものになり、コードが消えるので必ず禁止する
        args = ["merge", "--no-ff", "--no-edit", "-m", message]
        args << "--allow-unrelated-histories" unless @git.merge_base("HEAD", commit)
        result = @git.capture(*args, BRANCH)
        return true if result.success?

        if @git.merge_in_progress?
          raise MergeError, t(:"tracking.merge_conflict", branch: BRANCH, output: result.stdout.strip)
        end

        raise MergeError, t(:"tracking.merge_failed", branch: BRANCH, output: result.stderr.strip)
      end

      # ファイルごとに、最後に記録したRecordedを返す(リポジトリ上のパスがキー)
      def recorded
        commit = tip
        return {} unless commit

        result = {}
        seen = {}
        # 新しいコミットから順に見て、最初に見つかった記録を使う
        @git.run("log", "--format=%B%x00", commit).split("\0").each do |body|
          body.each_line(chomp: true) do |line|
            if (m = HOST_FILE.match(line))
              next if seen[m[:path]]

              seen[m[:path]] = true
              result[m[:path]] = Recorded.new(modified: Float(m[:modified]), size: Integer(m[:size]))
            elsif (m = HOST_FILE_DELETED.match(line))
              seen[m[:path]] = true
            end
          end
        end
        result
      end

      private

      def check_commit(sha, parents)
        short = sha[0, 7]
        problems = []
        problems << t(:"invariant.merge_commit", commit: short, count: parents.size) if parents.size > 1

        body = @git.run("log", "-1", "--format=%B", sha)
        op = body[/^Host-Op: (.+)$/, 1]
        if op.nil?
          problems << t(:"invariant.no_op", commit: short)
        elsif !OPS.include?(op)
          problems << t(:"invariant.unknown_op", commit: short, op: op)
        end

        tree = @git.ls_tree_with_size(sha)
        outside = tree.keys.reject { |path| TOP_DIRS.any? { |dir| path.start_with?("#{dir}/") } }
        unless outside.empty?
          dirs = TOP_DIRS.map { |dir| "#{dir}/" }.join(t(:"invariant.dir_separator"))
          more = outside.size > 3 ? t(:"invariant.more", count: outside.size - 3) : ""
          problems << t(:"invariant.outside", commit: short, dirs: dirs, paths: "#{outside.first(3).join(', ')}#{more}")
        end

        body.each_line(chomp: true) do |line|
          if (m = HOST_DB.match(line))
            problems << t(:"invariant.db_missing", commit: short, path: m[:path]) unless tree.key?(m[:path])
            next
          end
          if (m = HOST_FILE_DELETED.match(line))
            problems << t(:"invariant.deleted_present", commit: short, path: m[:path]) if tree.key?(m[:path])
            next
          end
          next unless (m = HOST_FILE.match(line))

          entry = tree[m[:path]]
          if entry.nil?
            problems << t(:"invariant.file_missing", commit: short, path: m[:path])
          elsif entry[1] != Integer(m[:size])
            problems << t(:"invariant.size_mismatch", commit: short, recorded: m[:size], actual: entry[1],
                                                      path: m[:path])
          end
        end
        problems
      end

      # host-trackingにあって)、まだ現在のブランチに取り込んでいない変更のパス
      def unmerged_paths
        commit = tip
        return [] unless commit

        base = @git.merge_base("HEAD", commit)
        base ? @git.diff_paths(base, commit) : @git.ls_tree_paths(commit)
      end

      def message(op, fetched, removed)
        count = fetched.size + removed.size
        lines = ["#{op}: #{count} #{count == 1 ? 'file' : 'files'}", "", "Host-Op: #{op}"]
        fetched.each do |f|
          lines << if f.info
                     "Host-File: #{f.repo_path} modified=#{f.info.modified} size=#{f.info.size}"
                   else
                     "Host-DB: #{f.repo_path}"
                   end
        end
        removed.each { |path| lines << "Host-File: #{path} deleted" }
        "#{lines.join("\n")}\n"
      end
    end
  end
end
