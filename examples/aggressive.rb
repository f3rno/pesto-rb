require 'connection_pool'
require 'redis'
require 'securerandom'
require_relative '../lib/pesto.rb'

$use_sleep = false
$key_num = 5
$concurrency = 10

def lock(ctx, pfx, pid = 0)
  pl = Pesto::Lock.new({ :pool => ctx[:pool] })
  keys = []

  for i in 0..$key_num
    keys << "pesto:#{pfx}:#{i}"
  end

  keys.shuffle!

  d1 = Time.now

  locked = pl.lock(keys, timeout_lock: 0.05, interval_check: 0.005 )

  if locked == 1
    pl.unlock(keys)
    puts "[#{pid}] lock acquired/dismissed (took: #{(Time.now - d1) * 1000}ms)"
  else
    puts "[#{pid}] lock failed"
  end
end

pfx = SecureRandom.hex(10)
children = []

def killall(pids)
  pids.each do |pid|
    Process.kill 9, pid
  end
  Process.exit
end

Signal.trap('INT')  { killall(children) }
Signal.trap('TERM')  { killall(children) }

for pid in 0..$concurrency
  puts "[#{pid}] fork"
  children << fork do
    redis = ConnectionPool.new(size: 3, :timeout => 10) { Redis.new }
    while true do
      lock({ :pool => redis }, pfx, pid)
      if $use_sleep
        delay = rand(1000).to_f / 10000.0
        sleep delay
      end
    end
  end
end

while true do
  sleep 1
end
