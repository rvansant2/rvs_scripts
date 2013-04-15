rvs_accesslogparser
===========

Having been faced with a task to parse out access logs for many different reason, this script is meant to be run as a cron or as a bulk ingest of server access logs for reporting purposes.  The script is also meant to be flexible where the default configuration, file paths and regex properties can be overridden by passing in a configuration hash to the class.  Each parsed log file produces a subsequent CSV file for importing into a Database or any other Data stores, like MongoDB, for reporting purposes - utilizing the access log timestamps to isolate filtered time periods in the report.  This script also supports a 'type' field in the Database table for file structure, example below:

-log_files
---images (flagged as a 'type')
-----year
-------month
---------day
-----------hour

---player (flagged as a 'type')
-----year
-------month
---------day
-----------hour

configuration
===========

config.rb file has global variables, but can be modified to match your server environemnt

overriding configuration hash below
{
	:log_dir_path => PATH TO YOUR LOG FILES, 
	:process_new_files_only => true or false (for cron purposes), 
	:export_file_to_csv => true or false, 
	:export_file_to_csv_path => PATH TO WHERE YOU WANT CSV FILES, 
	:regex => {
				:type => 'log_files\/(.+?)\/', 
				:ip => '^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})?', 
				:date => '\[(.*?)\]', 
				:data_transfer => '200\s(.*?)\s|disconnect\s(.*?)\s408(.*?)-\s-', 
				:cdn_server => ']\s"GET\s\/(.+?)\/|http:\/\/(.+?)\/', 
				:extra_data => '"-"\s(.*?)\s"-"'
			}
}

running script
===========

review test.rb, passing in an emapty hash will use the default config

todo
===========

1) Add data importing based on a configuration property
2) Data importing for MySQL or MongoDB

