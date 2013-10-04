require 'RMagick'
require 'pocolog'

#adds some useful methods to rock base types 
#for example:
#       /base/samples/frame/Frame can now be saved/loaded to/from file
#       frame.to_file
#       frame.from_file
#       frame.display

# adds some methods to frame 
# do not use this functions if you need high performance
# use default_logger and Vizkit widget instead
Typelib.specialize '/base/samples/frame/Frame' do
  def to_file(filename)
    to_rmagick.write(filename)
  end
  def to_rmagick
    w, h = size.width, size.height
    mimage = Magick::Image.new(w, h)
    data = image.to_byte_array
    if frame_mode == :MODE_RGB
      mimage.import_pixels(0, 0, w, h, "RGB", data[8..-1])
    elsif frame_mode == :MODE_GRAYSCALE
      mimage.import_pixels(0, 0, w, h, "I", data[8..-1])
    else
      raise 'Frame Mode is not supproted. Supported modes are MODE_RGB and MODE_GRAYSCALE'
    end 
  end

  #very very slow !!!
  #use Vizkit.default_loader.ImageView widget to display frames
  def display
    to_rmagick.display
  end

  #very very slow !!! 
  def from_file(filename)
    rimage = Magick::Image.read(filename).first
    raise "cannot open file #{filename}" unless rimage
    self.size.height = rimage.rows
    self.size.width = rimage.columns
    self.time = Time.now

    #check if we have a gray image
    if rimage.gray?
      self.image = rimage.export_pixels(0,0,rimage.columns,rimage.rows,"I")
      self.frame_mode = :MODE_GRAYSCALE
      self.pixel_size = 1
      self.row_size = rimage.columns
      self.frame_status = :STATUS_VALID
      self.data_depth = 8
    else
      #we have a rgb image
      self.image = rimage.export_pixels(0,0,rimage.columns,rimage.rows,"RGB")
      self.frame_mode = :MODE_RGB
      self.pixel_size = 3
      self.row_size = rimage.columns*3
      self.frame_status = :STATUS_VALID
      self.data_depth = 8
    end
  end
end
