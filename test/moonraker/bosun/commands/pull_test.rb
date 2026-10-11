# frozen_string_literal: true

require "test_helper"

class PullCommandTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  T1 = 1_790_000_100.75

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\nmax_velocity: 300\n")
    @moonraker.put("config", "moonraker.conf", "[server]\n")
    assert_equal 0, bosun("add", "printer.cfg", "moonraker.conf"), @err.string
    @out.truncate(0)
    @out.rewind
  end

  def test_pull_fetches_all_tracked_files
    @moonraker.put("config", "printer.cfg", "[printer]\nmax_velocity: 350\n", modified: T1)
    parent = tracking_tip
    assert_equal 0, bosun("pull"), @err.string

    assert_equal [parent], parents(Moonraker::Bosun::HostTracking::REF)
    assert_equal "[printer]\nmax_velocity: 350\n", read("config/printer.cfg")
    assert_includes @out.string, "取得しました: config/moonraker.conf\n取得しました: config/printer.cfg\n"
    assert_includes @out.string, "  変更: config/printer.cfg\n"
    refute_includes @out.string, "変更: config/moonraker.conf"
    assert_match(/mainにマージしました/, @out.string)
    assert_includes git("log", "-1", "--format=%s", "main"), "(pull: config/printer.cfg)"
  end

  def test_pull_records_metadata_of_all_fetched_files
    @moonraker.put("config", "printer.cfg", "[printer]\nmax_velocity: 350\n", modified: T1)
    @moonraker.put("config", "moonraker.conf", "[server]\n", modified: T1)
    assert_equal 0, bosun("pull")

    assert_equal <<~MESSAGE.strip, tracking_messages.first
      pull: 2 files

      Host-Op: pull
      Host-File: config/moonraker.conf modified=#{T1} size=9
      Host-File: config/printer.cfg modified=#{T1} size=28
    MESSAGE
  end

  def test_pull_without_change
    tip = tracking_tip
    main = rev("main")
    assert_equal 0, bosun("pull")

    assert_equal tip, tracking_tip
    assert_equal main, rev("main")
    assert_match(/変更はありません/, @out.string)
  end

  def test_pull_merges_unmerged_commit_without_change
    git("reset", "-q", "--hard", "HEAD^1")
    assert_equal 0, bosun("pull"), @err.string

    assert git("merge-base", "--is-ancestor", tracking_tip, "main")
    assert_equal "[server]\n", read("config/moonraker.conf")
  end

  def test_pull_merges_with_local_change
    base = "[printer]\nmax_velocity: 300\n\n[stepper_x]\nstep_pin: PC2\n\n[stepper_y]\nstep_pin: PB8\n"
    @moonraker.put("config", "printer.cfg", base, modified: T1)
    assert_equal 0, bosun("pull"), @err.string
    write("config/printer.cfg", base.sub("max_velocity: 300", "max_velocity: 250"))
    git("commit", "-q", "-am", "local")
    @moonraker.put("config", "printer.cfg", "#{base}\n#*# SAVE_CONFIG\n", modified: T1 + 1)
    assert_equal 0, bosun("pull"), @err.string

    assert_equal "#{base.sub('max_velocity: 300', 'max_velocity: 250')}\n#*# SAVE_CONFIG\n", read("config/printer.cfg")
  end

  def test_pull_keeps_deleted_file_and_warns
    @moonraker.delete("config", "moonraker.conf")
    assert_equal 0, bosun("pull")

    assert_includes tree_paths(Moonraker::Bosun::HostTracking::REF), "config/moonraker.conf"
    assert_includes @out.string, "ホストで削除(取得していません):\n  moonraker.conf\n  → トラッキングをやめるなら bosun forget <ファイル>\n"
    assert_equal "[server]\n", read("config/moonraker.conf")
  end

  def test_pull_skips_read_only_file_and_warns
    @moonraker.put("config", "moonraker.conf", "[server]\nchanged\n", permissions: "r", modified: T1)
    assert_equal 0, bosun("pull")

    assert_equal "[server]\n", show("#{Moonraker::Bosun::HostTracking::REF}:config/moonraker.conf")
    assert_includes @out.string, "ホストで書き込めなくなった(取得していません):\n  moonraker.conf\n"
  end

  def test_pull_shows_untracked_files
    @moonraker.put("config", "crowsnest.conf", "[crowsnest]\n")
    @moonraker.put("config", "mainsail.cfg", "[virtual_sdcard]\n", permissions: "r")
    assert_equal 0, bosun("pull")

    assert_includes @out.string, "トラッキングしていない(取得していません):\n  crowsnest.conf\n  → トラッキングするなら bosun add <ファイル>\n"
    refute_includes @out.string, "mainsail.cfg"
    refute_includes tree_paths(Moonraker::Bosun::HostTracking::REF), "config/crowsnest.conf"
  end

  def test_pull_aborts_on_uncommitted_change_of_tracked_file
    tip = tracking_tip
    write("config/moonraker.conf", "local\n")
    @moonraker.put("config", "printer.cfg", "[printer]\nchanged\n", modified: T1)

    assert_equal 1, bosun("pull")
    assert_match(%r{未コミットの変更があります.*\n  config/moonraker.conf}, @err.string)
    assert_equal tip, tracking_tip
    assert_empty @moonraker.downloads.drop(2)
  end

  def test_pull_conflict
    write("config/printer.cfg", "[printer]\nmax_velocity: 250\n")
    git("commit", "-q", "-am", "local")
    @moonraker.put("config", "printer.cfg", "[printer]\nmax_velocity: 350\n", modified: T1)

    assert_equal 1, bosun("pull")
    assert_match(/マージで衝突しました/, @err.string)
    assert_equal "[printer]\nmax_velocity: 350\n", show("#{Moonraker::Bosun::HostTracking::REF}:config/printer.cfg")
  end

  def test_pull_without_host_tracking
    git("branch", "-q", "-D", Moonraker::Bosun::HostTracking::BRANCH)
    assert_equal 1, bosun("pull")
    assert_match(/トラッキング中のファイルがありません/, @err.string)
  end

  def test_pull_rejects_arguments
    assert_equal 1, bosun("pull", "printer.cfg")
    assert_match(/引数を指定できません/, @err.string)
  end
end
