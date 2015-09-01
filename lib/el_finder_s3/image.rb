require 'rubygems'
require 'shellwords'
require 'image_size'
require 'mini_magick'

module ElFinderS3

  # Represents default image handler.
  # It uses *mogrify* to resize images and *convert* to create thumbnails.
  class Image

    def self.size(pathname)
      return nil unless File.exist?(pathname)
      s = ::ImageSize.new(File.open(pathname)).size.to_s
      s = nil if s.empty?
      return s
    end

    def self.resize(pathname, options = {})
      return nil unless File.exist?(pathname)
      system(::Shellwords.join(['mogrify', '-resize', "#{options[:width]}x#{options[:height]}!", pathname.to_s]))
    end

    # of self.resize

    def self.thumbnail(imgSourcePath, dst, options = {})
      image = MiniMagick::Image.open(imgSourcePath)
      image.combine_options do |c|
        c.thumbnail "#{options[:width]}x#{options[:height]}"
        c.background 'white'
        c.gravity 'center'
        c.extent "#{options[:width]}x#{options[:height]}"
      end
      dst.write(image)
    end # of self.resize

  end # of class Image

end # of module ElFinderS3
