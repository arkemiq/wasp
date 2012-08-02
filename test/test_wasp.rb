require 'test/unit'
require 'wasp'

class WaspTest < Test::Unit::TestCase
  def test_english_wasp
    assert_equal "wasp world",
      Wasp.hi("english")
  end
end