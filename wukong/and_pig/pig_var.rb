require 'wukong/and_pig/pig_var'
require 'wukong/and_pig/variable_inflections'
require 'wukong/and_pig/pig_var/file_methods'

module Wukong
  module AndPig

    class PigVar
      cattr_accessor :default_path
      attr_accessor  :name, :klass, :path_base
      def initialize name, klass, path_base=nil
        self.name       = name.relationize.underscore
        self.klass      = klass
        self.path_base = path_base || self.class.default_path
      end

      # ===========================================================================
      #
      # As a variable
      #

      # variable's name in relation form
      def relation
        name.relationize
      end
      alias_method :relationize, :relation

      def path
        "%s/%s" % [path_base, name]
      end

      def emit cmd
        puts cmd + ';'
        self
      end

      def emit_set var, cmd
        emit "%-23s\t= %s" % [var, cmd]
      end

      def illustrate
        emit "ILLUSTRATE #{relation}"
      end

      # ===========================================================================
      #
      # Options
      #

      def parallelize! str, options
        str << " PARALLEL #{options[:parallel]}" if options[:parallel]
      end


      # ===========================================================================
      #
      # As a variable
      #

      # http://wiki.apache.org/pig-data/attachments/FrontPage/attachments/plrm.htm#_DISTINCT
      def distinct dest_rel, *args
        options = args.extract_options!
        str = "DISTINCT #{relation}"
        parallelize! str, options
        emit_set dest_rel.relationize, str
        PigVar.new dest_rel, klass
      end

      # http://wiki.apache.org/pig-data/attachments/FrontPage/attachments/plrm.htm#_DISTINCT
      def group dest_rel, *args
        options = args.extract_options!
        by      = case
                  when options[:by] == :all then 'ALL'
                  when options[:by]         then "BY #{[options[:by]].flatten.join(", ")}"
                  else                           "BY #{args.join(", ")}"
                  end
        str     = "GROUP #{relation} #{by}"
        parallelize! str, options
        emit_set dest_rel.relationize, str
        PigVar.new dest_rel, klass
      end

      def foreach dest_rel, *args
        case
        when args.length == 1 && args[0].is_a?(String) then gen_string = args[0]
        else gen_string = 'GENERATE ' + args.join(", ")
        end
        emit_set dest_rel.relationize, "FOREACH #{relation} #{gen_string}"
        PigVar.new dest_rel, klass
      end
      alias_method :generate, :foreach

      # ===========================================================================
      #
      # Synthesized Expressions
      #
      REL_COUNTERS = { }
      def temp_rel rel
        REL_COUNTERS[rel] ||= 0
        REL_COUNTERS[rel]  += 1
        "#{rel}_#{REL_COUNTERS[rel]}"
      end

      def count_distinct dest_rel, attr, group_by
        distincted =
          generate(temp_rel(dest_rel), attr).
          distinct(temp_rel(dest_rel), :parallel => 10)
        distincted.
          group(   temp_rel(dest_rel), group_by).
          foreach( dest_rel,  "GENERATE COUNT(#{distincted.relation}.#{attr}) AS n_#{attr}")
      end

      #
      # Group a relation into bins, and return the counts for each bin
      # * dest_rel - Relation to store
      #   {bin,
      #
      def histogram dest_rel, bin_attr, bin_expr=nil
        bin_expr ||= bin_attr
        bin_name   = "#{bin_attr}_bin"
        binned     = foreach(temp_rel(dest_rel), "GENERATE #{bin_expr} AS #{bin_name}")
        binned.      group(  temp_rel(dest_rel), :by => bin_name).
                     foreach(         dest_rel,  "GENERATE group AS #{bin_name}, COUNT(#{binned.relation}) AS #{bin_attr}_count")
      end

    end
  end
end

