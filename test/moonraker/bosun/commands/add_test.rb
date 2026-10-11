# frozen_string_literal: true

require "test_helper"

class AddCommandTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\nkinematics: cartesian\n", modified: 1_791_695_466.5512717)
    @moonraker.put("config", "moonraker.conf", "[server]\n")
    @moonraker.put("config", "macros/start.cfg", "[gcode_macro START]\n")
    @moonraker.put("config", "mainsail.cfg", "[virtual_sdcard]\n", permissions: "r")
    @moonraker.put("config", "printer-20261011_141106.cfg", "[printer]\n")
  end

  def test_first_add_creates_orphan_branch_and_merges
    main_before = rev("main")
    assert_equal 0, bosun("add", "printer.cfg", "macros/start.cfg"), @err.string

    # host-trackingは親を持たず、config/だけを含む
    assert_empty parents(Moonraker::Bosun::HostTracking::REF)
    assert_equal ["config/macros/start.cfg", "config/printer.cfg"], tree_paths(Moonraker::Bosun::HostTracking::REF)

    # mainはhost-trackingとのマージコミットになり、コードも残る
    assert_equal [main_before, tracking_tip], parents("main")
    assert_equal ["README.md", "config/macros/start.cfg", "config/printer.cfg", "lib/bosun.rb"], tree_paths("main")
    assert_equal "[printer]\nkinematics: cartesian\n", read("config/printer.cfg")
    assert_match(/host-trackingにコミットしました/, @out.string)
    assert_match(/mainにマージしました/, @out.string)
  end

  def test_commit_message_records_host_metadata
    assert_equal 0, bosun("add", "printer.cfg")
    assert_equal <<~MESSAGE.strip, tracking_messages.first
      add: 1 file

      Host-Op: add
      Host-File: config/printer.cfg modified=1791695466.5512717 size=32
    MESSAGE
  end

  # gitに記録するメッセージは、表示の言語によらず英語にする
  def test_merge_message_is_english
    assert_equal 0, bosun("add", "printer.cfg", "macros/start.cfg")
    assert_equal "Merge host-tracking (add: config/macros/start.cfg, config/printer.cfg)",
                 git("log", "-1", "--format=%s", "main").strip
  end

  def test_add_in_english
    assert_equal 0, bosun("add", "printer.cfg", env: {}), @err.string
    assert_equal <<~TEXT, @out.string
      Fetched: config/printer.cfg
      Committed to host-tracking: #{tracking_tip[0, 7]}
        changed: config/printer.cfg
      Merged into main
    TEXT
  end

  def test_second_add_extends_tree
    assert_equal 0, bosun("add", "printer.cfg")
    first = tracking_tip
    assert_equal 0, bosun("add", "moonraker.conf")

    assert_equal [first], parents(Moonraker::Bosun::HostTracking::REF)
    assert_equal ["config/moonraker.conf", "config/printer.cfg"], tree_paths(Moonraker::Bosun::HostTracking::REF)
    assert_equal "[server]\n", read("config/moonraker.conf")
    # 2回目以降は共通の祖先があるので、通常のマージになる
    assert_equal tracking_tip, parents("main").last
  end

  def test_add_without_change_does_not_commit
    assert_equal 0, bosun("add", "printer.cfg")
    tip = tracking_tip
    main = rev("main")
    assert_equal 0, bosun("add", "printer.cfg")

    assert_equal tip, tracking_tip
    assert_equal main, rev("main")
    assert_match(/変更はありません/, @out.string)
  end

  def test_add_keeps_host_bytes
    content = "[printer]\r\nmax_velocity: 300\r\n\xE3\x81\x82".b
    @moonraker.put("config", "printer.cfg", content)
    write(".gitattributes", "*.cfg text eol=lf\n")
    git("add", ".gitattributes")
    git("commit", "-q", "-m", "attributes")
    assert_equal 0, bosun("add", "printer.cfg")

    blob = git("rev-parse", "#{Moonraker::Bosun::HostTracking::REF}:config/printer.cfg").strip
    assert_equal content, git("cat-file", "blob", blob).b
  end

  def test_add_with_unstaged_changes_in_other_files
    assert_equal 0, bosun("add", "printer.cfg")
    write("lib/bosun.rb", "# changed\n")

    assert_equal 0, bosun("add", "moonraker.conf"), @err.string
    assert_equal "# changed\n", read("lib/bosun.rb")
    assert_equal " M lib/bosun.rb\n", git("status", "--porcelain")
  end

  def test_add_aborts_on_staged_changes
    assert_equal 0, bosun("add", "printer.cfg")
    tip = tracking_tip
    write("README.md", "# staged\n")
    git("add", "README.md")

    assert_equal 1, bosun("add", "moonraker.conf")
    assert_match(/ステージ済みの変更があります/, @err.string)
    assert_equal tip, tracking_tip
  end

  def test_add_aborts_on_uncommitted_change_of_target
    assert_equal 0, bosun("add", "printer.cfg")
    tip = tracking_tip
    write("config/printer.cfg", "local edit\n")

    assert_equal 1, bosun("add", "printer.cfg")
    assert_match(%r{未コミットの変更があります.*\n  config/printer.cfg}, @err.string)
    assert_equal tip, tracking_tip
    assert_equal "local edit\n", read("config/printer.cfg")
  end

  def test_add_aborts_on_untracked_file_at_target
    write("config/moonraker.conf", "local\n")

    assert_equal 1, bosun("add", "moonraker.conf")
    assert_match(%r{  config/moonraker.conf}, @err.string)
    assert_nil Moonraker::Bosun::Git.new(@cwd).rev_parse(Moonraker::Bosun::HostTracking::REF)
  end

  def test_add_aborts_on_uncommitted_change_of_unmerged_file
    # host-trackingへのコミットだけが済み、マージされていない状態を作る
    assert_equal 0, bosun("add", "printer.cfg")
    git("reset", "-q", "--hard", "HEAD^1")
    write("config/printer.cfg", "local\n")

    assert_equal 1, bosun("add", "moonraker.conf")
    assert_match(%r{  config/printer.cfg}, @err.string)
  end

  def test_add_rejects_excluded_files
    assert_equal 1, bosun("add", "mainsail.cfg")
    assert_match(/対象にできないファイルです\(rwでない\): mainsail.cfg/, @err.string)

    assert_equal 1, bosun("add", "printer-20261011_141106.cfg")
    assert_match(/対象にできないファイルです\(バックアップファイル\)/, @err.string)
    assert_nil Moonraker::Bosun::Git.new(@cwd).rev_parse(Moonraker::Bosun::HostTracking::REF)
  end

  def test_add_rejects_missing_file
    assert_equal 1, bosun("add", "printer.cfg", "nosuch.cfg")
    assert_match(%r{ホストにファイルがありません: config/nosuch.cfg}, @err.string)
    assert_nil Moonraker::Bosun::Git.new(@cwd).rev_parse(Moonraker::Bosun::HostTracking::REF)
  end

  def test_add_on_host_tracking_branch
    assert_equal 0, bosun("add", "printer.cfg")
    git("checkout", "-q", Moonraker::Bosun::HostTracking::BRANCH)

    assert_equal 1, bosun("add", "moonraker.conf")
    assert_match(/host-trackingブランチでは実行できません/, @err.string)
  end

  def test_add_on_detached_head
    git("checkout", "-q", "--detach")
    assert_equal 1, bosun("add", "printer.cfg")
    assert_match(/detached HEAD/, @err.string)
  end

  def test_add_merge_conflict
    @moonraker.put("config", "printer.cfg", "[printer]\nmax_velocity: 300\n")
    assert_equal 0, bosun("add", "printer.cfg")
    write("config/printer.cfg", "[printer]\nmax_velocity: 250\n")
    git("commit", "-q", "-am", "local edit")
    @moonraker.put("config", "printer.cfg", "[printer]\nmax_velocity: 350\n")

    assert_equal 1, bosun("add", "printer.cfg")
    assert_match(/マージで衝突しました/, @err.string)
    assert_match(/git merge --abort/, @err.string)
    # host-trackingにはホストの内容がコミットされている
    assert_equal "[printer]\nmax_velocity: 350\n", show("#{Moonraker::Bosun::HostTracking::REF}:config/printer.cfg")

    assert_equal 1, bosun("add", "moonraker.conf")
    assert_match(/マージの途中です/, @err.string)
  end

  def test_add_merges_host_change_with_local_change
    @moonraker.put("config", "printer.cfg", "[printer]\nmax_velocity: 300\n\n#*# SAVE_CONFIG\n#*# a = 1\n")
    assert_equal 0, bosun("add", "printer.cfg")
    write("config/printer.cfg", "[printer]\nmax_velocity: 250\n\n#*# SAVE_CONFIG\n#*# a = 1\n")
    git("commit", "-q", "-am", "local edit")
    @moonraker.put("config", "printer.cfg", "[printer]\nmax_velocity: 300\n\n#*# SAVE_CONFIG\n#*# a = 2\n")

    assert_equal 0, bosun("add", "printer.cfg"), @err.string
    assert_equal "[printer]\nmax_velocity: 250\n\n#*# SAVE_CONFIG\n#*# a = 2\n", read("config/printer.cfg")
  end

  def test_host_tracking_never_contains_main_commits
    assert_equal 0, bosun("add", "printer.cfg")
    write("config/printer.cfg", "local\n")
    git("commit", "-q", "-am", "local edit")
    assert_equal 0, bosun("add", "moonraker.conf")

    refute_includes git("rev-list", Moonraker::Bosun::HostTracking::REF).split, rev("main~1")
    git("rev-list", Moonraker::Bosun::HostTracking::REF).split.each do |commit|
      assert_operator parents(commit).size, :<=, 1
      assert(tree_paths(commit).all? { |path| path.start_with?("config/") })
    end
  end

  def test_add_outside_git_repository
    Dir.mktmpdir do |dir|
      cli = Moonraker::Bosun::CLI.new(out: @out, err: @err, env: {}, cwd: dir, client: @moonraker)
      assert_equal 1, cli.run(["add", "printer.cfg"])
      assert_match(/run inside a git repository/, @err.string)
    end
  end
end
