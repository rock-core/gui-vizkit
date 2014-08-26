begin
require 'ropencv'
rescue
    raise "No gem ropencv found. Please install ropencv via 'gem install ropencv'"
end
require 'pocolog'

#adds some useful methods to rock base types 
#for example:
#       /base/samples/frame/Frame can now be saved/loaded to/from file
#       frame.to_file
#       frame.from_file
Typelib.specialize '/base/samples/frame/Frame' do
    def to_file(filename)
        OpenCV::Cv::imwrite(self.to_mat,filename)
    end

    def to_mat
        channels = if self.frame_mode == :MODE_UNDEFINED
                       0
                   elsif(self.frame_mode == :MODE_BAYER)
                       1
                   elsif(self.frame_mode == :MODE_BAYER_RGGB)
                       1
                   elsif(self.frame_mode == :MODE_BAYER_BGGR)
                       1
                   elsif(self.frame_mode == :MODE_BAYER_GBRG)
                       1
                   elsif(self.frame_mode == :MODE_BAYER_GRBG)
                       1
                   elsif(self.frame_mode == :MODE_GRAYSCALE)
                       1
                   elsif(self.frame_mode == :MODE_UYVY)
                       1
                   elsif(self.frame_mode == :MODE_RGB)
                       3
                   elsif(self.frame_mode == :MODE_BGR)
                       3
                   elsif(self.frame_mode == :MODE_RGB32)
                       4
                   else
                       raise "Unsupported frame_mode";
                   end
        type = if(channels == 1)
                   if(self.pixel_size == 1)
                       OpenCV::Cv::CV_8UC1;
                   elsif(self.pixel_size == 2)
                       OpenCV::Cv::CV_16UC1;
                   else
                       raise "Unsupported pixel_size"
                   end
               elsif channels == 3
                   if(self.pixel_size == 3)
                       OpenCV::Cv::CV_8UC3;
                   elsif(self.pixel_size == 6)
                       OpenCV::Cv::CV_16UC3;
                   else
                       raise "Unsupported pixel_size"
                   end
               else
                    raise "Unsupported number of channels"
               end
        p = FFI::Pointer.new(:char,self.image.contained_memory_id)
        OpenCV::Cv::Mat.new(self.size.height,self.size.width,type,p)
    end

    def from_mat(mat)
        if(mat.type == OpenCV::Cv::CV_8UC1)
            self.frame_mode = :MODE_GRAYSCALE
            self.pixel_size = 1
            self.row_size = mat.cols
            self.frame_status = :STATUS_VALID
            self.data_depth = 8
        elsif(mat.type == OpenCV::Cv::CV_8UC3)
            self.frame_mode = :MODE_RGB
            self.pixel_size = 3
            self.row_size = mat.cols*3
            self.frame_status = :STATUS_VALID
            self.data_depth = 8
        else
            raise "Unsupported mat type"
        end
        self.size.height = mat.rows
        self.size.width = mat.cols
        self.time = Time.now
        self.image.raw_memcpy(mat.data.address,mat.total*self.pixel_size)
    end
end
