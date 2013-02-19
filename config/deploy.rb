require 'bundler/capistrano'

load 'deploy' if respond_to?(:namespace) # cap2 differentiator
require 'highline/import'

default_run_options[:pty] = true

# be sure to change these
set :application, 'triviajabber'
set :repository,  "git@github.com:xurde/Triviapad-triviajabber.git"

# If you aren't using Subversion to manage your source code, specify
# your SCM below:
set :scm_verbose, true
set :scm, :git
#set :scm_password, "capistranodeploy"
#set :git_password, "capistranodeploy"

#set :use_sudo, false
set :keep_releases, 3

set :environment, choose('Staging', 'Production')

case environment
when 'Staging'
  #ssh_options[:forward_agent] = true
  set :deploy_via, :remote_cache
  set :user, 'capistrano'
  set :password, 'fugazz1'
  set :domain, 'dev.triviapad.com'
  set :branch, "master"
  set :deploy_to, "/www/#{application}"
when 'Production'
  ssh_options[:forward_agent] = true
  set :deploy_via, :remote_cache
  set :branch, "master"
  set :user, 'capistrano'
  set :domain, 'raw.triviapad.com'
  set :deploy_to, "/www/#{application}"
end

role :app, domain
role :web, domain
role :db,  domain, :primary => true


#after 'deploy:update', 'deploy:enable_default_theme', 'deploy:cleanup'

namespace :deploy do

  desc "Update symlinks to the current release"
  task :update_links, :roles => :app do
    #run "ln -nfs #{deploy_to}/shared/system/ #{release_path}/public/system"
    run "ln -nfs #{deploy_to}/shared/system/config/database.yml #{release_path}/config/database.yml"
    # run "ln -nfs #{deploy_to}/shared/system/config/s3.yml #{release_path}/config/s3.yml"
    # run "ln -nfs #{deploy_to}/shared/system/config/unicorn.rb #{release_path}/config/unicorn.rb"
    run "ln -nfs #{deploy_to}/shared/system/config/triviajabber.yml #{release_path}/config/triviajabber.yml"
  end

  desc "Restart passenger"
  task :restart do
    #run "touch #{current_path}/tmp/restart.txt"
  end

  desc "Fetch and Install the bundled gems"
  task :bundle_gems do
    run "cd #{current_path} && bundle install --without development"
  end

  desc "Install gems"
  task :install_required_gems do
    sudo 'gem update --system'
    sudo 'gem install rake'
    sudo 'gem install bundler'
  end

  desc "Override default deploy:cold"
  task :cold do
    update
    load_schema
    migrate
    start
  end

  task :load_schema, :roles => :app do
    run "cd #{current_path}; RAILS_ENV=production rake db:create"
  end

  after 'deploy:update', 'deploy:update_links', 'deploy:bundle_gems'
  after 'deploy:setup',  'deploy:install_required_gems'
end


namespace :logs do

  desc "tail production log files" 
  task :tail, :roles => :app do
    run "tail --lines 100 -f #{shared_path}/log/production.log" do |channel, stream, data|
      puts  # for an extra line break before the host name
      puts "#{channel[:host]}: #{data}"
      break if stream == :err
    end
  end

end
