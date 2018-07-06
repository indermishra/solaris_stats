require 'vmstat'
require 'sensu-plugin/metric/cli'
require 'socket'
require "solaris_stats/version"

module SolarisStats 
    def self.snapshot
        Vmstat.snapshot
    end

    class DiskUsageMetrics < Sensu::Plugin::Metric::CLI::Graphite
      option :scheme,
             description: 'Metric naming scheme, text to prepend to .$parent.$child',
             long: '--scheme SCHEME',
             default: "#{Socket.gethostname}.disk_usage"

      option :ignore_mnt,
             description: 'Ignore mounts matching pattern(s)',
             short: '-i MNT[,MNT]',
             long: '--ignore-mount',
             proc: proc { |a| a.split(',') }

      option :include_mnt,
             description: 'Include only mounts matching pattern(s)',
             short: '-I MNT[,MNT]',
             long: '--include-mount',
             proc: proc { |a| a.split(',') }

      option :flatten,
             description: 'Output mounts with underscore rather than dot',
             short: '-f',
             long: '--flatten',
             boolean: true,
             default: false

      option :local,
             description: 'Only check local filesystems (df -l option)',
             short: '-l',
             long: '--local',
             boolean: true,
             default: false

      option :block_size,
             description: 'Set block size for sizes printed',
             short: '-B BLOCK_SIZE',
             long: '--block-size BLOCK_SIZE',
             default: 'M'

      # Main function
      #
      def run
        delim = config[:flatten] == true ? '_' : '.'
        # Get disk usage from df with used and avail in megabytes
        # #YELLOW
        command = if Gem::Platform.local.os == 'solaris'
                    "df -k #{config[:local] ? '-l' : ''}"
                  else
                    "df -PB#{config[:block_size]} #{config[:local] ? '-l' : ''}"
                  end

        `#{command}`.split("\n").drop(1).each do |line|
          _, _, used, avail, used_p, mnt = line.split

          unless %r{/sys[/|$]|/dev[/|$]|/run[/|$]} =~ mnt
            next if config[:ignore_mnt] && config[:ignore_mnt].find { |x| mnt.match(x) }
            next if config[:include_mnt] && !config[:include_mnt].find { |x| mnt.match(x) }
            mnt = if config[:flatten]
                    mnt.eql?('/') ? 'root' : mnt.gsub(/^\//, '')
                  else
                    # If mnt is only / replace that with root if its /tmp/foo
                    # replace first occurance of / with root.
                    mnt.length == 1 ? 'root' : mnt.gsub(/^\//, 'root.')
                  end
            # Fix subsequent slashes
            mnt = mnt.gsub '/', delim
            output [config[:scheme], mnt, 'used'].join('.'), used.gsub(config[:block_size], '')
            output [config[:scheme], mnt, 'avail'].join('.'), avail.gsub(config[:block_size], '')
            output [config[:scheme], mnt, 'used_percentage'].join('.'), used_p.delete('%')
          end
        end
        ok
      end
    end
end
