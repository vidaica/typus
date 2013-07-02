require "test_helper"

class I18nTest < ActiveSupport::TestCase

  test "t" do
    assert_equal "Hello", Typus::I18n.t("Hello")

    assert_equal "Hello @fesplugas!", Typus::I18n.t("Hello %{human}!", :human => "@fesplugas")
  end

  test 't using keys' do
    assert_equal "Hello world", Typus::I18n.t(".hello", :default => "Hello world!")

    I18n.locale = :missing
    assert_equal "Missing Hello world", Typus::I18n.t(".hello", :default => "Missing Hello world")
  end

  test "default_locale" do
    assert_equal :en, Typus::I18n.default_locale
  end

  test "available_locales" do
    assert Typus::I18n.available_locales.is_a?(Hash)
  end

end
