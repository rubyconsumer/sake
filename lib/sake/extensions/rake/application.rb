module Rake # :nodoc: all
  class Application
    ##
    # Show the tasks as 'sake' tasks.
    def printf(*args)
      args[0].sub!('rake', 'sake') if args[0].is_a? String
      super
    end

    ##
    # Show tasks that don't have comments'
    def display_tasks_and_comments(tasks = nil, pattern = nil, display_hidden = nil)
      tasks ||= self.tasks

      if pattern ||= options.show_task_pattern
        tasks = tasks.select { |t| t.name[pattern] || t.comment.to_s[pattern] }
      end

      width = tasks.collect { |t| t.name.length }.max

      tasks.each do |t|
        comment = "   # #{t.comment}" if t.comment
        if display_hidden
          printf "sake %-#{width}s#{comment}\n", t.name
        else
          printf "sake %-#{width}s#{comment}\n", t.name if t.name && t.comment
        end
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
  
    ##
    # Accept only one task, unlike Rake, to make passing arguments cleaner.
    alias_method :sake_original_collect_tasks, :collect_tasks
    def collect_tasks
      sake_original_collect_tasks
      @top_level_tasks = [@top_level_tasks.first]
    end
  end
end
