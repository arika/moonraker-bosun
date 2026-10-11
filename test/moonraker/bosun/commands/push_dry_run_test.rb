# frozen_string_literal: true

require "test_helper"

class PushDryRunTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  T1 = 1_790_000_100.75

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\n")
    @moonraker.put("config", "moonraker.conf", "[server]\n")
    assert_equal 0, bosun("add", "printer.cfg", "moonraker.conf"), @err.string
    @out.truncate(0)
    @out.rewind
  end

  def commit_local(path, content)
    write("config/#{path}", content)
    git("add", "config/#{path}")
    git("commit", "-q", "-m", "local #{path}")
  end

  def test_nothing_to_push
    assert_equal 0, bosun("push", "--dry-run")
    assert_equal "反映する変更はありません\n", @out.string
  end

  def test_update_and_create
    commit_local("printer.cfg", "[printer]\nlocal\n")
    commit_local("macros.cfg", "[gcode_macro A]\n")

    assert_equal 0, bosun("push", "-n"), @err.string
    assert_includes @out.string, "作成: macros.cfg\n更新: printer.cfg\n"
    assert_includes @out.string, "--dry-run のため、ホストには書き込んでいません"
    # ホストは変わらない
    assert_equal "[printer]\n", @moonraker.download("config", "printer.cfg")
    assert_nil(@moonraker.list_files("config").find { |info| info.path == "macros.cfg" })
  end

  def test_aborts_when_host_changed_after_fetch
    commit_local("printer.cfg", "[printer]\nlocal\n")
    @moonraker.put("config", "printer.cfg", "[printer]\nhost\n", modified: T1)

    assert_equal 1, bosun("push", "-n")
    assert_includes @out.string, "反映できないファイル:\n  printer.cfg: ホストで変更されています(最後に取得した内容と一致しません)\n    " \
                                 "→ bosun pull で取り込んでから、もう一度 bosun push を実行する\n"
    assert_match(/中止しました\(ホストには何も書き込んでいません\)/, @out.string)
  end

  def test_aborts_when_host_changed_with_same_metadata
    # statusの簡易な判定では検知できない変更も、pushの前には厳密に確認する
    commit_local("printer.cfg", "[printer]\nlocal\n")
    @moonraker.put("config", "printer.cfg", "[PRINTER]\n")

    assert_equal 1, bosun("push", "-n")
    assert_match(/printer.cfg: ホストで変更されています/, @out.string)
  end

  def test_one_problem_aborts_everything
    commit_local("printer.cfg", "[printer]\nlocal\n")
    commit_local("moonraker.conf", "[server]\nlocal\n")
    @moonraker.put("config", "moonraker.conf", "[server]\nhost\n", modified: T1)

    assert_equal 1, bosun("push", "-n")
    assert_includes @out.string, "更新: printer.cfg\n"
    assert_match(/moonraker.conf: ホストで変更されています/, @out.string)
  end

  def test_aborts_when_host_deleted
    commit_local("printer.cfg", "[printer]\nlocal\n")
    @moonraker.delete("config", "printer.cfg")

    assert_equal 1, bosun("push", "-n")
    assert_match(/printer.cfg: ホストで削除されています/, @out.string)
  end

  def test_aborts_when_host_read_only
    commit_local("printer.cfg", "[printer]\nlocal\n")
    @moonraker.put("config", "printer.cfg", "[printer]\n", permissions: "r")

    assert_equal 1, bosun("push", "-n")
    assert_match(/printer.cfg: ホストで書き込めません\(rwでない\)/, @out.string)
  end

  def test_aborts_when_creating_existing_host_file
    commit_local("mainsail.cfg", "[virtual_sdcard]\n")
    @moonraker.put("config", "mainsail.cfg", "[virtual_sdcard]\n", permissions: "r")

    assert_equal 1, bosun("push", "-n")
    assert_match(/mainsail.cfg: ホストに同名のファイルがあります/, @out.string)
  end

  def test_aborts_when_creating_backup_like_name
    commit_local("printer-20261011_141106.cfg", "[printer]\n")

    assert_equal 1, bosun("push", "-n")
    assert_match(/バックアップファイルと同じ形式の名前です/, @out.string)
  end

  # シンボリックリンクをそのまま反映すると、リンク先のパスの文字列がファイルの内容になってしまう
  def test_aborts_when_local_file_is_symlink
    File.symlink("printer.cfg", File.join(@cwd, "config/link.cfg"))
    git("add", "config/link.cfg")
    git("commit", "-q", "-m", "link")

    assert_equal 1, bosun("push", "-n")
    assert_match(/link.cfg: 通常のファイルではありません\(gitのモード: 120000\)/, @out.string)
  end

  # host-trackingには通常のファイルとして記録するので、反映するとマージでモードが衝突する
  def test_aborts_when_local_file_is_executable
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    File.chmod(0o755, File.join(@cwd, "config/printer.cfg"))
    git("commit", "-q", "-am", "chmod")

    assert_equal 1, bosun("push", "-n")
    assert_match(/printer.cfg: 通常のファイルではありません\(gitのモード: 100755\)/, @out.string)
  end

  def test_skipped_files_are_reported
    commit_local("printer.cfg", "[printer]\nlocal\n")
    git("rm", "-q", "config/moonraker.conf")
    git("commit", "-q", "-m", "remove")

    assert_equal 0, bosun("push", "-n")
    assert_includes @out.string, "更新: printer.cfg\n"
    assert_includes @out.string, "ローカルで削除(反映しません):\n  moonraker.conf\n  → ホストからも削除するなら bosun rm <ファイル>\n"
  end

  def test_host_only_change_is_reported_but_not_blocking
    commit_local("printer.cfg", "[printer]\nlocal\n")
    @moonraker.put("config", "moonraker.conf", "[server]\nhost\n", modified: T1)

    assert_equal 0, bosun("push", "-n")
    assert_includes @out.string, "ホストで変更(反映しません):\n  moonraker.conf\n  → bosun pull で取り込む\n"
  end

  def test_aborts_while_printing
    commit_local("printer.cfg", "[printer]\nlocal\n")
    %w[printing paused].each do |state|
      @moonraker.print_state = state
      assert_equal 1, bosun("push", "-n")
      assert_match(/印刷中のため中止しました\(print_stats.state: #{state}\)/, @err.string)
    end
  end

  def test_runs_when_not_printing
    commit_local("printer.cfg", "[printer]\nlocal\n")
    [nil, "standby", "complete", "cancelled", "error"].each do |state|
      @moonraker.print_state = state
      assert_equal 0, bosun("push", "-n"), "state=#{state.inspect}"
    end
  end

  def test_aborts_on_uncommitted_change_in_config
    write("config/other.cfg", "untracked by git\n")
    assert_equal 1, bosun("push", "-n")
    assert_match(%r{未コミットの変更があります.*\n  config/other.cfg}, @err.string)
  end

  def test_aborts_when_unmerged
    git("reset", "-q", "--hard", "HEAD^1")
    assert_equal 1, bosun("push", "-n")
    assert_match(/まだ現在のブランチに取り込んでいないコミットがあります/, @err.string)
  end

  def test_without_host_tracking
    git("branch", "-q", "-D", Moonraker::Bosun::HostTracking::BRANCH)
    assert_equal 1, bosun("push", "-n")
    assert_match(/トラッキング中のファイルがありません/, @err.string)
  end
end
