require 'rubygems'
require 'active_support'


String.class_eval do
  #
  # Generate relation name from a handle
  #
  def relationize() camelize end
end
Symbol.class_eval do
  #
  # Generate relation name from a handle
  #
  def relationize
    to_s.relationize
  end
end

class << Integer ; def typify() 'int'           end ; end
class << Bignum  ; def typify() 'long'          end ; end
class << String  ; def typify() 'chararray'     end ; end
class << Symbol  ; def typify() self            end ; end
