class OperationsManager
  attr_reader :slots

  def initialize
    slot_port = Stager.settings.first_slot_port
    @slots = Stager.settings.slots.inject({}) do |hash, slot_name|
      hash[slot_name] = ActiveSlot.new(name: slot_name, port: slot_port)
      slot_port += 1
      hash
    end

    @slots_info_ts = Time.now - 42
    slots_info
  end

  def stage(slot_name, fork_name, branch_name)
    #FIXME can't stage multiple branches from same repo using current method :/
    if @slots.include?(slot_name)
      slot = @slots[slot_name]
      # ensure slot is in the database
      slot.save

      if slot.job_id != ''
        container = SidekiqStatus::Container.load(slot.job_id)
        container.request_kill
      end

      jid = OperationsManagerWorker.perform_async(slot_name, fork_name, branch_name)
      if jid
        slot.job_id = jid
        slot.save
        return true
      end
    end
    return false
  end

  def slots_info
    return @slots_info if (Time.now - @slots_info_ts) < 1.5
    @slots_info_ts = Time.now

    ActiveSlot.all.each do |active|
      next if !@slots.include?(active.name)
      @slots[active.name] = active
    end

    @slots_info = @slots.collect do |slot_name, slot|
      attrs = slot.attributes
      attrs.delete :app_pid
      attrs.delete :job_id

      if slot.job_id != ''
        container = SidekiqStatus::Container.load(slot.job_id)
        attrs[:status] = container.message if container.status != 'failed'
        attrs[:status] = container.status if attrs[:status].nil? or attrs[:status].empty?
      elsif slot.app_pid != -1
        attrs[:status] = 'Live'
      else
        attrs[:status] = 'Idle'
      end
      attrs
    end
  end
end

class OperationsManagerWorker
  include SidekiqStatus::Worker
  sidekiq_options retry: false

  def self.kill_app(pid)
    system <<-SCRIPT
      while ps -p #{pid} &> /dev/null; do
        kill #{pid} &> /dev/null
        sleep 1
      done
      ./script/delayed_job stop
    SCRIPT
  end

  def perform(slot_name, fork_name, branch_name)
    # HORRENDOUS HACK to avoid sqlite database locks
    # FIXME FIXME FIXME
    sleep 1
    # /FIXME
    slot = ActiveSlot.get(slot_name)

    self.total = 6

    # kill any app we know is taking up this slot
    app_dir = RepoManager.repo_dir(slot.current_fork)
    if slot.app_pid != -1 and !slot.current_fork.nil?
      Dir.chdir app_dir do
        at(1, 'Stopping Server')
        OperationsManagerWorker.kill_app slot.app_pid
      end
      slot.app_pid = -1
    end

    slot.current_fork = fork_name
    slot.current_branch = branch_name
    slot.save

    # kill the current app if it is running and we don't know
    app_dir = RepoManager.repo_dir slot.current_fork
    if File.exists?('tmp/pids/server.pid')
      pid = File.read('tmp/pids/server.pid')
      Dir.chdir app_dir do
        at(1, 'Stopping Server')
        OperationsManagerWorker.kill_app pid
      end
    end

    at(2, 'Updating repository')
    RepoManager.prepare_branch(slot.current_fork, slot.current_branch)

    Bundler.with_clean_env do
      Dir.chdir app_dir do
        ENV['RAILS_ENV'] = 'staging'
        ENV['STAGING_HOST'] = "#{Stager.settings.host}:#{slot.port}"

        at(3, 'Creating Gem Bundle')
        system 'bundle'

        at(4, 'Precompiling Assets')
        system 'bundle exec rake assets:precompile'

        at(5, 'Starting app server')
        # note: 'sleep 1' because sometimes server.pid is not yet created
        if system("bundle exec rails server -p #{slot[:port]} -d && sleep 1")
          pid = File.read('tmp/pids/server.pid')
          slot.app_pid = pid
          slot.save
        else
          raise 'Failed to start the application'
        end

        at(6, "Starting delayed_job worker")
        unless system('./script/delayed_job start')
          raise 'Failed to start delayed_job worker'
        end

        ENV.delete 'RAILS_ENV'
      end
    end
  end
end
