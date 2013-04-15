require './rvs_accesslogparser'
alp = RVS_AccessLogParser.new({})
alp.run
pp alp.t_args