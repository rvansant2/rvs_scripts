require 'rubygems'
require 'CGI'
require 'csv'
require 'pp'
require 'zlib'
require './config'

module HasProperties
  attr_accessor :props

  def has_properties(*args)
    @props = args
    instance_eval { attr_reader *args }
  end

  def self.included(base)
    base.extend self
  end

  def initialize(args)
    args.each {|k,v|
      instance_variable_set "@#{k}", v if self.class.props.member?(k)
    } if args.is_a? Hash
  end
end

class RVS_AccessLogParser
  include HasProperties
  has_properties :log_dir_path, :process_new_files_only, :export_file_to_csv
  attr_reader :regex_patterns, :t_args
  
  def initialize(args)
    super
    if args.empty? || (!args.empty? && args[:log_dir_path].nil?)
      instance_variable_set "@log_dir_path", LOG_DIR_PATH
    end
    
    if args.empty? || (!args.empty? && args[:process_new_files_only].nil?)
      instance_variable_set "@process_new_files_only", PROCESS_NEW_FILES_ONLY
    end
    
    if args.empty? || (!args.empty? && args[:export_file_to_csv].nil?)
      instance_variable_set "@export_file_to_csv", EXPORT_FILE_TO_CSV
    end
    
    if args.empty? || (!args.empty? && args[:export_file_to_csv_path].nil?)
      instance_variable_set "@export_file_to_csv_path", EXPORT_FILE_TO_CSV_PATH
    end
    
    if !args.empty? && !args[:regex].nil?
      @regex_patterns.merge(args[:regex])
    end
    @regex_patterns = {:type => 'log_files\/(.+?)\/', :ip => '^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})?', :date => '\[(.*?)\]', :data_transfer => '200\s(.*?)\s|disconnect\s(.*?)\s408(.*?)-\s-', :cdn_server => ']\s"GET\s\/(.+?)\/|http:\/\/(.+?)\/', :extra_data => '"-"\s(.*?)\s"-"'}
    @t_args = {:total_data => 0, :total_imp => 0, :total_line_count => 0}
    @dir_path = self.log_dir_path.to_s+'**/*/*.gz'
    @csv_headers = ["type","ip","date","data_transfer","cdn_server","extra_data","log_line"]
    @arr_lines = []
  end
  
  def run
    self.unzip_and_process_files
  end
  
  def unzip_and_process_files
    Dir.glob(@dir_path).sort{ |a,b|
        File.mtime(b) <=> File.mtime(a) 
      }.each do |zip_file_name|
      #if self.process_new_files_only && File.mtime(zip_file_name) > Time.new(2013, 04, 13, 10, 07, 0)#testing
        if self.process_new_files_only && File.mtime(zip_file_name) < Time.new
          File.open(zip_file_name) do |zipfile|
              gz = Zlib::GzipReader.new(zipfile)
              File.open(zip_file_name+'.txt', "w+") do |g|
                IO.copy_stream(gz, g)
              end
              gz.close
          end
          self.parse_file(zip_file_name)
        end
    end
  end
  
  def parse_file(zip_file_name)
    File.open(zip_file_name+'.txt') do |file|
      @arr_lines = @arr_lines.empty? ? @arr_lines : []
      file.each_line { |line|
        args = {}
        type = (/#{@regex_patterns[:type].to_s}/).match(zip_file_name.to_s)
        ip = (/#{@regex_patterns[:ip].to_s}/).match(line.to_s)
        date = (/#{@regex_patterns[:date].to_s}/).match(line.to_s)
        data_transfer = (/#{@regex_patterns[:data_transfer].to_s}/).match(line.to_s)
        cdn_server = (/#{@regex_patterns[:cdn_server].to_s}/).match(line.to_s)
        extra_data = (/#{@regex_patterns[:extra_data].to_s}/).match(line.to_s)

        args["type"] = (!type.nil? && type.size > 1) ? type[1] : 'log_file'
        args["ip"] = ip[0]
        args['date'] = date[1]
        if !data_transfer.nil? && data_transfer.size > 1 && data_transfer[3].nil?
          args['data_transfer'] = data_transfer[1].to_s
        elsif !data_transfer.nil? && data_transfer.size > 1 && !data_transfer[3].nil?
          args['data_transfer'] = data_transfer[3].to_s
        else
          args['data_transfer'] = 0
        end
        args['cdn_server'] = !cdn_server.nil? && cdn_server.size > 1 ? cdn_server[1].to_s : ''
        args['extra_data'] = !extra_data.nil? ? extra_data[0] : ''
        args['log_line'] = line

        if !data_transfer.nil?
          @t_args[:total_data] += data_transfer[1].to_i
          @t_args[:total_imp] = @t_args[:total_imp]+1
        end
        @t_args[:total_line_count] = @t_args[:total_line_count]+1

        @arr_lines.push(args)
      }
    end
    #File.delete(zip_file_name+'.txt')
    if self.export_file_to_csv
      self.write_csv_file(zip_file_name)
    end
  end
  
  def write_csv_file(zip_file_name)
    base_filename = (/\/(...+)\/(.+?).gz|\/(.+?).gz/).match(zip_file_name.to_s)
    base_filename = (!base_filename.nil? && base_filename[3].nil?) ? base_filename[2] : base_filename[3]
    header = @csv_headers
    CSV.open("#{@export_file_to_csv_path}#{base_filename}.csv", "w", { :quote_char => '"', :col_sep =>',', :row_sep =>:auto, :headers => true, :return_headers => false, :force_quotes => true}) do |csv|
      csv << (header.each {|element| element})
      @arr_lines.each do |hash|
        if hash.length > 2
          csv << hash
        end
      end
    end
  end
end
