##
# Sake.  Best served warm.
#
# >> Chris Wanstrath
# => chris@ozmm.org

require 'rubygems'
require 'rake'
require 'fileutils'
begin
  require 'ruby2ruby'
rescue LoadError
  die "=> Sake requires the ruby2ruby gem.  Please install it.  Thanks!"
end

##
# Show all Sake tasks (but no local Rake tasks).
#   $ sake -T
#
# Show tasks in a Rake file.
#   $ sake -T file.rake
#
# Install all tasks in a Rake file or a single Rake task
#   $ sake -i Rakefile
#   $ sake -i Rakefile db:migrate
#
# Run a Sake task.
#   $ sake <taskname>
#
# Some Sake tasks may depend on tasks which exist only locally.
#
# For instance, you may have a db:version sake task which depends
# on the 'environment' Rake task.  The 'environment' Rake task is one
# defined by Rails to load its environment.  This db:version task will
# work when your current directory is within a Rails app because
# Sake knows how to find Rake tasks.  This task will not work,
# however, in any other directory (unless a task named 'environment' 
# indeed exists).
#
# Sake can also serve its tasks over a network by launching a Mongrel handler.
# Pass the -S switch to start Sake in server mode.
#
#   $ sake -S
#
# You can, of course, specify a port.
#   $ sake -S -p 1111
#
# You can also daemonize your server for long term serving fun.
#   $ sake -S -d
#
class Sake
  module Version
    Major  = '0'
    Minor  = '1'
    Tweak  = '0'
    String = [ Major, Minor, Tweak ].join('.')
  end

  ##
  # The `application' class, this is basically the controller
  # which decides what to do then executes.
  def initialize(args)
    @args = args
    Rake.application
    Rake.application.options.silent = true
  end

  ##
  # This method figures out what to do and does it.
  # Basically a big switch.  Note the seemingly random
  # return statements: return if you don't want run_rake invoked.
  # Some actions do want it invoked, however, so they don't return
  # (like version, which prints a Sake version then trusts Rake to do
  # likewise).
  def run
    ##
    # Examine a Rake file.
    # $ sake -T file.rake
    if (index = @args.index('-T')) && (file = @args[index+1]).is_file?
      return show_tasks(TasksFile.new(file).tasks)

    ##
    # Show all Sake tasks (but no local Rake tasks).
    # $ sake -T
    elsif index || @args.empty?
      return show_tasks(Store.tasks.sort, @args[index.to_i+1])

    ##
    # Install a Rake file or a single Rake task
    # $ sake -i Rakefile
    # $ sake -i Rakefile db:migrate
    elsif index = @args.index('-i')
      return install(index)

    ##
    # Start a Mongrel handler which will serve local Rake tasks
    # to anyone who wants them.
    #
    # $ sake -S
    #
    # Set a port
    # $ sake -S -p 1111
    #
    # Daemonize
    # $ sake -S -d
    elsif @args.include? '-S'
      return serve_tasks

    ##
    # Prints Sake and Rake versions.
    elsif @args.include? '--version'
      version
    end

    ##
    # Runs Rake proper, including our ~/.sake tasks.
    run_rake
  end

  private

  def show_tasks(tasks = [], pattern = nil)
    Rake.application.show(tasks, pattern)
  end

  def install(index)
    unless (file = @args[index+1]) && file.is_file?
      die "=> `#{file}' is not a Rakefile, sorry." 
    end

    tasks = TasksFile.new(file).tasks

    # We may want to install a specific task
    if target_task = @args[index + 2]
      tasks = tasks.select { |task| task.name == target_task }
    end

    # No duplicates.
    tasks.each do |task|
      if Store.has_task? task
        puts "!! Task `#{task}' already exists in #{Store.path}"
      else
        puts "=> Installing task `#{task}'"
        Store.add_task task
      end
    end

    # Commit.
    Store.save!
  end

  def serve_tasks
    Server.start(@args)
  end

  def version
    puts "sake, version #{Version::String}"
  end

  def run_rake
    import Sake::Store.path
    Rake.application.run
  end

  ##
  # This class represents a Rake task file, in the traditional sense.
  # It takes on parameter: the path to a Rake file.  When instantiated,
  # it will read the file and parse out the rake tasks, storing them in
  # a 'tasks' array.  This array can be accessed directly:
  #
  #   file = Sake::TasksFile.new('Rakefile')
  #   puts file.tasks.inspect
  class TasksFile
    attr_reader :tasks

    def initialize(file)
      @namespace = []
      @tasks     = []
      @comment   = nil
      instance_eval File.read(file) if file.is_file?
    end

    ##
    # We fake out an approximation of the Rake DSL in order to build
    # our tasks array.
    private

    ##
    # Set a namespace for the duration of the block.  Namespaces can be 
    # nested.
    def namespace(name)
      @namespace << name
      yield
      @namespace.delete name
    end

    ##
    # Describe the following task.
    def desc(comment)
      @comment = comment
    end

    ## 
    # Define a task and any dependencies it may have.
    def task(name, &block)
      # If we're passed a hash, we know it has one key (the name of
      # the task) pointing to a single or multiple dependencies. 
      if name.is_a? Hash
        deps = name.values.first 
        name = name.keys.first
      end

      # Our namespace is really just a convenience method.  Essentially,
      # a namespace is just part of the task name.
      name = [ @namespace, name ].flatten * ':'

      # Sake's version of a rake task
      task = Task.new(name, deps, @comment, &block)

      @tasks << task

      # We sucked up the last 'desc' declaration if it existed, so now clear
      # it -- we don't want tasks without a description given one.
      @comment = nil
    end

    public

    ##
    # Call to_ruby on all our tasks and return a concat'd string of them.
    def to_ruby
      @tasks.map { |task| task.to_ruby }.join("\n")
    end

    ##
    # Add tasks to this TasksFile.  Can accept another TasksFile object or
    # an array of Task objects.
    def add_tasks(tasks)
      Array(tasks.is_a?(TasksFile) ? tasks.tasks : tasks).each do |task|
        add_task task
      end
    end

    ##
    # Single task version of add_tasks
    def add_task(task)
      @tasks << task
    end

    ##
    # Does this task exist?
    def has_task?(task)
      @tasks.map { |t| t.to_s }.include? task.to_s
    end

    ##
    # Hunt for and remove a particular task.
    def remove_task(task_name)
      @tasks.reject! { |task| task.name == task_name }
    end
  end

  ##
  # This is Sake's version of a Rake task.  Please handle with care.
  class Task
    attr_reader :name, :comment

    def initialize(name, deps = nil, comment = nil, &block)
      @name    = name
      @comment = comment
      @deps    = Array(deps)
      @body    = block
    end

    ##
    # Turn ourselves back into Rake task plaintext.
    def to_ruby
      out = ''
      out << "desc '#{@comment}'\n" if @comment
      out << "task '#{@name}'"

      if @deps.any?
        deps = @deps.map { |dep| "'#{dep}'" }.join(', ')
        out << " => [ #{deps} ]" 
      end

      out << " do\n"
      
      # get rid of the proc { / } lines
      out << @body.to_ruby.split("\n")[1...-1].join("\n")

      out << "\nend\n"
    end

    ##
    # String-ish duck typing
    def <=>(other)
      to_s <=> other.to_s
    end

    def to_s; @name end
    def inspect; @name.inspect end
  end

  ##
  # The store is, as of writing, a single Rake file: ~/.sake
  # When we add new tasks, we just re-build this file.  Over
  # and over.
  module Store
    extend self

    ##
    # Everything we can't catch gets sent to our tasks_file.
    # Common examples are #tasks or #add_task.
    def method_missing(*args, &block)
      tasks_file.send(*args, &block)
    end

    def tasks_file
      FileUtils.touch(path) unless path.is_file?
      @tasks_file ||= TasksFile.new(path)
    end

    def path
      File.join(File.expand_path('~'), '.sake')
    end

    def save!
      File.open(path, 'w') do |file|
        file.puts tasks_file.to_ruby
      end
    end
  end
