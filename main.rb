# frozen_string_literal: true

require 'json'
require 'optparse'

require 'faraday'
require 'aws-sdk-ec2'
require 'pry'

class Main
  attr_reader :region_code, :region_abbr, :discounted_usage_type_suffix, :opts

  def initialize
    @opts, _args = parse_options
    @region_code = opts[:region_code]
    @region_abbr = opts[:region_abbr]
    @discounted_usage_type_suffix = opts[:discounted_usage_type_suffix]
  end

  def call
    instances = Ec2Fetcher.new(opts).fetch_ondemand_running_instances

    saving_plans = ComputeSavingsPlansFetcher.new(opts).fetch_savings_plans
    instane_type_to_price = saving_plans.map { |x| [x["discountedUsageType"], x.dig('discountedRate', 'price')] }.to_h

    # instane_type_to_price = {"APN1-BoxUsage:r5a.xlarge"=>"0.185",...
    instances_prices = instances.map do |x|
      instance_type = x.instance_type

      discounted_usage_type = "#{region_abbr}#{discounted_usage_type_suffix}:#{instance_type}"
      price = instane_type_to_price[discounted_usage_type]

      instance_name = x.tags.find { |x| x.key == 'Name' }&.value || ''
      [instance_type, "'#{instance_name}'", price]
    end

    puts instances_prices.sort.map { |x| x.join(',') }
    puts instances_prices.map { |x| x[2].to_f }.sum
  end

  def parse_options
    opts = {
      region_code: 'ap-northeast-1',
      region_abbr: 'APN1',
      discounted_usage_type_suffix: '-BoxUsage',
      product_family: 'ComputeSavingsPlans',
      usage_type: 'ComputeSP:1yrAllUpfront',
      discounted_operation: 'RunInstances', # linux
    }

    op = OptionParser.new
    opts.each do |key, value|
      op.on("--#{key}", "default value: #{value}") { |v| opts[key] = v }
    end
    args = op.parse(ARGV)
    [opts, args]
  rescue OptionParser::InvalidOption => e
    puts op.to_s
    puts "error: #{e.message}" if e.message
    exit 1
  end
end

class Ec2Fetcher
  attr_reader :region_code

  def initialize(opts)
    @region_code = opts[:region_code]
  end

  def fetch_ondemand_running_instances
    # max_results: 1000. don't even have 1000 instances, right?
    response = ec2.describe_instances(filters: [{ name: 'instance-state-name', values: ['running'] }])
    running_instanes = response.reservations.flat_map(&:instances)

    # instance-lifecycle - Indicates whether this is a Spot Instance or a Scheduled Instance (spot | scheduled).
    ondemand_running_instances = running_instanes.reject(&:instance_lifecycle)
    ondemand_running_instances
  end

  def ec2
    @ec2 ||= Aws::EC2::Client.new(region: region_code)
  end
end

class ComputeSavingsPlansFetcher
  attr_reader :region_code, :priging_base_url, :product_family, :usage_type, :discounted_operation

  def initialize(opts)
    @priging_base_url = 'https://pricing.us-east-1.amazonaws.com'

    @region_code = opts[:region_code]
    @product_family = opts[:product_family]
    @usage_type = opts[:usage_type]
    @discounted_operation = opts[:discounted_operation]
  end

  def fetch_savings_plans
    savings_plan_version_json = fetch_savings_plan_version_json
    sku_list = savings_plan_version_json['products']
      .select { |x| x['productFamily'] == @product_family }
      .select { |x| x['usageType'] == @usage_type }
      .map { |x| x['sku'] }

    saving_plans = savings_plan_version_json['terms']['savingsPlan']
    matched_plans = sku_list.flat_map do |sku|
      saving_plans.select { |x| x['sku'] == sku }
    end

    saving_plan_rates = matched_plans.flat_map { |x| x['rates'] }
    saving_plan_rates.select { |x| x['discountedOperation'] == discounted_operation }
  end

  def fetch_savings_plan_version_json
    json_path = 'savings_plan_version.json'
    if File.exist?(json_path)
      JSON.parse(File.read(json_path))
    else
      savings_plan_version_json = download_savings_plan_version_json
      File.write(json_path, savings_plan_version_json.to_json)
      savings_plan_version_json
    end
  end

  def download_savings_plan_version_json
    puts 'Download savings_plan_version_json ...'

    pricing_index_url = "#{priging_base_url}/offers/v1.0/aws/index.json"
    index_json = fetch_json(pricing_index_url)

    savings_plan_index_path = index_json.dig('offers', 'AmazonEC2', 'currentSavingsPlanIndexUrl')
    savings_plan_index_url = "#{priging_base_url}#{savings_plan_index_path}"
    region_index_json = fetch_json(savings_plan_index_url)

    region = region_index_json['regions'].find { |x| x['regionCode'] == region_code }
    savings_plan_version_url = "#{priging_base_url}#{region["versionUrl"]}"
    fetch_json(savings_plan_version_url)
  end

  def fetch_json(url)
    response = Faraday.get(url)
    JSON.parse(response.body)
  end
end

Main.new.call if $PROGRAM_NAME == __FILE__
