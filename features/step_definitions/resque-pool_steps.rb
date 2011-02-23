When /^I run the pool manager as "([^"]*)"$/ do |cmd|
  @pool_manager_process = run_background(unescape(cmd))
  keep_trying do
    Then "the pool manager should start up"
  end
end

# this is a horrible hack, to make sure that it's done what it needs to do
# before we do our next step
def keep_trying(timeout=10, tries=0)
  announce "Try: #{tries}" if @announce_env
  yield
rescue RSpec::Expectations::ExpectationNotMetError
  if tries < 10
    sleep 1
    tries += 1
    retry
  else
    raise
  end
end

When /^I send the pool manager the "([^"]*)" signal$/ do |signal|
  @pool_manager_process.send_signal signal
  case signal
  when "QUIT"
    Then "the output should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[$PID]: QUIT: graceful shutdown, waiting for children
    EOF
  end
end

Then "the pool manager should start up" do
  Then "the output should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[$PID]: Resque Pool running in development environment
resque-pool-manager[$PID]: started manager
  EOF
end

# nomenclature: "report" => output to stdout/stderr
#               "log"    => output to default logfile
Then "the pool manager should report that the pool is empty" do
  Then "the output should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[$PID]: Pool is empty
  EOF
end

Then /^the pool manager should report that (\d+) workers are in the pool$/ do |count|
  count = Integer(count)
  announce "TODO: check output for worker started messages"
  pid_regex = (1..count).map { '\d+' }.join ', '
  Then "the output should match:", <<-EOF
resque-pool-manager\\[\\d+\\]: Pool contains worker PIDs: \\[#{pid_regex}\\]
  EOF
end

def children_of(ppid)
  ps = `ps -eo ppid,pid,cmd | grep '^ *#{ppid} '`
  ps.split(/\s*\n/).map do |line|
    _, pid, cmd = line.split(/\s+/, 3)
    [pid, cmd]
  end
end

Then "the pool manager should have no child processes" do
  children_of(@background.pid).should have(:no).keys
end

Then /^the pool manager should have (\d+) "([^"]*)" worker child processes$/ do |count, queues|
  children_of(@background.pid).select do |pid, cmd|
    cmd =~ /^resque-\d+.\d+.\d+: Waiting for #{queues}$/
  end.should have(Integer(count)).members
end

Then "the pool manager should finish" do
  # assuming there will not be multiple processes running
  processes.each { |cmd, p| p.stop }
end

Then "the pool manager should report that it is finished" do
  Then "the output should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[$PID]: manager finished
  EOF
end

Then /^the pool manager should report that a "([^"]*)" worker has been reaped$/ do |worker_type|
  And 'the output should match /Reaped resque worker\[\d+\] \(status: 0\) queues: '+ worker_type + '/'
end
