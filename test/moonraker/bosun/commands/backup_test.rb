# frozen_string_literal: true

require "test_helper"

class BackupCommandTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  def setup
    super
    @moonraker.db["mainsail"] = { "general" => { "printername" => "Ender-3 S1 Pro", "language" => "ja" },
                                  "dashboard" => { "mobileLayout" => [{ "visible" => true, "name" => "macros" }] } }
    @moonraker.db["maintenance"] = { "ed670200" => { "name" => "MAINTENANCE_INIT" } }
    @moonraker.db["moonraker"] = { "instance_id" => "278d" }
    @moonraker.db["update_manager"] = { "klipper" => { "last_refresh_time" => 1.0 } }
  end

  def path(namespace) = "backup/moonraker-db/#{namespace}.json"

  def test_first_backup_uses_defaults_that_exist
    assert_equal 0, bosun("backup"), @err.string

    assert_equal [path("mainsail"), path("maintenance")], tree_paths(Moonraker::Bosun::HostTracking::REF)
    assert_equal [path("mainsail"), path("maintenance")], tree_paths("main").grep(%r{\Abackup/})
    assert_match(/まだ何もバックアップしていないので/, @out.string)
    assert_equal <<~MESSAGE.strip, tracking_messages.first
      backup: 2 files

      Host-Op: backup
      Host-DB: #{path('mainsail')}
      Host-DB: #{path('maintenance')}
    MESSAGE
  end

  def test_first_backup_includes_webcams_and_timelapse_if_exist
    @moonraker.db["webcams"] = { "a" => { "name" => "cam" } }
    @moonraker.db["timelapse"] = { "enabled" => true }
    assert_equal 0, bosun("backup"), @err.string

    assert_equal %w[mainsail maintenance timelapse webcams].map { |ns| path(ns) }, tree_paths(Moonraker::Bosun::HostTracking::REF)
  end

  def test_json_is_sorted_and_pretty
    assert_equal 0, bosun("backup", "mainsail")
    assert_equal <<~JSON, read(path("mainsail"))
      {
        "dashboard": {
          "mobileLayout": [
            {
              "name": "macros",
              "visible": true
            }
          ]
        },
        "general": {
          "language": "ja",
          "printername": "Ender-3 S1 Pro"
        }
      }
    JSON
  end

  def test_backup_with_names_adds_namespace
    assert_equal 0, bosun("backup", "mainsail")
    assert_equal 0, bosun("backup", "moonraker")
    assert_equal [path("mainsail"), path("moonraker")], tree_paths(Moonraker::Bosun::HostTracking::REF)
  end

  def test_backup_without_args_refreshes_tracked_namespaces
    assert_equal 0, bosun("backup", "mainsail")
    @moonraker.db["mainsail"]["general"]["language"] = "en"
    @moonraker.db["webcams"] = { "a" => { "name" => "cam" } }
    @out.truncate(0)
    @out.rewind

    assert_equal 0, bosun("backup"), @err.string
    assert_equal [path("mainsail")], tree_paths(Moonraker::Bosun::HostTracking::REF)
    assert_includes read(path("mainsail")), "\"language\": \"en\""
    assert_includes @out.string, "  変更: #{path('mainsail')}\n"
    # まだバックアップしていない推奨のnamespaceを案内する
    assert_includes @out.string, "バックアップしていないnamespace(推奨):\n  maintenance\n  webcams\n"
  end

  def test_backup_without_change
    assert_equal 0, bosun("backup", "mainsail")
    tip = tracking_tip
    assert_equal 0, bosun("backup")
    assert_equal tip, tracking_tip
    assert_match(/変更はありません/, @out.string)
  end

  def test_key_order_from_host_does_not_matter
    assert_equal 0, bosun("backup", "mainsail")
    tip = tracking_tip
    @moonraker.db["mainsail"] = @moonraker.db["mainsail"].to_a.reverse.to_h
    assert_equal 0, bosun("backup")
    assert_equal tip, tracking_tip
  end

  def test_tracked_namespace_missing_on_host
    assert_equal 0, bosun("backup", "mainsail", "moonraker")
    @moonraker.db.delete("moonraker")
    assert_equal 0, bosun("backup"), @err.string
    assert_includes @out.string, "ホストにないnamespace(取得していません):\n  moonraker\n"
    assert_includes tree_paths(Moonraker::Bosun::HostTracking::REF), path("moonraker")
  end

  def test_backup_and_config_share_host_tracking
    @moonraker.put("config", "printer.cfg", "[printer]\n")
    assert_equal 0, bosun("add", "printer.cfg")
    assert_equal 0, bosun("backup")
    assert_equal ["backup/moonraker-db/mainsail.json", "backup/moonraker-db/maintenance.json", "config/printer.cfg"],
                 tree_paths(Moonraker::Bosun::HostTracking::REF)
    @out.truncate(0)
    @out.rewind
    assert_equal 0, bosun("audit"), @out.string
  end

  def test_missing_namespace
    assert_equal 1, bosun("backup", "webcams")
    assert_match(/ホストにnamespaceがありません: webcams/, @err.string)
  end

  def test_invalid_namespace
    assert_equal 1, bosun("backup", "../x")
    assert_match(/namespaceの指定が不正です/, @err.string)
  end

  def test_aborts_on_uncommitted_change
    assert_equal 0, bosun("backup", "mainsail")
    write(path("mainsail"), "{}\n")
    assert_equal 1, bosun("backup")
    assert_match(/未コミットの変更があります/, @err.string)
  end

  def test_status
    assert_equal 0, bosun("backup", "mainsail")
    @out.truncate(0)
    @out.rewind
    assert_equal 0, bosun("backup", "--status")
    assert_equal <<~TEXT, @out.string
      mainsail        バックアップ中
      maintenance     推奨
      moonraker
      update_manager
    TEXT
  end

  def test_status_short_option_and_arguments
    assert_equal 0, bosun("backup", "-s")
    assert_includes @out.string, "mainsail        推奨\n"
    assert_equal 1, bosun("backup", "-s", "mainsail")
    assert_match(/--statusには引数を指定できません/, @err.string)
  end

  def test_audit_detects_missing_backup_file
    assert_equal 0, bosun("backup", "mainsail")
    tree = git("rev-parse", "#{Moonraker::Bosun::HostTracking::REF}^{tree}").strip
    commit, = Open3.capture2("git", "-C", @cwd, "commit-tree", tree, "-p", tracking_tip, "-F", "-",
                             stdin_data: "backup: 1 file\n\nHost-Op: backup\nHost-DB: #{path('nosuch')}\n")
    git("update-ref", Moonraker::Bosun::HostTracking::REF, commit.strip)
    git("merge", "-q", "--no-ff", "--no-edit", Moonraker::Bosun::HostTracking::BRANCH)

    assert_equal 1, bosun("audit")
    assert_match(/Host-DBに記録したファイルがツリーにありません: #{Regexp.escape(path('nosuch'))}/, @out.string)
  end
end
