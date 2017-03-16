set :application, 'fat_free_crm'
set :stage, "production"
set :branch, "master"
set :deploy_to, "/home/sites/#{fetch(:stage)}/#{fetch(:application)}"

server '83.170.70.107', user: 'www-data', roles: %w{web app}

namespace :symlinks do
  desc "create links to secrets"
  task :secure do
    on roles(:app) do
      within release_path do
        ['database','secrets'].each do |secret|
          secret_file_link="#{release_path}/config/#{secret}.yml"
          secret_file_target="#{shared_path}/config/#{secret}.yml"
          execute "rm -f #{secret_file_link}"
          execute "ln -s #{secret_file_target} #{secret_file_link}"
        end
      end
    end
  end
  desc "create linked folders"
  task :create do
    on roles(:app) do
      within release_path do
        ["log","tmp"].each do |shared_folder|
          shared_folder_path="#{shared_path}/#{shared_folder}"
          begin
            execute "mkdir #{shared_folder_path}"
          rescue
          end
          # execute "rm -rf #{release_path}/#{shared_folder}"
          # execute "ln -s #{shared_folder_path} #{release_path}/#{shared_folder}"
        end
      end
    end
  end
end

namespace :bundle do
  desc "bundle install"
  task :install do
    on roles(:app) do
      within release_path do
        execute "/bin/bash -l -i -c 'cd #{release_path} && rvm use default && bundle install'"
      end
    end
  end
end

namespace :db do
  desc "migrate database"
  task :migrate do
    on roles(:app) do
      within release_path do
        execute "/bin/bash -l -i -c 'cd #{release_path} && rvm use default && rake RAILS_ENV=#{fetch(:stage)} db:migrate'"
      end
    end
  end
end

namespace :rails do
  desc "precompile assets"
  task :precompile_assets do
    on roles(:app) do
      within release_path do
        execute "/bin/bash -l -i -c 'cd #{release_path} && rvm use default && rake RAILS_ENV=#{fetch(:stage)} assets:precompile'"
      end
    end
  end

  desc "restart"
  task :restart do
    on roles(:app) do
      within release_path do
        execute "/bin/bash -l -i -c 'cd #{release_path} && rvm use default && touch tmp/restart.txt'"
      end
    end
  end

  desc "webpacker"
  task :webpacker do
    on roles(:app) do
      within release_path do
        execute "/bin/bash -l -i -c 'cd #{release_path} && rvm use default && yarn install --production && rake RAILS_ENV=production webpacker:compile'"
      end
    end
  end
end


after "symlinks:create", "symlinks:secure"
after "deploy:updated", "symlinks:create"
after "deploy:updated", "bundle:install"
after "bundle:install", "rails:precompile_assets"
after "rails:precompile_assets", "db:migrate"
after "deploy:finished", "rails:restart"
