class RigidBodyStateEditor
    
    def self.create_widget(parent = nil)
        form = Vizkit.load(File.join(File.dirname(__FILE__),'rigid_body_state.ui'),parent)
        form.extend Functions
        form.init
        form
    end

    module Functions
        def init
            @rigid_body_state = nil 
            @callback_fct = nil
            @timer = Qt::Timer.new
            start_value.connect(SIGNAL('clicked()')) do
                begin
                    sample = generate_sample(@rigid_body_state)
                    @callback_fct.call(sample) if @callback_fct
                rescue RuntimeError => e
                    pp e
                end
            end
            start_sequence.connect(SIGNAL('clicked()')) do
                if @timer.isActive
                    stop_sequence
                else
                    @step = 0
                    @timer.start(1000/update_frequency.value)
                    start_sequence.text = "Stop Sequence"
                end
            end
            @timer.connect(SIGNAL('timeout()')) do 
                begin
                    sample = generate_sample(@rigid_body_state,@step)
                    @callback_fct.call(sample) if @callback_fct
                    @step += 1
                    if @step > number_of_steps.value 
                        stop_sequence
                    end
                rescue RuntimeError => e
                    pp e
                end
            end
        end

        def stop_sequence
            @timer.stop
            start_sequence.text = "Start Sequence"
        end

        def generate_sample(sample,step=0)
            sample = if @rigid_body_state
                         @rigid_body_state
                     else
                         Types::Base::Samples::RigidBodyState.new
                     end
            sample.time = Time.now
            sample.sourceFrame = source_frame.text
            sample.targetFrame = target_frame.text
            if sample.targetFrame.empty? || sample.sourceFrame.empty?
                Kernel.raise 'Cannot generate sample. Empty soure or target frame!'
            end

            sample.position.x = x_start.value + step*(x_end.value-x_start.value)/number_of_steps.value
            sample.position.y = y_start.value + step*(y_end.value-y_start.value)/number_of_steps.value
            sample.position.z = z_start.value + step*(z_end.value-z_start.value)/number_of_steps.value

            alpha = alpha_start.value+step*(alpha_end.value-alpha_start.value)/number_of_steps.value
            alpha = alpha/180*Math::PI
            beta = beta_start.value+step*(beta_end.value-beta_start.value)/number_of_steps.value
            beta = beta/180*Math::PI
            gamma = gamma_start.value+step*(gamma_end.value-gamma_start.value)/number_of_steps.value
            gamma = gamma/180*Math::PI

            sample.orientation = Eigen::Quaternion.from_euler(Eigen::Vector3.new(alpha,beta,gamma),2,1,0)
            sample
        end

        def default_options
            options = Hash.new
        end

        def options(hash = Hash.new)
            @options ||= default_options
            @options.merge!(hash)
        end

        def edit(rigid_body_state=nil,options=nil,&block)
            if rigid_body_state
                source_frame.setText rigid_body_state.sourceFrame
                target_frame.setText rigid_body_state.targetFrame
                x_start.setValue rigid_body_state.position.x
                y_start.setValue rigid_body_state.position.y
                z_start.setValue rigid_body_state.position.z

                angles = rigid_body_state.orientation.to_euler(2,1,0)
                alpha_start.setValue angles[0]*180/Math::PI
                beta_start.setValue angles[1]*180/Math::PI
                gamma_start.setValue angles[2]*180/Math::PI
            end

            @rigid_body_state = rigid_body_state
            @callback_fct = block
        end
    end
end

Vizkit::UiLoader.register_ruby_widget("RigidBodyStateEditor",RigidBodyStateEditor.method(:create_widget))
Vizkit::UiLoader.register_control_for("RigidBodyStateEditor",Types::Base::Samples::RigidBodyState,:edit)
