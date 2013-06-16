# Keeps track of the repositories and branches we know about

class RepoManager
  attr_reader :forks

  def initialize(octokit)
    @octokit = octokit

    @forks = @octokit.forks(Stager.settings.base_repo[:name]).inject({}) do |hash, fork|
      hash[fork.owner.login] = { name: fork.name }
      hash
    end

    Dir.glob("#{Stager.settings.git_data_path}/*/*").each do |dir|
      next if !File.directory?(dir)
      username = dir.split('/')[-2]
      if @forks.has_key?(username)
        repo = Rugged::Repository.new(dir)
        @forks[username][:branches] = Rugged::Branch.each_name(repo, :local).to_a
      end
    end
  end

  def update_branch_info(owner)
    begin
      repo = @forks[owner]
      branches = @octokit.branches(owner + '/' + repo[:name])
    rescue
      return
    else
      repo[:branches] = branches.collect { |branch| branch.name }
      return repo[:branches]
    end
    # FIXME read local stuff too
  end

  def self.prepare_repo(app_dir, url)
    if !File.exists?(app_dir)
      Dir.chdir(File.dirname(app_dir)) do
        system <<-SCRIPT
          git clone #{url}
        SCRIPT
      end
    end
  end

  def self.prepare_branch(app_dir, branch)
    Dir.chdir app_dir do
      system <<-SCRIPT
        git fetch
        git checkout -f #{branch}
        git pull
      SCRIPT
    end
  end
end
