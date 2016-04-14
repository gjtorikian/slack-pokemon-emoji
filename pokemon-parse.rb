require 'base64'
require 'json'
require 'yaml'
require 'tmpdir'
require 'fileutils'

res = `convert`
if res.nil?
  raise "ImageMagick (and convert) must be installed for this to work."
end

BASE64_REGEXP = %r{'data:image/png;base64,(.+)?'}
summaries = JSON.parse(File.read('./monsterSummaries.json'))

FileUtils.mkdir_p('images')

yaml_data = { 'title' => 'pokemon', 'emojis' => [] }

File.read('./sprites.css').lines.each_with_index do |line, i|
  # next if i > 5
  data = line.match(BASE64_REGEXP).captures.first
  name = summaries[i]['name'].downcase
  original_file = "#{name}_original.png"
  File.open(original_file, 'wb') do |f|
    f.write(Base64.decode64(data))
  end

  resized_file = File.join('.', 'images', "#{name}_resized.png")

  # Slack has a max emoji size of 64k. Many gifs are larger than that at
  # 128x128, so try progressively smaller sizes.
  tries = 0
  scale = 130
  while tries == 0 || (File.size(resized_file) > 64_000) && tries < 30
    scale = scale - 2
    `convert #{original_file} -resize "#{scale}x#{scale}^" -gravity center -crop #{scale}x#{scale}+0+0 +repage #{resized_file}`
    tries = tries + 1
  end

  if (File.size(resized_file) > 64_000)
    puts "Sorry, couldn't get this file resized below 64k for slack. I went down to #{scale}x#{scale}."
    exit 1
  else
    FileUtils.rm(original_file)
  end

  yaml_data['emojis'] << { 'name': name, 'src': resized_file }
end

File.write('pokemon_emojipack.yml', yaml_data.to_yaml)
