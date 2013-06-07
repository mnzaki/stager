Rake::TaskManager.record_task_metadata = true

task :default do
  puts "Available tasks:"
  Rake.application.options.show_tasks = :tasks
  Rake.application.options.full_description = true
  Rake.application.options.show_task_pattern = //
  Rake.application.display_tasks_and_comments
end

task :env do
  require_relative 'app.rb'
end

namespace :db do
  desc 'Drop and recreate the database'
  task :setup => :env do
    DataMapper.finalize.auto_migrate!
  end

  desc 'Migrate the database'
  task :migrate => :env do
    DataMapper.finalize.auto_upgrade!
  end
end

