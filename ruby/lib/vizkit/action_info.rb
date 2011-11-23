# An array with 4 elements storing useful information for context menu actions.
# This data structure is mainly used in port visualization applications.
class ActionInfo < Array
    WIDGET_NAME = 0
    TASK_NAME = 1
    PORT_NAME = 2
    PORT_TYPE = 3

    def initialize
        super(4)
    end
end
