class Sake
  ##
  # Lets us do:
  #   tasks = TasksFile.parse('Rakefile').tasks
  #   task  = tasks['db:remigrate']
  class TasksArray < Array
    ##
    # Accepts a task name or index.
    def [](name_or_index)
      if name_or_index.is_a? String
        detect { |task| task.name == name_or_index }
      else
        super
      end
    end

    ##
    # The source of all these tasks.
    def to_ruby
      map { |task| task.to_ruby }.join("\n")
    end
  end
end
