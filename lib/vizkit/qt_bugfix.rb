

#this solves a problem this Qt::Object.connecet and block or method invokation
#the problem occures when the program needs more memory which results
#in accidently deleting all connections assigned to a block or method.
module Qt
  def Internal.signal_connect(src, signal, block)
          @@storage ||= Array.new
          args = (signal =~ /\((.*)\)/) ? $1 : ""
          signature = Qt::MetaObject.normalizedSignature("invoke(%s)" % args).to_s
          @@storage <<  Qt::SignalBlockInvocation.new(src, block, signature)
          return Qt::Object.connect(	src,
                                                                  signal,
                                                                  @@storage.last,
                                                                  SLOT(signature) )
  end

  def Internal.connect(src, signal, target, block)
          @@storage ||= Array.new
          args = (signal =~ /\((.*)\)/) ? $1 : ""
          @@storage <<  Qt::BlockInvocation.new(target, block, signature)
          signature = Qt::MetaObject.normalizedSignature("invoke(%s)" % args).to_s
          return Qt::Object.connect(	src,
                                                                  signal,
                                                                  @@storage.last,
                                                                  SLOT(signature) )
  end

  def Internal.method_connect(src, signal, target, method)
          @@storage ||= Array.new
          signal = SIGNAL(signal) if signal.is_a?Symbol
          args = (signal =~ /\((.*)\)/) ? $1 : ""
          signature = Qt::MetaObject.normalizedSignature("invoke(%s)" % args).to_s
          @@storage << Qt::MethodInvocation.new(target, method, signature)
          return Qt::Object.connect(  src,
                                                                  signal,
                                                                  @@storage.last,
                                                                  SLOT(signature) )
  end

  def Internal.single_shot_timer_connect(intertal, target, block)
          @@storage ||= Array.new
          @@storage << Qt::BlockInvocation.new(target, block, "invoke()")
          return Qt::Timer.singleShot(	interval,
                                                                          @@storage.last,
                                                                          SLOT("invoke()") )
  end

end
