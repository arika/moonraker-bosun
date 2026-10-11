# frozen_string_literal: true

require "test_helper"

class AuditCommandTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\n")
    @moonraker.put("config", "moonraker.conf", "[server]\n")
    assert_equal 0, bosun("add", "printer.cfg", "moonraker.conf"), @err.string
    @out.truncate(0)
    @out.rewind
    @moonraker.downloads.clear
  end

  def test_ok
    assert_equal 0, bosun("audit")
    assert_includes @out.string, "すべて同期済みです(2件)\n"
    assert_includes @out.string, "host-trackingの不変条件: 問題なし\n"
    assert @out.string.end_with?("問題はありません\n")
    # すべてのトラッキング中のファイルを取得して比べる
    assert_equal 2, @moonraker.downloads.size
  end

  def test_detects_change_with_same_metadata
    @moonraker.put("config", "printer.cfg", "[PRINTER]\n")
    assert_equal 0, bosun("status")
    @out.truncate(0)
    @out.rewind

    assert_equal 1, bosun("audit")
    assert_includes @out.string, "ホストで変更:\n  printer.cfg\n"
    assert @out.string.end_with?("問題があります\n")
  end

  def test_not_synced_is_problem
    write("config/printer.cfg", "[printer]\nlocal\n")
    git("commit", "-q", "-am", "local")
    assert_equal 1, bosun("audit")
    assert_includes @out.string, "ローカルで変更:\n  printer.cfg\n"
  end

  def test_unmerged_is_problem
    git("reset", "-q", "--hard", "HEAD^1")
    assert_equal 1, bosun("audit")
    assert_match(/まだ現在のブランチに取り込んでいないコミットがあります/, @out.string)
  end

  def test_untracked_file_is_not_problem
    @moonraker.put("config", "crowsnest.conf", "[crowsnest]\n")
    assert_equal 0, bosun("audit")
    assert_includes @out.string, "トラッキングしていない:\n  crowsnest.conf\n"
  end

  def test_rename_is_problem
    @moonraker.delete("config", "moonraker.conf")
    @moonraker.put("config", "server.conf", "[server]\n")
    assert_equal 1, bosun("audit")
    assert_includes @out.string, "moonraker.conf → server.conf"
  end

  def test_uncommitted_change_is_not_problem
    write("config/printer.cfg", "uncommitted\n")
    assert_equal 0, bosun("audit")
    assert_includes @out.string, "未コミットの変更"
  end

  def test_merge_of_main_into_host_tracking
    git("checkout", "-q", Moonraker::Bosun::HostTracking::BRANCH)
    git("merge", "-q", "--no-edit", "main")
    git("checkout", "-q", "main")

    assert_equal 1, bosun("audit")
    assert_match(/\h{7}: マージコミットです\(親が2個あります\)/, @out.string)
    assert_match(/\h{7}: Host-Opがありません/, @out.string)
    assert_match(%r{\h{7}: config/とbackup/以外のファイルがあります: README.md, lib/bosun.rb}, @out.string)
    assert_includes @out.string, "host-trackingの不変条件の違反:\n"
  end

  def test_commit_without_host_op
    git("checkout", "-q", Moonraker::Bosun::HostTracking::BRANCH)
    write("config/printer.cfg", "manual\n")
    git("commit", "-q", "-am", "manual edit")
    git("checkout", "-q", "main")

    assert_equal 1, bosun("audit")
    assert_match(/\h{7}: Host-Opがありません\(bosunが作成したコミットではありません\)/, @out.string)
  end

  def test_host_file_mismatch
    tree = git("rev-parse", "#{Moonraker::Bosun::HostTracking::REF}^{tree}").strip
    message = "pull: 2 files\n\nHost-Op: pull\nHost-File: config/printer.cfg modified=1.0 size=99\n" \
              "Host-File: config/missing.cfg modified=1.0 size=1\n"
    commit, = Open3.capture2("git", "-C", @cwd, "commit-tree", tree, "-p", tracking_tip, "-F", "-",
                             stdin_data: message)
    git("update-ref", Moonraker::Bosun::HostTracking::REF, commit.strip)
    git("merge", "-q", "--no-ff", "--no-edit", Moonraker::Bosun::HostTracking::BRANCH)

    assert_equal 1, bosun("audit")
    assert_match(%r{サイズ\(99\)がblobのサイズ\(10\)と違います: config/printer.cfg}, @out.string)
    assert_match(%r{ツリーにありません: config/missing.cfg}, @out.string)
  end

  def test_deleted_file_remaining_in_tree
    tree = git("rev-parse", "#{Moonraker::Bosun::HostTracking::REF}^{tree}").strip
    commit, = Open3.capture2("git", "-C", @cwd, "commit-tree", tree, "-p", tracking_tip, "-F", "-",
                             stdin_data: "forget: 1 file\n\nHost-Op: forget\nHost-File: config/printer.cfg deleted\n")
    git("update-ref", Moonraker::Bosun::HostTracking::REF, commit.strip)
    git("merge", "-q", "--no-ff", "--no-edit", Moonraker::Bosun::HostTracking::BRANCH)

    assert_equal 1, bosun("audit")
    assert_match(%r{削除と記録したファイルがツリーにあります: config/printer.cfg}, @out.string)
  end

  def test_unknown_host_op
    tree = git("rev-parse", "#{Moonraker::Bosun::HostTracking::REF}^{tree}").strip
    commit, = Open3.capture2("git", "-C", @cwd, "commit-tree", tree, "-p", tracking_tip, "-F", "-",
                             stdin_data: "x\n\nHost-Op: sync\n")
    git("update-ref", Moonraker::Bosun::HostTracking::REF, commit.strip)
    git("merge", "-q", "--no-ff", "--no-edit", Moonraker::Bosun::HostTracking::BRANCH)

    assert_equal 1, bosun("audit")
    assert_match(/不明なHost-Opです: sync/, @out.string)
  end
end
