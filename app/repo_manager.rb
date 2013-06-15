# Keeps track of the repositories and branches we know about

class RepoManager
  attr_reader :forks

  def initialize(octokit, repos_path, base_repo)
    @octokit = octokit
    @repos_path = repos_path
    @base_repo = base_repo
    @forks = @octokit.forks(base_repo).inject({}) do |hash, fork|
      hash[fork.owner.login] = { name: fork.name }
      hash
    end

    Dir.glob("#{@repos_path}/*/*").each do |dir|
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

  def self.prepare_branch(app_dir, branch)
    Dir.chdir app_dir do
      system <<-SCRIPT
        git checkout -f #{branch}
        git pull
      SCRIPT
    end
  end
end
