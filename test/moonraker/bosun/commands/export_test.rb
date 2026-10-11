# frozen_string_literal: true

require "test_helper"

class ExportCommandTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  def setup
    super
    # 日時の異なる3回の取得を、host-trackingに直接作る
    @c1 = tracking_commit({ "config/printer.cfg" => "v1\n" }, "2026-01-01T12:00:00+09:00", nil)
    @c2 = tracking_commit({ "config/printer.cfg" => "v2\n", "config/moonraker.conf" => "m2\n" },
                          "2026-02-01T12:00:00+09:00", @c1)
    git("update-ref", Moonraker::Bosun::HostTracking::REF, @c2)
    git("merge", "-q", "--no-ff", "--no-edit", "--allow-unrelated-histories", Moonraker::Bosun::HostTracking::BRANCH)
    @main_after_c2 = rev("HEAD")
    @c3 = tracking_commit({ "config/printer.cfg" => "v3\n", "config/moonraker.conf" => "m2\n",
                            "backup/moonraker-db/mainsail.json" => "{}\n" }, "2026-03-01T12:00:00+09:00", @c2)
    git("update-ref", Moonraker::Bosun::HostTracking::REF, @c3)
    @out_dir = File.join(@cwd, "out")
  end

  def tracking_commit(files, date, parent)
    env = { "GIT_INDEX_FILE" => File.join(@cwd, ".git", "test-index"),
            "GIT_COMMITTER_DATE" => date, "GIT_AUTHOR_DATE" => date }
    FileUtils.rm_f(env["GIT_INDEX_FILE"])
    files.each do |path, content|
      blob, = Open3.capture2(env, "git", "-C", @cwd, "hash-object", "-w", "--stdin", stdin_data: content)
      Open3.capture2(env, "git", "-C", @cwd, "update-index", "--add", "--cacheinfo", "100644,#{blob.strip},#{path}")
    end
    tree, = Open3.capture2(env, "git", "-C", @cwd, "write-tree")
    args = ["commit-tree", tree.strip, "-m", "pull: #{files.size} files\n\nHost-Op: pull"]
    args += ["-p", parent] if parent
    commit, = Open3.capture2(env, "git", "-C", @cwd, *args)
    commit.strip
  end

  def exported(path) = File.read(File.join(@out_dir, path))

  def test_export_latest_by_default
    assert_equal 0, bosun("export", "-o", @out_dir), @err.string
    assert_equal "v3\n", exported("config/printer.cfg")
    assert_equal "{}\n", exported("backup/moonraker-db/mainsail.json")
    assert_includes @out.string, "host-tracking: #{@c3[0, 7]} ("
    assert_includes @out.string, "  backup/moonraker-db/mainsail.json\n  config/moonraker.conf\n  config/printer.cfg\n"
  end

  def test_export_at
    assert_equal 0, bosun("export", "--at", "2026-02-15 00:00 +09:00", "-o", @out_dir), @err.string
    assert_equal "v2\n", exported("config/printer.cfg")
    refute_path_exists File.join(@out_dir, "backup")
  end

  def test_export_at_exact_time
    assert_equal 0, bosun("export", "--at", "2026-01-01T12:00:00+09:00", "-o", @out_dir), @err.string
    assert_equal "v1\n", exported("config/printer.cfg")
  end

  def test_export_at_before_first
    assert_equal 1, bosun("export", "--at", "2025-12-31", "-o", @out_dir)
    assert_match(/より前に取得したものがありません/, @err.string)
    refute_path_exists @out_dir
  end

  def test_export_at_invalid
    assert_equal 1, bosun("export", "--at", "あした")
    assert_match(/日時を解釈できません/, @err.string)
  end

  def test_export_rev_of_host_tracking_commit
    assert_equal 0, bosun("export", "--rev", @c1, "-o", @out_dir), @err.string
    assert_equal "v1\n", exported("config/printer.cfg")
  end

  def test_export_rev_of_main_commit
    # c3はまだmainに取り込んでいないので、取り込み済みのc2の時点になる
    assert_equal 0, bosun("export", "--rev", @main_after_c2, "-o", @out_dir), @err.string
    assert_equal "v2\n", exported("config/printer.cfg")
    assert_includes @out.string, "host-tracking: #{@c2[0, 7]} ("
  end

  def test_export_rev_before_merge
    assert_equal 1, bosun("export", "--rev", "#{@main_after_c2}^1")
    assert_match(/まだhost-trackingを取り込んでいません/, @err.string)
  end

  def test_export_rev_unknown
    assert_equal 1, bosun("export", "--rev", "nosuch")
    assert_match(/コミットが見つかりません: nosuch/, @err.string)
  end

  def test_export_selected_files
    assert_equal 0, bosun("export", "-o", @out_dir, "printer.cfg", "backup/moonraker-db/mainsail.json"), @err.string
    assert_equal %w[backup config], Dir.children(@out_dir).sort
    assert_equal ["printer.cfg"], Dir.children(File.join(@out_dir, "config"))
  end

  def test_export_missing_file
    assert_equal 1, bosun("export", "--rev", @c1, "-o", @out_dir, "moonraker.conf")
    assert_match(/その時点のファイルにありません: moonraker.conf/, @err.string)
    refute_path_exists @out_dir
  end

  def test_export_default_directory
    assert_equal 0, bosun("export", "--rev", @c1), @err.string
    dir = Dir.children(@cwd).grep(/\Aexport-/).first
    assert_match(/\Aexport-\d{8}-\d{6}-#{@c1[0, 7]}\z/, dir)
    assert_equal "v1\n", File.read(File.join(@cwd, dir, "config/printer.cfg"))
  end

  def test_export_aborts_when_directory_exists
    FileUtils.mkdir_p(@out_dir)
    assert_equal 1, bosun("export", "-o", @out_dir)
    assert_match(/書き出すディレクトリがすでにあります/, @err.string)
    assert_empty Dir.children(@out_dir)
  end

  def test_export_with_both_options
    assert_equal 1, bosun("export", "--at", "2026-02-01", "--rev", @c1)
    assert_match(/同時に指定できません/, @err.string)
  end

  def test_export_does_not_change_repository
    status = git("status", "--porcelain")
    head = rev("HEAD")
    Dir.mktmpdir("bosun-export") do |dir|
      assert_equal 0, bosun("export", "-o", File.join(dir, "out"))
    end
    assert_equal head, rev("HEAD")
    assert_equal status, git("status", "--porcelain")
  end
end
