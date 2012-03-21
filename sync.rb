require 'rubygems'
require 'aws/s3'

def sync_file(path, remote_root, bucket)
  remote_path = remote_root + "/" + path
  if !AWS::S3::S3Object.exists? remote_path, bucket.name
    puts "file #{path} does not exist on remote server - syncing"
    AWS::S3::S3Object.store(remote_path, open(path), bucket.name)
  else
    remote_file = AWS::S3::S3Object.find(remote_path, bucket.name)
    remote_file_mtime = DateTime.strptime(remote_file.about["last-modified"], '%a, %d %b %Y %X %Z')
    local_file_mtime = DateTime.parse(File.mtime(path).to_s)
    if local_file_mtime > remote_file_mtime
      puts "local file #{path} is newer - syncing"
      AWS::S3::S3Object.store(remote_path, open(path), bucket.name)
    end
  end
end

def sync_dir(dir, dest_dir, bucket)
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
      sync_dir(path, dest_dir, bucket)
    else 
      sync_file(path, dest_dir, bucket)
    end
  end
end

if ARGV.length == 0
  puts "Usage: sync source_dir dest_dir"
  exit
end

if !File.directory?(ARGV[0])
  puts "source_dir must be a directory"
  exit
end

source_dir = ARGV[0]
dest_dir = ARGV[1]

puts "source_dir: #{source_dir}"
puts "dest_dir: #{dest_dir}"

puts "Contents of source dir"
Dir.foreach(source_dir) do|filename|
  next if filename == '.' || filename == '..'
  puts File.basename(filename)
end

AWS::S3::Base.establish_connection!(
    :access_key_id     => 'AKIAIVMC57UNL7U5O4WA',
    :secret_access_key => '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'
)

bucket = AWS::S3::Bucket.find('kevinthorley.com')

sync_dir(source_dir, dest_dir, bucket)




