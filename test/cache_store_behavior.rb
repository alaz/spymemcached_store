module CacheStoreBehavior
  def test_should_read_and_write_strings
    assert @cache.write('foo', 'bar')
    assert_equal 'bar', @cache.read('foo')
  end

  def test_should_overwrite
    @cache.write('foo', 'bar')
    @cache.write('foo', 'baz')
    assert_equal 'baz', @cache.read('foo')
  end

  def test_fetch_without_cache_miss
    @cache.write('foo', 'bar')
    @cache.expects(:write).never
    assert_equal 'bar', @cache.fetch('foo') { 'baz' }
  end

  def test_fetch_with_cache_miss
    @cache.expects(:write).with('foo', 'baz', @cache.options)
    assert_equal 'baz', @cache.fetch('foo') { 'baz' }
  end

  def test_fetch_with_cache_miss_passes_key_to_block
    cache_miss = false
    assert_equal 3, @cache.fetch('foo') { |key| cache_miss = true; key.length }
    assert cache_miss

    cache_miss = false
    assert_equal 3, @cache.fetch('foo') { |key| cache_miss = true; key.length }
    assert !cache_miss
  end

  def test_fetch_with_forced_cache_miss
    @cache.write('foo', 'bar')
    @cache.expects(:read).never
    @cache.expects(:write).with('foo', 'bar', @cache.options.merge(:force => true))
    @cache.fetch('foo', :force => true) { 'bar' }
  end

  def test_fetch_with_cached_nil
    @cache.write('foo', nil)
    @cache.expects(:write).never
    assert_nil @cache.fetch('foo') { 'baz' }
  end

  def test_should_read_and_write_hash
    assert @cache.write('foo', {:a => "b"})
    assert_equal({:a => "b"}, @cache.read('foo'))
  end

  def test_should_read_and_write_integer
    assert @cache.write('foo', 1)
    assert_equal 1, @cache.read('foo')
  end

  def test_should_read_and_write_nil
    assert @cache.write('foo', nil)
    assert_equal nil, @cache.read('foo')
  end

  def test_should_read_and_write_false
    assert @cache.write('foo', false)
    assert_equal false, @cache.read('foo')
  end

  def test_read_multi
    @cache.write('foo', 'bar')
    @cache.write('fu', 'baz')
    @cache.write('fud', 'biz')
    assert_equal({"foo" => "bar", "fu" => "baz"}, @cache.read_multi('foo', 'fu'))
  end

  def test_read_multi_with_expires
    time = Time.now
    @cache.write('foo', 'bar', :expires_in => 10)
    @cache.write('fu', 'baz')
    @cache.write('fud', 'biz')
    Time.stubs(:now).returns(time + 11)
    assert_equal({"fu" => "baz"}, @cache.read_multi('foo', 'fu'))
  end

  def test_fetch_multi
    @cache.write('foo', 'bar')
    @cache.write('fud', 'biz')

    values = @cache.fetch_multi('foo', 'fu', 'fud') {|value| value * 2 }

    assert_equal(["bar", "fufu", "biz"], values)
    assert_equal("fufu", @cache.read('fu'))
  end

  def test_multi_with_objects
    foo = stub(:title => "FOO!", :cache_key => "foo")
    bar = stub(:cache_key => "bar")

    @cache.write('bar', "BAM!")

    values = @cache.fetch_multi(foo, bar) {|object| object.title }
    assert_equal(["FOO!", "BAM!"], values)
  end

  def test_read_and_write_compressed_small_data
    @cache.write('foo', 'bar', :compress => true)
    assert_equal 'bar', @cache.read('foo')
  end

  def test_read_and_write_compressed_large_data
    @cache.write('foo', 'bar', :compress => true, :compress_threshold => 2)
    assert_equal 'bar', @cache.read('foo')
  end

  def test_read_and_write_compressed_nil
    @cache.write('foo', nil, :compress => true)
    assert_nil @cache.read('foo')
  end

  def test_cache_key
    obj = Object.new
    def obj.cache_key
      :foo
    end
    @cache.write(obj, "bar")
    assert_equal "bar", @cache.read("foo")
  end

  def test_param_as_cache_key
    obj = Object.new
    def obj.to_param
      "foo"
    end
    @cache.write(obj, "bar")
    assert_equal "bar", @cache.read("foo")
  end

  def test_array_as_cache_key
    @cache.write([:fu, "foo"], "bar")
    assert_equal "bar", @cache.read("fu/foo")
  end

  def test_hash_as_cache_key
    @cache.write({:foo => 1, :fu => 2}, "bar")
    assert_equal "bar", @cache.read("foo=1/fu=2")
  end

  def test_keys_are_case_sensitive
    @cache.write("foo", "bar")
    assert_nil @cache.read("FOO")
  end

  def test_exist
    @cache.write('foo', 'bar')
    assert_equal true, @cache.exist?('foo')
    assert_equal false, @cache.exist?('bar')
  end

  def test_nil_exist
    @cache.write('foo', nil)
    assert @cache.exist?('foo')
  end

  def test_delete
    @cache.write('foo', 'bar')
    assert @cache.exist?('foo')
    assert @cache.delete('foo')
    assert !@cache.exist?('foo')
  end

  def test_original_store_objects_should_not_be_immutable
    bar = 'bar'
    @cache.write('foo', bar)
    assert_nothing_raised { bar.gsub!(/.*/, 'baz') }
  end

  def test_expires_in
    time = Time.local(2008, 4, 24)
    Time.stubs(:now).returns(time)

    @cache.write('foo', 'bar')
    assert_equal 'bar', @cache.read('foo')

    Time.stubs(:now).returns(time + 30)
    assert_equal 'bar', @cache.read('foo')

    Time.stubs(:now).returns(time + 61)
    assert_nil @cache.read('foo')
  end

  def test_race_condition_protection
    time = Time.now
    @cache.write('foo', 'bar', :expires_in => 60)
    Time.stubs(:now).returns(time + 61)
    result = @cache.fetch('foo', :race_condition_ttl => 10) do
      assert_equal 'bar', @cache.read('foo')
      "baz"
    end
    assert_equal "baz", result
  end

  def test_race_condition_protection_is_limited
    time = Time.now
    @cache.write('foo', 'bar', :expires_in => 60)
    Time.stubs(:now).returns(time + 71)
    result = @cache.fetch('foo', :race_condition_ttl => 10) do
      assert_equal nil, @cache.read('foo')
      "baz"
    end
    assert_equal "baz", result
  end

  def test_race_condition_protection_is_safe
    time = Time.now
    @cache.write('foo', 'bar', :expires_in => 60)
    Time.stubs(:now).returns(time + 61)
    begin
      @cache.fetch('foo', :race_condition_ttl => 10) do
        assert_equal 'bar', @cache.read('foo')
        raise ArgumentError.new
      end
    rescue ArgumentError
    end
    assert_equal "bar", @cache.read('foo')
    Time.stubs(:now).returns(time + 91)
    assert_nil @cache.read('foo')
  end

  def test_crazy_key_characters
    crazy_key = "#/:*(<+=> )&$%@?;'\"\'`~-"
    assert @cache.write(crazy_key, "1", :raw => true)
    assert_equal "1", @cache.read(crazy_key)
    assert_equal "1", @cache.fetch(crazy_key)
    assert @cache.delete(crazy_key)
    assert_equal "2", @cache.fetch(crazy_key, :raw => true) { "2" }
    assert_equal 3, @cache.increment(crazy_key)
    assert_equal 2, @cache.decrement(crazy_key)
  end

  def test_really_long_keys
    key = ""
    900.times{key << "x"}
    assert @cache.write(key, "bar")
    assert_equal "bar", @cache.read(key)
    assert_equal "bar", @cache.fetch(key)
    assert_nil @cache.read("#{key}x")
    assert_equal({key => "bar"}, @cache.read_multi(key))
    assert @cache.delete(key)
  end
end
