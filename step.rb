require 'optparse'
require 'tmpdir'
require 'open3'
require 'json'
require_relative 'xtc_client/client.rb'

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

# -----------------------
# --- Main
# -----------------------

#
# Parse options
options = {
  api_key: nil,
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: step.rb [options]'
  opts.on('-a', '--api key', 'Api key') { |a| options[:api_key] = a unless a.to_s == '' }
  opts.on('-h', '--help', 'Displays Help') do
    exit
  end
end
parser.parse!

test_runs = {'Android' => ENV.fetch('BITRISE_XAMARIN_ANDROID_TEST_ID'), 'iOS' => ENV.fetch('BITRISE_XAMARIN_IOS_TEST_ID')}
puts test_runs


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
    results.each do |r|
      if r.status == 'failed'
        puts "Failed on #{r.device_configuration_id}. Failing test!"
        exit 1
      end
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
  $stdout.flush
  sleep 10
end

