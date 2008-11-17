require 'rake'

class Sake
  ##
  # This class represents a Rake task file, in the traditional sense.
  # It takes on parameter: the path to a Rakefile.  When instantiated,
  # it will read the file and parse out the rake tasks, storing them in
  # a 'tasks' array.  This array can be accessed directly:
  #
  #   file = Sake::TasksFile.parse('Rakefile')
  #   puts file.tasks.inspect
  #
  # The parse method also works with remote files, as its implementation 
  # uses open-uri's open().
  #
  #   Sake::TasksFile.parse('Rakefile')
  #   Sake::TasksFile.parse('http://errtheblog.com/code/errake')
  class TasksFile

    include Rake::TaskManager

    attr_reader :tasks

    ##
    # The idea here is that we may be sucking in Rakefiles from an untrusted
    # source.  While we're happy to let the user audit the code of any Rake
    # task before running it, we'd rather not be responsible for executing a
    # `rm -rf` in the Rakefile itself.  To ensure this, we need to set a 
    # safelevel before parsing the Rakefile in question.
    def self.parse(file)
      body = (file == "-" ? $stdin : open(file)).read

      instance = new
      Thread.new { instance.instance_eval "$SAFE = 3\n#{body}" }.join
      instance
    end

    def initialize
      @namespace = []
      @tasks     = TasksArray.new
      @comment   = nil
    end

    ##
    # We fake out an approximation of the Rake DSL in order to build
    # our tasks array.

    ##
    # Call to_ruby on all our tasks and return a concat'd string of them.
    def to_ruby
      @tasks.to_ruby
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
    def remove_task(target_task)
      @tasks.reject! { |task| task.name == target_task.name }
    end

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
    def task(*args, &block)
      # Use Rake::TaskManager method to get task details
      task_name, arg_names, deps = resolve_args(args)

      # Our namespace is really just a convenience method.  Essentially,
      # a namespace is just part of the task name.
      task_name = [ @namespace, task_name ].flatten * ':'

      # Sake's version of a rake task
      task = Task.new(task_name, arg_names, deps, @comment, &block)

      @tasks << task

      # We sucked up the last 'desc' declaration if it existed, so now clear
      # it -- we don't want tasks without a description given one.
      @comment = nil
    end

  end
end
