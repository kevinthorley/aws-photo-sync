require 'rubygems'
require 'aws/s3'
require 'optparse'
require 'mini_exiftool'

def sync_file(path, remote_root, bucket, options, summary)
  puts "sync_file #{path}" if options[:verbose]
  remote_path = remote_root + "/" + path
  if !AWS::S3::S3Object.exists? remote_path, bucket.name
    do_sync(remote_path, path, bucket, options, summary)
  elsif options[:newer]
    puts "Checking if local file is newer" if options[:verbose]
    remote_file = AWS::S3::S3Object.find(remote_path, bucket.name)
    remote_file_mtime = DateTime.strptime(remote_file.about["last-modified"], '%a, %d %b %Y %X %Z')
    local_file_mtime = DateTime.parse(File.mtime(path).to_s)
    if local_file_mtime > remote_file_mtime
      do_sync(remote_path, path, bucket, options, summary)
    end
  end
end

def sync_dir(dir, dest_dir, bucket, options, summary)
  puts "sync_dir #{dir}" if options[:verbose]
  Dir.foreach(dir) do|filename|
    next if filename == '.' || filename == '..'
    
    if dir == '.'
      path = filename
    else
      path = dir + "/" + filename
    end

    if File.directory?(path)
      sync_dir(path, dest_dir, bucket, options, summary)
    elsif options[:include] && !File.fnmatch(options[:include], path)
      puts "#{path} doesn't match file file pattern #{options[:include]}" if options[:verbose]
      next
    elsif options[:keyword] && !MiniExiftool.new(path).keywords.to_a.include?(options[:keyword])
      puts "#{path} doesn't include keyword #{options[:keyword]}" if options[:verbose]
      next
    else
      sync_file(path, dest_dir, bucket, options, summary)
    end
  end
end

def do_sync(remote_path, path, bucket, options, summary)
  puts "do_sync #{path}" if options[:verbose]
  
  puts "Syncing file #{path}"
  AWS::S3::S3Object.store(remote_path, open(path), bucket.name) if !options[:dry_run]
  summary << path
end

def human_readable(size)
  kilobyte = 2.0**10
  megabyte = 2.0**20
  gigabyte = 2.0**30
  
  case
    when size < kilobyte : "%d bytes" % size
    when size < megabyte : "%.2f KB" % (size / kilobyte)
    when size < gigabyte : "%.2f MB" % (size / megabyte)
    else "%.2f GB" % (size / gigabyte)
  end
end

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: sync.rb [options] source dest_dir"
  options[:dry_run] = false
  opts.on( '-n', '--dry-run', 'Dry run' ) do
    options[:dry_run] = true
  end
  
  options[:verbose] = false
  opts.on( '-v', '--verbose', 'Verbose' ) do
    options[:verbose] = true
  end
  
  options[:include] = nil
  opts.on( '-i', '--include PATTERN', 'Only include files matching the specified pattern' ) do|pattern|
    options[:include] = pattern
  end
  
  options[:newer] = false
  opts.on( '-m', '--newer', 'Newer' ) do
    options[:newer] = true
  end
  
  options[:keyword] = nil
  opts.on( '-k', '--keyword KEYWORD', 'Keyword' ) do |keyword|
    options[:keyword] = keyword
  end
end

optparse.parse!

if ARGV.length != 3
  puts "Usage: sync.rb [options] bucket source dest"
  exit
end

bucket = ARGV[0]
source = ARGV[1]
dest_dir = ARGV[2]

puts "bucket name: #{bucket}" if options[:verbose]
puts "source: #{source}" if options[:verbose]
puts "dest: #{dest_dir}" if options[:verbose]

puts "DRY RUN" if options[:dry_run]
puts "Include #{options[:include]}" if options[:include]
puts "Keyword #{options[:keyword]}" if options[:keyword]

# Assumes keys in env variables:
# export AMAZON_ACCESS_KEY_ID='abcdefghijkl'
# export AMAZON_SECRET_ACCESS_KEY='1234567890'

AWS::S3::Base.establish_connection!(
  :access_key_id => ENV['AMAZON_ACCESS_KEY_ID'],
  :secret_access_key => ENV['AMAZON_SECRET_ACCESS_KEY']
)

bucket = AWS::S3::Bucket.find(bucket)

summary = []

if (File.directory? source)
   sync_dir(source, dest_dir, bucket, options, summary)
else
   sync_file(source, dest_dir, bucket, options, summary)
end

file_size = 0
summary.each do |file|
  file_size += File.size(file)
end

puts "Total number of files: #{summary.length}"
puts "Total size of files: #{human_readable(file_size)}"
