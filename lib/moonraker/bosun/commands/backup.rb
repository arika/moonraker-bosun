# frozen_string_literal: true

require "json"

module Moonraker
  module Bosun
    module Commands
      class Backup < Base
        include Fetching

        # まだ何もバックアップしていないときに、ホストにあればバックアップするnamespace
        # (Web UIなどの設定と、Moonrakerが管理するユーザの設定)
        DEFAULT_NAMESPACES = %w[mainsail fluidd mobileraker maintenance webcams timelapse].freeze
        NAMESPACE_PATTERN = /\A[A-Za-z0-9_.-]+\z/

        def run(args)
          status = false
          args = parse_options(args) do |o|
            o.on("-s", "--status", t(:"backup.status_option")) { status = true }
          end
          return 0 unless args

          if status
            check_no_arguments!(args, "--status")

            print_status
            return 0
          end

          args.each do |namespace|
            raise Error, t(:"backup.invalid_namespace", namespace: namespace) unless NAMESPACE_PATTERN.match?(namespace)
          end
          backup(args.uniq)
          0
        end

        def self.repo_path(namespace) = "#{HostTracking::DB_BACKUP_DIR}/#{namespace}.json"

        private

        # host-trackingでバックアップしているnamespace
        def tracked_namespaces
          tip = tracking.tip
          return [] unless tip

          @context.git.ls_tree_paths(tip, HostTracking::DB_BACKUP_DIR)
                  .map { |path| File.basename(path, ".json") }
        end

        def backup(requested)
          tracked = tracked_namespaces
          host = client.db_namespaces
          missing = []
          targets =
            if !requested.empty?
              missing_requested = requested - host
              unless missing_requested.empty?
                raise Error, t(:"backup.missing_requested", namespaces: missing_requested.join(", "))
              end

              requested
            elsif tracked.empty?
              out.puts t(:"backup.first", namespaces: DEFAULT_NAMESPACES.join(", "))
              DEFAULT_NAMESPACES & host
            else
              missing = tracked - host
              tracked & host
            end
          raise Error, t(:"backup.no_targets") if targets.empty?

          tracking.check_workspace!(targets.map { |namespace| self.class.repo_path(namespace) })

          fetched = targets.map do |namespace|
            f = HostTracking::Fetched.new(repo_path: self.class.repo_path(namespace),
                                          content: serialize(client.db_namespace(namespace)), info: nil)
            out.puts t(:"common.fetched", path: f.repo_path)
            f
          end
          print_notices(missing, requested.empty? && !tracked.empty? ? (DEFAULT_NAMESPACES & host) - tracked : [])
          commit_and_merge("backup", fetched)
        end

        # キーを辞書順に並べた、整形したJSON(Moonrakerが返すキーの順が変わっても差分が出ないようにする)
        def serialize(value)
          "#{JSON.pretty_generate(sort_keys(value))}\n"
        end

        def sort_keys(value)
          case value
          when Hash then value.keys.sort.to_h { |key| [key, sort_keys(value[key])] }
          when Array then value.map { |item| sort_keys(item) }
          else value
          end
        end

        def print_notices(missing, new_defaults)
          unless missing.empty?
            out.puts
            out.puts t(:"backup.missing")
            missing.each { |namespace| out.puts "  #{namespace}" }
            out.puts "  → #{t(:"backup.missing_guide")}"
            out.puts
          end
          return if new_defaults.empty?

          out.puts
          out.puts t(:"backup.recommended")
          new_defaults.each { |namespace| out.puts "  #{namespace}" }
          out.puts "  → #{t(:"backup.recommended_guide")}"
          out.puts
        end

        def print_status
          tracked = tracked_namespaces
          host = client.db_namespaces
          names = (host | tracked).sort
          width = names.map(&:size).max || 0
          names.each do |namespace|
            notes = status_notes(namespace, tracked, host)
            out.puts notes.empty? ? namespace : format("%-*s  %s", width, namespace, notes)
          end
        end

        # namespaceの状態(バックアップ中、ホストにない、推奨)
        def status_notes(namespace, tracked, host)
          notes = []
          notes << :tracked if tracked.include?(namespace)
          notes << :not_on_host unless host.include?(namespace)
          notes << :recommended if DEFAULT_NAMESPACES.include?(namespace) && !tracked.include?(namespace)
          notes.map { |note| t(:"backup.note.#{note}") }.join(t(:"backup.note_separator"))
        end
      end
    end
  end
end
