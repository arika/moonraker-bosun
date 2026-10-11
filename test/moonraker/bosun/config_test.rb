# frozen_string_literal: true

require "test_helper"

class ConfigTest < Minitest::Test
  def test_from_env
    config = Moonraker::Bosun::Config.from_env("MOONRAKER_BASE_URL" => "http://ender-3-s1-pro.local:7125")
    assert_equal "ender-3-s1-pro.local", config.base_url.host
    assert_equal 7125, config.base_url.port
  end

  def test_from_env_without_variable
    error = assert_raises(Moonraker::Bosun::Error) { Moonraker::Bosun::Config.from_env({}) }
    assert_match(/MOONRAKER_BASE_URL/, error.message)
  end

  def test_from_env_with_empty_variable
    assert_raises(Moonraker::Bosun::Error) { Moonraker::Bosun::Config.from_env("MOONRAKER_BASE_URL" => "") }
  end

  def test_non_http_url
    assert_raises(Moonraker::Bosun::Error) { Moonraker::Bosun::Config.new(base_url: "ftp://example.com") }
    assert_raises(Moonraker::Bosun::Error) { Moonraker::Bosun::Config.new(base_url: "ender-3-s1-pro.local:7125") }
  end

  def test_invalid_url
    assert_raises(Moonraker::Bosun::Error) { Moonraker::Bosun::Config.new(base_url: "http://exa mple.com") }
  end
end
