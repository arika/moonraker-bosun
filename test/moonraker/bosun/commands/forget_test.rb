# frozen_string_literal: true

require "test_helper"

class ForgetCommandTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\n")
    @moonraker.put("config", "moonraker.conf", "[server]\n")
    assert_equal 0, bosun("add", "printer.cfg", "moonraker.conf"), @err.string
    @out.truncate(0)
    @out.rewind
  end

  def test_forget_removes_from_host_tracking_and_local
    parent = tracking_tip
    assert_equal 0, bosun("forget", "moonraker.conf"), @err.string

    assert_equal [parent], parents(Moonraker::Bosun::HostTracking::REF)
    assert_equal ["config/printer.cfg"], tree_paths(Moonraker::Bosun::HostTracking::REF)
    assert_equal <<~MESSAGE.strip, tracking_messages.first
      forget: 1 file

      Host-Op: forget
      Host-File: config/moonraker.conf deleted
    MESSAGE
    refute_path_exists File.join(@cwd, "config/moonraker.conf")
    assert_includes @out.string, "  削除: config/moonraker.conf\n"
    assert_includes @out.string, "ホストのファイルは削除していません"
    # ホストのファイルは残る
    assert_equal "[server]\n", @moonraker.download("config", "moonraker.conf")
  end

  def test_status_after_forget
    assert_equal 0, bosun("forget", "moonraker.conf")
    @out.truncate(0)
    @out.rewind

    assert_equal 0, bosun("status")
    assert_includes @out.string, "トラッキングしていない:\n  moonraker.conf\n"
  end

  def test_forget_file_deleted_on_host_and_locally
    @moonraker.delete("config", "moonraker.conf")
    git("rm", "-q", "config/moonraker.conf")
    git("commit", "-q", "-m", "remove")

    assert_equal 0, bosun("forget", "moonraker.conf"), @err.string
    assert_equal ["config/printer.cfg"], tree_paths(Moonraker::Bosun::HostTracking::REF)
  end

  def test_forget_works_without_host
    @moonraker.define_singleton_method(:list_files) { |_root| raise Moonraker::Bosun::Error, "Moonrakerに接続できません" }
    assert_equal 0, bosun("forget", "moonraker.conf"), @err.string
  end

  def test_forget_rejects_untracked_file
    assert_equal 1, bosun("forget", "crowsnest.conf")
    assert_match(/トラッキングしていないファイルです: crowsnest.conf/, @err.string)
  end

  def test_forget_rejects_locally_modified_file
    write("config/moonraker.conf", "[server]\nlocal\n")
    git("commit", "-q", "-am", "local")
    tip = tracking_tip

    assert_equal 1, bosun("forget", "moonraker.conf")
    assert_match(/ローカル\(HEAD\)で変更されているファイルは対象にできません: moonraker.conf/, @err.string)
    assert_equal tip, tracking_tip
  end

  def test_forget_rejects_uncommitted_change
    write("config/moonraker.conf", "uncommitted\n")
    assert_equal 1, bosun("forget", "moonraker.conf")
    assert_match(/未コミットの変更があります/, @err.string)
  end

  def test_audit_after_forget
    assert_equal 0, bosun("forget", "moonraker.conf")
    @moonraker.delete("config", "moonraker.conf")
    @out.truncate(0)
    @out.rewind
    assert_equal 0, bosun("audit"), @out.string
  end
end
