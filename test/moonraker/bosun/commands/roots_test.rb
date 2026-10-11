# frozen_string_literal: true

require "test_helper"

class RootsCommandTest < Minitest::Test
  include CommandTestHelper

  def setup
    super
    @moonraker.root_infos = [
      Moonraker::Bosun::Client::RootInfo.new(name: "config", path: "/home/a/printer_data/config", permissions: "rw"),
      Moonraker::Bosun::Client::RootInfo.new(name: "logs", path: "/home/a/printer_data/logs", permissions: "r"),
      Moonraker::Bosun::Client::RootInfo.new(name: "config_examples", path: "/home/a/klipper/config", permissions: "r")
    ]
  end

  def test_roots_keeps_server_order
    assert_equal 0, bosun("roots")
    assert_equal "config\nlogs\nconfig_examples\n", @out.string
  end

  def test_roots_long
    assert_equal 0, bosun("roots", "-l")
    assert_equal <<~TEXT, @out.string
      rw  config           /home/a/printer_data/config
      r   logs             /home/a/printer_data/logs
      r   config_examples  /home/a/klipper/config
    TEXT
  end

  def test_roots_rejects_arguments
    assert_equal 1, bosun("roots", "config")
    assert_match(/引数を指定できません/, @err.string)
  end
end
