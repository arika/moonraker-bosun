# frozen_string_literal: true

require "test_helper"

class FileRulesTest < Minitest::Test
  def info(path, permissions = "rw")
    Moonraker::Bosun::Client::FileInfo.new(path: path, modified: 0.0, size: 0, permissions: permissions)
  end

  def test_host_backup
    assert Moonraker::Bosun::FileRules.host_backup?("printer-20261011_141106.cfg")
    assert Moonraker::Bosun::FileRules.host_backup?("macros/extra-20261011_141106.cfg")
    assert Moonraker::Bosun::FileRules.host_backup?("printer.conf-20261011_141106")
    assert Moonraker::Bosun::FileRules.host_backup?(".moonraker.conf.bkp")

    refute Moonraker::Bosun::FileRules.host_backup?("printer.cfg")
    refute Moonraker::Bosun::FileRules.host_backup?("printer-20261011.cfg")
    refute Moonraker::Bosun::FileRules.host_backup?("moonraker.conf.bkp")
    refute Moonraker::Bosun::FileRules.host_backup?(".bkp")
  end

  def test_exclusion_in_config
    assert_nil Moonraker::Bosun::FileRules.exclusion("config", info("printer.cfg"))
    assert_equal :read_only, Moonraker::Bosun::FileRules.exclusion("config", info("mainsail.cfg", "r"))
    assert_equal :read_only, Moonraker::Bosun::FileRules.exclusion("config", info("secret.cfg", ""))
    assert_equal :backup, Moonraker::Bosun::FileRules.exclusion("config", info("printer-20261011_141106.cfg"))
    assert_equal :backup, Moonraker::Bosun::FileRules.exclusion("config", info(".moonraker.conf.bkp"))
  end

  def test_no_exclusion_outside_config
    assert_nil Moonraker::Bosun::FileRules.exclusion("logs", info("klippy.log", "r"))
    assert_nil Moonraker::Bosun::FileRules.exclusion("config_examples",
                                                     info("printer-creality-ender3-s1-2021.cfg", "r"))
  end
end