end

module Rake
  class Application
    ##
    # Show the tasks as 'sake' tasks.
    def printf(*args)
      args[0].sub!('rake', 'sake') if args[0].is_a? String
      super
    end

    ##
    # Show tasks that don't have comments'
    def display_tasks_and_comments(tasks = nil, pattern = nil)
      tasks ||= self.tasks

      if pattern ||= options.show_task_pattern
        tasks = tasks.select { |t| t.name[pattern] || t.comment.to_s[pattern] }
      end

      width = tasks.collect { |t| t.name.length }.max

      tasks.each do |t|
        comment = "   # #{t.comment}" if t.comment
        printf "sake %-#{width}s#{comment}\n", t.name
      end
    end
    alias_method :show, :display_tasks_and_comments

    ##
    # Run Sake even if no Rakefile exists in the current directory.
    alias_method :sake_original_have_rakefile, :have_rakefile
    def have_rakefile(*args)
      @rakefile ||= ''
      sake_original_have_rakefile(*args) || true
    end
  end

  class Task
    ##
    # We want only run a Sake task -- not any other matching
    # or duplicate tasks.
    def enhance(deps=nil, &block)
      @prerequisites |= deps if deps
      @actions = [block] if block_given? 
      self
    end
  end
end

##
# Hacks which give us "Rakefile".is_file? 
class String
  def is_file?
    File.exists? self
  end
end

class Nil
  def is_file?
    false
  end
end

def die(*message)
  puts message 
  exit
end

Sake.new(ARGV).run if $0 == __FILE__