# frozen_string_literal: true

require "test_helper"

class CLITest < Minitest::Test
  include CommandTestHelper

  def test_help
    ["help", "-h", "--help", nil].each do |arg|
      @out.truncate(0)
      @out.rewind
      assert_equal 0, bosun(*[arg].compact)
      assert_match(/使い方: bosun/, @out.string)
      assert_match(/^  ls +ホストのファイル一覧を表示する$/, @out.string)
    end
  end

  def test_help_in_english
    [{}, { "LANG" => "C" }, { "LC_ALL" => "C", "LANG" => "ja_JP.UTF-8" }].each do |env|
      @out.truncate(0)
      @out.rewind
      assert_equal 0, bosun("help", env: env)
      assert_match(/Usage: bosun/, @out.string)
      assert_match(/^  ls +List files on the host$/, @out.string)
    end
  end

  def test_command_help_in_english
    assert_equal 0, bosun("push", "--help", env: {})
    assert_match(/^Usage: bosun push \[options\]$/, @out.string)
    assert_match(/Only show what would be applied/, @out.string)
  end

  # ファイルの書き込みの失敗は、スタックトレースではなくメッセージだけを表示する
  def test_system_call_error_is_reported_as_message
    @moonraker.put("config", "printer.cfg", "[printer]\n")
    File.chmod(0o555, @cwd)
    assert_equal 1, bosun("get", "printer.cfg")
    assert_match(/\Abosun: Permission denied/, @err.string)
  ensure
    File.chmod(0o755, @cwd)
  end

  def test_interrupt
    @moonraker.after_list = ->(_root) { raise Interrupt }
    assert_equal 130, bosun("ls")
    assert_equal "bosun: 中断しました\n", @err.string
  end

  def test_unknown_command
    assert_equal 1, bosun("nosuch")
    assert_match(/不明なコマンドです: nosuch/, @err.string)
  end

  def test_missing_base_url
    cli = Moonraker::Bosun::CLI.new(out: @out, err: @err, env: {}, cwd: @cwd)
    assert_equal 1, cli.run(["ls"])
    assert_match(/environment variable MOONRAKER_BASE_URL is not set/, @err.string)
  end
end
