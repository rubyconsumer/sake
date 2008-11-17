class NilClass
  def is_file?
    false
  end

  # under the evil
  def method_missing(*args, &block)
    super
  end
end
