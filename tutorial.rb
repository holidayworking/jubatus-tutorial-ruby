#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'bundler/setup'
require 'json'
require 'optparse'
require 'jubatus/classifier/client'
require 'jubatus/classifier/types'

def parse_args
  options = {
    :host       => '127.0.0.1',
    :port       => '9199',
    :name       => 'tutorial',
    :algorithm  => 'PA'
  }

  ARGV.options do |opts|
    opts.on('-h', '--host HOST') { |host| options[:host] = host }
    opts.on('-p', '--port NUMBER') { |port| options[:port] = port }
    opts.on('-n', '--name NAME') { |name| options[:name] = name }
    opts.on('-a', '--algorithm NAME') { |algorithm| options[:algorithm] = algorithm }
    opts.parse!
  end

  return options
end

def get_most_likely(estimates)
  result = nil
  estimates.each do |estimate|
    if result.nil? or estimate[1].to_f > result[1].to_f
      result = estimate
    end
  end
  return result
end

def main
  options = parse_args

  classifier = Jubatus::Client::Classifier.new(options[:host], options[:port])

  converter = {
    'string_filter_types' => {
      'detag' => { 'method' => 'regexp', 'pattern' => '<[^>]*>', 'replace' => '' }
    },
    'string_filter_rules' => [
      { 'key' => 'message', 'type' => 'detag', 'suffix' => '-detagged' }
    ],
    'num_filter_types' => {},
    'num_filter_rules' => [],
    'string_types' => {},
    'string_rules' => [
      { 'key' => 'message-detagged', 'type' => 'space', 'sample_weight' => 'bin', 'global_weight' => 'bin' }
    ],
    'num_types' => {},
    'num_rules' => []
  }

  config = Jubatus::Config_data.new(options[:algorithm], JSON.generate(converter))

  name = options[:name]

  puts classifier.set_config(name, config)
  puts classifier.get_config(name)
  puts classifier.get_status(name)

  IO.foreach('train.dat') do |line|
    label, file = line.chomp.split(',')
    dat = open(file).read
    datum = Jubatus::Datum.new([['message', dat]], [])
    classifier.train(name, [[label, datum]])
    puts classifier.get_status(name)
  end

  puts classifier.save(name, 'tutorial')

  puts classifier.load(name, 'tutorial')
  puts classifier.set_config(name, config)
  puts classifier.get_config(name)

  IO.foreach('test.dat') do |line|
    label, file = line.chomp.split(',')
    dat = open(file).read
    datum = Jubatus::Datum.new([['message', dat]], [])
    answer = classifier.classify(name, [datum])
    unless answer.nil?
      estimate = get_most_likely(answer[0])
      result = (label == estimate[0]) ? 'OK' : 'NG'
      puts "#{result},#{label}, #{estimate[0]}, #{estimate[1]}"
    end
  end
end

if __FILE__ == $0
  main()
end
