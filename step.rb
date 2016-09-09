require 'optparse'
require 'tmpdir'
require 'open3'
require 'json'
require_relative 'xtc_client/client.rb'

require_relative 'xamarin-builder/builder'

# -----------------------
# --- Constants
# -----------------------
@work_dir = ENV['BITRISE_SOURCE_DIR']
@result_log_path = File.join(@work_dir, 'TestResult.xml')

# -----------------------
# --- Functions
# -----------------------

def log_info(message)
  puts
  puts "\e[34m#{message}\e[0m"
end

def log_details(message)
  puts "  #{message}"
end

def log_done(message)
  puts "  \e[32m#{message}\e[0m"
end

def log_warning(message)
  puts "\e[33m#{message}\e[0m"
end

def log_error(message)
  puts "\e[31m#{message}\e[0m"
end

def log_fail(message)
  system('envman add --key BITRISE_XAMARIN_TEST_RESULT --value failed')

  puts "\e[31m#{message}\e[0m"
  exit(1)
end

def fail_with_message(message)
  puts "\e[31m#{message}\e[0m"
  exit(1)
end

def export_ios_xcarchive(archive_path, export_options)
  log_info("Exporting ios archive at path: #{archive_path}")

  export_options_path = export_options
  unless export_options_path
    log_info('Generating export options')

    # Generate export options
    #  Bundle install
    current_dir = File.expand_path(File.dirname(__FILE__))
    gemfile_path = File.join(current_dir, 'export-options', 'Gemfile')

    bundle_install_command = [
      "BUNDLE_GEMFILE=\"#{gemfile_path}\"",
      'bundle',
      'install'
    ]

    log_info(bundle_install_command.join(' '))
    success = system(bundle_install_command.join(' '))
    fail_with_message('Failed to create export options (required gem install failed)') unless success

    #  Bundle exec
    temp_dir = Dir.mktmpdir('_bitrise_')

    export_options_path = File.join(temp_dir, 'export_options.plist')
    export_options_generator = File.join(current_dir, 'export-options', 'generate_ios_export_options.rb')

    bundle_exec_command = [
      "BUNDLE_GEMFILE=\"#{gemfile_path}\"",
      'bundle',
      'exec',
      'ruby',
      export_options_generator,
      "-o \"#{export_options_path}\"",
      "-a \"#{archive_path}\""
    ]

    log_info(bundle_exec_command.join(' '))
    success = system(bundle_exec_command.join(' '))
    fail_with_message('Failed to create export options') unless success
  end

  # Export ipa
  export_command = [
    'xcodebuild',
    '-exportArchive',
    "-archivePath \"#{archive_path}\"",
    "-exportPath \"#{temp_dir}\"",
    "-exportOptionsPlist \"#{export_options_path}\""
  ]

  log_info(export_command.join(' '))
  success = system(export_command.join(' '))
  fail_with_message('Failed to export IPA') unless success

  temp_ipa_path = Dir[File.join(temp_dir, '*.ipa')].first
  fail_with_message('No generated IPA found') unless temp_ipa_path

  temp_ipa_path
end
puts "ENVIRONMENT"
ENV.keys.each {|k| puts "#{k}: #{ENV[k]}"}
# -----------------------
# --- Main
# -----------------------

