# frozen_string_literal: true

require "test_helper"

class DiffCommandTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\nmax_velocity: 300\n")
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

  def test_no_difference
    assert_equal 0, bosun("diff")
    assert_equal "", @out.string
  end

  def test_shows_committed_local_changes
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    write("config/moonraker.conf", "uncommitted\n")

    assert_equal 0, bosun("diff")
    assert_includes @out.string, "-max_velocity: 300\n+max_velocity: 250\n"
    # 未コミットの変更は含めない
    refute_includes @out.string, "uncommitted"
  end

  def test_limit_to_files_and_stat
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    commit_local("moonraker.conf", "[server]\nlocal\n")

    assert_equal 0, bosun("diff", "--stat", "moonraker.conf")
    assert_includes @out.string, "config/moonraker.conf"
    refute_includes @out.string, "printer.cfg"
  end

  def test_rejects_invalid_path
    assert_equal 1, bosun("diff", "../README.md")
    assert_match(/ファイルの指定が不正です/, @err.string)
  end

  def test_without_host_tracking
    git("branch", "-q", "-D", Moonraker::Bosun::HostTracking::BRANCH)
    assert_equal 1, bosun("diff")
    assert_match(/トラッキング中のファイルがありません/, @err.string)
  end
end
