# frozen_string_literal: true

require "test_helper"

class GetCommandTest < Minitest::Test
  include CommandTestHelper

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\n")
    @moonraker.put("config", "mainsail.cfg", "[virtual_sdcard]\n", permissions: "r")
    @moonraker.put("config", "macros/printer.cfg", "[gcode_macro X]\n")
    @moonraker.put("config_examples", "printer-creality-ender3-s1-2021.cfg", "# sample\n", permissions: "r")
  end

  def read(name) = File.binread(File.join(@cwd, name))

  def test_get
    assert_equal 0, bosun("get", "printer.cfg", "mainsail.cfg")
    assert_equal "[printer]\n", read("printer.cfg")
    assert_equal "[virtual_sdcard]\n", read("mainsail.cfg")
    assert_match(/取得しました: printer.cfg/, @out.string)
  end

  def test_get_from_subdirectory_uses_basename
    assert_equal 0, bosun("get", "macros/printer.cfg")
    assert_equal "[gcode_macro X]\n", read("printer.cfg")
  end

  def test_get_other_root
    assert_equal 0, bosun("get", "-r", "config_examples", "printer-creality-ender3-s1-2021.cfg")
    assert_equal "# sample\n", read("printer-creality-ender3-s1-2021.cfg")
  end

  def test_get_aborts_when_file_exists
    File.write(File.join(@cwd, "printer.cfg"), "local\n")
    assert_equal 1, bosun("get", "mainsail.cfg", "printer.cfg")
    assert_match(/同名のファイルがあるため、取得を中止しました: printer.cfg/, @err.string)
    assert_equal "local\n", read("printer.cfg")
    refute_path_exists File.join(@cwd, "mainsail.cfg")
  end

  def test_get_aborts_on_duplicated_names
    assert_equal 1, bosun("get", "printer.cfg", "macros/printer.cfg")
    assert_match(/ファイル名が重複しています: printer.cfg/, @err.string)
    assert_empty Dir.children(@cwd)
  end

  def test_get_missing_file_writes_nothing
    assert_equal 1, bosun("get", "printer.cfg", "nosuch.cfg")
    assert_match(%r{ホストにファイルがありません: config/nosuch.cfg}, @err.string)
    assert_empty Dir.children(@cwd)
  end

  def test_get_rejects_invalid_paths
    ["/etc/passwd", "../moonraker.conf", "a/../../b"].each do |path|
      assert_equal 1, bosun("get", path)
    end
    assert_empty Dir.children(@cwd)
  end

  def test_get_without_arguments
    assert_equal 1, bosun("get")
    assert_match(/取得するファイルを指定してください/, @err.string)
  end
end
