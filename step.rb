require 'optparse'
require 'tmpdir'
require 'open3'
require 'json'
require 'nokogiri'
require 'terminal-table'
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

def process_nunit_data(nunit_urls)
  results = {}
  nunit_urls.each do |platform, zip_url|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        puts zip_url
        raise "Download failed!" unless system("curl -s -o nunit.zip \"#{zip_url}\"")
        raise "Unzip failed" unless system("unzip nunit.zip")
        Dir["*.xml"].each do |f|
          puts "XML file: #{f}"
          doc = File.open(f) { |f| Nokogiri::XML(f) }
          doc.xpath("//test-case[contains(@name, '(#{platform})')]").each do |x|
            k = x["name"].sub("(#{platform})", "")
            results[k] = {} unless results[k]

            result = x["result"]
            if x['result'] == "Failure"
              categories = x.xpath(".//categories/category").collect{|x| x["name"]}.compact
              if categories.include? 'bug'
                result = "Inconclusive"
              end
            end
            results[k][f.sub('_nunit_report.xml', '')] = {result: result}
          end
        end
      end
    end
  end
  results
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
nunit_urls = {}

180.times do |i|
  test_runs.each do |platform, id|
    next if finished_platforms.include?(platform)
    c = Xamarin::TestCloud::Api::V0::Client.new(options[:api_key])
    x = c.test_runs.results(id)
    finished = x.finished
    results = x.results
    print "#{platform}:"

    if finished
      finished_platforms << platform
      nunit_urls[platform] = x.logs.nunit_xml_zip
      puts "done"
    else
      puts " No results yet. Carry on!"
      next
    end
  end
  if finished_platforms.size == test_runs.size
    puts "All done!"
    break
  end
  $stdout.flush
  sleep 10
end

failed = false

results = process_nunit_data(nunit_urls)
rows = []
columns = results.values.first.keys
rows << [""] + columns
results.each do |test_case, test_results|
  row = [test_case]
  columns.each do |device|
    result = test_results[device][:result]
    row << result
    if result[device] == "Failure"
      puts "#{device} failed"
      failed = true
    end
  end
  rows << row
end

puts Terminal::Table.new(rows: rows)


exit 1 if failed

