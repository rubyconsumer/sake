class NilClass
  # under the evil
  def method_missing(*args, &block)
    super
  end
end