#
# Parse options
options = {
  project: nil,
  configuration: nil,
  platform: nil,
  api_key: nil,
  user: nil,
  android_devices: nil,
  ios_devices: nil,
  async: 'yes',
  series: 'master',
  parallelization: nil,
  sign_parameters: nil,
  other_parameters: nil
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: step.rb [options]'
  opts.on('-s', '--project path', 'Project path') { |s| options[:project] = s unless s.to_s == '' }
  opts.on('-c', '--configuration config', 'Configuration') { |c| options[:configuration] = c unless c.to_s == '' }
  opts.on('-p', '--platform platform', 'Platform') { |p| options[:platform] = p unless p.to_s == '' }
  opts.on('-a', '--api key', 'Api key') { |a| options[:api_key] = a unless a.to_s == '' }
  opts.on('-u', '--user user', 'User') { |u| options[:user] = u unless u.to_s == '' }
  opts.on('-d', '--devices devices', 'Devices') { |d| options[:devices] = d unless d.to_s == '' }
  opts.on('-y', '--async async', 'Async') { |y| options[:async] = y unless y.to_s == '' }
  opts.on('-r', '--series series', 'Series') { |r| options[:series] = r unless r.to_s == '' }
  opts.on('-l', '--parallelization parallelization', 'Parallelization') { |l| options[:parallelization] = l unless l.to_s == '' }
  opts.on('-g', '--sign parameters', 'Sign') { |g| options[:sign_parameters] = g unless g.to_s == '' }
  opts.on('-m', '--other parameters', 'Other') { |m| options[:other_parameters] = m unless m.to_s == '' }
  opts.on('-h', '--help', 'Displays Help') do
    exit
  end
end
parser.parse!
options[:android_devices] = ENV['test_cloud_android_devices']
options[:ios_devices] = ENV['test_cloud_ios_devices']

#
# Print options
log_info 'Configs:'
log_details("* project: #{options[:project]}")
log_details("* configuration: #{options[:configuration]}")
log_details("* platform: #{options[:platform]}")
log_details('* api_key: ***')
log_details("* user: #{options[:user]}")
log_details("* devices: #{options[:devices]}")
log_details("* async: #{options[:async]}")
log_details("* series: #{options[:series]}")
log_details("* parallelization: #{options[:parallelization]}")
log_details('* sign_parameters: ***')
log_details("* other_parameters: #{options[:other_parameters]}")

#
# Validate options
log_fail('No project file found') unless options[:project] && File.exist?(options[:project])
log_fail('configuration not specified') unless options[:configuration]
log_fail('platform not specified') unless options[:platform]
log_fail('api_key not specified') unless options[:api_key]
log_fail('user not specified') unless options[:user]
log_fail('devices not specified') unless (options[:android_devices] || options[:ios_devices])
log_fail('series not specified') unless options[:series]

#
# Main
begin
  builder = Builder.new(options[:project], options[:configuration], options[:platform], [Api::IOS, Api::ANDROID])
  builder.build
  builder.build_test
rescue => ex
  log_error(ex.inspect.to_s)
  log_error('--- Stack trace: ---')
  log_fail(ex.backtrace.to_s)
end

output = builder.generated_files
log_fail 'No output generated' if output.nil? || output.empty?

any_uitest_built = false

test_runs = {}
output.each do |_, project_output|
  next if project_output[:uitests].nil? || project_output[:uitests].empty?

  app_path = nil
  platform = nil
  devices = nil
  if project_output[:xcarchive]
    app_path = export_ios_xcarchive(project_output[:xcarchive], options[:export_options])
    system("envman add --key BITRISE_IPA_PATH --value \"#{app_path}\"")
    platform = 'ios'
    devices = options[:ios_devices]
  elsif project_output[:apk]
    unsigned_path = project_output[:apk]
    x = "jarsigner -sigalg SHA1withDSA -digestalg SHA1 -keypass #{ENV["BITRISEIO_ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD"]} -storepass #{ENV["BITRISEIO_ANDROID_KEYSTORE_PASSWORD"]} -keystore #{ENV["BITRISEIO_ANDROID_KEYSTORE_PATH"]} #{unsigned_path} #{ENV["BITRISEIO_ANDROID_KEYSTORE_ALIAS"]}"
    puts x
    puts `#{x}`
    app_path = unsigned_path.sub(".apk", "-signed.apk")
    y = "zipalign 4 #{unsigned_path} #{app_path}"
    puts y
    puts `#{y}`

    system("envman add --key BITRISE_SIGNED_APK_PATH --value \"#{app_path}\"")
    platform = 'android'
    devices = options[:android_devices]
  end

  log_fail('no generated app found') unless app_path

  project_output[:uitests].each do |dll_path|
    any_uitest_built = true

    assembly_dir = File.dirname(dll_path)

    log_info("Uploading #{app_path} with #{dll_path}")

    #
    # Get test cloud path
    test_cloud = Dir[File.join(@work_dir, '/**/packages/Xamarin.UITest.*/tools/test-cloud.exe')].last
    log_fail("Can't find test-cloud.exe") unless test_cloud

    #
    # Build Request
    request = ['mono', "\"#{test_cloud}\"", 'submit', "\"#{app_path}\"", options[:api_key]]
    request << options[:sign_parameters] if platform == 'android' && options[:sign_parameters]
    request << "--user #{options[:user]}"
    request << "--assembly-dir \"#{assembly_dir}\""
    request << "--devices #{devices}"
    request << '--async-json' if options[:async] == 'yes'
    request << "--series #{options[:series]}" if options[:series]
    request << "--nunit-xml #{@result_log_path}"
    request << '--fixture-chunk' if options[:parallelization] == 'by_test_fixture'
    request << '--test-chunk' if options[:parallelization] == 'by_test_chunk'
    request << options[:other_parameters]

    log_details(request.join(' '))
    puts

    #
    # Run Test Cloud Upload
    captured_stdout_err_lines = []
    success = Open3.popen2e(request.join(' ')) do |stdin, stdout_err, wait_thr|
      stdin.close

      while line = stdout_err.gets
        puts line
        captured_stdout_err_lines << line
      end

      wait_thr.value.success?
    end

    puts

    #
    # Process output
    result_log = ''
    if File.exist? @result_log_path
      file = File.open(@result_log_path)
      result_log = file.read
      file.close

      system("envman add --key BITRISE_XAMARIN_TEST_FULL_RESULTS_TEXT --value \"#{result_log}\"") if result_log.to_s != ''
      log_details "Logs are available at path: #{@result_log_path}"
      puts
    end

    unless success
      puts
      puts result_log
      puts

      log_fail('Xamarin Test Cloud failed')
    end

    #
    # Set output envs
    if options[:async] == 'yes'
      captured_stdout_err = captured_stdout_err_lines.join('')

      test_run_id_regexp_from_async_output = /"TestRunId":"(?<id>.*)",/

      match = captured_stdout_err.match(test_run_id_regexp_from_async_output)
      if match
        captures = match.captures
        test_run_id = captures[0] if captures && captures.length == 1

        if test_run_id.to_s != ''
          test_runs[platform] = test_run_id
          system("envman add --key BITRISE_XAMARIN_TEST_TO_RUN_ID --value \"#{test_run_id}\"")
          system("envman add --key BITRISE_XAMARIN_ANDROID_TEST_RUN_URL --value \"https://testcloud.xamarin.com/test/#{test_run_id}\"")
          log_details "Found Test Run ID: #{test_run_id}"
        end
      end

      error_messages_regexp = /"ErrorMessages":\[(?<error>.*)\],/
      error_messages = ''

      match = captured_stdout_err.match(error_messages_regexp)
      if match
        captures = match.captures
        error_messages = captures[0] if captures && captures.length == 1

        if error_messages.to_s != ''
          log_fail("Xamarin Test Cloud submit failed, with error(s): #{error_messages}")
        end
      end
    else
      captured_stdout_err = captured_stdout_err_lines.join('')

      test_run_id_regexp_from_sync_output = /Test report: https:\/\/testcloud.xamarin.com\/test\/.*_(?<id>.*)\//

      match = captured_stdout_err.match(test_run_id_regexp_from_sync_output)
      if match
        captures = match.captures
        test_run_id = captures[0] if captures && captures.length == 1

        if test_run_id.to_s != ''
          system("envman add --key BITRISE_XAMARIN_TEST_TO_RUN_ID --value \"#{test_run_id}\"")
          system("envman add --key BITRISE_XAMARIN_ANDROID_TEST_RUN_URL --value \"https://testcloud.xamarin.com/test/#{test_run_id}\"")
          log_details "Found Test Run ID: #{test_run_id}"
        end
      end
    end

    system('envman add --key BITRISE_XAMARIN_TEST_RESULT --value succeeded')
    log_done('Xamarin Test Cloud submit succeeded')
  end
end

unless any_uitest_built
  puts "generated_files: #{output}"
  log_fail 'No APK or built UITest found in outputs'
end

puts "Waiting for results"
finished_platforms = []
180.times do |i|
  test_runs.each do |platform, id|
    next if finished_platforms.include?(platform)
    c = Xamarin::TestCloud::Api::V0::Client.new(options[:api_key])
    x = c.test_runs.results(id)
    finished = x.finished
    results = x.results
    print "#{platform}: "

    unless results
      puts " No results yet. Carry on!"
      next
    end
    print results.collect{|r| "#{r.device_configuration_id}: #{r.status}"}.join(', ')

    if finished
      finished_platforms << platform
      puts " ✅"
    else
      puts "..."
    end
  end
  if finished_platforms.size == test_runs.size
    puts "All done!"
    break
  end
  sleep 10
end

