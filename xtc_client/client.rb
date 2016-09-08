require 'faraday'
require 'json'
require 'representable/json'

module Xamarin
  module TestCloud
    module Api
      module V0

        class Client
          API_VERSION = 0.0

          attr_reader :connection
          attr_reader :apps, :test_runs, :device_configurations, :subscriptions, :storage

          def initialize(api_key, base_path='https://testcloud.xamarin.com')
            @api_key = api_key
            @connection = Faraday.new(:url => base_path) do |faraday|
              faraday.request :url_encoded # form-encode POST params
              faraday.authorization :token, api_key
              faraday.response :logger # log requests to STDOUT
              faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
            end

            @apps = Apps.new(self)
            @test_runs = TestRuns.new(self)
            @device_configurations = DeviceConfigurations.new(self)
            @subscriptions = Subscriptions.new(self)
            @storage = Storage.new(self)
            
          end

          def follow_redirect(response)
            if response.status == 302
              Faraday.get response['location']
            else
              response
            end
          end
        

          class Apps
            def initialize(client)
              @client = client
            end

            # List apps owned by the team
            # # @return [array<App>]
            def find(page: nil, per_page: nil)
              
              response = @client.connection.get do |req|
                req.url "api/v0/apps"
                req.params['page'] = page if page
                req.params['per_page'] = per_page if per_page
              end
              response = @client.follow_redirect response
              if response.success?
                result = AppCollection.new.extend(AppCollectionRepresenter).from_json(response.body)
                result.apps
              elsif response.status == 404
                []
              else
                raise ApiError.new(response.status, response.body)
              end
              
            end

            # List test runs for an app
            # # @return [array<TestRun>]
            def test_runs(app_id, page: nil, per_page: nil)
              
              response = @client.connection.get do |req|
                req.url "api/v0/apps/#{app_id}/test-runs"
                req.params['page'] = page if page
                req.params['per_page'] = per_page if per_page
              end
              response = @client.follow_redirect response
              if response.success?
                result = TestRunCollection.new.extend(TestRunCollectionRepresenter).from_json(response.body)
                result.test_runs
              elsif response.status == 404
                []
              else
                raise ApiError.new(response.status, response.body)
              end
              
            end
          end

          class TestRuns
            def initialize(client)
              @client = client
            end

            # Results of a single test run
            # # @return [ResultCollection]
            def results(id)
              
              response = @client.connection.get do |req|
                req.url "api/v0/test-runs/#{id}/results"
              end
              response = @client.follow_redirect response
              if response.success?
                result = ResultCollection.new.extend(ResultCollectionRepresenter).from_json(response.body)
                result
              elsif response.status == 404
                []
              else
                raise ApiError.new(response.status, response.body)
              end
              
            end

            # Metadata of a single test run
            # # @return [TestRun]
            def get(id)
              
              response = @client.connection.get do |req|
                req.url "api/v0/test-runs/#{id}"
              end
              response = @client.follow_redirect response
              if response.success?
                result = TestRun.new.extend(TestRunRepresenter).from_json(response.body)
                result
              elsif response.status == 404
                nil
              else
                raise ApiError.new(response.status, response.body)
              end
              
            end
          end

          class DeviceConfigurations
            def initialize(client)
              @client = client
            end

            # List device configurations currently available
            # # @return [array<DeviceConfiguration>]
            def find(q: nil, sort: nil, model: nil, manufacturer: nil, name: nil, os: nil, platform: nil, page: nil, per_page: nil)
              
              response = @client.connection.get do |req|
                req.url "api/v0/device-configurations"
                req.params['q'] = q if q
                req.params['sort'] = sort if sort
                req.params['model'] = model if model
                req.params['manufacturer'] = manufacturer if manufacturer
                req.params['name'] = name if name
                req.params['os'] = os if os
                req.params['platform'] = platform if platform
                req.params['page'] = page if page
                req.params['per_page'] = per_page if per_page
              end
              response = @client.follow_redirect response
              if response.success?
                result = DeviceConfigurationCollection.new.extend(DeviceConfigurationCollectionRepresenter).from_json(response.body)
                result.device_configurations
              elsif response.status == 404
                []
              else
                raise ApiError.new(response.status, response.body)
              end
              
            end
          end

          class Subscriptions
            def initialize(client)
              @client = client
            end

            # Retrieve details of the team's current subscription
            # # @return [Subscription]
            def current()
              
              response = @client.connection.get do |req|
                req.url "api/v0/subscriptions/current"
              end
              response = @client.follow_redirect response
              if response.success?
                result = Subscription.new.extend(SubscriptionRepresenter).from_json(response.body)
                result
              elsif response.status == 404
                nil
              else
                raise ApiError.new(response.status, response.body)
              end
              
            end
          end

          class Storage
            def initialize(client)
              @client = client
            end

            # List apps binaries stored with the team
            # # @return [array<uri>]
            def find()
              
              response = @client.connection.get do |req|
                req.url "api/v0/storage"
              end
              response = @client.follow_redirect response
              if response.success?
                result = StoredAppCollection.new.extend(StoredAppCollectionRepresenter).from_json(response.body)
                result.stored_apps
              elsif response.status == 404
                []
              else
                raise ApiError.new(response.status, response.body)
              end
              
            end

            # Upload an APK or IPA
            # # @return [uri]
            def create(app_file)
              
              payload = { app_file: Faraday::UploadIO.new(File.expand_path(app_file), 'application/octet-stream') }
              response = @client.connection.post do |req|
                req.url "api/v0/storage"
                req.body = payload
              end
              if [302, 303].include? response.status
                response.headers[:location]
              elsif response.status == 404
                nil
              else
                raise ApiError.new(response.status, response.body)
              end
              
            end
          end
        end

        # Models
        

        # The web pages related to a resource
        class Link
          
          attr_accessor :title # The name of the web page
          attr_accessor :href # The URI of the web page

          def to_s
            out = ''
            out << 'Link:' << "\n"
            out << '    title'.ljust(35) << title << "\n" if title
            out << '    href'.ljust(35) << href << "\n" if href
            out
          end
        end

        # A list of links
        class LinkCollection
          
          attr_accessor :links # A list of links

          def to_s
            out = ''
            out << 'LinkCollection:' << "\n"
            out << '    links'.ljust(35) << '[' << links*', ' << "]\n" if links
            out
          end
        end

        # Summary single test run on Xamarin Test Cloud
        class TestRun
          
          attr_accessor :app_name # The name of the app
          attr_accessor :id # The unique id of the test upload
          attr_accessor :date_uploaded # The date and time the test was uploaded
          attr_accessor :relative_date # The date and time the test was uploaded, relative to now, in English
          attr_accessor :platform # The device platform targeted by the test. Possible values are 'ios' or 'android'
          attr_accessor :app_version # The compiled version of the app binary
          attr_accessor :test_parameters # Hash with the parameters given during test upload
          attr_accessor :binary_id # Bundle ID of an iOS app / package ID for an Android app.
          attr_accessor :test_series_name # The name of the test series with which this test upload is associated
          attr_accessor :name_of_uploader # The name of the user who uploaded this test
          attr_accessor :email_of_uploader # The email address of the user who uploaded this test
          attr_accessor :results # The URL of the test results for each test on each selected device

          def to_s
            out = ''
            out << 'TestRun:' << "\n"
            out << '    app_name'.ljust(35) << app_name << "\n" if app_name
            out << '    id'.ljust(35) << id << "\n" if id
            out << '    date_uploaded'.ljust(35) << date_uploaded << "\n" if date_uploaded
            out << '    relative_date'.ljust(35) << relative_date << "\n" if relative_date
            out << '    platform'.ljust(35) << platform << "\n" if platform
            out << '    app_version'.ljust(35) << app_version << "\n" if app_version
            out << '    test_parameters'.ljust(35) << test_parameters.to_json << "\n" if test_parameters
            out << '    binary_id'.ljust(35) << binary_id << "\n" if binary_id
            out << '    test_series_name'.ljust(35) << test_series_name << "\n" if test_series_name
            out << '    name_of_uploader'.ljust(35) << name_of_uploader << "\n" if name_of_uploader
            out << '    email_of_uploader'.ljust(35) << email_of_uploader << "\n" if email_of_uploader
            out << '    results'.ljust(35) << results << "\n" if results
            out
          end
        end

        # List of test runs
        class TestRunCollection
          
          attr_accessor :test_runs # A list of test runs

          def to_s
            out = ''
            out << 'TestRunCollection:' << "\n"
            out << '    test_runs'.ljust(35) << '[' << test_runs*', ' << "]\n" if test_runs
            out
          end
        end

        # Summary statistics for a single test across different devices in a single test run.
        class TestStatistics
          
          attr_accessor :passed # Number of tests that passed succesfully
          attr_accessor :failed # Number of tests that failed
          attr_accessor :skipped # Number of tests that were skipped
          attr_accessor :total # Total number of tests in this test run

          def to_s
            out = ''
            out << 'TestStatistics:' << "\n"
            out << '    passed'.ljust(35) << passed << "\n" if passed
            out << '    failed'.ljust(35) << failed << "\n" if failed
            out << '    skipped'.ljust(35) << skipped << "\n" if skipped
            out << '    total'.ljust(35) << total << "\n" if total
            out
          end
        end

        # Log files produced during a single device during a single test run
        class DeviceLogs
          
          attr_accessor :device_configuration_id # The human readable unique id for the type of device and os
          attr_accessor :device_log # The URI of the device log file
          attr_accessor :test_log # The URI of the device log file

          def to_s
            out = ''
            out << 'DeviceLogs:' << "\n"
            out << '    device_configuration_id'.ljust(35) << device_configuration_id << "\n" if device_configuration_id
            out << '    device_log'.ljust(35) << device_log << "\n" if device_log
            out << '    test_log'.ljust(35) << test_log << "\n" if test_log
            out
          end
        end

        # Log files produced during a single test run
        class TestLogs
          
          attr_accessor :nunit_xml_zip # URI of the NUNit log files bundled together
          attr_accessor :devices # Collection of device log files and test log files for each device configuration

          def to_s
            out = ''
            out << 'TestLogs:' << "\n"
            out << '    nunit_xml_zip'.ljust(35) << nunit_xml_zip << "\n" if nunit_xml_zip
            out << '    devices'.ljust(35) << '[' << devices*', ' << "]\n" if devices
            out
          end
        end

        # Details of a single test run
        class ResultCollection
          
          attr_accessor :results # A list of results for all tests on all selected devices
          attr_accessor :finished # True when all devices have finished running all tests, or the test is aborted.
          attr_accessor :logs # The logs that were produced by the test as a whole and by each device

          def to_s
            out = ''
            out << 'ResultCollection:' << "\n"
            out << '    results'.ljust(35) << '[' << results*', ' << "]\n" if results
            out << '    finished'.ljust(35) << finished << "\n" if finished
            out << '    logs'.ljust(35) << logs << "\n" if logs
            out
          end
        end

        # The result of one test on one device
        class Result
          
          attr_accessor :test_group # The title of the test group ("feature" in Calabash, "test class" in UITest)
          attr_accessor :test_name # The title of the test ("scenario" in Calabash, "test method" in UITest)
          attr_accessor :device_configuration_id # The human readable unique id for the type of device and os
          attr_accessor :status # The abbreviated status of the test. Possible values are 'passed', 'failed' or 'skipped'.

          def to_s
            out = ''
            out << 'Result:' << "\n"
            out << '    test_group'.ljust(35) << test_group << "\n" if test_group
            out << '    test_name'.ljust(35) << test_name << "\n" if test_name
            out << '    device_configuration_id'.ljust(35) << device_configuration_id << "\n" if device_configuration_id
            out << '    status'.ljust(35) << status << "\n" if status
            out
          end
        end

        # A mobile app uploaded to Xamarin Test Cloud
        class App
          
          attr_accessor :name # The name of the app
          attr_accessor :id # An automatically generated unique id for the app
          attr_accessor :binary_id # Bundle ID of an iOS app / package ID for an Android app.
          attr_accessor :platform # The platform. Can be android or ios
          attr_accessor :created_date # The time the app was first uploaded
          attr_accessor :test_runs # The url used to retrieve the list of test runs for the app
          attr_accessor :links # The web pages on the Xamarin Test Cloud web site related to this app

          def to_s
            out = ''
            out << 'App:' << "\n"
            out << '    name'.ljust(35) << name << "\n" if name
            out << '    id'.ljust(35) << id << "\n" if id
            out << '    binary_id'.ljust(35) << binary_id << "\n" if binary_id
            out << '    platform'.ljust(35) << platform << "\n" if platform
            out << '    created_date'.ljust(35) << created_date << "\n" if created_date
            out << '    test_runs'.ljust(35) << test_runs << "\n" if test_runs
            out << '    links'.ljust(35) << '[' << links*', ' << "]\n" if links
            out
          end
        end

        # A list of mobile apps uploaded to Xamarin Test Cloud
        class AppCollection
          
          attr_accessor :apps # The name of the app

          def to_s
            out = ''
            out << 'AppCollection:' << "\n"
            out << '    apps'.ljust(35) << '[' << apps*', ' << "]\n" if apps
            out
          end
        end

        # 
        class DeviceConfiguration
          
          attr_accessor :name # A human readable representation of manufacturer, model and operating system
          attr_accessor :id # A unique and human readable id for this device configuration
          attr_accessor :manufacturer # The name of the manufacturer
          attr_accessor :platform # The device configuration's platform. Can be android or ios.
          attr_accessor :os # The operating system on the device configuration

          def to_s
            out = ''
            out << 'DeviceConfiguration:' << "\n"
            out << '    name'.ljust(35) << name << "\n" if name
            out << '    id'.ljust(35) << id << "\n" if id
            out << '    manufacturer'.ljust(35) << manufacturer << "\n" if manufacturer
            out << '    platform'.ljust(35) << platform << "\n" if platform
            out << '    os'.ljust(35) << os << "\n" if os
            out
          end
        end

        # 
        class DeviceConfigurationCollection
          
          attr_accessor :device_configurations # A list of device configurations

          def to_s
            out = ''
            out << 'DeviceConfigurationCollection:' << "\n"
            out << '    device_configurations'.ljust(35) << '[' << device_configurations*', ' << "]\n" if device_configurations
            out
          end
        end

        # Xamarin Test Cloud Subscription information
        class Subscription
          
          attr_accessor :name # The name of the subscription tier
          attr_accessor :period_start # The date when the usage counter was last reset (if applicable to subscription)
          attr_accessor :next_usage_reset # The date when the usage counters are goint to be reset next (if applicable to subscription)
          attr_accessor :total_hours # The allowed test hours during the current billing period (if applicable to subscription)
          attr_accessor :used_hours # The test hours spent during the current billing period (if applicable to subscription)
          attr_accessor :used_percent # The test hours spent during the current billing period expressed as percent of the total hours (if applicable to subscription)
          attr_accessor :concurrent_devices # The maximum allowed concurrent devices (if applicable to subscription)
          attr_accessor :daily_total_hours # The allowed test hours per day (if applicable to subscription)
          attr_accessor :used_average # The average usage in hours (if applicable to subscription)
          attr_accessor :organization # The organization that owns the subscription

          def to_s
            out = ''
            out << 'Subscription:' << "\n"
            out << '    name'.ljust(35) << name << "\n" if name
            out << '    period_start'.ljust(35) << period_start << "\n" if period_start
            out << '    next_usage_reset'.ljust(35) << next_usage_reset << "\n" if next_usage_reset
            out << '    total_hours'.ljust(35) << "%.1f" % total_hours << "\n" if total_hours
            out << '    used_hours'.ljust(35) << "%.1f" % used_hours << "\n" if used_hours
            out << '    used_percent'.ljust(35) << "%.1f" % used_percent << "\n" if used_percent
            out << '    concurrent_devices'.ljust(35) << concurrent_devices << "\n" if concurrent_devices
            out << '    daily_total_hours'.ljust(35) << daily_total_hours << "\n" if daily_total_hours
            out << '    used_average'.ljust(35) << "%.1f" % used_average << "\n" if used_average
            out << '    organization'.ljust(35) << organization << "\n" if organization
            out
          end
        end

        # Organization
        class Organization
          
          attr_accessor :id # The unique id of the organization
          attr_accessor :name # The name of the organization

          def to_s
            out = ''
            out << 'Organization:' << "\n"
            out << '    id'.ljust(35) << id << "\n" if id
            out << '    name'.ljust(35) << name << "\n" if name
            out
          end
        end

        # A list of apps stored
        class StoredAppCollection
          
          attr_accessor :stored_apps # 

          def to_s
            out = ''
            out << 'StoredAppCollection:' << "\n"
            out << '    stored_apps'.ljust(35) << '[' << stored_apps*', ' << "]\n" if stored_apps
            out
          end
        end

        

        module LinkRepresenter
          include Representable::JSON
          
          property :title, as: :title # The name of the web page
          property :href, as: :href # The URI of the web page
        end

        module OrganizationRepresenter
          include Representable::JSON
          
          property :id, as: :id # The unique id of the organization
          property :name, as: :name # The name of the organization
        end

        module TestRunRepresenter
          include Representable::JSON
          
          property :app_name, as: :appName # The name of the app
          property :id, as: :id # The unique id of the test upload
          property :date_uploaded, as: :dateUploaded # The date and time the test was uploaded
          property :relative_date, as: :relativeDate # The date and time the test was uploaded, relative to now, in English
          property :platform, as: :platform # The device platform targeted by the test. Possible values are 'ios' or 'android'
          property :app_version, as: :appVersion # The compiled version of the app binary
          property :test_parameters, as: :testParameters # Hash with the parameters given during test upload
          property :binary_id, as: :binaryId # Bundle ID of an iOS app / package ID for an Android app.
          property :test_series_name, as: :testSeriesName # The name of the test series with which this test upload is associated
          property :name_of_uploader, as: :nameOfUploader # The name of the user who uploaded this test
          property :email_of_uploader, as: :emailOfUploader # The email address of the user who uploaded this test
          property :results, as: :results # The URL of the test results for each test on each selected device
        end

        module SubscriptionRepresenter
          include Representable::JSON
          
          property :name, as: :name # The name of the subscription tier
          property :period_start, as: :periodStart # The date when the usage counter was last reset (if applicable to subscription)
          property :next_usage_reset, as: :nextUsageReset # The date when the usage counters are goint to be reset next (if applicable to subscription)
          property :total_hours, as: :totalHours # The allowed test hours during the current billing period (if applicable to subscription)
          property :used_hours, as: :usedHours # The test hours spent during the current billing period (if applicable to subscription)
          property :used_percent, as: :usedPercent # The test hours spent during the current billing period expressed as percent of the total hours (if applicable to subscription)
          property :concurrent_devices, as: :concurrentDevices # The maximum allowed concurrent devices (if applicable to subscription)
          property :daily_total_hours, as: :dailyTotalHours # The allowed test hours per day (if applicable to subscription)
          property :used_average, as: :usedAverage # The average usage in hours (if applicable to subscription)
          property :organization, extend: OrganizationRepresenter, class: Organization, as: :organization # The organization that owns the subscription
        end

        module TestStatisticsRepresenter
          include Representable::JSON
          
          property :passed, as: :passed # Number of tests that passed succesfully
          property :failed, as: :failed # Number of tests that failed
          property :skipped, as: :skipped # Number of tests that were skipped
          property :total, as: :total # Total number of tests in this test run
        end

        module DeviceLogsRepresenter
          include Representable::JSON
          
          property :device_configuration_id, as: :deviceConfigurationId # The human readable unique id for the type of device and os
          property :device_log, as: :deviceLog # The URI of the device log file
          property :test_log, as: :testLog # The URI of the device log file
        end

        module TestLogsRepresenter
          include Representable::JSON
          
          property :nunit_xml_zip, as: :nunitXmlZip # URI of the NUNit log files bundled together
          collection :devices, extend: DeviceLogsRepresenter, class: DeviceLogs, as: :devices # Collection of device log files and test log files for each device configuration
        end

        module DeviceConfigurationRepresenter
          include Representable::JSON
          
          property :name, as: :name # A human readable representation of manufacturer, model and operating system
          property :id, as: :id # A unique and human readable id for this device configuration
          property :manufacturer, as: :manufacturer # The name of the manufacturer
          property :platform, as: :platform # The device configuration's platform. Can be android or ios.
          property :os, as: :os # The operating system on the device configuration
        end

        module AppRepresenter
          include Representable::JSON
          
          property :name, as: :name # The name of the app
          property :id, as: :id # An automatically generated unique id for the app
          property :binary_id, as: :binaryId # Bundle ID of an iOS app / package ID for an Android app.
          property :platform, as: :platform # The platform. Can be android or ios
          property :created_date, as: :createdDate # The time the app was first uploaded
          property :test_runs, as: :testRuns # The url used to retrieve the list of test runs for the app
          collection :links, extend: LinkRepresenter, class: Link, as: :links # The web pages on the Xamarin Test Cloud web site related to this app
        end

        module ResultRepresenter
          include Representable::JSON
          
          property :test_group, as: :testGroup # The title of the test group ("feature" in Calabash, "test class" in UITest)
          property :test_name, as: :testName # The title of the test ("scenario" in Calabash, "test method" in UITest)
          property :device_configuration_id, as: :deviceConfigurationId # The human readable unique id for the type of device and os
          property :status, as: :status # The abbreviated status of the test. Possible values are 'passed', 'failed' or 'skipped'.
        end

        module AppCollectionRepresenter
          include Representable::JSON
          
          collection :apps, extend: AppRepresenter, class: App, as: :apps # The name of the app
        end

        module ResultCollectionRepresenter
          include Representable::JSON
          
          collection :results, extend: ResultRepresenter, class: Result, as: :results # A list of results for all tests on all selected devices
          property :finished, as: :finished # True when all devices have finished running all tests, or the test is aborted.
          property :logs, extend: TestLogsRepresenter, class: TestLogs, as: :logs # The logs that were produced by the test as a whole and by each device
        end

        module DeviceConfigurationCollectionRepresenter
          include Representable::JSON
          
          collection :device_configurations, extend: DeviceConfigurationRepresenter, class: DeviceConfiguration, as: :deviceConfigurations # A list of device configurations
        end

        module TestRunCollectionRepresenter
          include Representable::JSON
          
          collection :test_runs, extend: TestRunRepresenter, class: TestRun, as: :testRuns # A list of test runs
        end

        module LinkCollectionRepresenter
          include Representable::JSON
          
          collection :links, extend: LinkRepresenter, class: Link, as: :links # A list of links
        end

        module StoredAppCollectionRepresenter
          include Representable::JSON
          
          collection :stored_apps, as: :storedApps # 
        end

        class ApiError < StandardError
          attr_reader :code

          def initialize(code, message='')
            super(message)
            @code = code
          end
        end
      end
    end
  end
end
