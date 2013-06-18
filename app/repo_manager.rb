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

  def self.repo_dir(repo_name)
    File.join(Stager.settings.git_data_path, repo_name)
  end

  def self.clone_url(repo_name)
    "https://#{Stager.settings.base_repo[:access_token]}@github.com/#{repo_name}"
  end

  def self.prepare_repo(repo_name, use_reference = true)
    dir = RepoManager.repo_dir repo_name
    url = RepoManager.clone_url repo_name
    if !File.exists?(dir)
      user_dir = File.dirname(dir)
      FileUtils.mkdir_p user_dir
      Dir.chdir(user_dir) do
        if use_reference
          base_repo = RepoManager.repo_dir Stager.settings.base_repo[:name]
          system "git clone --reference #{base_repo} #{url}"
        else
          system "git clone #{url}"
        end
      end
    end
  end

  def self.prepare_branch(repo_name, branch_name)
    RepoManager.prepare_repo repo_name
    dir = RepoManager.repo_dir repo_name
    Dir.chdir dir do
      system <<-SCRIPT
        git fetch &&
        git checkout -f #{branch_name} &&
        git reset --hard origin/#{branch_name}
      SCRIPT
    end
  end
end
