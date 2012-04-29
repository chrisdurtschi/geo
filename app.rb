require 'grit'
require 'foreman/cli'

module Geo
  class App
    def self.upgrade!
      repo = Grit::Repo.new(File.join(File.dirname(__FILE__), '.'))
      repo.remote_fetch('origin')
      remote = repo.remotes.find { |r| r.name == 'origin/master' }
      remote_commit = remote.commit.to_s
      local_commit  = repo.commits.last.to_s

      if remote_commit != local_commit && repo.fast_forwardable?(remote_commit, local_commit)
        STDOUT.puts "Geo::App - upgrading"
        STDOUT.puts repo.git.native 'merge', {}, 'origin/master'
        foreman = Foreman::CLI.new
        foreman.export 'upstart', '/etc/init'
        STDOUT.puts "Geo::App - exported Foreman upstart scripts"
        STDOUT.puts `restart geo`
      else
        STDOUT.puts "Geo::App - nothing to upgrade"
      end
    end
  end
end
