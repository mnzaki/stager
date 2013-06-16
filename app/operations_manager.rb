class OperationsManager
  attr_reader :slots

  def initialize
    slot_port = Stager.settings.first_slot_port
    @slots = Stager.settings.slots.inject({}) do |hash, slot|
      hash[slot] = { currentFork: nil, currentBranch: nil, port: slot_port}
      slot_port += 1
      hash
    end

    ActiveSlot.all.each do |active|
      next if !@slots.include?(active.name)
      @slots[active.name].merge!({
        currentFork: active.current_fork,
        currentBranch: active.current_branch,
        port: active.port
      })
    end
  end

  def stage(slot_name, fork_name, branch_name)
    @slots[slot_name].merge!({
      currentFork: fork_name,
      currentBranch: branch_name
    })
    OperationsManager.delay.start_app(slot_name, @slots[slot_name])
  end

  def self.start_app(slot_name, slot)
    Bundler.with_clean_env do
      url = Octokit::Repositories.new(slot[:currentFork]).url
      app_dir = File.join(Stager.settings.git_data_path, slot[:currentFork])
      RepoManager.prepare_repo(app_dir, url)
      RepoManager.prepare_branch(app_dir, slot[:currentBranch])

      Dir.chdir app_dir do
        system <<-SCRIPT
          export RAILS_ENV=staging
          bundle &&
          rake assets:precompile &&
          rails server -p #{slot[:port]}
        SCRIPT
      end
    end
  end
end

