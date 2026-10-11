# frozen_string_literal: true

require "test_helper"

class StatusCommandTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\n")
    @moonraker.put("config", "moonraker.conf", "[server]\n")
  end

  def test_all_synced
    assert_equal 0, bosun("add", "printer.cfg", "moonraker.conf")
    @out.truncate(0)
    @out.rewind

    assert_equal 0, bosun("status")
    assert_match(/\Ahost-tracking: \h{7} \(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\)\n\nすべて同期済みです\(2件\)\n\z/, @out.string)
  end

  def test_shows_states_with_guides
    assert_equal 0, bosun("add", "printer.cfg", "moonraker.conf")
    @moonraker.put("config", "printer.cfg", "[printer]\nhost\n", modified: 1_790_000_100.0)
    @moonraker.put("config", "crowsnest.conf", "[crowsnest]\n")
    write("config/printer.cfg", "uncommitted\n")
    @out.truncate(0)
    @out.rewind

    assert_equal 0, bosun("status")
    assert_includes @out.string, <<~TEXT
      ホストで変更:
        printer.cfg
        → bosun pull で取り込む
    TEXT
    assert_includes @out.string, <<~TEXT
      トラッキングしていない:
        crowsnest.conf
        → トラッキングするなら bosun add <ファイル>
    TEXT
    assert_includes @out.string, "同期済み: 1件\n"
    assert_includes @out.string, "未コミットの変更(判定はHEADの内容で行っています):\n  config/printer.cfg\n"
  end

  def test_rename_guide
    assert_equal 0, bosun("add", "printer.cfg")
    @moonraker.delete("config", "printer.cfg")
    @moonraker.put("config", "main.cfg", "[printer]\n")

    assert_equal 0, bosun("status")
    assert_includes @out.string, "  printer.cfg → main.cfg\n"
    assert_includes @out.string, "bosun add main.cfg と bosun forget printer.cfg"
  end

  def test_unmerged_warning
    assert_equal 0, bosun("add", "printer.cfg")
    git("reset", "-q", "--hard", "HEAD^1")

    assert_equal 0, bosun("status")
    assert_match(/まだ現在のブランチに取り込んでいないコミットがあります/, @out.string)
    assert_match(/git merge --no-ff host-tracking/, @out.string)
  end

  def test_without_host_tracking
    assert_equal 0, bosun("status")
    assert_match(/host-tracking: まだありません/, @out.string)
    assert_includes @out.string, "トラッキングしていない:\n  moonraker.conf\n  printer.cfg\n"
  end
end
