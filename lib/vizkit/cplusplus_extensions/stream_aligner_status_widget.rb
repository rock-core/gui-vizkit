Vizkit::UiLoader.extend_cplusplus_widget_class "StreamAlignerWidget" do
    def initialize_vizkit_extension
	# we need to enable to QtTypelibExtension, so that the call
	# to updateData is converted properly
	extend Vizkit::QtTypelibExtension
    end

    def update( sample, port )
	updateData( sample )
    end
end

Vizkit::UiLoader.register_widget_for("StreamAlignerWidget","/aggregator/StreamAlignerStatus",:update)
