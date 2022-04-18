module SourceTestHelper
  # A helper method to automate all the checks needed to make sure that a strategy does not break.
  #
  # * If download_size is nil, it tests that the file is downloaded correctly, otherwise it also checks the filesize.
  # * If deleted is true, it skips the downloading check, but it still tries everything else and makes sure nothing breaks.
  # * Any passed kwargs parameter is tested against the strategy.
  def strategy_should_work(url, referer: nil, download_size: nil, deleted: false, **methods_to_test)
    context "a strategy for #{url}#{", referer: #{referer}" if referer.present?}".chomp do
      strategy = Source::Extractor.find(url, referer)

      should "not raise anything" do
        assert_nothing_raised { strategy.to_h }
      end

      should "make sure that image_urls is an array of valid elements" do
        assert((strategy.image_urls.instance_of? Array))
        assert_not(strategy.image_urls.include?(nil))
      end

      should_download_successfully(strategy, download_size) unless deleted

      # {profile_url: nil}[:profile_url].present? -> false
      # Doing it this way instead we can check profile_url even if it's passed as a nil.
      if methods_to_test.include? :profile_url
        profile_url = methods_to_test.delete(:profile_url)
        should_handle_artists_correctly(strategy, profile_url)
      end

      tags = methods_to_test.delete(:tags)
      should_validate_tags(strategy, tags)

      # check any method that is passed as kwargs, in order to hardcode as few thingss as possible
      methods_to_test.each do |method_name, expected_value|
        should "make sure that '#{method_name}' matches" do
          if expected_value.instance_of? Regexp
            assert_match(expected_value, strategy.try(method_name))
          elsif expected_value.nil?
            assert_nil(strategy.try(method_name))
          else
            assert_equal(expected_value, strategy.try(method_name))
          end
        end
      end
    end
  end

  def should_download_successfully(strategy, download_size = nil)
    should "download successfully" do
      file = strategy.download_file!(strategy.image_urls.first)
      if download_size.present?
        assert_equal(expected_filesize, file.size)
      else
        assert_not_nil(file.size)
      end
    end
  end

  def should_handle_artists_correctly(strategy, profile_url)
    if profile_url.present?
      should "correctly match a strategy to an artist with the same profile url" do
        assert_equal(profile_url, strategy.profile_url)
        artist = FactoryBot.create(:artist, name: strategy.artist_name, url_string: profile_url)
        assert_equal([artist], strategy.artists)
      end
    else
      should "not incorrectly extract a profile url or artist data when there's none to be found" do
        assert_nil(strategy.profile_url)
        assert_nil(strategy.artist_name)
        assert_equal([], strategy.other_names)
      end
    end
  end

  def should_validate_tags(strategy, tags = nil)
    should "make sure that tags return an array of arrays" do
      assert((strategy.tags.instance_of? Array))
      if strategy.tags.present?
        assert((strategy.tags.first.instance_of? Array))
      end
    end

    return unless tags.present?

    should "make sure that tags match" do
      if tags&.first.instance_of? Array
        assert_equal(tags.sort, strategy.tags.sort)
      elsif tags&.first.instance_of? String
        assert_equal(tags.map(&:downcase).sort, strategy.tags.map(&:first).map(&:downcase).sort)
      end
    end
  end

end
