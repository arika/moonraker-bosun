# frozen_string_literal: true

require "test_helper"

class LsCommandTest < Minitest::Test
  include CommandTestHelper

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\n")
    @moonraker.put("config", "moonraker.conf", "[server]\n")
    @moonraker.put("config", "mainsail.cfg", "[virtual_sdcard]\n", permissions: "r")
    @moonraker.put("config", "printer-20261011_141106.cfg", "[printer]\n")
    @moonraker.put("config", ".moonraker.conf.bkp", "[server]\n")
    @moonraker.put("logs", "klippy.log", "log\n", permissions: "r")
  end

  def test_ls_excludes_read_only_and_backup_files
    assert_equal 0, bosun("ls")
    assert_equal "moonraker.conf\nprinter.cfg\n", @out.string
  end

  def test_ls_all
    assert_equal 0, bosun("ls", "-a")
    assert_equal [".moonraker.conf.bkp", "mainsail.cfg", "moonraker.conf",
                  "printer-20261011_141106.cfg", "printer.cfg"],
                 @out.string.lines(chomp: true)
  end

  def test_ls_long
    assert_equal 0, bosun("ls", "-l")
    lines = @out.string.lines(chomp: true)
    assert_equal 2, lines.size
    assert_match(/\Arw  10  \d{4}-\d\d-\d\d \d\d:\d\d:\d\d  printer.cfg\z/, lines.last)
  end

  def test_ls_long_all_shows_reason
    assert_equal 0, bosun("ls", "-la")
    assert_match(/  mainsail.cfg  \(除外: rwでない\)$/, @out.string)
    assert_match(/  \.moonraker\.conf\.bkp  \(除外: バックアップファイル\)$/, @out.string)
  end

  def test_ls_other_root_shows_all
    assert_equal 0, bosun("ls", "--root", "logs")
    assert_equal "klippy.log\n", @out.string
  end

  def test_ls_rejects_arguments
    assert_equal 1, bosun("ls", "printer.cfg")
    assert_match(/引数を指定できません/, @err.string)
  end

  def test_ls_invalid_option
    assert_equal 1, bosun("ls", "-x")
    assert_match(/オプションが不正です/, @err.string)
  end

  def test_ls_help
    assert_equal 0, bosun("ls", "--help")
    assert_match(/使い方: bosun ls/, @out.string)
  end
end
