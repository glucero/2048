include Rake::DSL

Rake::TaskManager.record_task_metadata = true

desc 'List all rake tasks (rake -T)'
task(:default) do
  Rake.application.options.show_tasks = :tasks
  Rake.application.options.show_task_pattern = //
  Rake.application.display_tasks_and_comments
end

desc 'Start 2048 Game'
task(:start) { exec 'ruby', '2048.rb' }
