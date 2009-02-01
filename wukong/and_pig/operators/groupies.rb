# -*- coding: utf-8 -*-
#
# The FOREACH relational operator
#
module Wukong
  module AndPig
    class PigVar

      #===========================================================================
      #
      # GROUP and COGROUP
      #

      def self.by_clause by_spec
        case by_spec
        when Array      then 'BY ' + by_spec.join(", ")
        when :all       then 'ALL'
        when Symbol     then 'BY ' + by_spec.to_s
        when String     then by_spec
        when Hash       then by_clause(by_spec[:by])
        else raise "Don't know how to group on #{by_spec.inspect}"
        end
      end

      def l_klass_for_group group_by
        # TypedStruct.new([
        #     :group,     types_for_fields(group_by),
        #     relation,   self.klass
        #     ])
        Struct.new(:group, relation)
      end

      #
      # COGROUP - Groups the data in two or more relations.
      #
      # == Syntax
      #
      #   alias  = COGROUP alias1 BY field_alias [INNER | OUTER],
      #                    aliasN BY field_alias [INNER | OUTER] [PARALLEL n] ;
      #
      # == Structure
      #
      #   { group, <structure of alias1>, <structure of alias2>, ... }
      #
      # == Terms
      #
      # * alias         The name a relation.
      #
      # * field_alias The name of one or more fields in a relation.  If multiple
      #                 fields are specified, separate with commas and enclose
      #                 in parentheses. For example, X = COGROUP A BY (f1, f2);
      #
      #                 The number of fields specified in each BY clause must
      #                 match. For example, X = COGROUP A BY (a1,a2,a3), B BY
      #                 (b1,b2,b3);
      #
      # * BY            Keyword.
      #
      # * INNER         Eliminate NULLs on that grouping
      # * OUTER         Do not eliminate NULLs on that grouping (default)
      #
      # * PARALLEL n -- Increase the parallelism of a job by specifying the
      #                 number of reduce tasks, n. The optimal number of
      #                 parallel tasks depends on the amount of memory on each
      #                 node and the memory required by each of the tasks. To
      #                 determine n, use the following as a general guideline:
      #
      #                     n = (nr_nodes - 1) * 0.45 * nr_GB
      #
      #                 where nr_nodes is the number of nodes used and nr_GB is
      #                 the amount of physical memory on each node.
      #
      #                 Note the following:
      #                 - Parallel only affects the number of reduce tasks. Map
      #                   parallelism is determined by the input file, one map
      #                   for each HDFS block.
      #                 - If you don’t specify parallel, you still get the same
      #                   map parallelism but only one reduce task.
      #
      # == Usage
      #
      # The COGOUP operator groups the data in two or more relations based on
      # the common field values.
      #
      # Note: The COGROUP and JOIN operators perform similar functions. COGROUP
      # creates a nested set of output tuples while JOIN creates a flat set of
      # output tuples with NULLs eliminated.
      #
      # == Examples
      #
      # Suppose we have two relations, A and B.
      #
      # A: (owner:chararray, pet:chararray)
      # ---------------
      # (Alice, cat)
      # (Alice, goldfish)
      # (Alice, turtle)
      # (Bob,   cat)
      # (Bob,   dog)
      #
      # B: (friend1:chararray, friend2:charrarray)
      # ---------------------
      # (Cindy, Alice)
      # (Mark, Alice)
      # (Paul, Bob)
      # (Paul, Jane)
      #
      # In this example tuples are co-grouped using field “owner” from relation
      # A and field “friend2” from relation B as the key fields. The DESCRIBE
      # operator shows the schema for relation X, which has two fields, "group"
      # and "A" (for an explanation, see GROUP).
      #
      #   X = COGROUP A BY owner, B BY friend2;
      #   DESCRIBE X;
      #
      #    X: {group: chararray,
      #        A: {owner:   chararray,pet:     chararray},
      #        B: {friend1: chararray,friend2: chararray}}
      #
      # Relation X looks like this. A tuple is created for each unique key
      # field. The tuple includes the key field and two bags. The first bag is
      # the tuples from the first relation with the matching key field. The
      # second bag is the tuples from the second relation with the matching key
      # field. If no tuples match the key field, the bag is empty.
      #
      #   (Alice, {(Alice, turtle), (Alice, goldfish), (Alice, cat)},
      #           {(Cindy, Alice), (Mark, Alice)})
      #   (Bob,   {(Bob, dog), (Bob, cat)},
      #           {(Paul, Bob)})
      #   (Jane,  {},
      #           {(Paul, Jane)})
      #
      # In this example tuples are co-grouped and the INNER keyword is used to
      # ensure that only bags with at least one tuple are returned.
      #
      #   X = COGROUP A BY owner INNER, B BY friend2 INNER;
      #
      # Relation X looks like this.
      #
      #   (Alice, {(Alice, turtle), (Alice, goldfish), (Alice, cat)},
      #           {(Cindy, Alice), (Mark, Alice)})
      #   (Bob,   {(Bob, dog), (Bob, cat)},
      #           {(Paul, Bob)})
      #
      # In this example tuples are co-grouped and the INNER keyword is used
      # asymmetrically on only one of the relations.
      #
      #   X = COGROUP A BY owner, B BY friend2 INNER;
      #
      # Relation X looks like this.
      #
      #   (Alice, {(Alice, turtle), (Alice, goldfish), (Alice, cat)},
      #           {(Cindy, Alice), (Mark, Alice)})
      #   (Bob,   {(Bob, dog), (Bob, cat)},
      #           {(Paul, Bob)})
      #   (Jane,  {},
      #           {(Paul, Jane)})
      #
      #
      def group group_by
        l_klass   = l_klass_for_group group_by
        by_clause = self.class.by_clause(group_by)
        new_in_chain l_klass, "GROUP #{relation} #{by_clause}"
      end

      #
      # COGROUP pig expression:
      #   UserPosts = COGROUP Posts BY user_id, Users BY user_id ;
      #
      def self.cogroup *args
        # FIXME
        l_klass = args.first.klass
        pred = in_groups_of(args, 2).map do |relation, group_by|
          "%s %s" % [relation.relation, by_clause(group_by)]
        end
        new l_klass, l_klass.to_s, 1, "COGROUP #{pred.join(", ")}"
      end

      def cogroup *args
        self.class.cogroup self, *args
      end


      # ===========================================================================
      #
      # JOIN
      #
      def join
        new_in_chain klass, "JOIN #{relation}"
      end

    end
  end
end
