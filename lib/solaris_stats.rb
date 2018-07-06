require 'vmstat'
require "solaris_stats/version"

module SolarisStats
	def self.snapshot
		Vmstat.snapshot
	end
  # Your code goes here...
end
