# frozen_string_literal: true

module Moonraker
  module Bosun
    # ホスト(H)、host-trackingの先頭(T)、HEAD(L)の3つを比べて、ファイルごとの状態を判定する
    #
    # docs/design.md の「状態の判定」を参照。
    class SyncStatus
      # 表示する順に並べる。見出しと案内はMessagesの state.<状態>.label と state.<状態>.guide
      STATES = %i[host_modified local_modified both_modified host_deleted both_deleted host_read_only
                  local_deleted host_modified_local_deleted local_added added_on_both untracked synced].freeze

      def self.label(state) = Messages.t(:"state.#{state}.label")

      # 解消するための手順の案内(同期済みにはない)
      def self.guide(state)
        return nil if state == :synced

        Messages.t(:"state.#{state}.guide", branch: HostTracking::BRANCH, dir: HostTracking::CONFIG_DIR)
      end

      # pathはRoot configからのパス
      Entry = Data.define(:path, :state)
      # ホストで名前を変更した可能性があるファイルの組
      Rename = Data.define(:from, :to)

      attr_reader :entries, :renames

      # strict: trueなら、トラッキング中のファイルをすべて取得して内容を比べる
      def initialize(git:, client:, tracking:, strict: false)
        @git = git
        @client = client
        @tracking = tracking
        @strict = strict
        compute
      end

      def tip = @tracking.tip

      # host-trackingに、まだ現在のブランチに取り込んでいないコミットがあるか
      def unmerged? = !tip.nil? && !@git.ancestor?(tip, "HEAD")

      def by_state(state) = @entries.select { |entry| entry.state == state }

      # pathはRoot configからのパス
      def host_info(path) = @host[path]
      def tracked_blob(path) = @tracked[path]
      def local_blob(path) = @local[path]
      def local_mode(path) = @local_modes[path]

      # ホストの内容を取得し、blobのSHA-1を返す
      def host_blob(path)
        @git.hash_object(@client.download(FileRules::CONFIG_ROOT, path), write: false)
      end

      private

      def compute
        @host = @client.list_files(FileRules::CONFIG_ROOT).to_h { |info| [info.path, info] }
        @tracked = tip ? tree(tip) : {}
        @local = tree("HEAD")
        @local_modes = @git.ls_tree_modes("HEAD", HostTracking::CONFIG_DIR)
                           .transform_keys { |path| HostTracking.host_path(path) }
        @recorded = @tracking.recorded

        untracked_candidates = @host.keys.select { |path| FileRules.exclusion(FileRules::CONFIG_ROOT, @host[path]).nil? }
        paths = (@tracked.keys | @local.keys | untracked_candidates).sort
        @entries = paths.map { |path| Entry.new(path: path, state: state_of(path)) }
        @renames = detect_renames
      end

      def tree(rev)
        @git.ls_tree(rev, HostTracking::CONFIG_DIR).transform_keys { |path| HostTracking.host_path(path) }
      end

      def state_of(path)
        host = @host[path]
        tracked = @tracked[path]
        local = @local[path]

        if tracked
          return local ? :host_deleted : :both_deleted unless host
          return :host_read_only unless host.writable?

          host_same = host_same?(path, host, tracked)
          if local.nil?
            host_same ? :local_deleted : :host_modified_local_deleted
          elsif local == tracked
            host_same ? :synced : :host_modified
          else
            host_same ? :local_modified : :both_modified
          end
        elsif local
          host ? :added_on_both : :local_added
        else
          :untracked
        end
      end

      # ホストの内容が、最後に取得した内容(blob)と同じか
      def host_same?(path, host, blob)
        unless @strict
          recorded = @recorded[HostTracking.repo_path(path)]
          if recorded
            return true if recorded.modified == host.modified && recorded.size == host.size
            # サイズが違えば内容も違う
            return false if recorded.size != host.size
          end
        end
        # 更新日時だけが違う場合などは、取得して内容を比べる
        host_blob(path) == blob
      end

      # ホストで削除されたファイルと同じ内容のトラッキングしていないファイルを、名前の変更の候補とする
      def detect_renames
        deleted = (by_state(:host_deleted) + by_state(:both_deleted)).map(&:path)
        untracked = by_state(:untracked).map(&:path)
        return [] if deleted.empty? || untracked.empty?

        deleted.flat_map do |from|
          blob = @tracked[from]
          size = @git.blob_size(blob)
          untracked.filter_map do |to|
            Rename.new(from: from, to: to) if @host[to].size == size && host_blob(to) == blob
          end
        end
      end
    end
  end
end
