require 'sake/tasks_file'

class Sake
  ##
  # The store is, as of writing, a single Rakefile: ~/.sake
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

    ##
    # A TaskFile object of our Store
    def tasks_file
      @tasks_file ||= TasksFile.parse(path)
    end

    ##
    # The platform-aware path to the Store
    def path
      path = if PLATFORM =~ /win32/
        win32_path
      else
        File.join(File.expand_path('~'), '.sake')
      end
      FileUtils.touch(path) unless path.is_file?
      path
    end

    def win32_path #:nodoc:
      unless File.exists?(win32home = ENV['HOMEDRIVE'] + ENV['HOMEPATH'])
        puts "# No HOMEDRIVE or HOMEPATH environment variable.",  
             "# Sake needs to know where it should save Rake tasks!"
      else
        File.join(win32home, 'Sakefile')
      end
    end

    ##
    # Wrote our current tasks_file to disk, overwriting the current Store.
    def save!
      tasks_file # ensure the tasks_file is loaded before overwriting
      File.open(path, 'w') do |file|
        file.puts tasks_file.to_ruby
      end
    end
  end
end
