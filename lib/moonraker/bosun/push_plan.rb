# frozen_string_literal: true

module Moonraker
  module Bosun
    # pushでホストに反映する内容と、反映できない理由を決める
    #
    # docs/design.md の「push」を参照。
    class PushPlan
      include Messages

      # kindは:createか:update。pathはRoot configからのパス
      # hostは計画を立てたときのホストのファイルの情報(作成の場合はnil)
      Action = Data.define(:path, :kind, :blob, :host)
      Problem = Data.define(:path, :reason, :guide)
      # 反映しないファイル(stateはSyncStatus::STATESのキー)
      Skipped = Data.define(:path, :state)

      # ホストには通常のファイルしか作れないので、これ以外のモード(シンボリックリンク、実行可能ファイル、
      # submoduleなど)は反映しない。host-trackingにはホストの内容を通常のファイルとして記録するため、
      # 反映するとマージでモードが衝突する
      REGULAR_FILE_MODE = "100644"

      # 反映の対象にしないが、知らせる状態
      NOTICE_STATES = %i[host_modified local_deleted host_modified_local_deleted
                         host_deleted both_deleted host_read_only].freeze

      attr_reader :actions, :problems, :skipped

      def initialize(status)
        @status = status
        raise Error, unmerged_message if status.unmerged?

        @actions = []
        @problems = []
        @skipped = []
        status.entries.each { |entry| plan(entry) }
      end

      def ok? = @problems.empty?

      private

      def plan(entry)
        tracked = @status.tracked_blob(entry.path)
        local = @status.local_blob(entry.path)
        # ローカルにあり、最後に取得した内容と違うファイルが対象
        if local && local != tracked
          mode = @status.local_mode(entry.path)
          return problem(entry.path, :not_regular_file, mode: mode) unless mode == REGULAR_FILE_MODE

          tracked ? plan_update(entry.path, local, tracked) : plan_create(entry.path, local)
        elsif NOTICE_STATES.include?(entry.state)
          @skipped << Skipped.new(path: entry.path, state: entry.state)
        end
      end

      def plan_update(path, local, tracked)
        host = @status.host_info(path)
        if host.nil?
          problem(path, :host_deleted)
        elsif !host.writable?
          problem(path, :not_writable)
        elsif @status.host_blob(path) != tracked
          # 最後に取得した後にホストで変更された内容を、上書きしないようにする
          problem(path, :host_modified, :pull)
        else
          @actions << Action.new(path: path, kind: :update, blob: local, host: host)
        end
      end

      def plan_create(path, local)
        if @status.host_info(path)
          problem(path, :exists)
        elsif FileRules.host_backup?(path)
          problem(path, :backup_name)
        else
          @actions << Action.new(path: path, kind: :create, blob: local, host: nil)
        end
      end

      # 理由は plan.<reason>、案内は plan.<guide>_guide(省略時は理由と同じ名前)
      def problem(path, reason, guide = reason, **params)
        @problems << Problem.new(path: path, reason: t(:"plan.#{reason}", **params), guide: t(:"plan.#{guide}_guide"))
      end

      def unmerged_message = t(:"plan.unmerged", branch: HostTracking::BRANCH)
    end
  end
end
