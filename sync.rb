require 'rubygems'
require 'aws/s3'
require 'optparse'
require 'mini_exiftool'

def sync_file(path, remote_root, bucket, options)
  puts "sync_file #{path}" if options[:verbose]
  remote_path = remote_root + "/" + path
  if !AWS::S3::S3Object.exists? remote_path, bucket.name
    do_sync(remote_path, path, bucket, options)
  elsif options[:newer]
    puts "Checking if local file is newer"
    remote_file = AWS::S3::S3Object.find(remote_path, bucket.name)
    remote_file_mtime = DateTime.strptime(remote_file.about["last-modified"], '%a, %d %b %Y %X %Z')
    local_file_mtime = DateTime.parse(File.mtime(path).to_s)
    if local_file_mtime > remote_file_mtime
      do_sync(remote_path, path, bucket, options)
    end
  end
end

def sync_dir(dir, dest_dir, bucket, options)
  puts "sync_dir #{dir}" if options[:verbose]
  Dir.foreach(dir) do|filename|
    next if filename == '.' || filename == '..'
    
    if dir == '.'
      path = filename
    else
      path = dir + "/" + filename
    end

    if File.directory?(path) 
      sync_dir(path, dest_dir, bucket, options)
    elsif !options[:include] || options[:include] && File.fnmatch(options[:include], path) 
      sync_file(path, dest_dir, bucket, options)
    end
  end
end

def do_sync(remote_path, path, bucket, options)
  puts "do_sync #{path}" if options[:verbose]
  if options[:keyword] && !MiniExiftool.new(path).keyword.to_a.include?(options[:keyword])
    return
  end
  
  puts "Syncing file #{path}"
  AWS::S3::S3Object.store(remote_path, open(path), bucket.name) if !options[:dry_run]
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

if ARGV.length != 2
  puts "Usage: sync.rb [options] source dest_dir"
  exit
end

source = ARGV[0]
dest_dir = ARGV[1]

puts "source: #{source}" if options[:verbose]
puts "dest_dir: #{dest_dir}" if options[:verbose]

puts "DRY RUN" if options[:dry_run]
puts "Include #{options[:include]}" if options[:include]

# Assumes keys in env variables:
# export AMAZON_ACCESS_KEY_ID='abcdefghijkl'
# export AMAZON_SECRET_ACCESS_KEY='1234567890'
 
AWS::S3::Base.establish_connection!(
  :access_key_id => ENV['AMAZON_ACCESS_KEY_ID'],
  :secret_access_key => ENV['AMAZON_SECRET_ACCESS_KEY']
)

bucket = AWS::S3::Bucket.find('kevinthorley.com')

if (File.directory? source)
   sync_dir(source, dest_dir, bucket, options)
else
   sync_file(source, dest_dir, bucket, options)
end

