Rake::TaskManager.record_task_metadata = true

task :default do
  puts "Available tasks:"
  Rake.application.options.show_tasks = :tasks
  Rake.application.options.full_description = true
  Rake.application.options.show_task_pattern = //
  Rake.application.display_tasks_and_comments
end

task :env do
  require './app.rb'
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

desc 'syncronize slot app pids'
task :sync_pids => :env do
    ActiveSlot.all.each do |slot|
        ps_result = `ps -eo pid,command | grep "rails.*#{slot.port}"`
        pid = ps_result.split("\n").select {|i| !i.include?("grep")}.first.to_i
        slot.app_pid = -1
        slot.app_pid = pid unless pid==0
        slot.save
    end
end
