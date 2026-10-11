# frozen_string_literal: true

require "test_helper"

class RmCommandTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\n")
    @moonraker.put("config", "moonraker.conf", "[server]\n")
    @moonraker.put("config", "crowsnest.conf", "[crowsnest]\n")
    assert_equal 0, bosun("add", "printer.cfg", "moonraker.conf", "crowsnest.conf"), @err.string
    @out.truncate(0)
    @out.rewind
  end

  def host_paths = @moonraker.list_files("config").map(&:path).sort

  def test_rm_deletes_host_file_and_stops_tracking
    assert_equal 0, bosun("rm", "moonraker.conf"), @err.string

    assert_equal ["crowsnest.conf", "printer.cfg"], host_paths
    assert_equal ["config/crowsnest.conf", "config/printer.cfg"], tree_paths(Moonraker::Bosun::HostTracking::REF)
    assert_includes tracking_messages.first, "Host-Op: rm\nHost-File: config/moonraker.conf deleted"
    refute_path_exists File.join(@cwd, "config/moonraker.conf")
    assert_includes @out.string, "削除しました: moonraker.conf\n"
  end

  def test_rm_after_local_deletion
    git("rm", "-q", "config/moonraker.conf")
    git("commit", "-q", "-m", "remove")

    assert_equal 0, bosun("rm", "moonraker.conf"), @err.string
    assert_equal ["crowsnest.conf", "printer.cfg"], host_paths
    @out.truncate(0)
    @out.rewind
    assert_equal 0, bosun("audit"), @out.string
  end

  def test_rm_dry_run
    assert_equal 0, bosun("rm", "-n", "moonraker.conf")
    assert_includes @out.string, "削除: moonraker.conf\n"
    assert_includes @out.string, "--dry-run のため"
    assert_includes host_paths, "moonraker.conf"
  end

  def test_rm_aborts_when_host_changed
    @moonraker.put("config", "moonraker.conf", "[server]\nhost\n", modified: 1_790_000_500.0)

    assert_equal 1, bosun("rm", "moonraker.conf", "crowsnest.conf")
    assert_match(/削除できないファイルがあるため、中止しました/, @err.string)
    assert_match(/moonraker.conf: ホストで変更されています/, @err.string)
    assert_includes host_paths, "crowsnest.conf"
  end

  def test_rm_aborts_when_host_changed_with_same_metadata
    @moonraker.put("config", "moonraker.conf", "[SERVER]\n")
    assert_equal 1, bosun("rm", "moonraker.conf")
    assert_match(/ホストで変更されています/, @err.string)
  end

  def test_rm_aborts_when_host_deleted
    @moonraker.delete("config", "moonraker.conf")
    assert_equal 1, bosun("rm", "moonraker.conf")
    assert_match(/moonraker.conf: ホストで削除されています → トラッキングをやめるなら bosun forget moonraker.conf/, @err.string)
  end

  def test_rm_aborts_when_read_only
    @moonraker.put("config", "moonraker.conf", "[server]\n", permissions: "r")
    assert_equal 1, bosun("rm", "moonraker.conf")
    assert_match(/ホストで書き込めません/, @err.string)
  end

  def test_rm_aborts_when_host_changes_after_check
    @moonraker.after_download = lambda do |_root, path|
      @moonraker.put("config", path, "[server]\nhost\n", modified: 1_790_000_500.0)
      @moonraker.after_download = nil
    end

    assert_equal 1, bosun("rm", "moonraker.conf")
    assert_match(/確認の後にホストでファイルが変わったため、中止しました/, @err.string)
    assert_includes host_paths, "moonraker.conf"
  end

  def test_rm_records_deleted_files_when_failing_midway
    @moonraker.define_singleton_method(:delete_file) do |root, path|
      raise Moonraker::Bosun::Client::APIError.new(500, "Internal Server Error") if path == "moonraker.conf"

      delete(root, path)
    end

    assert_equal 1, bosun("rm", "crowsnest.conf", "moonraker.conf")
    assert_match(/削除の途中で失敗しました。削除していないファイル: moonraker.conf/, @err.string)
    assert_equal ["config/moonraker.conf", "config/printer.cfg"], tree_paths(Moonraker::Bosun::HostTracking::REF)
  end

  def test_rm_records_deleted_files_when_interrupted
    @moonraker.define_singleton_method(:delete_file) do |root, path|
      raise Interrupt if path == "moonraker.conf"

      delete(root, path)
    end

    assert_equal 130, bosun("rm", "crowsnest.conf", "moonraker.conf")
    assert_match(/削除の途中で失敗しました。削除していないファイル: moonraker.conf/, @err.string)
    assert_equal ["config/moonraker.conf", "config/printer.cfg"], tree_paths(Moonraker::Bosun::HostTracking::REF)
  end

  def test_rm_aborts_while_printing
    @moonraker.print_state = "paused"
    assert_equal 1, bosun("rm", "moonraker.conf")
    assert_match(/印刷中のため中止しました/, @err.string)
    assert_includes host_paths, "moonraker.conf"
  end

  def test_rm_rejects_locally_modified_file
    write("config/moonraker.conf", "[server]\nlocal\n")
    git("commit", "-q", "-am", "local")
    assert_equal 1, bosun("rm", "moonraker.conf")
    assert_match(/ローカル\(HEAD\)で変更されているファイルは対象にできません/, @err.string)
  end

  def test_rm_rejects_untracked_file
    @moonraker.put("config", "sonar.conf", "[sonar]\n")
    assert_equal 1, bosun("rm", "sonar.conf")
    assert_match(/トラッキングしていないファイルです/, @err.string)
    assert_includes host_paths, "sonar.conf"
  end
end
