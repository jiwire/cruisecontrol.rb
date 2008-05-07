module SourceControl
  class Mercurial < AbstractAdapter

    attr_accessor :repository

    def initialize(options)
      options = options.dup
      @path = options.delete(:path) || "."
      @error_log = options.delete(:error_log)
      @interactive = options.delete(:interactive)
      @repository = options.delete(:repository)
      raise "don't know how to handle '#{options.keys.first}'" if options.length > 0
    end

    def checkout(revision = nil, stdout = $stdout)
      raise 'Repository location is not specified' unless @repository

      raise "#{path} is not empty, cannot clone a project into it" unless (Dir.entries(path) - ['.', '..']).empty?
      FileUtils.rm_rf(path)

      # need to read from command output, because otherwise tests break
      hg('clone', [@repository, path], :execute_in_current_directory => false) do |io|
        begin
          while line = io.gets
            stdout.puts line
          end
        rescue EOFError
        end
      end
    end

    def latest_revision
      pull_new_changesets
      hg_output = hg('log', ['-v', '-r', 'tip'])
      Mercurial::LogParser.new.parse(hg_output).first 
    end

    def update(revision)
      hg("update")
    end

    def up_to_date?(reasons = [])
      _new_revisions = new_revisions
      if _new_revisions.empty?
        return true
      else
        reasons << _new_revisions
        return false
      end
    end

    def creates_ordered_build_labels?() false end

    protected

    def pull_new_changesets
      hg("pull")
    end

    def new_revisions
      pull_new_changesets
      hg_output = hg('parents', ['-v'])
      current_local_revision = Mercurial::LogParser.new.parse(hg_output).first
      revisions_since(current_local_revision)
    end

    def revisions_since(revision)
      log_output = hg("log", ['-v', '-r', "#{revision.number}:tip"])
      revs = LogParser.new.parse(log_output)
      revs.delete_if do |rev|
        rev.number == revision.number
      end
      revs
    end

    def hg(operation, arguments = [], options = {}, &block)
      command = ["hg", operation] + arguments.compact
## TODO: figure out how to handle the same thing with hg
##      command << "--non-interactive" unless @interactive
      execute_in_local_copy(command, options, &block)
    end

  end
end
