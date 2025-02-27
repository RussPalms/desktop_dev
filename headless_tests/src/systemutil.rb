require 'etc'

class ProcessNotFound < StandardError
end

class SystemUtil
    def self.loaded_libs(process_name)
        case os
        when :linux
            process_pid = pid process_name
            if !process_pid
                raise ProcessNotFound.new "No process #{process_name} found"
            end
            loaded_libs = `sudo pldd #{process_pid} | grep '^/.*$'`.lines.map(&:chomp)
            if $?.to_i != 0
                raise ProcessNotFound.new "Failed to retrieve loaded libraries for #{process_name}"
            end
            loaded_libs
        when :windows
            loaded_libs = `powershell "Get-Process -name #{process_name} | ForEach-Object { $_.Modules.FileName }"`.lines.map(&:chomp)
            if $?.to_i != 0
                raise ProcessNotFound.new "No process #{process_name} found"
            end
            loaded_libs
        when :macos
            process_pid = pid process_name
            if !process_pid
                raise ProcessNotFound.new "No process #{process_name} found"
            end
            loaded_libs = `sudo vmmap -w #{process_pid} | grep .dylib | grep -v 'IOSurface' | sed 's/.* \\(\\/.*\\.dylib\\)/\\1/g'`.lines.map(&:chomp)
            if $?.to_i != 0
                raise ProcessNotFound.new "Failed to retrieve loaded libraries for #{process_name}"
            end
            loaded_libs
        end
    end

    def self.pid(process_name)
        pids = `pgrep #{process_name}`
        pids.split()[0]
    end

    def self.os
        case Etc.uname[:sysname]
        when "Windows_NT"
            :windows
        when "Linux"
            :linux
        when "Darwin"
            :macos
        end
    end

    def self.arch
        case Etc.uname[:machine]
        when "arm64"
            :arm64
        when "aarch64"
            :arm64
        when "x86_64"
            :x86_64
        end
    end

    def self.windows?
        os == :windows
    end

    def self.linux?
        os == :linux
    end

    def self.macos?
        os == :macos
    end

    def self.os_choose(windows_value, macos_value, linux_value)
        case self.os
        when :windows
            windows_value
        when :macos
            macos_value
        when :linux
            linux_value
        end
    end

    def self.CI?
        ENV["GITHUB_CI"] != nil
    end

    def self.local_traffic_test_command
        if macos?
            # pings are blocked in Github-hosted runners, so we use nslookup.
            "nslookup google.com"
        elsif Command.execute("which traceroute")
            # This will be the default for Linux in CI, and for any local Linux machine with traceroute installed. 
            # Ping is blocked in GHA hosted runners, and nslookup gives false failures in ubuntu.
            "traceroute -m 1"
        else
            # We use self-hosted Windows runners in CI so ping is not blocked.
            "ping -n 1"
        end
    end
end

