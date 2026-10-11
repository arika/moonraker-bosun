# frozen_string_literal: true

require "test_helper"

class SyncStatusTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  T0 = 1_790_000_000.25
  T1 = 1_790_000_100.75

  def setup
    super
    put("printer.cfg", "[printer]\n")
    put("moonraker.conf", "[server]\n")
    assert_equal 0, bosun("add", "printer.cfg", "moonraker.conf"), @err.string
    @moonraker.downloads.clear
  end

  def put(path, content, modified: T0, permissions: "rw")
    @moonraker.put("config", path, content, modified: modified, permissions: permissions)
  end

  def status(strict: false)
    git = Moonraker::Bosun::Git.new(@cwd)
    Moonraker::Bosun::SyncStatus.new(git: git, client: @moonraker, tracking: Moonraker::Bosun::HostTracking.new(git),
                                     strict: strict)
  end

  def states(status = self.status) = status.entries.to_h { |entry| [entry.path, entry.state] }

  def commit_local(path, content)
    write("config/#{path}", content)
    git("add", "config/#{path}")
    git("commit", "-q", "-m", "local #{path}")
  end

  def test_synced_without_download
    assert_equal({ "moonraker.conf" => :synced, "printer.cfg" => :synced }, states)
    assert_empty @moonraker.downloads
  end

  def test_host_modified_with_different_size_without_download
    put("printer.cfg", "[printer]\nmax_velocity: 300\n", modified: T1)
    assert_equal :host_modified, states["printer.cfg"]
    assert_empty @moonraker.downloads
  end

  def test_host_modified_with_same_size_downloads
    put("printer.cfg", "[PRINTER]\n", modified: T1)
    assert_equal :host_modified, states["printer.cfg"]
    assert_equal [%w[config printer.cfg]], @moonraker.downloads
  end

  def test_only_modified_time_changed_is_synced
    put("printer.cfg", "[printer]\n", modified: T1)
    assert_equal :synced, states["printer.cfg"]
    assert_equal [%w[config printer.cfg]], @moonraker.downloads
  end

  def test_strict_downloads_everything
    assert_equal :synced, states(status(strict: true))["printer.cfg"]
    assert_equal 2, @moonraker.downloads.size
  end

  def test_strict_detects_change_with_same_metadata
    # 更新日時とサイズが同じまま内容が変わった場合は、strictでのみ検知できる
    put("printer.cfg", "[PRINTER]\n", modified: T0)
    assert_equal :synced, states["printer.cfg"]
    assert_equal :host_modified, states(status(strict: true))["printer.cfg"]
  end

  def test_local_modified
    commit_local("printer.cfg", "[printer]\nlocal\n")
    assert_equal :local_modified, states["printer.cfg"]
  end

  def test_both_modified
    commit_local("printer.cfg", "[printer]\nlocal\n")
    put("printer.cfg", "[printer]\nhost\n", modified: T1)
    assert_equal :both_modified, states["printer.cfg"]
  end

  def test_host_deleted
    @moonraker.delete("config", "printer.cfg")
    assert_equal :host_deleted, states["printer.cfg"]
  end

  def test_both_deleted
    @moonraker.delete("config", "printer.cfg")
    git("rm", "-q", "config/printer.cfg")
    git("commit", "-q", "-m", "remove")
    assert_equal :both_deleted, states["printer.cfg"]
  end

  def test_host_read_only
    put("printer.cfg", "[printer]\n", permissions: "r")
    assert_equal :host_read_only, states["printer.cfg"]
  end

  def test_local_deleted
    git("rm", "-q", "config/printer.cfg")
    git("commit", "-q", "-m", "remove")
    assert_equal :local_deleted, states["printer.cfg"]
  end

  def test_host_modified_local_deleted
    git("rm", "-q", "config/printer.cfg")
    git("commit", "-q", "-m", "remove")
    put("printer.cfg", "[printer]\nhost\n", modified: T1)
    assert_equal :host_modified_local_deleted, states["printer.cfg"]
  end

  def test_local_added
    commit_local("macros.cfg", "[gcode_macro A]\n")
    assert_equal :local_added, states["macros.cfg"]
  end

  def test_added_on_both
    commit_local("macros.cfg", "[gcode_macro A]\n")
    put("macros.cfg", "[gcode_macro B]\n")
    assert_equal :added_on_both, states["macros.cfg"]
  end

  def test_untracked_excludes_ignored_files
    put("crowsnest.conf", "[crowsnest]\n")
    put("mainsail.cfg", "[virtual_sdcard]\n", permissions: "r")
    put("printer-20261011_141106.cfg", "[printer]\n")
    result = states

    assert_equal :untracked, result["crowsnest.conf"]
    refute result.key?("mainsail.cfg")
    refute result.key?("printer-20261011_141106.cfg")
  end

  def test_uncommitted_local_change_is_not_considered
    write("config/printer.cfg", "[printer]\nuncommitted\n")
    assert_equal :synced, states["printer.cfg"]
  end

  def test_rename_detection
    @moonraker.delete("config", "printer.cfg")
    put("printer-main.cfg", "[printer]\n")
    put("other.cfg", "[other]\n")
    result = status

    assert_equal [Moonraker::Bosun::SyncStatus::Rename.new(from: "printer.cfg", to: "printer-main.cfg")], result.renames
  end

  def test_unmerged
    refute_predicate status, :unmerged?
    git("reset", "-q", "--hard", "HEAD^1")
    assert_predicate status, :unmerged?
  end

  def test_without_host_tracking
    git("branch", "-q", "-D", Moonraker::Bosun::HostTracking::BRANCH)
    git("reset", "-q", "--hard", "HEAD^1")
    put("crowsnest.conf", "[crowsnest]\n")
    result = status

    assert_nil result.tip
    refute_predicate result, :unmerged?
    assert(result.entries.all? { |entry| entry.state == :untracked })
  end
end
