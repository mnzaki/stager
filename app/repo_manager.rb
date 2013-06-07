# Keeps track of the repositories and branches we know about

class RepoManager
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

  def forks
    @forks
  end
end
