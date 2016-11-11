require File.expand_path("../rake_helper", __FILE__)

output_text = ''

namespace :development do
  task :export, :database, :table do |t, args|
    export(:development, args[:database], args[:table]) do |line|
      output_text << line.gsub(/write `([^`]+)`/) { "write `#{File.basename($1)}`" }
    end
    notify(:development, output_text)
  end

  task :'dry-run', :database, :table do |t, args|
    apply(:development, args[:database], args[:table], dry_run: true) do |line|
      output_text << line
    end
    notify(:development, output_text)
  end

  task :apply, :database, :table do |t, args|
    apply(:development, args[:database], args[:table]) do |line|
      output_text << line
    end
    notify(:development, output_text)
  end
end

namespace :production do
  task :export, :database, :table do |t, args|
    export(:production, args[:database], args[:table]) do |line|
      output_text << line.gsub(/write `([^`]+)`/) { "write `#{File.basename($1)}`" }
    end
    notify(:production, output_text)
  end

  task :'dry-run', :database, :table do |t, args|
    switch_master_branch()
    apply(:production, args[:database], args[:table], dry_run: true) do |line|
      output_text << line
    end
    notify(:production, output_text)
  end

  task :apply, :database, :table do |t, args|
    switch_master_branch()
    apply(:production, args[:database], args[:table]) do |line|
      output_text << line
    end
    notify(:production, output_text)
  end
end
