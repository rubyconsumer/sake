class Sake
  ##
  # This is Sake's version of a Rake task.  Please handle with care.
  class Task
    attr_reader :name, :comment

    def initialize(name, args = nil, deps = nil, comment = nil, &block)
      @name    = name
      @comment = comment
      @args    = Array(args)
      @deps    = Array(deps)
      @body    = block
    end

    ##
    # Turn ourselves back into Rake task plaintext.
    def to_ruby
      out = ''
      out << "desc '#{@comment.gsub("'", "\\\\'")}'\n" if @comment
      out << "task '#{@name}'"

      if @args.any?
        args = @args.map { |arg| ":#{arg}" }.join(', ')
        out << ", #{args} "
      end

      if @deps.any?
        deps = @deps.map { |dep| "'#{dep}'" }.join(', ')
        out << ", :needs => [ #{deps} ]"
      end

      if @args.any?
        out << " do |t, args|\n"
      else
        out << " do\n"
      end
      
      # get rid of the proc { / } lines
      out << @body.to_ruby.split("\n")[1...-1].join("\n") rescue nil

      out << "\nend\n"
    end

    ##
    # String-ish duck typing, sorting based on Task names
    def <=>(other)
      to_s <=> other.to_s
    end

    ##
    # The task name
    def to_s; @name end

    ##
    # Basically to_s.inspect
    def inspect; @name.inspect end
  end
end
