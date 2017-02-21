module RepositoryHost
  class Github < Base
    IGNORABLE_EXCEPTIONS = [Octokit::Unauthorized, Octokit::InvalidRepository, Octokit::RepositoryUnavailable, Octokit::NotFound, Octokit::Conflict, Octokit::Forbidden, Octokit::InternalServerError, Octokit::BadGateway, Octokit::ClientError]

    def avatar_url(size = 60)
      "https://avatars.githubusercontent.com/u/#{repository.owner_id}?size=#{size}"
    end

    def create_webhook(token = nil)
      api_client(token).create_hook(
        full_name,
        'web',
        {
          :url => 'https://libraries.io/hooks/github',
          :content_type => 'json'
        },
        {
          :events => ['push', 'pull_request'],
          :active => true
        }
      )
    rescue Octokit::UnprocessableEntity
      nil
    end

    def download_forks(token = nil)
      return true if repository.fork?
      return true unless repository.forks_count && repository.forks_count > 0 && repository.forks_count < 100
      return true if repository.forks_count == repository.forked_repositories.count
      AuthToken.new_client(token).forks(repository.full_name).each do |fork|
        Repository.create_from_hash(fork)
      end
    end

    def download_issues(token = nil)
      api_client = AuthToken.new_client(token)
      issues = api_client.issues(full_name, state: 'all')
      issues.each do |issue|
        Issue.create_from_hash(repository, issue)
      end
    rescue *IGNORABLE_EXCEPTIONS
      nil
    end

    private

    def api_client(token = nil)
      AuthToken.fallback_client(token)
    end
  end
end
