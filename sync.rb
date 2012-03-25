require 'rubygems'
require 'aws/s3'
require 'optparse'

def sync_file(path, remote_root, bucket, options)
  remote_path = remote_root + "/" + path
  if !AWS::S3::S3Object.exists? remote_path, bucket.name
    puts "file #{path} does not exist on remote server - syncing"
    do_sync(remote_path, path, bucket) if !options[:dry_run]
  else
    remote_file = AWS::S3::S3Object.find(remote_path, bucket.name)
    remote_file_mtime = DateTime.strptime(remote_file.about["last-modified"], '%a, %d %b %Y %X %Z')
    local_file_mtime = DateTime.parse(File.mtime(path).to_s)
    if local_file_mtime > remote_file_mtime
      puts "local file #{path} is newer - syncing"
      do_sync(remote_path, path, bucket) if !options[:dry_run]
    end
  end
end

def sync_dir(dir, dest_dir, bucket, options)
  Dir.foreach(dir) do|filename|
    next if filename == '.' || filename == '..'
    
    if dir == '.'
      path = filename
    else
      path = dir + "/" + filename
    end

    puts "Checking path #{path}"
    if File.directory?(path) 
      puts "file #{path} is a directory - entering directory"
      sync_dir(path, dest_dir, bucket, options)
    else 
      sync_file(path, dest_dir, bucket, options)
    end
  end
end

def do_sync(remote_path, path, bucket)
  AWS::S3::S3Object.store(remote_path, open(path), bucket.name)
end

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: sync.rb [options] source dest_dir"
  options[:dry_run] = false
  opts.on( '-n', '--dry-run', 'Dry run' ) do
       options[:dry_run] = true
     end
end

optparse.parse!


if ARGV.length != 2
  puts "Usage: sync.rb [options] source dest_dir"
  exit
end

source = ARGV[0]
dest_dir = ARGV[1]

puts "source: #{source}"
puts "dest_dir: #{dest_dir}"

puts "DRY RUN" if options[:dry_run]

AWS::S3::Base.establish_connection!(
    :access_key_id     => 'AKIAIVMC57UNL7U5O4WA',
    :secret_access_key => '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'
)

bucket = AWS::S3::Bucket.find('kevinthorley.com')

if (File.directory? source)
   sync_dir(source, dest_dir, bucket, options)
else
   sync_file(source, dest_dir, bucket, options)
end




