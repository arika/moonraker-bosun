# frozen_string_literal: true

require "test_helper"

class MessagesTest < Minitest::Test
  Messages = Moonraker::Bosun::Messages

  def placeholders(text) = text.scan(Messages::PLACEHOLDER).flatten.sort

  def test_every_entry_has_both_languages_with_same_placeholders
    Messages::CATALOG.each do |key, entry|
      assert_equal %i[en ja], entry.keys.sort, key
      entry.each_value { |text| refute_empty text, key }
      assert_equal placeholders(entry[:ja]), placeholders(entry[:en]), key
    end
  end

  def test_keys_used_in_lib_exist
    lib = File.expand_path("../../../lib", __dir__)
    keys = Dir["#{lib}/**/*.rb"].reject { |path| path.end_with?("messages/catalog.rb") }.flat_map do |path|
      File.read(path).scan(/:"([a-z_]+(?:\.[a-z_]+)+)"/).flatten
    end
    refute_empty keys
    keys.uniq.each { |key| assert Messages::CATALOG.key?(key.to_sym), "missing: #{key}" }
  end

  # 式展開で組み立てるキー
  def test_dynamic_keys_exist
    keys = Moonraker::Bosun::CLI::COMMANDS.values.flat_map do |command|
      %W[#{command.command_name}.summary #{command.command_name}.usage]
    end
    keys += Moonraker::Bosun::SyncStatus::STATES.map { |state| "state.#{state}.label" }
    keys += (Moonraker::Bosun::SyncStatus::STATES - [:synced]).map { |state| "state.#{state}.guide" }
    keys += Moonraker::Bosun::FileRules::REASONS.map { |reason| "exclusion.#{reason}" }
    keys += %w[push.create push.update tracking.changed tracking.removed]
    keys += %w[tracked not_on_host recommended].map { |note| "backup.note.#{note}" }
    keys += %w[host_deleted not_writable exists backup_name not_regular_file].flat_map do |name|
      %W[plan.#{name} plan.#{name}_guide]
    end
    keys += %w[plan.host_modified plan.pull_guide]
    keys.each { |key| assert Messages::CATALOG.key?(key.to_sym), "missing: #{key}" }
  end

  def test_locale_from_env
    assert_equal :en, Messages.locale_from_env({})
    assert_equal :en, Messages.locale_from_env("LANG" => "C")
    assert_equal :en, Messages.locale_from_env("LANG" => "en_US.UTF-8")
    assert_equal :ja, Messages.locale_from_env("LANG" => "ja_JP.UTF-8")
    assert_equal :ja, Messages.locale_from_env("LC_MESSAGES" => "ja_JP.UTF-8", "LANG" => "C")
    assert_equal :en, Messages.locale_from_env("LC_ALL" => "C", "LC_MESSAGES" => "ja_JP.UTF-8")
    assert_equal :ja, Messages.locale_from_env("LC_ALL" => "", "LANG" => "ja_JP.UTF-8")
  end

  def test_translate
    assert_equal "Fetched: printer.cfg", Messages.t(:"common.fetched", path: "printer.cfg")
    Messages.with_locale(:ja) do
      assert_equal "取得しました: printer.cfg", Messages.t(:"common.fetched", path: "printer.cfg")
    end
    assert_equal :en, Messages.locale
  end

  # Fiberの中(Enumerator#nextなど)でも、設定した言語を使う
  def test_locale_is_shared_with_fibers
    Messages.with_locale(:ja) do
      assert_equal :ja, Fiber.new { Messages.locale }.resume
    end
  end

  def test_translate_without_param
    assert_raises(KeyError) { Messages.t(:"common.fetched") }
  end
end
