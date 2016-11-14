require "yaml"
require "json"
require "tmpdir"
require "fileutils"
require "open3"
require "dotenv"
require "slack/incoming/webhooks"

Dotenv.load
SLACK_WEB_HOOK_URL = ENV['SLACK_WEB_HOOK_URL']

PROJECT_DIR = File.expand_path("..", __FILE__)

RESPONSES = {
  :checkout_master_01 => "Switched to branch 'master'",
  :checkout_master_02 => "Already on 'master'",
  :pull_origin_master => "Already up-to-date."
}

def notify(environment, message)
  emoji = ':memo:'
  if message.include?('Apply')
    emoji = ':construction:'
    emoji = ':white_check_mark:' if message.include?('dry-run')
  end

  subject = "environment: #{environment}"
  puts "#{subject}\n#{message}"

  slack = Slack::Incoming::Webhooks.new SLACK_WEB_HOOK_URL
  slack.post("#{emoji} #{subject} #{emoji}\n#{message}")
end

def execute_command(command)
  command_result = ''
  IO.popen(command, :err => [:child, :out]).each { |line| command_result << line }
  command_result
end

def switch_master_branch
  # masterブランチに切り替え
  command_result = execute_command('git checkout master')
  if (!command_result.include?(RESPONSES[:checkout_master_01]) && !command_result.include?(RESPONSES[:checkout_master_02]))
    raise "failed to switch to master branch"
  end

  # 最新のソースを取得
  command_result = execute_command('git pull origin master')
  if (!command_result.include?(RESPONSES[:pull_origin_master]))
    raise "failed to pull from repository"
  end
end

def database_config
  database_yml = File.expand_path("../database.yml", __FILE__)
  YAML.load_file(database_yml)
end

def ridgepole(config_name, *args)
  unless config = database_config[config_name.to_s]
    raise "`#{config_name}` not found in database.yml"
  end

  config = JSON.dump(config)
  args << "--verbose" if ENV["VERBOSE"]
  args << "--debug" if ENV["DEBUG"]
  args = args.join(" ")

  out = []

 Open3.popen2e("ridgepole -c '#{config}' #{args}") do |stdin, stdout_and_stderr, wait_thr|
    stdin.close

    stdout_and_stderr.each_line do |line|
      out << line
      yield(line) if block_given?
    end
  end

  out.join("\n")
end

def export(environment, database, table, options = {}, &block)
  config_name = [environment, database].join("_")
  args = ["--export"]
  args.concat ["--tables", table] if table
  args << "--ignore-tables '#{options[:ignore_tables].join(",")}'" if options[:ignore_tables]
  Dir.mktmpdir do |dir|
    args.concat ["--output #{dir}/Schemafile", "--split"]
    ridgepole(config_name, *args, &block)
    files = Dir.glob("#{dir}/*").select {|f| not table or f !~ /Schemafile/ }
    database_dir = File.join(PROJECT_DIR, database)
    FileUtils.mkdir_p(database_dir)
    FileUtils.cp_r(files, database_dir)
  end
end

def apply(environment, database, table, options = {}, &block)
  mode = options[:mode] || :apply
  config_name = [environment, database].join("_")
  schema_file = File.join(PROJECT_DIR, database, "Schemafile")
  args = ["--#{mode}", '--file', schema_file]
  args.concat ["--dry-run"] if options[:dry_run]
  args.concat ["--tables", table] if table
  args << "--ignore-tables '#{options[:ignore_tables].join(",")}'" if options[:ignore_tables]
  ridgepole(config_name, *args, &block)
end
