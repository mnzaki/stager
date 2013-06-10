class OperationsManager
  attr_reader :slots

  def initialize(git_data_path, slots, slot_port)
    @git_data_path = git_data_path

    @slots = slots.inject({}) do |hash, slot|
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
    app_dir = File.join(@git_data_path, fork_name)
    OperationsManager.delay.start_app(@slots[slot_name], app_dir, branch_name)
  end

  def self.start_app(slot, app_dir, branch_name)
    Bundler.with_clean_env do
      RepoManager.prepare_branch(app_dir, branch_name)

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

