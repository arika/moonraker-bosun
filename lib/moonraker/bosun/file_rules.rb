# frozen_string_literal: true

module Moonraker
  module Bosun
    # ホストのファイルを一覧やトラッキングの対象にするかどうかの判定
    #
    # docs/design.md の「対象のファイル」を参照。
    module FileRules
      CONFIG_ROOT = "config"

      # Klipperの SAVE_CONFIG によるもの: <名前>-YYYYMMDD_HHMMSS.cfg
      KLIPPER_BACKUP = /-\d{8}_\d{6}(?:\.cfg)?\z/
      # Moonrakerによるもの: .<名前>.bkp
      MOONRAKER_BACKUP = /\A\..+\.bkp\z/

      REASONS = %i[read_only backup].freeze

      module_function

      def reason_text(reason) = Messages.t(:"exclusion.#{reason}")

      def host_backup?(path)
        name = File.basename(path)
        KLIPPER_BACKUP.match?(name) || MOONRAKER_BACKUP.match?(name)
      end

      # 除外する理由(REASONSのキー)を返す。除外しない場合はnil
      def exclusion(root, info)
        return nil unless root == CONFIG_ROOT
        return :read_only unless info.writable?
        return :backup if host_backup?(info.path)

        nil
      end
    end
  end
end
