# config valid only for Capistrano 3.1
#lock '3.2.1'

# application and repo settings
set :application, 'hydraagg'
set :repo_url, "https://github.com/AndrewGearhart/dplah.git"
#set :repo_url, "https://github.com/psu-stewardship/#{fetch(:application)}.git"

# default branch is :develop
#ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call
set :branch, ENV["REVISION"] || ENV["BRANCH_NAME"] || "develop"

# default user and deployment location
set :user, "deploy"
set :deploy_to, "/opt/hydraagg/deploy/#{fetch(:application)}"
set :use_sudo, false

# ssh key settings
set :ssh_options, {
    keys: [File.join(ENV["HOME"], ".ssh", "id_deploy_rsa")],
    forward_agent: true,
    #auth_methods: %w(password)
    #keys: %w(/home/rlisowski/.ssh/id_rsa),  
}

# rbenv settings
set :rbenv_type, :user # or :system, depends on your rbenv setup
set :rbenv_ruby, File.read(File.join(File.dirname(__FILE__), '..', '.ruby-version')).chomp # read from file above
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec" # rbenv settings
set :rbenv_map_bins, %w{rake gem bundle ruby rails} # map the following bins
set :rbenv_roles, :all # default value

#set passenger to just the web servers
set :passenger_roles, :web

# rails settings, NOTE: Task is wired into event stack
set :rails_env, 'production'

# whenever settings, NOTE: Task is wired into event stack
set :whenever_identifier, -> {"#{fetch(:application)}_#{fetch(:stage)}"}
set :whenever_roles, [:app, :job]

# git for source control
set :scm, :git
#set :git_strategy, Capistrano::Git::SubmoduleStrategy

# Default value for :format is :pretty
set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :debug

# Default value for :pty is false
set :pty, true

# Default value for :linked_files is []
#set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
# set :linked_dirs, %w{log}
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5, setting to 7
set :keep_releases, 7

#capistrano-passenger gem values
# Until Passenger allows sudoless restarts this needs to be in place as, we restrict sudo commands and the sudo command needed would have to change with every ruby version change because of the rbenv prefix.
set :passenger_restart_command, "sudo service httpd restart"
set :passenger_restart_options, -> {}

# Apache namespace to control apache
namespace :apache do
 [:stop, :start, :restart, :reload].each do |action|
 desc "#{action.to_s.capitalize} Apache"
  task action do
   on roles(:web) do
    execute "sudo service httpd #{action.to_s}"
   end
  end
 end
end

namespace :deploy do
  
  # Link the appropriate configuration files based on application, stage, and release path
  desc "Link shared files"
  task :symlink_shared do
  on roles(:app) do
#### dpla.yml from dpla.yml.example -- add this
    #execute "ln -sf /dlt/#{fetch(:application)}/config_#{fetch(:stage)}/#{fetch(:application)}/database.yml #{fetch(:release_path)}/config/"
    #execute "ln -sf /dlt/#{fetch(:application)}/config_#{fetch(:stage)}/#{fetch(:application)}/secret_token.rb #{fetch(:release_path)}/config/initializers/"
    end
  end
  after 'deploy:symlink:shared', :symlink_shared 

  # Resolarize objects
  desc "Re-solrize objects"
  task :resolrize do
   on roles(:job) do
    within release_path do
     with rails_env: fetch(:rails_env) do
      execute :rake, "#{fetch(:application)}:resolrize"
     end
   end
  end
 end
 after :migrate, :resolrize
 
 # Restart resque-pool.
 desc "Restart resque-pool"
 task :resquepoolrestart do
  on roles(:job) do
    execute :sudo,  "/sbin/service resque_pool restart"
  end
 end
 before :restart, :resquepoolrestart
 
 #after :publishing, :restart
 after :restart, "passenger:warmup" 
end
