##
# Hacks which give us "Rakefile".is_file? 
class String # :nodoc: 
  def is_file?
    File.exists? self
  end
end
