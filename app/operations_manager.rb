class OperationsManager
  attr_reader :slots

  def initialize
    slot_port = Stager.settings.first_slot_port
    @slots = Stager.settings.slots.inject({}) do |hash, slot_name|
      hash[slot_name] = ActiveSlot.new(name: slot_name, port: slot_port)
      slot_port += 1
      hash
    end

    ActiveSlot.all.each do |active|
      next if !@slots.include?(active.name)
      @slots[active.name] = active
    end
  end

  def stage(slot_name, fork_name, branch_name)
    #FIXME can't stage multiple branches from same repo using current method :/
    if @slots.include?(slot_name)
      slot = @slots[slot_name]
      # ensure slot is in the database
      slot.save

      if slot.job_id != -1
        container = SidekiqStatus::Container.load(slot.job_id)
        puts slot.job_id
        puts container.status
        container.request_kill
      end

      jid = OperationsManagerWorker.perform_async(slot_name, fork_name, branch_name)
      if jid
        slot.attributes = { job_id: jid }
        return true
      end
    end
    return false
  end

end

class OperationsManagerWorker
  include SidekiqStatus::Worker

  def perform(slot_name, fork_name, branch_name)
    slot = ActiveSlot.get(slot_name)
    app_dir = File.join(Stager.settings.git_data_path, slot.current_fork)

    self.total = 5

    Dir.chdir app_dir do
      if slot.app_pid != -1
        at(1, 'Stopping Server')
        system <<-SCRIPT
          while ps -p #{slot.app_pid} &> /dev/null; do
            kill #{slot.app_pid} &> /dev/null
            sleep 1
          done
        SCRIPT
      end
      slot.attributes = { app_pid: -1 }
    end

    slot.attributes = { current_fork: fork_name, current_branch: branch_name }

    url = Octokit::Repository.new(slot.current_fork).url
    app_dir = File.join(Stager.settings.git_data_path, slot.current_fork)

    at(2, 'Update repository')
    RepoManager.prepare_repo(app_dir, url)
    RepoManager.prepare_branch(app_dir, slot.current_branch)

    Bundler.with_clean_env do
      Dir.chdir app_dir do
        ENV['RAILS_ENV'] = 'staging'

        at(3, 'Creating Gem Bundle')
        system 'bundle'

        at(4, 'Precompiling Assets')
        system 'bundle exec rake assets:precompile'

        at(5, 'Starting server')
        if system("rails server -p #{slot[:port]} -d")
          pid = File.read('tmp/pids/server.pid')
          slot.attributes = { app_pid: pid }
        end

        ENV.delete 'RAILS_ENV'
      end
    end
  end
end
